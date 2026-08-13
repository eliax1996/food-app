import Foundation

struct WidgetDailySummary: Codable {
    var date: Date
    var calories: Int
    var caloriesAreComplete: Bool?
    var waterGlasses: Int
    var lastWaterRecordedAt: Date?
    var calorieGoal: Int?
    var waterGoal: Int?
    var revision: Int64?

    var resolvedCalorieGoal: Int { max(1, calorieGoal ?? 1_700) }
    var hasCompleteCalories: Bool { caloriesAreComplete ?? false }
    var resolvedWaterGoal: Int { max(1, waterGoal ?? 8) }
    var resolvedRevision: Int64 { max(0, revision ?? 0) }
}

enum WidgetDailySummaryStore {
    static let appGroupIdentifier = "group.ch.elia.count-calories.shared"
    static let widgetKind = "CaloriesSummaryWidget"

    private static let summaryKey = "dailySummary"
    private static let lockFileName = "daily-summary.lock"

    static func load() -> WidgetDailySummary {
        (try? withExclusiveLock { loadUnlocked() }) ?? emptySummary()
    }

    static func adjustWater(by delta: Int) -> WidgetDailySummary {
        (try? withExclusiveLock {
            var summary = loadUnlocked()
            let previous = summary.waterGlasses
            summary.waterGlasses = min(max(0, previous + delta), 30)
            if summary.waterGlasses > previous {
                summary.lastWaterRecordedAt = .now
            }
            if summary.waterGlasses != previous {
                summary.revision = summary.resolvedRevision + 1
                saveUnlocked(summary)
            }
            return summary
        }) ?? load()
    }

    private static func loadUnlocked() -> WidgetDailySummary {
        guard
            let data = defaults.data(forKey: summaryKey),
            let summary = try? JSONDecoder().decode(WidgetDailySummary.self, from: data),
            Calendar.current.isDateInToday(summary.date)
        else {
            return emptySummary()
        }
        return summary
    }

    private static func saveUnlocked(_ summary: WidgetDailySummary) {
        if let data = try? JSONEncoder().encode(summary) {
            defaults.set(data, forKey: summaryKey)
        }
    }

    private static func emptySummary() -> WidgetDailySummary {
        WidgetDailySummary(
            date: Calendar.current.startOfDay(for: .now),
            calories: 0,
            caloriesAreComplete: true,
            waterGlasses: 0,
            lastWaterRecordedAt: nil,
            calorieGoal: 1_700,
            waterGoal: 8,
            revision: 0
        )
    }

    private static func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T {
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private static var lockURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(lockFileName)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(lockFileName)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
