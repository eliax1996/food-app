import Charts
import SwiftUI

enum HistoryMetric: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case weight = "Weight"

    var id: String { rawValue }
}

struct CalorieProgressChart: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let progress: CalorieProgress
    let diaryDays: [CalorieDiaryDay]

    @State private var chartSelectionDate: Date?
    @State private var selectedDate: Date?

    private var chartMaximum: Double {
        let values = progress.summaries.map { Double($0.calories) }
        let goals = progress.goalContexts.compactMap { $0.calories.map(Double.init) }
        return max(values.max() ?? 0, goals.max() ?? 0, 1) * 1.15
    }

    private var selectedSummary: DailyCalorieSummary? {
        guard let selectedDate else { return nil }
        return progress.summaries.first { $0.date == selectedDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(progress.summaries, id: \.date) { summary in
                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Calories", summary.calories)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(4)
                }

                ForEach(progress.goalContexts, id: \.date) { context in
                    if let goal = context.calories {
                        LineMark(
                            x: .value("Goal date", context.date, unit: .day),
                            y: .value("Historical daily goal", goal),
                            series: .value("Goal series", "Historical goal")
                        )
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .interpolationMethod(.stepEnd)
                    }
                }

                if let selectedSummary {
                    RuleMark(x: .value("Selected day", selectedSummary.date))
                        .foregroundStyle(.primary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("Selected day", selectedSummary.date),
                        y: .value("Selected calories", selectedSummary.calories)
                    )
                    .foregroundStyle(.primary)
                    .symbolSize(100)
                }
            }
            .chartYScale(domain: 0...chartMaximum)
            .chartXAxis {
                AxisMarks(values: calorieXAxisValues) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine()
                    AxisValueLabel(format: IntegerFormatStyle<Int>.number.notation(.compactName))
                }
            }
            .chartXSelection(value: $chartSelectionDate)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectNearest(
                                        using: proxy,
                                        location: value.location,
                                        in: geometry
                                    )
                                }
                                .onEnded { value in
                                    selectNearest(
                                        using: proxy,
                                        location: value.location,
                                        in: geometry
                                    )
                                }
                        )
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(calorieAccessibilitySummary)
            .accessibilityValue(calorieAccessibilityValue)
            .accessibilityHint("Swipe up or down to cycle recorded days.")
            .accessibilityAdjustableAction { direction in
                adjustSelection(direction)
            }
            .accessibilityIdentifier("progress-calorie-chart")

            if let selectedSummary {
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected day")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(selectedSummary.date.formatted(date: .complete, time: .omitted))
                            .accessibilityIdentifier("progress-calorie-selected-date")
                        Text("\(selectedSummary.calories.formatted(.number)) kcal")
                            .accessibilityIdentifier("progress-calorie-selected-calories")
                        Text(calorieGoalText(for: selectedSummary.date))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("progress-calorie-selected-goal")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(calorieSelectionAccessibilityLabel)
                    .accessibilityIdentifier("progress-calorie-selected-detail")

                    if let diaryDay = selectedDiaryDay {
                        NavigationLink {
                            CalorieDiaryView(days: diaryDays, initialDate: diaryDay.date)
                        } label: {
                            Label("View Day", systemImage: "list.bullet.rectangle")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("progress-calorie-view-day")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .contain)
            } else {
                Text("Tap or drag a recorded day to inspect exact calories and historical goal context.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("progress-calorie-selection-prompt")
            }
        }
        .onAppear {
            resetSelectionIfNeeded()
        }
        .onChange(of: chartSelectionDate) { _, newValue in
            selectNearest(to: newValue)
        }
        .onChange(of: progress) { _, _ in
            resetSelectionIfNeeded()
        }
    }

    private var calorieXAxisValues: [Date] {
        let dates = progress.summaries.map(\.date)
        guard dynamicTypeSize.isAccessibilitySize, dates.count > 3 else { return dates }
        return [dates[0], dates[dates.count / 2], dates[dates.count - 1]]
    }

    private var calorieAccessibilitySummary: String {
        let count = progress.summaries.count
        let dayLabel = count == 1 ? "recorded day" : "recorded days"
        let average = progress.averageCalories?.formatted(.number.precision(.fractionLength(0))) ?? "no"
        let goalContext = progress.comparableGoalDays == 0
            ? "Historical goal context unavailable."
            : "Historical goal context available for \(progress.comparableGoalDays) of \(count) days."
        return "Calories trend for \(count) \(dayLabel). Average \(average) calories. \(goalContext)"
    }

    private var calorieAccessibilityValue: String {
        guard let selectedSummary else {
            return "No recorded day selected. Swipe up or down to cycle recorded days."
        }
        return "Selected \(selectedSummary.date.formatted(date: .complete, time: .omitted)), \(selectedSummary.calories.formatted(.number)) kcal. \(calorieGoalText(for: selectedSummary.date))."
    }

    private var selectedDiaryDay: CalorieDiaryDay? {
        guard let selectedSummary else { return nil }
        return diaryDays.first { $0.date == selectedSummary.date }
    }

    private var calorieSelectionAccessibilityLabel: String {
        guard let selectedSummary else { return "No calorie point selected" }
        return "Selected day \(selectedSummary.date.formatted(date: .complete, time: .omitted)), \(selectedSummary.calories.formatted(.number)) kcal. \(calorieGoalText(for: selectedSummary.date))."
    }

    private func calorieGoalText(for date: Date) -> String {
        guard let goal = progress.goalContexts.first(where: { $0.date == date })?.calories else {
            return "Historical goal unavailable"
        }
        return "Historical goal: \(goal.formatted(.number)) kcal"
    }

    private func selectNearest(to date: Date?) {
        guard let date,
              let nearest = progress.summaries.min(by: { distance(from: $0.date, to: date) < distance(from: $1.date, to: date) }) else {
            selectedDate = nil
            return
        }
        selectedDate = nearest.date
    }

    private func resetSelectionIfNeeded() {
        guard let selectedDate else { return }
        guard progress.summaries.contains(where: { $0.date == selectedDate }) else {
            self.selectedDate = nil
            chartSelectionDate = nil
            return
        }
    }

    private func selectNearest(
        using proxy: ChartProxy,
        location: CGPoint,
        in geometry: GeometryProxy
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else { return }
        let xPosition = location.x - plotFrame.minX
        selectNearest(to: proxy.value(atX: xPosition, as: Date.self))
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let dates = progress.summaries.map(\.date)
        guard !dates.isEmpty else { return }
        let currentIndex = selectedDate.flatMap { dates.firstIndex(of: $0) }

        switch direction {
        case .increment:
            let index = ((currentIndex ?? -1) + 1) % dates.count
            selectedDate = dates[index]
            chartSelectionDate = dates[index]
        case .decrement:
            let index = ((currentIndex ?? dates.count) + dates.count - 1) % dates.count
            selectedDate = dates[index]
            chartSelectionDate = dates[index]
        @unknown default:
            break
        }
    }

    private func distance(from left: Date, to right: Date) -> TimeInterval {
        abs(left.timeIntervalSinceReferenceDate - right.timeIntervalSinceReferenceDate)
    }
}

