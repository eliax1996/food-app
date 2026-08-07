import AppIntents
import ActivityKit
import OSLog
import SwiftUI
import WidgetKit

struct CaloriesWidgetEntry: TimelineEntry {
    let date: Date
    let summary: WidgetDailySummary
}

struct CaloriesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaloriesWidgetEntry {
        CaloriesWidgetEntry(
            date: .now,
            summary: WidgetDailySummary(
                date: .now,
                calories: 540,
                waterGlasses: 3,
                lastWaterRecordedAt: .now
            )
        )
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
        WidgetDailySummaryStore.adjustWater(by: 1)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetDailySummaryStore.widgetKind)
        await LiveActivityMockWaterUpdater.adjust(by: 1)
        return .result()
    }
}

struct RemoveWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Remove Glass of Water"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetDailySummaryStore.adjustWater(by: -1)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetDailySummaryStore.widgetKind)
        await LiveActivityMockWaterUpdater.adjust(by: -1)
        return .result()
    }
}

private enum LiveActivityMockWaterUpdater {
    private static let logger = Logger(
        subsystem: "ch.elia.count-calories",
        category: "LiveActivity"
    )

    static func adjust(by delta: Int) async {
        // TODO: Persist this change to the app's real SwiftData store after enabling
        // App Groups, which requires a paid Apple Developer Program membership.
        logger.notice(
            "Applying a display-only water adjustment. Real persistence requires the App Groups capability."
        )

        for activity in Activity<CaloriesActivityAttributes>.activities {
            var state = activity.content.state
            state.waterGlasses = max(0, state.waterGlasses + delta)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CaloriesMetricsHeader(
                calories: entry.summary.calories,
                waterGlasses: entry.summary.waterGlasses
            )

            HStack(spacing: 8) {
                Link(destination: URL(string: "countcalories://add-food")!) {
                    Label("Add food", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)

                Button(intent: RemoveWaterIntent()) {
                    Image(systemName: "minus")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)

                Button(intent: AddWaterIntent()) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

private struct CaloriesMetricsHeader: View {
    let calories: Int
    let waterGlasses: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(calories)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                Text("kcal today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(waterGlasses)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                Text("glasses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CaloriesLiveActivityView: View {
    let state: CaloriesActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CaloriesMetricsHeader(
                calories: state.calories,
                waterGlasses: state.waterGlasses
            )

            HStack(spacing: 8) {
                Link(destination: URL(string: "countcalories://add-food")!) {
                    Label("Add food", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)

                Button(intent: RemoveWaterIntent()) {
                    Image(systemName: "minus")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)

                Button(intent: AddWaterIntent()) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

struct CaloriesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CaloriesActivityAttributes.self) { context in
            CaloriesLiveActivityView(state: context.state)
                .activityBackgroundTint(Color(uiColor: .systemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.calories)", systemImage: "flame.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("\(context.state.waterGlasses)", systemImage: "drop.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Link("Add food", destination: URL(string: "countcalories://add-food")!)
                        Spacer()
                        Button(intent: RemoveWaterIntent()) {
                            Image(systemName: "minus.circle")
                        }
                        Button(intent: AddWaterIntent()) {
                            Image(systemName: "plus.circle")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            } compactLeading: {
                Label("\(context.state.calories)", systemImage: "flame.fill")
                    .labelStyle(.titleAndIcon)
            } compactTrailing: {
                Label("\(context.state.waterGlasses)", systemImage: "drop.fill")
                    .labelStyle(.titleAndIcon)
            } minimal: {
                Image(systemName: "flame.fill")
            }
            .widgetURL(URL(string: "countcalories://add-food"))
            .keylineTint(.orange)
        }
    }
}

struct CaloriesSummaryWidget: Widget {
    let kind = WidgetDailySummaryStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaloriesWidgetProvider()) { entry in
            CaloriesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Calories")
        .description("Track today's calories and water.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CountCaloriesWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaloriesSummaryWidget()
        CaloriesLiveActivity()
    }
}
