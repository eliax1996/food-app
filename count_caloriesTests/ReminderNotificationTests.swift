import Foundation
import XCTest
#if !SWIFT_PACKAGE
import UserNotifications
#endif
#if !SWIFT_PACKAGE
import SwiftData
#endif
#if SWIFT_PACKAGE
@testable import ReminderCore
#else
@testable import count_calories
#endif

@MainActor
final class ReminderNotificationTests: XCTestCase {
#if !SWIFT_PACKAGE
    func testFailedReminderReplacementRestoresPreviousRequestsAndRemovesIntroducedOnes() async {
        let old = notificationRequest(identifier: "count-calories.reminder.old")
        let unchanged = notificationRequest(identifier: "count-calories.reminder.same")
        let introduced = notificationRequest(identifier: "count-calories.reminder.new")
        var stored = Dictionary(uniqueKeysWithValues: [old, unchanged].map { ($0.identifier, $0) })
        var desiredAttempts = 0

        let succeeded = await ReminderNotificationManager.replacePendingRequests(
            existingRequests: [old, unchanged],
            desiredRequests: [unchanged, introduced],
            add: { request in
                desiredAttempts += 1
                if request.identifier == introduced.identifier, desiredAttempts == 2 {
                    throw CocoaError(.fileWriteUnknown)
                }
                stored[request.identifier] = request
            },
            remove: { identifiers in
                identifiers.forEach { stored.removeValue(forKey: $0) }
            }
        )

        XCTAssertFalse(succeeded)
        XCTAssertEqual(Set(stored.keys), Set([old.identifier, unchanged.identifier]))
    }