struct WeightProgressChart: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let progress: WeightProgress
    let targetWeight: Double?

    @State private var chartSelectionDate: Date?
    @State private var selectedDate: Date?

    private var selectedWeightPoints: [WeightProgressPoint] {
        guard let selectedDate else { return [] }
        return progress.points.filter { $0.date == selectedDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .symbolSize(28)
                }

                if let targetWeight, targetWeight.isFinite, targetWeight > 0 {
                    RuleMark(y: .value("Target", targetWeight))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }

                if let selectedDate, !selectedWeightPoints.isEmpty {
                    RuleMark(x: .value("Selected date and time", selectedDate))
                        .foregroundStyle(.primary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    ForEach(Array(selectedWeightPoints.enumerated()), id: \.offset) { _, point in
                        PointMark(
                            x: .value("Selected date and time", point.date),
                            y: .value("Selected weight", point.kilograms)
                        )
                        .foregroundStyle(.primary)
                        .symbolSize(100)
                    }
                }
            }
            .chartYScale(domain: progress.domain ?? 0.1...1)
            .chartXAxis {
                AxisMarks(values: weightXAxisValues) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine()
                    AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                }
            }
            .chartXSelection(value: $chartSelectionDate)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectNearest(
                                        using: proxy,
                                        location: value.location,
                                        in: geometry
                                    )
                                }
                                .onEnded { value in
                                    selectNearest(
                                        using: proxy,
                                        location: value.location,
                                        in: geometry
                                    )
                                }
                        )
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(weightAccessibilitySummary)
            .accessibilityValue(weightAccessibilityValue)
            .accessibilityHint("Swipe up or down to cycle recorded weight times.")
            .accessibilityAdjustableAction { direction in
                adjustSelection(direction)
            }
            .accessibilityIdentifier("progress-weight-chart")

            if let selectedDate, !selectedWeightPoints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedWeightPoints.count == 1 ? "Selected reading" : "Selected readings at same time")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(selectedDate.formatted(date: .complete, time: .shortened))
                        .accessibilityIdentifier("progress-weight-selected-date")
                    Text(selectedWeightReadingsText)
                        .accessibilityIdentifier("progress-weight-selected-readings")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(weightSelectionAccessibilityLabel)
                .accessibilityIdentifier("progress-weight-selected-detail")
            } else {
                Text("Tap or drag a recorded weight to inspect its exact date, time, and readings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("progress-weight-selection-prompt")
            }
        }
        .onAppear {
            resetSelectionIfNeeded()
        }
        .onChange(of: chartSelectionDate) { _, newValue in
            selectNearest(to: newValue)
        }
        .onChange(of: progress) { _, _ in
            resetSelectionIfNeeded()
        }
    }

    private var weightXAxisValues: [Date] {
        let dates = progress.points.map(\.date)
        let desiredCount = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        guard dates.count > desiredCount else { return dates }
        return (0..<desiredCount).map { index in
            let position = Double(index) * Double(dates.count - 1) / Double(desiredCount - 1)
            return dates[Int(position.rounded())]
        }
    }

    private var weightAccessibilitySummary: String {
        let count = progress.points.count
        let weightLabel = count == 1 ? "recorded weight" : "recorded weights"
        let current = progress.current.map { "Current \($0.formatted(.number.precision(.fractionLength(1)))) kilograms." } ?? ""
        return "Weight trend with \(count) \(weightLabel). \(current)"
    }

    private var weightAccessibilityValue: String {
        guard let selectedDate, !selectedWeightPoints.isEmpty else {
            return "No recorded weight selected. Swipe up or down to cycle recorded weights."
        }
        return "Selected \(selectedDate.formatted(date: .complete, time: .shortened)). \(selectedWeightReadingsText)."
    }

    private var selectedWeightReadingsText: String {
        let readings = selectedWeightPoints.enumerated().map { index, point in
            "Reading \(index + 1), \(weightText(point.kilograms))"
        }.joined(separator: "; ")
        return "\(selectedWeightPoints.count) raw reading\(selectedWeightPoints.count == 1 ? "" : "s"): \(readings)"
    }

    private var weightSelectionAccessibilityLabel: String {
        guard let selectedDate, !selectedWeightPoints.isEmpty else {
            return "No weight point selected"
        }
        return "Selected \(selectedDate.formatted(date: .complete, time: .shortened)). \(selectedWeightReadingsText)."
    }

    private func weightText(_ kilograms: Double) -> String {
        "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    private func selectNearest(to date: Date?) {
        guard let date,
              let nearest = progress.points.min(by: { distance(from: $0.date, to: date) < distance(from: $1.date, to: date) }) else {
            selectedDate = nil
            return
        }
        selectedDate = nearest.date
    }

    private func resetSelectionIfNeeded() {
        guard let selectedDate else { return }
        guard progress.points.contains(where: { $0.date == selectedDate }) else {
            self.selectedDate = nil
            chartSelectionDate = nil
            return
        }
    }

    private func selectNearest(
        using proxy: ChartProxy,
        location: CGPoint,
        in geometry: GeometryProxy
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else { return }
        let xPosition = location.x - plotFrame.minX
        selectNearest(to: proxy.value(atX: xPosition, as: Date.self))
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let dates = progress.points.reduce(into: [Date]()) { dates, point in
            if !dates.contains(point.date) {
                dates.append(point.date)
            }
        }
        guard !dates.isEmpty else { return }
        let currentIndex = selectedDate.flatMap { dates.firstIndex(of: $0) }

        switch direction {
        case .increment:
            let index = ((currentIndex ?? -1) + 1) % dates.count
            selectedDate = dates[index]
            chartSelectionDate = dates[index]
        case .decrement:
            let index = ((currentIndex ?? dates.count) + dates.count - 1) % dates.count
            selectedDate = dates[index]
            chartSelectionDate = dates[index]
        @unknown default:
            break
        }
    }

    private func distance(from left: Date, to right: Date) -> TimeInterval {
        abs(left.timeIntervalSinceReferenceDate - right.timeIntervalSinceReferenceDate)
    }
}
