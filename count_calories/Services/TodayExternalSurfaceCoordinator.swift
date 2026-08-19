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
#if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("-design-review") else { return nil }
#endif
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

            WidgetDailySummaryStore.save(
                calories: value.calories,
                caloriesAreComplete: value.caloriesAreComplete,
                waterGlasses: value.waterGlasses,
                lastWaterRecordedAt: value.lastWaterRecordedAt,
                calorieGoal: value.calorieGoal,
                waterGoal: value.waterGoal,
                preservePendingWidgetWater: preservePendingWidgetWater
            )

            ReminderNotificationManager.shared.enqueueReschedule(
                meals: value.mealReminderRecords,
                water: value.waterReminderRecords,
                weights: value.weightReminderRecords,
                preferences: .stored()
            )

            return CaloriesLiveActivityManager.synchronize(
                calories: value.calories,
                caloriesAreComplete: value.caloriesAreComplete,
                waterGlasses: value.waterGlasses,
                calorieGoal: value.calorieGoal,
                waterGoal: value.waterGoal
            )
        } catch {
            AppLogger.persistence.error(
                "Failed to synchronize Today external surfaces: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