    func testSuccessfulReminderReplacementAddsDesiredBeforeRemovingObsolete() async {
        let old = notificationRequest(identifier: "count-calories.reminder.old")
        let replacement = notificationRequest(identifier: "count-calories.reminder.new")
        var events: [String] = []

        let succeeded = await ReminderNotificationManager.replacePendingRequests(
            existingRequests: [old],
            desiredRequests: [replacement],
            add: { request in events.append("add:\(request.identifier)") },
            remove: { identifiers in events.append("remove:\(identifiers.joined(separator: ","))") }
        )

        XCTAssertTrue(succeeded)
        XCTAssertEqual(events, [
            "remove:\(old.identifier)",
            "add:\(replacement.identifier)"
        ])
    }
#endif
    func testMealPlansSkipMealsAlreadyRecordedThatDay() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 8, 0, calendar: calendar)
        let breakfast = MealReminderRecord(
            mealType: ReminderMeal.breakfast.rawValue,
            date: try date(2026, 6, 10, 7, 30, calendar: calendar)
        )
        let preferences = ReminderPreferences(
            breakfastEnabled: true,
            lunchEnabled: true
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [breakfast],
            water: []
        )

        XCTAssertFalse(plans.contains {
            $0.kind == .meal(.breakfast) && calendar.isDate($0.fireDate, inSameDayAs: now)
        })
        XCTAssertTrue(plans.contains {
            $0.kind == .meal(.lunch) && calendar.isDate($0.fireDate, inSameDayAs: now)
        })
        XCTAssertEqual(plans.filter { $0.kind == .meal(.breakfast) }.count, 4)
        XCTAssertEqual(plans.filter { $0.kind == .meal(.lunch) }.count, 5)
    }

    func testPastMealWindowsAreNotBackfilled() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 14, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            breakfastEnabled: true,
            lunchEnabled: true,
            dinnerEnabled: true
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: []
        )
        let todaysPlans = plans.filter { calendar.isDate($0.fireDate, inSameDayAs: now) }

        XCTAssertEqual(todaysPlans.map(\.kind), [.meal(.dinner)])
    }

    func testLegacyMealWithoutTypeSuppressesSnackReminder() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 8, 0, calendar: calendar)
        let legacyMeal = MealReminderRecord(
            mealType: nil,
            date: try date(2026, 6, 10, 7, 30, calendar: calendar)
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: ReminderPreferences(snackEnabled: true),
            meals: [legacyMeal],
            water: []
        )

        XCTAssertFalse(plans.contains {
            $0.kind == .meal(.snack) && calendar.isDate($0.fireDate, inSameDayAs: now)
        })
    }

    func testWaterPlanStartsTwoHoursAfterLatestGlass() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 9, 0, calendar: calendar)
        let lastGlass = try date(2026, 6, 10, 8, 30, calendar: calendar)
        let waterRecord = WaterReminderRecord(
            date: now,
            glasses: 2,
            lastRecordedAt: lastGlass
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: ReminderPreferences(waterEnabled: true),
            meals: [],
            water: [waterRecord]
        )
        let firstWaterPlan = try XCTUnwrap(plans.first { $0.kind == .water })

        XCTAssertEqual(
            firstWaterPlan.fireDate,
            try date(2026, 6, 10, 10, 30, calendar: calendar)
        )
    }

    func testOverdueWaterPlanFiresSoonWithoutSchedulingPastDates() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 15, 0, calendar: calendar)

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: ReminderPreferences(waterEnabled: true),
            meals: [],
            water: []
        )
        let firstWaterPlan = try XCTUnwrap(plans.first { $0.kind == .water })

        XCTAssertEqual(firstWaterPlan.fireDate, now.addingTimeInterval(60))
        XCTAssertTrue(plans.allSatisfy { $0.fireDate > now })
    }

    func testWaterGoalSuppressesOnlyCurrentDay() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 7, 0, calendar: calendar)
        let waterRecord = WaterReminderRecord(
            date: now,
            glasses: ReminderSchedulePlanner.waterGoal,
            lastRecordedAt: now
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: ReminderPreferences(waterEnabled: true),
            meals: [],
            water: [waterRecord]
        )
        let waterPlans = plans.filter { $0.kind == .water }

        XCTAssertFalse(waterPlans.contains { calendar.isDate($0.fireDate, inSameDayAs: now) })
        XCTAssertEqual(waterPlans.count, 28)
    }

    func testFullScheduleStaysBelowSystemPendingNotificationLimit() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 7, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            breakfastEnabled: true,
            lunchEnabled: true,
            snackEnabled: true,
            dinnerEnabled: true,
            waterEnabled: true
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: []
        )

        XCTAssertEqual(plans.count, 55)
        XCTAssertLessThanOrEqual(plans.count, ReminderSchedulePlanner.pendingNotificationLimit)
        XCTAssertEqual(Set(plans.map(\.identifier)).count, plans.count)
    }

    func testCustomMealTimesStayIndependentAndSuppressOnlyMatchingMeal() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 7, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            breakfastEnabled: true,
            lunchEnabled: true,
            breakfastTime: ReminderTime(hour: 8, minute: 15),
            lunchTime: ReminderTime(hour: 14, minute: 45)
        )
        let breakfast = MealReminderRecord(
            mealType: ReminderMeal.breakfast.rawValue,
            date: try date(2026, 6, 10, 7, 30, calendar: calendar)
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [breakfast],
            water: []
        )

        XCTAssertFalse(plans.contains {
            $0.kind == .meal(.breakfast) && calendar.isDate($0.fireDate, inSameDayAs: now)
        })
        XCTAssertEqual(
            plans.first { $0.kind == .meal(.lunch) }?.fireDate,
            try date(2026, 6, 10, 14, 45, calendar: calendar)
        )
        XCTAssertEqual(
            plans.first { $0.kind == .meal(.breakfast) }?.fireDate,
            try date(2026, 6, 11, 8, 15, calendar: calendar)
        )
    }

    func testDailyWeightReminderSkipsDaysWithMeasurements() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 7, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            weightEnabled: true,
            weightTime: ReminderTime(hour: 9, minute: 30),
            weightFrequency: .daily
        )
        let todayWeight = WeightReminderRecord(
            date: try date(2026, 6, 10, 6, 30, calendar: calendar)
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: [],
            weights: [todayWeight]
        )

        XCTAssertEqual(plans.count, 4)
        XCTAssertTrue(plans.allSatisfy { $0.kind == .weight })
        XCTAssertFalse(plans.contains { calendar.isDate($0.fireDate, inSameDayAs: now) })
        XCTAssertEqual(
            plans.first?.fireDate,
            try date(2026, 6, 11, 9, 30, calendar: calendar)
        )
    }

    func testWeeklyWeightReminderWaitsSevenCalendarDaysAfterLatestMeasurement() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 7, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            weightEnabled: true,
            weightTime: ReminderTime(hour: 8, minute: 45),
            weightFrequency: .weekly
        )
        let latestWeight = WeightReminderRecord(
            date: try date(2026, 6, 8, 20, 0, calendar: calendar)
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: [],
            weights: [latestWeight]
        )

        XCTAssertEqual(plans, [
            ReminderNotificationPlan(
                identifier: "count-calories.reminder.weight.2026-6-15-8-45-0",
                kind: .weight,
                fireDate: try date(2026, 6, 15, 8, 45, calendar: calendar)
            )
        ])
    }

    func testOverdueWeeklyWeightReminderUsesNextChosenTime() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 10, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            weightEnabled: true,
            weightTime: ReminderTime(hour: 9, minute: 0),
            weightFrequency: .weekly
        )
        let oldWeight = WeightReminderRecord(
            date: try date(2026, 5, 1, 8, 0, calendar: calendar)
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: [],
            weights: [oldWeight]
        )

        XCTAssertEqual(plans.map(\.fireDate), [
            try date(2026, 6, 11, 9, 0, calendar: calendar)
        ])
    }

    func testOverdueWeeklyWeightReminderUsesTodayWhenChosenTimeIsStillAhead() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 7, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            weightEnabled: true,
            weightTime: ReminderTime(hour: 9, minute: 0),
            weightFrequency: .weekly
        )
        let oldWeight = WeightReminderRecord(
            date: try date(2026, 5, 1, 8, 0, calendar: calendar)
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: [],
            weights: [oldWeight]
        )

        XCTAssertEqual(plans.map(\.fireDate), [
            try date(2026, 6, 10, 9, 0, calendar: calendar)
        ])
    }

    func testFullScheduleIncludingDailyWeightStaysBelowSystemLimit() throws {
        let calendar = utcCalendar()
        let now = try date(2026, 6, 10, 7, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            breakfastEnabled: true,
            lunchEnabled: true,
            snackEnabled: true,
            dinnerEnabled: true,
            waterEnabled: true,
            weightEnabled: true,
            weightFrequency: .daily
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: [],
            weights: []
        )

        XCTAssertEqual(plans.count, 60)
        XCTAssertLessThanOrEqual(plans.count, ReminderSchedulePlanner.pendingNotificationLimit)
        XCTAssertEqual(Set(plans.map(\.identifier)).count, plans.count)
    }

    func testSpringDSTMovesNonexistentMealTimeForwardWithoutChangingDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try date(2026, 3, 7, 23, 0, calendar: calendar)
        let preferences = ReminderPreferences(
            breakfastEnabled: true,
            breakfastTime: ReminderTime(hour: 2, minute: 30)
        )

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: [],
            water: []
        )
        let first = try XCTUnwrap(plans.first)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: first.fireDate)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.hour, 3)
        XCTAssertGreaterThan(first.fireDate, now)
    }

