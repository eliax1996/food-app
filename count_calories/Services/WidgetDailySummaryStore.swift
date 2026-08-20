import Foundation
import WidgetKit

enum WidgetDailySummaryStore {
    static let appGroupIdentifier = "group.ch.elia.count-calories.shared"
    static let widgetKind = "CaloriesSummaryWidget"

    private static let summaryKey = "dailySummary"
    private static let summaryFileName = "daily-summary.json"
    private static let lockFileName = "daily-summary.lock"

    static func load() -> WidgetDailySummary? {
        do {
            return try withExclusiveLock { try loadUnlocked() }
        } catch {
            let operation = AppLogger.begin(
                "widget.summary_load",
                category: .integrations,
                source: "app"
            )
            AppLogger.fail(operation, error: error)
            return nil
        }
    }

    @discardableResult
    static func refreshCalorieGoal(_ calorieGoal: Int) -> Bool {
        mutate(operation: "widget.goal_refresh") { summary in
            summary.calorieGoal = max(1, calorieGoal)
        }
    }

    static func pendingWaterRevision() -> Int64 {
        load()?.resolvedRevision ?? 0
    }

    static func adjustWater(by delta: Int, now: Date = .now) -> WidgetDailySummary? {
        let operation = AppLogger.begin(
            "widget.water_adjust",
            category: .integrations,
            source: "app"
        )
        do {
            let result = try withExclusiveLock {
                let loaded = try loadUnlocked()
                let stored = loaded.map {
                    Calendar.current.isDate($0.date, inSameDayAs: now) ? $0 : .empty(date: now)
                } ?? .empty(date: now)
                let adjusted = try WidgetDailySummaryMutation.adjustWater(
                    stored,
                    by: delta,
                    now: now
                )
                if adjusted != stored {
                    try saveUnlocked(adjusted)
                }
                return adjusted
            }
            AppLogger.succeed(operation)
            return result
        } catch {
            AppLogger.fail(operation, error: error)
            return nil
        }
    }

    @discardableResult
    static func save(
        calories: Int,
        caloriesAreComplete: Bool = true,
        waterGlasses: Int,
        lastWaterRecordedAt: Date? = nil,
        calorieGoal: Int? = nil,
        waterGoal: Int? = nil,
        date: Date = .now,
        reloadWidget: Bool = true,
        preservePendingWidgetWater: Bool = true,
        parentOperationID: UUID? = nil
    ) -> Bool {
        let operation = AppLogger.begin(
            "widget.summary_save",
            category: .integrations,
            source: "app",
            parentID: parentOperationID
        )
        var recoveredCorruptSummary = false
        do {
            try withExclusiveLock {
                let stored: WidgetDailySummary?
                do {
                    stored = try loadUnlocked()
                } catch {
                    try removeStoredSummaryUnlocked()
                    recoveredCorruptSummary = true
                    stored = nil
                }
                let sameDay = stored.map {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                } ?? false
                let pendingWidgetWaterExists = preservePendingWidgetWater
                    && sameDay
                    && (stored?.resolvedRevision ?? 0) > 0
                let summary = WidgetDailySummary(
                    date: Calendar.current.startOfDay(for: date),
                    calories: max(0, calories),
                    caloriesAreComplete: caloriesAreComplete,
                    waterGlasses: pendingWidgetWaterExists
                        ? min(max(0, stored?.waterGlasses ?? waterGlasses), 30)
                        : min(max(0, waterGlasses), 30),
                    lastWaterRecordedAt: pendingWidgetWaterExists
                        ? stored?.lastWaterRecordedAt
                        : lastWaterRecordedAt,
                    calorieGoal: calorieGoal.map { max(1, $0) } ?? stored?.calorieGoal,
                    waterGoal: waterGoal.map { max(1, $0) } ?? stored?.waterGoal,
                    revision: sameDay && preservePendingWidgetWater ? stored?.revision : 0
                )
                try saveUnlocked(summary)
            }
        } catch {
            AppLogger.fail(operation, error: error)
            return false
        }

        if reloadWidget {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
        if recoveredCorruptSummary {
            AppLogger.partial(operation, failedComponent: "corrupt_summary_recovered")
        } else {
            AppLogger.succeed(operation)
        }
        return true
    }

    @discardableResult
    static func acknowledgeWaterRevision(_ revision: Int64) -> Bool {
        var matchedRevision = false
        let saved = mutate(operation: "widget.water_acknowledge") { summary in
            guard summary.resolvedRevision == revision else { return }
            matchedRevision = true
            summary.revision = 0
        }
        return saved && matchedRevision
    }

    private static func mutate(
        operation name: String,
        _ mutation: (inout WidgetDailySummary) -> Void
    ) -> Bool {
        let operation = AppLogger.begin(name, category: .integrations, source: "app")
        var recoveredCorruptSummary = false
        do {
            try withExclusiveLock {
                var summary: WidgetDailySummary
                do {
                    summary = try loadUnlocked() ?? emptySummary()
                } catch {
                    try removeStoredSummaryUnlocked()
                    recoveredCorruptSummary = true
                    summary = emptySummary()
                }
                mutation(&summary)
                try saveUnlocked(summary)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            if recoveredCorruptSummary {
                AppLogger.partial(operation, failedComponent: "corrupt_summary_recovered")
            } else {
                AppLogger.succeed(operation)
            }
            return true
        } catch {
            AppLogger.fail(operation, error: error)
            return false
        }
    }

    private static func loadUnlocked() throws -> WidgetDailySummary? {
        let fileURL = try summaryURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try JSONDecoder().decode(
                WidgetDailySummary.self,
                from: Data(contentsOf: fileURL)
            )
        }
        guard let legacyData = try defaults().data(forKey: summaryKey) else { return nil }
        let summary = try JSONDecoder().decode(WidgetDailySummary.self, from: legacyData)
        try saveUnlocked(summary)
        try defaults().removeObject(forKey: summaryKey)
        return summary
    }

    private static func saveUnlocked(_ summary: WidgetDailySummary) throws {
        let data = try JSONEncoder().encode(summary)
        try data.write(to: summaryURL(), options: .atomic)
    }

    private static func removeStoredSummaryUnlocked() throws {
        let fileURL = try summaryURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try defaults().removeObject(forKey: summaryKey)
    }

    private static func emptySummary() -> WidgetDailySummary {
        .empty()
    }

    private static func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T {
        let descriptor = open(try lockURL().path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private static func sharedContainer() throws -> URL {
        try WidgetSharedStorageRequirement.requireContainer(
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )
        )
    }

    private static func lockURL() throws -> URL {
        try sharedContainer().appendingPathComponent(lockFileName)
    }

    private static func summaryURL() throws -> URL {
        try sharedContainer().appendingPathComponent(summaryFileName)
    }

    private static func defaults() throws -> UserDefaults {
        try WidgetSharedStorageRequirement.requireDefaults(
            UserDefaults(suiteName: appGroupIdentifier)
        )
    }

#if DEBUG || RELEASE_VALIDATION
    static func testingStoredData() throws -> Data? {
        try withExclusiveLock {
            let fileURL = try summaryURL()
            return FileManager.default.fileExists(atPath: fileURL.path)
                ? try Data(contentsOf: fileURL)
                : nil
        }
    }

    static func replaceTestingStoredData(_ data: Data?) throws {
        try withExclusiveLock {
            try removeStoredSummaryUnlocked()
            if let data {
                try data.write(to: summaryURL(), options: .atomic)
            }
        }
    }
#endif
}
