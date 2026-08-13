import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

@MainActor
final class CalorieTrackingTests: XCTestCase {
#if !SWIFT_PACKAGE
    func testLiveActivityCalorieStatusHandlesRemainingOverAndInvalidValues() {
        let remaining = CaloriesActivityAttributes.ContentState(
            calories: 1_240,
            waterGlasses: 5,
            calorieGoal: 2_000,
            waterGoal: 8
        ).calorieStatus()
        let over = CaloriesActivityAttributes.ContentState(
            calories: 2_125,
            waterGlasses: 8,
            calorieGoal: 2_000,
            waterGoal: 8
        ).calorieStatus()
        let invalid = CaloriesActivityAttributes.ContentState(
            calories: -40,
            waterGlasses: 0,
            calorieGoal: 0,
            waterGoal: 0
        ).calorieStatus()

        XCTAssertEqual(remaining.value, 760)
        XCTAssertFalse(remaining.isOverGoal)
        XCTAssertEqual(remaining.label, "kcal remaining")
        XCTAssertEqual(over.value, 125)
        XCTAssertTrue(over.isOverGoal)
        XCTAssertEqual(over.label, "kcal over")
        XCTAssertEqual(invalid.value, 1)
        XCTAssertFalse(invalid.isOverGoal)
        XCTAssertEqual(
            CaloriesActivityAttributes.ContentState(
                calories: 0,
                waterGlasses: 0,
                calorieGoal: nil,
                waterGoal: nil
            ).resolvedCalorieGoal,
            1_700
        )
    }
#endif

    func testDefaultAlmondMilkServingContains15Calories() {
        let calories = CalorieCalculator.calories(
            caloriesPerServing: 15,
            servingAmount: 100,
            consumedAmount: 100,
            portionCount: 1
        )

        XCTAssertEqual(calories, 15)
    }

    func testCaloriesScaleForFractionalBeveragePortion() {
        let calories = CalorieCalculator.calories(
            caloriesPerServing: 176,
            servingAmount: 275,
            consumedAmount: 275,
            portionCount: 0.25
        )

        XCTAssertEqual(calories, 44)
    }

    func testCalorieCalculationRejectsInvalidAmounts() {
        XCTAssertEqual(
            CalorieCalculator.calories(
                caloriesPerServing: 100,
                servingAmount: 0,
                consumedAmount: 100,
                portionCount: 1
            ),
            0
        )
        XCTAssertEqual(
            CalorieCalculator.calories(
                caloriesPerServing: 100,
                servingAmount: 100,
                consumedAmount: -1,
                portionCount: 1
            ),
            0
        )
        XCTAssertEqual(
            CalorieCalculator.calories(
                caloriesPerServing: 100,
                servingAmount: 100,
                consumedAmount: 100,
                portionCount: 0
            ),
            0
        )
    }

    func testSuggestedMealUsesExpectedTimeWindows() {
        let expectations: [(hour: Int, meal: MealType)] = [
            (0, .snack),
            (4, .snack),
            (5, .breakfast),
            (10, .breakfast),
            (11, .lunch),
            (15, .lunch),
            (16, .dinner),
            (20, .dinner),
            (21, .snack),
            (23, .snack)
        ]

        for expectation in expectations {
            XCTAssertEqual(
                MealType.suggested(at: date(hour: expectation.hour), calendar: calendar),
                expectation.meal,
                "Unexpected meal at hour \(expectation.hour)"
            )
        }
    }

    func testDailyHistoryGroupsRecordsByCalendarDay() {
        let firstDay = date(day: 1, hour: 8)
        let secondDay = date(day: 2, hour: 8)
        let summaries = CalorieHistory.dailySummaries(
            for: [
                CalorieRecord(date: firstDay, calories: 250),
                CalorieRecord(date: date(day: 1, hour: 18), calories: 700),
                CalorieRecord(date: secondDay, calories: 1_100)
            ],
            calendar: calendar
        )

        XCTAssertEqual(summaries, [
            DailyCalorieSummary(date: calendar.startOfDay(for: firstDay), calories: 950),
            DailyCalorieSummary(date: calendar.startOfDay(for: secondDay), calories: 1_100)
        ])
    }

    func testDailyHistoryKeepsMostRecentFourteenDays() {
        let records = (0..<16).map { dayOffset in
            CalorieRecord(
                date: calendar.date(byAdding: .day, value: dayOffset, to: date(day: 1, hour: 8))!,
                calories: dayOffset
            )
        }

        let summaries = CalorieHistory.dailySummaries(for: records, calendar: calendar)

        XCTAssertEqual(summaries.count, 14)
        XCTAssertEqual(summaries.first?.calories, 2)
        XCTAssertEqual(summaries.last?.calories, 15)
    }

    func testDeepLinksMapWidgetActions() {
        XCTAssertEqual(
            AppDeepLinkAction(url: URL(string: "countcalories://add-food")!),
            .addMeal
        )
        XCTAssertEqual(
            AppDeepLinkAction(url: URL(string: "countcalories://water?delta=1")!),
            .adjustWater(by: 1)
        )
        XCTAssertEqual(
            AppDeepLinkAction(url: URL(string: "countcalories://water?delta=-1")!),
            .adjustWater(by: -1)
        )
    }

    func testDeepLinksRejectUnsupportedOrEmptyActions() {
        XCTAssertNil(AppDeepLinkAction(url: URL(string: "https://add-food")!))
        XCTAssertNil(AppDeepLinkAction(url: URL(string: "countcalories://unknown")!))
        XCTAssertNil(AppDeepLinkAction(url: URL(string: "countcalories://water")!))
        XCTAssertNil(AppDeepLinkAction(url: URL(string: "countcalories://water?delta=0")!))
        XCTAssertNil(AppDeepLinkAction(url: URL(string: "countcalories://water?delta=glass")!))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(day: Int = 1, hour: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: day,
            hour: hour
        ).date!
    }
}
