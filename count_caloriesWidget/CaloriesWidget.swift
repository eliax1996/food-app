import AppIntents
import ActivityKit
import SwiftUI
import WidgetKit

private let addFoodURL = URL(string: "countcalories://add-food")!

struct CaloriesWidgetEntry: TimelineEntry {
    let date: Date
    let summary: WidgetDailySummary
}

struct CaloriesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaloriesWidgetEntry {
        CaloriesWidgetEntry(date: .now, summary: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (CaloriesWidgetEntry) -> Void) {
        completion(CaloriesWidgetEntry(date: .now, summary: WidgetDailySummaryStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaloriesWidgetEntry>) -> Void) {
        let entry = CaloriesWidgetEntry(date: .now, summary: WidgetDailySummaryStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Glass of Water"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let summary = WidgetDailySummaryStore.adjustWater(by: 1)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetDailySummaryStore.widgetKind)
        await WidgetLiveActivityUpdater.apply(summary)
        return .result()
    }
}

struct RemoveWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Remove Glass of Water"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let summary = WidgetDailySummaryStore.adjustWater(by: -1)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetDailySummaryStore.widgetKind)
        await WidgetLiveActivityUpdater.apply(summary)
        return .result()
    }
}

private enum WidgetLiveActivityUpdater {
    static func apply(_ summary: WidgetDailySummary) async {
        for activity in Activity<CaloriesActivityAttributes>.activities {
            let state = CaloriesActivityAttributes.ContentState(
                calories: summary.calories,
                waterGlasses: summary.waterGlasses,
                calorieGoal: summary.resolvedCalorieGoal,
                waterGoal: summary.resolvedWaterGoal
            )
            await activity.update(
                ActivityContent(
                    state: state,
                    staleDate: activity.content.staleDate
                )
            )
        }
    }
}

struct CaloriesWidgetEntryView: View {
    let entry: CaloriesWidgetEntry

