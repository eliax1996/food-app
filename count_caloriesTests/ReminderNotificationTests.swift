#if !SWIFT_PACKAGE
import Foundation
import XCTest
@testable import count_calories

@MainActor
final class ReminderNotificationTests: XCTestCase {
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
        XCTAssertLessThanOrEqual(plans.count, 64)
        XCTAssertEqual(Set(plans.map(\.identifier)).count, plans.count)
    }

    func testLegacyWidgetSummaryDecodesWithoutWaterTimestamp() throws {
        let data = #"{"date":0,"calories":120,"waterGlasses":2}"#.data(using: .utf8)!

        let summary = try JSONDecoder().decode(WidgetDailySummary.self, from: data)

        XCTAssertEqual(summary.calories, 120)
        XCTAssertEqual(summary.waterGlasses, 2)
        XCTAssertNil(summary.lastWaterRecordedAt)
    }

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
#endif
