import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.calendar) private var calendar
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var profiles: [UserProfile]

    @Binding private var selectedMetric: HistoryMetric

    init(selectedMetric: Binding<HistoryMetric>) {
        _selectedMetric = selectedMetric
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var goalRevisions: [CalorieGoalRevisionPoint] {
        profile?.adaptivePlanState?.goalRevisions.map {
            CalorieGoalRevisionPoint(
                effectiveDate: $0.effectiveDay,
                sequence: $0.sequence,
                calories: $0.calories
            )
        } ?? []
    }

    private var dailyCalorieSummaries: [DailyCalorieSummary] {
        CalorieHistory.dailySummaries(
            for: entries.map { CalorieRecord(date: $0.date, calories: $0.calories) },
            calendar: calendar,
            limit: 7
        )
    }

    private var incompleteCalorieDayCount: Int {
        dailyCalorieSummaries.count(where: { !$0.caloriesAreComplete })
    }

    private var calorieDiaryDays: [CalorieDiaryDay] {
        CalorieDiary.days(
            from: entries.map {
                CalorieDiaryRecord(
                    id: $0.stableID,
                    date: $0.date,
                    mealType: $0.mealType,
                    foodName: $0.foodName,
                    calories: $0.calories,
                    loggedAmount: $0.loggedAmount,
                    portionCount: $0.portionQuantity,
                    unitRawValue: $0.servingUnitRawValue,
                    carbohydratesGrams: $0.carbohydratesGrams,
                    proteinGrams: $0.proteinGrams,
                    fatGrams: $0.fatGrams,
                    fiberGrams: $0.fiberGrams,
                    modifiedAt: $0.modifiedAt,
                    loggedSnapshotKindRawValue: $0.loggedSnapshotKindRawValue,
                    loggedCalorieDensity: $0.resolvedLoggedCalorieDensity
                )
            },
            calendar: calendar
        )
    }

    private var calorieProgress: CalorieProgress {
        ProgressHistory.calorieProgress(
            summaries: dailyCalorieSummaries,
            goalRevisions: goalRevisions,
            calendar: calendar
        )
    }

    private var weightProgress: WeightProgress {
        ProgressHistory.weightProgress(
            entries: weights.map {
                WeightProgressPoint(
                    date: $0.date,
                    kilograms: $0.kilograms,
                    stableID: $0.stableID,
                    sequence: $0.sequence
                )
            },
            targetWeight: profile?.targetWeight,
            now: .now
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
        }
    }

    @ViewBuilder
    private var calorieSection: some View {
        Section("Calories") {
            if incompleteCalorieDayCount > 0 {
                Label(
                    "\(incompleteCalorieDayCount) recorded \(incompleteCalorieDayCount == 1 ? "day has" : "days have") incomplete calorie data and \(incompleteCalorieDayCount == 1 ? "is" : "are") excluded from trends.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.subheadline)
                .foregroundStyle(.orange)
                .accessibilityIdentifier("progress-calorie-incomplete")
            }
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
                CalorieProgressChart(
                    progress: calorieProgress,
                    diaryDays: calorieDiaryDays
                )
            }

            NavigationLink {
                CalorieDiaryView(
                    initialDate: calorieDiaryDays.first?.date ?? calendar.startOfDay(for: .now)
                )
            } label: {
                Label("Food Diary", systemImage: "list.bullet.rectangle")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("progress-food-diary")
        }
    }

    @ViewBuilder
    private var weightSection: some View {
        Section("Weight") {
            if weightProgress.points.isEmpty {
                ContentUnavailableView(
                    "No weights recorded",
                    systemImage: "scalemass",
                    description: Text("Record weight in the Weight tab to see change over time.")
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
                if weightProgress.points.count > 1 {
                    WeightProgressChart(progress: weightProgress, targetWeight: validTargetWeight)
                } else {
                    Text("Add another reading in the Weight tab to see a trend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("progress-weight-chart-prompt")
                }
            }
        }
    }

    private var calorieAverageValue: String {
        guard let average = calorieProgress.averageCalories else { return "—" }
        return "\(average.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    private var calorieSummaryDetail: String {
        let recordedDays = calorieProgress.summaries.count
        let dayLabel = recordedDays == 1 ? "recorded day" : "recorded days"
        let recordedDaysText = "\(recordedDays) \(dayLabel)"

        guard let difference = calorieProgress.goalDifference,
              calorieProgress.comparableGoalDays > 0 else {
            return "\(recordedDaysText) • Historical goal context unavailable"
        }

        let relation: String
        switch difference {
        case let value where value > 0:
            relation = "Average \(abs(value).formatted(.number.precision(.fractionLength(0)))) kcal above historical daily goals"
        case let value where value < 0:
            relation = "Average \(abs(value).formatted(.number.precision(.fractionLength(0)))) kcal below historical daily goals"
        default:
            relation = "At historical daily goals on average"
        }
        let comparable = calorieProgress.comparableGoalDays == 1
            ? "1 comparable day"
            : "\(calorieProgress.comparableGoalDays) comparable days"
        if calorieProgress.missingGoalDays > 0 {
            let missing = calorieProgress.missingGoalDays == 1
                ? "1 day without goal context"
                : "\(calorieProgress.missingGoalDays) days without goal context"
            return "\(recordedDaysText) • \(comparable) • \(relation) • \(missing)"
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
            details.append("Set target in Settings")
        }
        return details.joined(separator: " • ")
    }

    private func weightLabel(_ weight: Double?) -> String {
        guard let weight else { return "—" }
        return "\(weight.formatted(.number.precision(.fractionLength(1)))) kg"
    }
}

#if DEBUG
private struct HistoryPreview: View {
    @State var metric: HistoryMetric
    let state: DesignReviewState

    var body: some View {
        HistoryView(selectedMetric: $metric)
            .modelContainer(PreviewData.makeContainer(state: state))
    }
}

#Preview("Progress — Calories") {
    HistoryPreview(metric: .calories, state: .normal)
}

#Preview("Progress — Weight") {
    HistoryPreview(metric: .weight, state: .normal)
}

#Preview("Progress — Empty weight") {
    HistoryPreview(metric: .weight, state: .empty)
}
#endif
