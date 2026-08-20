import Foundation

nonisolated struct WidgetDailySummary: Codable, Equatable, Sendable {
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

    static func empty(date: Date = .now, calendar: Calendar = .current) -> Self {
        WidgetDailySummary(
            date: calendar.startOfDay(for: date),
            calories: 0,
            caloriesAreComplete: true,
            waterGlasses: 0,
            lastWaterRecordedAt: nil,
            calorieGoal: 1_700,
            waterGoal: 8,
            revision: 0
        )
    }

    static func unavailable(date: Date = .now, calendar: Calendar = .current) -> Self {
        var summary = empty(date: date, calendar: calendar)
        summary.caloriesAreComplete = false
        return summary
    }
}

nonisolated enum WidgetSharedStorageRequirement {
    static func requireContainer(_ container: URL?) throws -> URL {
        guard let container else { throw CocoaError(.fileNoSuchFile) }
        return container
    }

    static func requireDefaults(_ defaults: UserDefaults?) throws -> UserDefaults {
        guard let defaults else { throw CocoaError(.fileNoSuchFile) }
        return defaults
    }
}

nonisolated enum WidgetLiveActivityUpdateDecision: Equatable, Sendable {
    case update
    case stop

    static func resolve(summary: WidgetDailySummary) -> Self {
        summary.hasCompleteCalories ? .update : .stop
    }
}

nonisolated enum WidgetDailySummaryMutation {
    static func adjustWater(
        _ summary: WidgetDailySummary,
        by delta: Int,
        now: Date = .now
    ) throws -> WidgetDailySummary {
        var result = summary
        let previous = min(max(0, result.waterGlasses), 30)
        let adjusted = min(max(0, previous + delta), 30)
        result.waterGlasses = adjusted
        guard adjusted != previous else { return result }
        guard result.resolvedRevision < Int64.max else {
            throw CocoaError(.coderInvalidValue)
        }
        if adjusted > previous {
            result.lastWaterRecordedAt = now
        }
        result.revision = result.resolvedRevision + 1
        return result
    }
}
