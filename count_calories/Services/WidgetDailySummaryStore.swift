import Foundation
import WidgetKit

struct WidgetDailySummary: Codable {
    var date: Date
    var calories: Int
    var waterGlasses: Int
    var lastWaterRecordedAt: Date?
    var calorieGoal: Int?
    var waterGoal: Int?
    var revision: Int64?

    var resolvedRevision: Int64 { max(0, revision ?? 0) }
}

enum WidgetDailySummaryStore {
    static let appGroupIdentifier = "group.ch.elia.count-calories.shared"
    static let widgetKind = "CaloriesSummaryWidget"

    private static let summaryKey = "dailySummary"
    private static let lockFileName = "daily-summary.lock"

    static func load() -> WidgetDailySummary? {
        try? withExclusiveLock { loadUnlocked() }
    }

    static func refreshCalorieGoal(_ calorieGoal: Int) {
        mutate { summary in
            summary.calorieGoal = max(1, calorieGoal)
        }
    }

    static func pendingWaterRevision() -> Int64 {
        load()?.resolvedRevision ?? 0
    }

    static func save(
        calories: Int,
        waterGlasses: Int,
        lastWaterRecordedAt: Date? = nil,
        calorieGoal: Int? = nil,
        waterGoal: Int? = nil,
        date: Date = .now,
        reloadWidget: Bool = true,
        preservePendingWidgetWater: Bool = true
    ) {
        do {
            try withExclusiveLock {
                let stored = loadUnlocked()
                let sameDay = stored.map {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                } ?? false
                let newerWidgetWaterExists = preservePendingWidgetWater
                    && sameDay
                    && (stored?.resolvedRevision ?? 0) > 0
                    && stored?.waterGlasses != waterGlasses
                let summary = WidgetDailySummary(
                    date: Calendar.current.startOfDay(for: date),
                    calories: max(0, calories),
                    waterGlasses: newerWidgetWaterExists
                        ? min(max(0, stored?.waterGlasses ?? waterGlasses), 30)
                        : min(max(0, waterGlasses), 30),
                    lastWaterRecordedAt: newerWidgetWaterExists
                        ? stored?.lastWaterRecordedAt
                        : lastWaterRecordedAt,
                    calorieGoal: calorieGoal.map { max(1, $0) } ?? stored?.calorieGoal,
                    waterGoal: waterGoal.map { max(1, $0) } ?? stored?.waterGoal,
                    revision: sameDay ? stored?.revision : 0
                )
                try saveUnlocked(summary)
            }
        } catch {
            return
        }

        if reloadWidget {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }

    static func acknowledgeWaterRevision(_ revision: Int64) {
        mutate { summary in
            guard summary.resolvedRevision == revision else { return }
            summary.revision = 0
        }
    }

    private static func mutate(_ mutation: (inout WidgetDailySummary) -> Void) {
        do {
            try withExclusiveLock {
                var summary = loadUnlocked() ?? emptySummary()
                mutation(&summary)
                try saveUnlocked(summary)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } catch {
            return
        }
    }

    private static func loadUnlocked() -> WidgetDailySummary? {
        guard let data = defaults.data(forKey: summaryKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDailySummary.self, from: data)
    }

    private static func saveUnlocked(_ summary: WidgetDailySummary) throws {
        let data = try JSONEncoder().encode(summary)
        defaults.set(data, forKey: summaryKey)
    }

    private static func emptySummary() -> WidgetDailySummary {
        WidgetDailySummary(
            date: Calendar.current.startOfDay(for: .now),
            calories: 0,
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
