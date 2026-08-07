import Foundation
import WidgetKit

struct WidgetDailySummary: Codable {
    var date: Date
    var calories: Int
    var waterGlasses: Int
    var lastWaterRecordedAt: Date?
}

enum WidgetDailySummaryStore {
    static let appGroupIdentifier = "group.ch.elia.count-calories.shared"
    static let widgetKind = "CaloriesSummaryWidget"

    private static let summaryKey = "dailySummary"

    static func load() -> WidgetDailySummary? {
        guard let data = defaults.data(forKey: summaryKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDailySummary.self, from: data)
    }

    static func save(
        calories: Int,
        waterGlasses: Int,
        lastWaterRecordedAt: Date? = nil,
        date: Date = .now,
        reloadWidget: Bool = true
    ) {
        let summary = WidgetDailySummary(
            date: Calendar.current.startOfDay(for: date),
            calories: max(0, calories),
            waterGlasses: max(0, waterGlasses),
            lastWaterRecordedAt: lastWaterRecordedAt
        )

        if let data = try? JSONEncoder().encode(summary) {
            defaults.set(data, forKey: summaryKey)
        }

        if reloadWidget {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