#if !SWIFT_PACKAGE
    @MainActor
    func testWidgetWaterImportPersistsSharedSummaryWithoutTodayView() throws {
        let container = try ModelContainer(
            for: WaterDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let suiteName = WidgetDailySummaryStore.appGroupIdentifier
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let previousData = defaults.data(forKey: "dailySummary")
        defer {
            if let previousData {
                defaults.set(previousData, forKey: "dailySummary")
            } else {
                defaults.removeObject(forKey: "dailySummary")
            }
        }
        WidgetDailySummaryStore.save(
            calories: 300,
            waterGlasses: 4,
            lastWaterRecordedAt: today,
            calorieGoal: 1_700,
            waterGoal: 8,
            date: today,
            reloadWidget: false
        )

        var synchronizedGlasses: Int?
        try WidgetWaterImportService.synchronize(
            in: container,
            calendar: Calendar(identifier: .gregorian),
            now: today,
            synchronizeExternalSurfaces: { context, _ in
                synchronizedGlasses = try? context.fetch(FetchDescriptor<WaterDay>()).first?.glasses
            }
        )

        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<WaterDay>()).first)
        XCTAssertEqual(saved.glasses, 4)
        XCTAssertEqual(saved.lastRecordedAt, today)
        XCTAssertEqual(synchronizedGlasses, 4)
        XCTAssertEqual(WidgetDailySummaryStore.pendingWaterRevision(), 0)
    }

    @MainActor
    func testAppMirrorPreservesPendingWidgetWaterUntilImport() throws {
        let today = Date()
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: WidgetDailySummaryStore.appGroupIdentifier
        ))
        let previousData = defaults.data(forKey: "dailySummary")
        defer {
            if let previousData {
                defaults.set(previousData, forKey: "dailySummary")
            } else {
                defaults.removeObject(forKey: "dailySummary")
            }
        }
        WidgetDailySummaryStore.save(
            calories: 100,
            waterGlasses: 4,
            calorieGoal: 1_700,
            waterGoal: 8,
            date: today,
            reloadWidget: false
        )
        var pending = try XCTUnwrap(WidgetDailySummaryStore.load())
        pending.waterGlasses = 5
        pending.revision = 1
        defaults.set(try JSONEncoder().encode(pending), forKey: "dailySummary")

        WidgetDailySummaryStore.save(
            calories: 200,
            waterGlasses: 4,
            calorieGoal: 1_700,
            waterGoal: 8,
            date: today,
            reloadWidget: false
        )

        let merged = try XCTUnwrap(WidgetDailySummaryStore.load())
        XCTAssertEqual(merged.calories, 200)
        XCTAssertEqual(merged.waterGlasses, 5)
        XCTAssertEqual(merged.resolvedRevision, 1)
    }

    func testLegacyWidgetSummaryDecodesWithoutWaterTimestamp() throws {
        let data = #"{"date":0,"calories":120,"waterGlasses":2}"#.data(using: .utf8)!

        let summary = try JSONDecoder().decode(WidgetDailySummary.self, from: data)

        XCTAssertEqual(summary.calories, 120)
        XCTAssertEqual(summary.waterGlasses, 2)
        XCTAssertNil(summary.lastWaterRecordedAt)
        XCTAssertNil(summary.calorieGoal)
        XCTAssertNil(summary.waterGoal)
        XCTAssertNil(summary.revision)
    }
