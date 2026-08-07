import Foundation

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
    static func load() -> WidgetDailySummary {
        guard
            let data = defaults.data(forKey: summaryKey),
            let summary = try? JSONDecoder().decode(WidgetDailySummary.self, from: data),
            Calendar.current.isDateInToday(summary.date)
        else {
            return WidgetDailySummary(
                date: Calendar.current.startOfDay(for: .now),
                calories: 0,
                waterGlasses: 0,
                lastWaterRecordedAt: nil
            )
        }

        return summary
    }

    static func adjustWater(by delta: Int) {
        var summary = load()
        summary.waterGlasses = max(0, summary.waterGlasses + delta)
        if delta > 0 {
            summary.lastWaterRecordedAt = .now
        }
        save(summary)
    }

    static func save(_ summary: WidgetDailySummary) {
        if let data = try? JSONEncoder().encode(summary) {
            defaults.set(data, forKey: summaryKey)
        }
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
