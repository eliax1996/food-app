#if !SWIFT_PACKAGE
import XCTest
@testable import count_calories

final class DailyCaloriesAccessibilitySummaryTests: XCTestCase {
    func testSummaryUsesOneSemanticContractForRemainingAndOverGoal() {
        XCTAssertEqual(
            DailyCaloriesAccessibilitySummary.value(
                calories: 1_200,
                calorieGoal: 1_700,
                caloriesAreComplete: true
            ),
            "1200 calories eaten, 500 calories remaining, daily goal 1700 calories"
        )
        XCTAssertEqual(
            DailyCaloriesAccessibilitySummary.value(
                calories: 1_900,
                calorieGoal: 1_700,
                caloriesAreComplete: true
            ),
            "1900 calories eaten, 200 calories over goal, daily goal 1700 calories"
        )
    }

    func testIncompleteSummaryNeverStatesRemainingBudget() {
        let value = DailyCaloriesAccessibilitySummary.value(
            calories: 600,
            calorieGoal: 1_700,
            caloriesAreComplete: false
        )

        XCTAssertEqual(
            value,
            "Known food entries total 600 calories. Daily budget status unavailable because one or more logged foods has invalid calorie data."
        )
        XCTAssertFalse(value.contains("remaining"))
    }
}
#endif