#endif

    func testStoredPreferencesKeepReminderTypesIndependent() throws {
        let suiteName = "ReminderNotificationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: ReminderPreferenceKey.lunch)
        defaults.set(true, forKey: ReminderPreferenceKey.water)

        let preferences = ReminderPreferences.stored(in: defaults)

        XCTAssertFalse(preferences.breakfastEnabled)
        XCTAssertTrue(preferences.lunchEnabled)
        XCTAssertFalse(preferences.snackEnabled)
        XCTAssertFalse(preferences.dinnerEnabled)
        XCTAssertTrue(preferences.waterEnabled)
    }

    func testStoredPreferencesRoundTripTimesWeightAndLegacyDefaults() throws {
        let suiteName = "ReminderNotificationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacy = ReminderPreferences.stored(in: defaults)
        XCTAssertEqual(legacy.breakfastTime, ReminderTime(hour: 9, minute: 0))
        XCTAssertEqual(legacy.lunchTime, ReminderTime(hour: 13, minute: 0))
        XCTAssertEqual(legacy.snackTime, ReminderTime(hour: 16, minute: 0))
        XCTAssertEqual(legacy.dinnerTime, ReminderTime(hour: 20, minute: 0))
        XCTAssertFalse(legacy.weightEnabled)
        XCTAssertEqual(legacy.weightFrequency, .weekly)

        let expected = ReminderPreferences(
            breakfastEnabled: true,
            snackEnabled: true,
            waterEnabled: true,
            weightEnabled: true,
            breakfastTime: ReminderTime(hour: 7, minute: 25),
            lunchTime: ReminderTime(hour: 12, minute: 10),
            snackTime: ReminderTime(hour: 15, minute: 35),
            dinnerTime: ReminderTime(hour: 19, minute: 50),
            weightTime: ReminderTime(hour: 8, minute: 5),
            weightFrequency: .daily
        )
        expected.store(in: defaults)

        XCTAssertEqual(ReminderPreferences.stored(in: defaults), expected)
    }

    func testInvalidStoredTimesFallBackIndependently() throws {
        let suiteName = "ReminderNotificationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(-1, forKey: ReminderPreferenceKey.breakfastTime)
        defaults.set(24 * 60, forKey: ReminderPreferenceKey.lunchTime)
        defaults.set(17 * 60 + 12, forKey: ReminderPreferenceKey.snackTime)

        let preferences = ReminderPreferences.stored(in: defaults)

        XCTAssertEqual(preferences.breakfastTime, ReminderTime(hour: 9, minute: 0))
        XCTAssertEqual(preferences.lunchTime, ReminderTime(hour: 13, minute: 0))
        XCTAssertEqual(preferences.snackTime, ReminderTime(hour: 17, minute: 12))
    }

    func testAllDisabledPreferencesProduceNoPlans() throws {
        let calendar = utcCalendar()

        let plans = ReminderSchedulePlanner.plans(
            now: try date(2026, 6, 10, 7, 0, calendar: calendar),
            calendar: calendar,
            preferences: ReminderPreferences(),
            meals: [],
            water: []
        )

        XCTAssertTrue(plans.isEmpty)
    }

#if !SWIFT_PACKAGE
    private func notificationRequest(identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: identifier,
            content: UNMutableNotificationContent(),
            trigger: nil
        )
    }
#endif

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
