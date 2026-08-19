import Charts
import SwiftData
import SwiftUI

struct WeightLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator
    @Environment(\.calendar) private var calendar
    @Query(sort: \WeightEntry.date, order: .reverse) private var rawEntries: [WeightEntry]
    @Query private var profiles: [UserProfile]

    private let onViewProgress: () -> Void

    @State private var editorPresentation: WeightEditorPresentation?
    @State private var pendingDeletion: WeightEntry?
    @State private var deletedMeasurements: [WeightMeasurementSnapshot] = []
    @State private var operationError: WeightLogOperationError?

    init(onViewProgress: @escaping () -> Void = {}) {
        self.onViewProgress = onViewProgress
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var validTargetWeight: Double? {
        guard let targetWeight = profile?.targetWeight,
              targetWeight.isFinite,
              targetWeight > 0 else {
            return nil
        }
        return targetWeight
    }

    private var summaryProgress: WeightProgress {
        ProgressHistory.weightProgress(
            entries: rawEntries.map {
                WeightProgressPoint(
                    date: $0.date,
                    kilograms: $0.kilograms,
                    stableID: $0.stableID,
                    sequence: $0.sequence
                )
            },
            targetWeight: validTargetWeight,
            limit: 7,
            now: .now
        )
    }

    private var sections: [WeightLogSection] {
        Dictionary(grouping: rawEntries) { calendar.startOfDay(for: $0.date) }
            .map { date, entries in
                WeightLogSection(
                    date: date,
                    entries: entries.sorted { left, right in
                        WeightHistory.isNewer(
                            date: left.date,
                            sequence: left.sequence,
                            stableID: left.stableID,
                            than: right.date,
                            sequence: right.sequence,
                            stableID: right.stableID
                        )
                    }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private var undoMessage: String {
        deletedMeasurements.count == 1 ? "Weight deleted" : "Weights deleted"
    }

    var body: some View {
        NavigationStack {
            List {
                if sections.isEmpty {
                    ContentUnavailableView {
                        Label("No weights recorded", systemImage: "scalemass")
                    } description: {
                        Text("Record your first weight to start tracking changes.")
                    } actions: {
                        Button(action: beginRecording) {
                            Text("Record Weight")
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .accessibilityIdentifier("weight-log-empty")
                } else {
                    if !summaryProgress.points.isEmpty {
                        Section("Summary") {
                            weightSummary
                            if summaryProgress.points.count > 1 {
                                WeightLogSummaryChart(
                                    progress: summaryProgress,
                                    targetWeight: validTargetWeight
                                )
                            } else {
                                Text("Add another reading to see your trend.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("weight-log-chart-prompt")
                            }
                            Button(action: onViewProgress) {
                                HStack {
                                    Text("View full trends")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("weight-view-progress")
                        }
                    }

                    ForEach(sections) { section in
                        Section(section.date.formatted(.dateTime.weekday(.wide).month().day().year())) {
                            ForEach(section.entries) { entry in
                                weightRow(entry)
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("weight-log")
            .navigationTitle("Weight Log")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !deletedMeasurements.isEmpty {
                    HStack {
                        Text(undoMessage)
                            .accessibilityLabel(undoMessage)
                        Spacer()
                        Button("Undo", action: undoDeletion)
                            .accessibilityIdentifier("weight-undo")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: beginRecording) {
                        Image(systemName: "plus")
                    }
                    .controlSize(.large)
                    .accessibilityIdentifier("record-weight-button")
                    .accessibilityLabel("Record Weight")
                }
            }
            .sheet(item: $editorPresentation) { presentation in
                WeightEditor(
                    entry: presentation.entry,
                    defaultKilograms: presentation.defaultKilograms,
                    now: .now
                ) { kilograms, date in
                    try saveWeight(
                        presentation.entry,
                        kilograms: kilograms,
                        date: date
                    )
                }
            }
            .alert(
                "Delete this weight?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    pendingDeletion = nil
                }
                Button("Delete", role: .destructive) {
                    if let pendingDeletion {
                        deleteWeight(pendingDeletion)
                    }
                    self.pendingDeletion = nil
                }
                .accessibilityIdentifier("confirm-delete-weight")
            } message: {
                Text("This weight can be restored with Undo after deletion.")
            }
            .alert(operationError?.title ?? "", isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(operationError?.message ?? "Unknown error")
            }
        }
    }

    private var weightSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let currentWeight = summaryProgress.current {
                Text(weightText(currentWeight))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            Text(recentChangeDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(targetDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weightSummaryAccessibilityLabel)
    }

    private var recentChangeDescription: String {
        let count = summaryProgress.points.count
        guard let change = summaryProgress.periodChange else {
            return "1 recorded reading"
        }
        guard abs(change) >= 0.05 else {
            return "No change over last \(count) readings"
        }
        let sign = change > 0 ? "+" : "−"
        return "\(sign)\(abs(change).formatted(.number.precision(.fractionLength(1)))) kg over last \(count) readings"
    }

    private var targetDescription: String {
        guard let targetWeight = validTargetWeight,
              let distance = summaryProgress.targetDistance else {
            return "No target set"
        }
        let target = "Target \(weightText(targetWeight))"
        if abs(distance) < 0.05 {
            return "At target • \(target)"
        }
        if distance > 0 {
            return "\(distance.formatted(.number.precision(.fractionLength(1)))) kg below target • \(target)"
        }
        return "\(abs(distance).formatted(.number.precision(.fractionLength(1)))) kg above target • \(target)"
    }

    private var weightSummaryAccessibilityLabel: String {
        guard let current = summaryProgress.current else { return "Weight summary unavailable" }
        return "Current \(weightText(current)). \(recentChangeDescription). \(targetDescription)."
    }

    @ViewBuilder
    private func weightRow(_ entry: WeightEntry) -> some View {
        Button {
            editorPresentation = WeightEditorPresentation(entry: entry)
        } label: {
            HStack {
                Text(weightText(entry.kilograms))
                    .font(.body.weight(.semibold))
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("weight-log-row")
        .accessibilityLabel("Weight measurement")
        .accessibilityValue("\(weightText(entry.kilograms)), \(entry.date.formatted(date: .complete, time: .shortened))")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @MainActor
    private func beginRecording() {
        editorPresentation = WeightEditorPresentation(
            entry: nil,
            defaultKilograms: WeightEntryDraft.defaultKilograms(
                measurements: rawEntries.map {
                    WeightProgressPoint(
                        date: $0.date,
                        kilograms: $0.kilograms,
                        stableID: $0.stableID,
                        sequence: $0.sequence
                    )
                },
                profileCurrentWeight: validProfileCurrentWeight
            )
        )
    }

    private var validProfileCurrentWeight: Double? {
        guard let currentWeight = profile?.currentWeight,
              currentWeight.isFinite,
              currentWeight > 0 else {
            return nil
        }
        return currentWeight
    }

    @MainActor
    private func saveWeight(
        _ entry: WeightEntry?,
        kilograms: Double,
        date: Date
    ) throws {
        guard let mutationCoordinator else {
            throw PlanEvidenceMutationError.coordinatorUnavailable
        }
        let store = WeightMeasurementStore(coordinator: mutationCoordinator)
        if let entry {
            try store.update(entry, kilograms: kilograms, date: date)
        } else {
            try store.add(kilograms: kilograms, date: date)
        }
        rescheduleReminders()
    }

    @MainActor
    private func deleteWeight(_ entry: WeightEntry) {
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            deletedMeasurements.append(
                try WeightMeasurementStore(coordinator: mutationCoordinator).delete(entry)
            )
            rescheduleReminders()
        } catch {
            operationError = .delete
        }
    }

    @MainActor
    private func undoDeletion() {
        guard let deletedMeasurement = deletedMeasurements.last else { return }

        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            _ = try WeightMeasurementStore(coordinator: mutationCoordinator).restore(deletedMeasurement)
            deletedMeasurements.removeLast()
            rescheduleReminders()
        } catch {
            operationError = .restore
        }
    }

    private func rescheduleReminders() {
        TodayExternalSurfaceCoordinator.synchronize(
            modelContext: modelContext,
            calendar: calendar
        )
    }

    private func weightText(_ kilograms: Double) -> String {
        "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
    }
}

private enum WeightLogOperationError {
    case delete
    case restore

    var title: String {
        switch self {
        case .delete: "Could not delete weight"
        case .restore: "Could not restore weight"
        }
    }

    var message: String {
        switch self {
        case .delete: "Your weight could not be deleted. Please try again."
        case .restore: "Your weight could not be restored. Please try again."
        }
    }
}

private struct WeightEditorPresentation: Identifiable {
    let id = UUID()
    let entry: WeightEntry?
    let defaultKilograms: Double

    init(entry: WeightEntry?, defaultKilograms: Double = 70) {
        self.entry = entry
        self.defaultKilograms = defaultKilograms
    }
}

private struct WeightLogSection: Identifiable {
    let date: Date
    let entries: [WeightEntry]

    var id: Date { date }
}

private struct WeightLogSummaryChart: View {
    let progress: WeightProgress
    let targetWeight: Double?

    var body: some View {
        if let domain = progress.domain {
            VStack(spacing: 4) {
                Chart {
                    ForEach(Array(progress.points.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.kilograms)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.kilograms)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(24)
                    }

                    if let targetWeight, targetWeight.isFinite, targetWeight > 0 {
                        RuleMark(y: .value("Target", targetWeight))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .chartYScale(domain: domain)
                .chartXScale(range: .plotDimension(padding: 16))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                        AxisGridLine()
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                    }
                }
                .frame(height: 126)

                HStack {
                    if let firstDate = progress.points.first?.date {
                        Text(firstDate, format: .dateTime.month(.abbreviated).day())
                    }
                    Spacer()
                    if let firstDate = progress.points.first?.date,
                       let lastDate = progress.points.last?.date,
                       !Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
                        Text(lastDate, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityIdentifier("weight-log-chart")
        }
    }

    private var accessibilitySummary: String {
        let count = progress.points.count
        let readingLabel = count == 1 ? "reading" : "readings"
        let current = progress.current.map {
            "Current \($0.formatted(.number.precision(.fractionLength(1)))) kilograms."
        } ?? ""
        let target: String
        if let targetWeight {
            target = " Target \(targetWeight.formatted(.number.precision(.fractionLength(1)))) kilograms."
        } else {
            target = ""
        }
        return "Weight trend for last \(count) raw \(readingLabel). \(current)\(target)"
    }
}

@MainActor
private struct WeightEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @FocusState private var weightFieldIsFocused: Bool
    @State private var kilogramsText: String
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var errorMessage: String?

    private let isEditing: Bool
    private let originalTimestamp: Date?
    private let onSave: @MainActor (Double, Date) throws -> Void

    private struct Adjustment: Identifiable {
        let title: String
        let delta: Double
        let identifier: String

        var id: String { identifier }
    }

    private let adjustments = [
        Adjustment(title: "−1", delta: -1, identifier: "weight-decrease-1"),
        Adjustment(title: "−0.1", delta: -0.1, identifier: "weight-decrease-0.1"),
        Adjustment(title: "+0.1", delta: 0.1, identifier: "weight-increase-0.1"),
        Adjustment(title: "+1", delta: 1, identifier: "weight-increase-1")
    ]

    init(
        entry: WeightEntry?,
        defaultKilograms: Double,
        now: Date,
        onSave: @escaping @MainActor (Double, Date) throws -> Void
    ) {
        let measurementDate = entry?.date ?? now
        _kilogramsText = State(initialValue: Self.weightInput(entry?.kilograms ?? defaultKilograms))
        _selectedDate = State(initialValue: measurementDate)
        _selectedTime = State(initialValue: measurementDate)
        isEditing = entry != nil
        originalTimestamp = entry?.date
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    VStack(spacing: 16) {
                        HStack {
                            TextField("Weight", text: $kilogramsText)
                                .keyboardType(.decimalPad)
                                .focused($weightFieldIsFocused)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("weight-value")
                                .accessibilityLabel("Weight in kilograms")
                                .accessibilityValue(kilogramsText)
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }

                        adjustmentControls
                    }
                    .padding(.vertical, 4)
                }

                Section("When") {
                    DatePicker("Date", selection: $selectedDate, in: ...Date.now, displayedComponents: .date)
                        .accessibilityIdentifier("weight-date")
                        .accessibilityLabel("Weight date")
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("weight-time")
                        .accessibilityLabel("Weight time")
                }
            }
            .navigationTitle(isEditing ? "Edit Weight" : "Record Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("weight-save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        weightFieldIsFocused = false
                    }
                    .accessibilityIdentifier("weight-keyboard-done")
                }
            }
        }
        .accessibilityIdentifier("weight-editor")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Could not save weight", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var adjustmentControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(adjustments) { adjustment in
                    adjustmentButton(adjustment)
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(adjustments) { adjustment in
                    adjustmentButton(adjustment)
                }
            }
        }
    }

    private func adjustmentButton(_ adjustment: Adjustment) -> some View {
        let adjusted = parsedKilograms().flatMap {
            WeightEntryDraft.adjustedKilograms($0, by: adjustment.delta)
        }
        let action = adjustment.delta < 0 ? "Decrease" : "Increase"
        let magnitude = abs(adjustment.delta)
        let unit = magnitude == 1 ? "kilogram" : "kilograms"

        return Button {
            guard let adjusted else { return }
            kilogramsText = adjusted.formatted(
                .number
                    .precision(.fractionLength(1))
                    .locale(locale)
            )
            errorMessage = nil
        } label: {
            Text(adjustment.title)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, minHeight: 44)
        .disabled(adjusted == nil)
        .accessibilityLabel("\(action) weight by \(magnitude.formatted(.number.locale(locale))) \(unit)")
        .accessibilityValue("Current \(kilogramsText) kilograms")
        .accessibilityHint("Date and time stay unchanged.")
        .accessibilityIdentifier(adjustment.identifier)
    }

    private func save() {
        guard let kilograms = parsedKilograms() else {
            errorMessage = "Enter a valid weight in kilograms."
            return
        }

        do {
            let timestamp = try WeightHistory.combinedTimestamp(
                date: selectedDate,
                time: selectedTime,
                originalTimestamp: originalTimestamp,
                calendar: calendar,
                now: .now
            )
            try onSave(kilograms, timestamp)
            dismiss()
        } catch WeightHistoryError.invalidWeight {
            errorMessage = "Weight must be greater than zero."
        } catch WeightHistoryError.futureTimestamp {
            errorMessage = "Weight time cannot be in the future."
        } catch {
            errorMessage = "Your weight could not be saved. Please try again."
        }
    }

    private func parsedKilograms() -> Double? {
        guard let decimal = Decimal(string: kilogramsText, locale: locale) else { return nil }
        let kilograms = NSDecimalNumber(decimal: decimal).doubleValue
        return WeightHistory.isValidWeight(kilograms) ? kilograms : nil
    }

    private static func weightInput(_ kilograms: Double) -> String {
        kilograms.formatted(.number.precision(.fractionLength(1)))
    }
}

#if DEBUG
#Preview("Weight Log") {
    WeightLogView(onViewProgress: {})
        .previewPlanEvidenceContainer(PreviewData.makeContainer())
}

#Preview("Weight Log — Empty") {
    WeightLogView(onViewProgress: {})
        .previewPlanEvidenceContainer(PreviewData.makeContainer(state: .empty))
}

#Preview("Weight Editor") {
    WeightEditor(
        entry: nil,
        defaultKilograms: 71.2,
        now: .now,
        onSave: { _, _ in }
    )
}
#endif
