import Foundation
import SwiftData
import os

struct TodayExternalSurfaceSnapshot: Equatable {
    let calories: Int
    let caloriesAreComplete: Bool
    let waterGlasses: Int
    let lastWaterRecordedAt: Date?
    let calorieGoal: Int
    let waterGoal: Int
    let mealReminderRecords: [MealReminderRecord]
    let waterReminderRecords: [WaterReminderRecord]
    let weightReminderRecords: [WeightReminderRecord]
}

nonisolated enum TodayExternalSurfaceOutcome: Equatable, Sendable {
    case success
    case partial(String)
    case cancelled

    static func resolve(
        widgetSaved: Bool,
        reminderResult: ReminderSchedulingResult,
        liveActivityResult: CaloriesLiveActivityManager.SynchronizationResult
    ) -> Self {
        guard liveActivityResult == .success else { return .cancelled }
        switch reminderResult {
        case .superseded:
            return .cancelled
        case .failed:
            return .partial(widgetSaved ? "reminders" : "widget_and_reminders")
        case .scheduled, .disabled, .authorizationUnavailable:
            return widgetSaved ? .success : .partial("widget")
        }
    }
}

@MainActor
enum TodayExternalSurfaceCoordinator {
    static func snapshot(
        entries: [PlateEntry],
        waterDays: [WaterDay],
        weights: [WeightEntry],
        profiles: [UserProfile],
        calendar: Calendar = .current,
        now: Date = .now,
        waterGoal: Int = 8
    ) -> TodayExternalSurfaceSnapshot {
        let todayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let calorieTotal = CalorieCalculator.assessedTotal(todayEntries.map(\.calories))
        let water = waterDays.first { calendar.isDate($0.date, inSameDayAs: now) }
        return TodayExternalSurfaceSnapshot(
            calories: calorieTotal.calories,
            caloriesAreComplete: calorieTotal.isComplete,
            waterGlasses: water?.glasses ?? 0,
            lastWaterRecordedAt: water?.lastRecordedAt,
            calorieGoal: profiles.first?.dailyCalorieGoal ?? 1_700,
            waterGoal: waterGoal,
            mealReminderRecords: entries.map {
                MealReminderRecord(mealType: $0.mealType, date: $0.date)
            },
            waterReminderRecords: waterDays.map {
                WaterReminderRecord(
                    date: $0.date,
                    glasses: $0.glasses,
                    lastRecordedAt: $0.lastRecordedAt
                )
            },
            weightReminderRecords: weights.map { WeightReminderRecord(date: $0.date) }
        )
    }

    @discardableResult
    static func synchronize(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        waterGoal: Int = 8,
        preservePendingWidgetWater: Bool = true
    ) -> Task<Void, Never>? {
#if DEBUG || RELEASE_VALIDATION
        guard !ProcessInfo.processInfo.arguments.contains("-design-review") else { return nil }
#endif
        let operation = AppLogger.begin(
            "external_surfaces.synchronize",
            category: .integrations,
            source: "app"
        )
        do {
            let readContext = ModelContext(modelContext.container)
            let value = snapshot(
                entries: try readContext.fetch(FetchDescriptor<PlateEntry>()),
                waterDays: try readContext.fetch(FetchDescriptor<WaterDay>()),
                weights: try readContext.fetch(FetchDescriptor<WeightEntry>()),
                profiles: try readContext.fetch(FetchDescriptor<UserProfile>()),
                calendar: calendar,
                waterGoal: waterGoal
            )

            let widgetSaved = WidgetDailySummaryStore.save(
                calories: value.calories,
                caloriesAreComplete: value.caloriesAreComplete,
                waterGlasses: value.waterGlasses,
                lastWaterRecordedAt: value.lastWaterRecordedAt,
                calorieGoal: value.calorieGoal,
                waterGoal: value.waterGoal,
                preservePendingWidgetWater: preservePendingWidgetWater,
                parentOperationID: operation.id
            )

            let reminderSynchronization = ReminderNotificationManager.shared.enqueueReschedule(
                meals: value.mealReminderRecords,
                water: value.waterReminderRecords,
                weights: value.weightReminderRecords,
                preferences: .stored(),
                parentOperationID: operation.id
            )

            let activitySynchronization = CaloriesLiveActivityManager.synchronize(
                calories: value.calories,
                caloriesAreComplete: value.caloriesAreComplete,
                waterGlasses: value.waterGlasses,
                calorieGoal: value.calorieGoal,
                waterGoal: value.waterGoal,
                parentOperationID: operation.id
            )
            return Task { @MainActor in
                let reminderResult = await reminderSynchronization.value
                let liveActivityResult = await activitySynchronization.value
                switch TodayExternalSurfaceOutcome.resolve(
                    widgetSaved: widgetSaved,
                    reminderResult: reminderResult,
                    liveActivityResult: liveActivityResult
                ) {
                case .success:
                    AppLogger.succeed(operation, count: 3)
                case .partial(let component):
                    AppLogger.partial(operation, failedComponent: component)
                case .cancelled:
                    AppLogger.cancel(operation, reason: "superseded")
                }
            }
        } catch {
            AppLogger.fail(operation, error: error)
            return nil
        }
    }
}
