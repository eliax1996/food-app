import SwiftData
import SwiftUI
import os

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var profiles: [UserProfile]

    @State private var selectedMetric: HistoryMetric
    @State private var showingWeightPicker = false
    @State private var draftWeightKilograms = 70
    @State private var draftWeightTenths = 0
    @State private var isSavingWeight = false
    @State private var errorMessage: String?

    init(initialMetric: HistoryMetric = .calories) {
        _selectedMetric = State(initialValue: initialMetric)
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var todaysWeight: WeightEntry? {
        weights.first { Calendar.current.isDateInToday($0.date) }
    }

    private var dailyGoal: Int? {
        guard let goal = profile?.dailyCalorieGoal, goal > 0 else { return nil }
        return goal
    }

    private var calorieProgress: CalorieProgress {
        ProgressHistory.calorieProgress(
            summaries: CalorieHistory.dailySummaries(
                for: entries.map { CalorieRecord(date: $0.date, calories: $0.calories) },
                limit: 7
            ),
            dailyGoal: dailyGoal
        )
    }

    private var weightProgress: WeightProgress {
        ProgressHistory.weightProgress(
            entries: weights.map { WeightProgressPoint(date: $0.date, kilograms: $0.kilograms) },
            targetWeight: profile?.targetWeight
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(HistoryMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("progress-metric-picker")
                }

                if selectedMetric == .calories {
                    calorieSection
                } else {
                    weightSection
                }
            }
            .navigationTitle("Progress")
            .sheet(isPresented: $showingWeightPicker) {
                weightPickerSheet
            }
            .alert("Could not save weight", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    @ViewBuilder
    private var calorieSection: some View {
        Section("Calories") {
            if calorieProgress.summaries.isEmpty {
                ContentUnavailableView(
                    "No recorded days",
                    systemImage: "fork.knife",
                    description: Text("Log meals to see daily calorie progress here.")
                )
                .accessibilityIdentifier("progress-calorie-empty")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Average per recorded day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(calorieAverageValue)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("progress-calorie-summary")
                    Text(calorieSummaryDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                CalorieProgressChart(progress: calorieProgress, dailyGoal: dailyGoal)
            }
        }
    }

    @ViewBuilder
    private var weightSection: some View {
        Section("Weight") {
            if weightProgress.points.isEmpty {
                ContentUnavailableView(
                    "No weights recorded",
                    systemImage: "scalemass",
                    description: Text("Record weight to see change over time and distance to target.")
                )
                .accessibilityIdentifier("progress-weight-empty")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current \(weightLabel(weightProgress.current))")
                        .font(.headline)
                        .accessibilityIdentifier("progress-weight-current")
                    Text(weightDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("progress-weight-summary")
                }
                WeightProgressChart(progress: weightProgress, targetWeight: validTargetWeight)
            }
        }

        Section {
            Button {
                prepareWeightPicker()
                showingWeightPicker = true
            } label: {
                Label(weightActionTitle, systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
            }
            .accessibilityIdentifier("record-weight")
        }
    }

    private var weightPickerSheet: some View {
        WeightPickerSheet(
            kilograms: $draftWeightKilograms,
            tenths: $draftWeightTenths,
            title: weightPickerTitle,
            isSaving: isSavingWeight,
            onCancel: { showingWeightPicker = false },
            onSave: saveWeight
        )
    }

    private var calorieAverageValue: String {
        guard let average = calorieProgress.averageCalories else { return "—" }
        return "\(average.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    private var calorieSummaryDetail: String {
        let recordedDays = calorieProgress.summaries.count
        let dayLabel = recordedDays == 1 ? "recorded day" : "recorded days"
        let recordedDaysText = "\(recordedDays) \(dayLabel)"

        guard let dailyGoal, let difference = calorieProgress.goalDifference else {
            return "\(recordedDaysText) • No daily goal"
        }

        let relation: String
        switch difference {
        case let value where value > 0:
            relation = "\(abs(value).formatted(.number.precision(.fractionLength(0)))) kcal above \(dailyGoal.formatted()) kcal goal"
        case let value where value < 0:
            relation = "\(abs(value).formatted(.number.precision(.fractionLength(0)))) kcal below \(dailyGoal.formatted()) kcal goal"
        default:
            relation = "At \(dailyGoal.formatted()) kcal goal"
        }
        return "\(recordedDaysText) • \(relation)"
    }

    private var validTargetWeight: Double? {
        guard let target = profile?.targetWeight, target.isFinite, target > 0 else { return nil }
        return target
    }

    private var weightDetail: String {
        var details: [String] = []
        if let change = weightProgress.periodChange {
            if abs(change) < 0.05 {
                details.append("No change over \(weightProgress.points.count) recorded weights")
            } else {
                let direction = change > 0 ? "↑" : "↓"
                let sign = change > 0 ? "+" : "−"
                details.append("\(direction) \(sign)\(abs(change).formatted(.number.precision(.fractionLength(1)))) kg over \(weightProgress.points.count) recorded weights")
            }
        } else {
            details.append("1 recorded weight")
        }

        if let distance = weightProgress.targetDistance {
            if abs(distance) < 0.05 {
                details.append("At target")
            } else if distance > 0 {
                details.append("\(distance.formatted(.number.precision(.fractionLength(1)))) kg below target")
            } else {
                details.append("\(abs(distance).formatted(.number.precision(.fractionLength(1)))) kg above target")
            }
        } else {
            details.append("Set target in Config")
        }
        return details.joined(separator: " • ")
    }

    private var weightActionTitle: String {
        todaysWeight == nil ? "Record weight" : "Update today’s weight"
    }

    private var weightPickerTitle: String {
        todaysWeight == nil ? "Record weight" : "Update weight"
    }

    private func weightLabel(_ weight: Double?) -> String {
        guard let weight else { return "—" }
        return "\(weight.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    private func prepareWeightPicker() {
        let baseWeight = todaysWeight?.kilograms ?? weightProgress.current ?? profile?.currentWeight ?? 70
        let roundedWeight = min(max((baseWeight * 10).rounded() / 10, 30), 250)
        draftWeightKilograms = Int(roundedWeight)
        draftWeightTenths = Int((roundedWeight * 10).rounded()) % 10
    }

    private func saveWeight(_ kilograms: Double) {
        guard kilograms.isFinite, kilograms > 0 else { return }
        isSavingWeight = true

        if let todaysWeight {
            todaysWeight.kilograms = kilograms
            todaysWeight.date = .now
        } else {
            modelContext.insert(WeightEntry(kilograms: kilograms))
        }
        profile?.currentWeight = kilograms

        do {
            try modelContext.save()
            isSavingWeight = false
            showingWeightPicker = false
        } catch {
            modelContext.rollback()
            isSavingWeight = false
            AppLogger.persistence.error("Failed to save weight: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your weight could not be saved. Please try again."
        }
    }
}

private struct WeightPickerSheet: View {
    @Environment(\.locale) private var locale
    @Binding var kilograms: Int
    @Binding var tenths: Int

    let title: String
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (Double) -> Void

    private var weight: Double {
        Double(kilograms) + Double(tenths) / 10
    }

    private var decimalSeparator: String {
        locale.decimalSeparator ?? "."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("\(weight, format: .number.precision(.fractionLength(1))) kg")
                        .font(.title.bold())
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("weight-draft-value")

                    HStack(spacing: 0) {
                        Picker("Kilograms", selection: $kilograms) {
                            ForEach(30...250, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("weight-kilograms-picker")

                        Picker("Tenths", selection: $tenths) {
                            ForEach(0...9, id: \.self) { value in
                                Text("\(decimalSeparator)\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("weight-tenths-picker")
                    }
                    .frame(height: 180)
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancel-weight")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(weight) }
                        .disabled(isSaving)
                        .accessibilityIdentifier("save-weight")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#if DEBUG
#Preview("Progress — Calories") {
    HistoryView(initialMetric: .calories)
        .modelContainer(PreviewData.makeContainer())
}

#Preview("Progress — Weight") {
    HistoryView(initialMetric: .weight)
        .modelContainer(PreviewData.makeContainer())
}

#Preview("Progress — Empty weight") {
    HistoryView(initialMetric: .weight)
        .modelContainer(PreviewData.makeContainer(state: .empty))
}
#endif
