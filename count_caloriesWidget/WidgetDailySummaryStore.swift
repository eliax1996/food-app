import Foundation
import os

struct WidgetWaterAdjustment {
    let summary: WidgetDailySummary
    let operationID: UUID
}

enum WidgetDailySummaryStore {
    static let appGroupIdentifier = "group.ch.elia.count-calories.shared"
    static let widgetKind = "CaloriesSummaryWidget"

    private static let summaryKey = "dailySummary"
    private static let summaryFileName = "daily-summary.json"
    private static let lockFileName = "daily-summary.lock"
    private static let logger = Logger(
        subsystem: "ch.elia.count-calories",
        category: "widget"
    )

    static func load() -> WidgetDailySummary {
        do {
            return try withExclusiveLock { try loadUnlocked() }
        } catch {
            logger.error("event=operation_failure operation=widget.summary_load source=widget error_category=storage")
            return .unavailable()
        }
    }

    static func adjustWater(by delta: Int) throws -> WidgetWaterAdjustment {
        let operationID = UUID()
        let operationIDText = operationID.uuidString
        logger.notice(
            "event=operation_start operation=widget.water_adjust operation_id=\(operationIDText, privacy: .public) parent_id=none source=widget"
        )
        do {
            let result = try withExclusiveLock {
                let stored = try loadUnlocked()
                let summary = try WidgetDailySummaryMutation.adjustWater(
                    stored,
                    by: delta
                )
                if summary != stored {
                    try saveUnlocked(summary)
                }
                return summary
            }
            logger.notice(
                "event=operation_success operation=widget.water_adjust operation_id=\(operationIDText, privacy: .public) parent_id=none source=widget"
            )
            return WidgetWaterAdjustment(summary: result, operationID: operationID)
        } catch {
            logger.error(
                "event=operation_failure operation=widget.water_adjust operation_id=\(operationIDText, privacy: .public) parent_id=none source=widget error_category=storage"
            )
            throw error
        }
    }

    private static func loadUnlocked() throws -> WidgetDailySummary {
        let fileURL = try summaryURL()
        let data: Data
        if FileManager.default.fileExists(atPath: fileURL.path) {
            data = try Data(contentsOf: fileURL)
        } else if let legacyData = try defaults().data(forKey: summaryKey) {
            data = legacyData
            try data.write(to: fileURL, options: .atomic)
            try defaults().removeObject(forKey: summaryKey)
        } else {
            return .unavailable()
        }
        let summary = try JSONDecoder().decode(WidgetDailySummary.self, from: data)
        guard Calendar.current.isDateInToday(summary.date) else {
            return .unavailable()
        }
        return summary
    }

    private static func saveUnlocked(_ summary: WidgetDailySummary) throws {
        let data = try JSONEncoder().encode(summary)
        try data.write(to: summaryURL(), options: .atomic)
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
}