    private var calorieStatus: CaloriesActivityAttributes.CalorieActivityStatus {
        entry.summary.activityState.calorieStatus(goal: entry.summary.resolvedCalorieGoal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 18) {
                calorieSummary
                Spacer(minLength: 8)
                waterSummary
            }

            HStack(spacing: 10) {
                Link(destination: addFoodURL) {
                    Label("Log food", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Log food")

                Button(intent: RemoveWaterIntent()) {
                    Image(systemName: "minus")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(entry.summary.waterGlasses == 0)
                .accessibilityLabel("Remove glass of water")

                Button(intent: AddWaterIntent()) {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(entry.summary.waterGlasses >= 30)
                .accessibilityLabel("Add glass of water")
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(addFoodURL)
    }

    private var calorieSummary: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label {
                if entry.summary.hasCompleteCalories {
                    Text(calorieStatus.value, format: .number)
                        .monospacedDigit()
                } else {
                    Text("—")
                }
            } icon: {
                Image(systemName: entry.summary.hasCompleteCalories
                    ? (calorieStatus.isOverGoal ? "exclamationmark.circle.fill" : "flame.fill")
                    : "exclamationmark.triangle.fill")
                    .foregroundStyle(entry.summary.hasCompleteCalories
                        ? (calorieStatus.isOverGoal ? .red : .orange)
                        : .orange)
            }
            .font(.title2.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Text(entry.summary.hasCompleteCalories ? calorieStatus.label : "calories incomplete")
                .font(.caption)
                .foregroundStyle(entry.summary.hasCompleteCalories && calorieStatus.isOverGoal ? .red : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(entry.summary.hasCompleteCalories
                 ? "\(entry.summary.calories.formatted()) eaten · \(entry.summary.resolvedCalorieGoal.formatted()) goal"
                 : "Open app to review logged data")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily calories")
        .accessibilityValue(entry.summary.hasCompleteCalories
            ? "\(entry.summary.calories) eaten, \(calorieStatus.value) \(calorieStatus.label), daily goal \(entry.summary.resolvedCalorieGoal)"
            : "Calorie total incomplete. Open Count Calories to review logged data.")
    }

    private var waterSummary: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Label {
                Text(entry.summary.waterGlasses, format: .number)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
            }
            .font(.title2.bold())
            .lineLimit(1)

            Text("of \(entry.summary.resolvedWaterGoal) glasses")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ProgressView(
                value: min(
                    Double(entry.summary.waterGlasses) / Double(entry.summary.resolvedWaterGoal),
                    1
                )
            )
            .tint(.blue)
            .frame(width: 76)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water")
        .accessibilityValue(
            "\(entry.summary.waterGlasses) of \(entry.summary.resolvedWaterGoal) glasses"
        )
    }
}

private struct CaloriesLiveActivityView: View {
    let context: ActivityViewContext<CaloriesActivityAttributes>

    private var calorieStatus: CaloriesActivityAttributes.CalorieActivityStatus {
        context.state.calorieStatus()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(calorieStatus.value, format: .number)
                        .font(.title.bold())
                        .monospacedDigit()
                    Text(calorieStatus.label)
                        .font(.caption)
                        .foregroundStyle(calorieStatus.isOverGoal ? .red : .secondary)
                    Text("\(context.state.calories.formatted()) eaten · \(context.state.resolvedCalorieGoal.formatted()) goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 2) {
                    Label("\(context.state.waterGlasses) of \(context.state.resolvedWaterGoal)", systemImage: "drop.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text("glasses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: addFoodURL) {
                Label("Log food", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}

struct CaloriesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CaloriesActivityAttributes.self) { context in
            CaloriesLiveActivityView(context: context)
                .activityBackgroundTint(Color(uiColor: .systemBackground))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(addFoodURL)
        } dynamicIsland: { context in
            let status = context.state.calorieStatus()

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Label("\(status.value)", systemImage: status.isOverGoal ? "exclamationmark.circle.fill" : "flame.fill")
                            .font(.headline)
                        Text(status.isOverGoal ? "over" : "remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Label("\(context.state.waterGlasses)/\(context.state.resolvedWaterGoal)", systemImage: "drop.fill")
                            .font(.headline)
                        Text("glasses")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: addFoodURL) {
                        Label("Log food", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                }
            } compactLeading: {
                Label("\(status.value)", systemImage: status.isOverGoal ? "exclamationmark.circle.fill" : "flame.fill")
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("\(status.value) \(status.label)")
            } compactTrailing: {
                Label("\(context.state.waterGlasses)", systemImage: "drop.fill")
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("\(context.state.waterGlasses) of \(context.state.resolvedWaterGoal) glasses")
            } minimal: {
                Image(systemName: status.isOverGoal ? "exclamationmark.circle.fill" : "flame.fill")
                    .accessibilityLabel("\(status.value) \(status.label)")
            }
            .widgetURL(addFoodURL)
            .keylineTint(status.isOverGoal ? .red : .orange)
        }
    }
}

struct CaloriesSummaryWidget: Widget {
    let kind = WidgetDailySummaryStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaloriesWidgetProvider()) { entry in
            CaloriesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Calories")
        .description("See remaining calories, water progress, and log food.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct CountCaloriesWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaloriesSummaryWidget()
        CaloriesLiveActivity()
    }
}

private extension WidgetDailySummary {
    static let preview = WidgetDailySummary(
        date: .now,
        calories: 1_240,
        caloriesAreComplete: true,
        waterGlasses: 5,
        lastWaterRecordedAt: .now,
        calorieGoal: 2_000,
        waterGoal: 8,
        revision: 0
    )

    var activityState: CaloriesActivityAttributes.ContentState {
        CaloriesActivityAttributes.ContentState(
            calories: calories,
            waterGlasses: waterGlasses,
            calorieGoal: resolvedCalorieGoal,
            waterGoal: resolvedWaterGoal
        )
    }
}

#if DEBUG
#Preview("Medium", as: .systemMedium) {
    CaloriesSummaryWidget()
} timeline: {
    CaloriesWidgetEntry(date: .now, summary: .preview)
}

#Preview("Over Goal", as: .systemMedium) {
    CaloriesSummaryWidget()
} timeline: {
    CaloriesWidgetEntry(
        date: .now,
        summary: WidgetDailySummary(
            date: .now,
            calories: 2_125,
            caloriesAreComplete: true,
            waterGlasses: 8,
            lastWaterRecordedAt: .now,
            calorieGoal: 2_000,
            waterGoal: 8,
            revision: 0
        )
    )
}

#Preview("Live Activity", as: .content, using: CaloriesActivityAttributes(
    calorieGoal: 2_000,
    waterGoal: 8
)) {
    CaloriesLiveActivity()
} contentStates: {
    CaloriesActivityAttributes.ContentState(
        calories: 1_240,
        waterGlasses: 5,
        calorieGoal: 2_000,
        waterGoal: 8
    )
    CaloriesActivityAttributes.ContentState(
        calories: 2_125,
        waterGlasses: 8,
        calorieGoal: 2_000,
        waterGoal: 8
    )
}
#endif
