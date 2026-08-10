import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

final class NutritionReferencePlanTests: XCTestCase {
    func testReferencesDerivePercentAndGramRangesFromCalorieGoal() throws {
        let plan = try XCTUnwrap(NutritionReferencePlan(calorieGoal: 1_700))

        XCTAssertEqual(plan.calorieGoal, 1_700)
        XCTAssertEqual(plan.carbohydrate.energyFractionRange, 0.45...0.65)
        XCTAssertEqual(plan.carbohydrate.gramsRange.lowerBound, 191.25, accuracy: 0.000_001)
        XCTAssertEqual(plan.carbohydrate.gramsRange.upperBound, 276.25, accuracy: 0.000_001)
        XCTAssertEqual(plan.protein.energyFractionRange, 0.10...0.35)
        XCTAssertEqual(plan.protein.gramsRange.lowerBound, 42.5, accuracy: 0.000_001)
        XCTAssertEqual(plan.protein.gramsRange.upperBound, 148.75, accuracy: 0.000_001)
        XCTAssertEqual(plan.fat.energyFractionRange, 0.20...0.35)
        XCTAssertEqual(plan.fat.gramsRange.lowerBound, 37.777_777, accuracy: 0.000_001)
        XCTAssertEqual(plan.fat.gramsRange.upperBound, 66.111_111, accuracy: 0.000_001)
        XCTAssertEqual(plan.fiberGrams, 23.8, accuracy: 0.000_001)
    }

    func testReferencesRecalculateForChangedGoal() throws {
        let plan = try XCTUnwrap(NutritionReferencePlan(calorieGoal: 2_000))

        XCTAssertEqual(plan.reference(for: .carbohydrates).gramsRange, 225...325)
        XCTAssertEqual(plan.reference(for: .protein).gramsRange, 50...175)
        XCTAssertEqual(plan.reference(for: .fat).gramsRange.lowerBound, 44.444_444, accuracy: 0.000_001)
        XCTAssertEqual(plan.reference(for: .fat).gramsRange.upperBound, 77.777_777, accuracy: 0.000_001)
        XCTAssertEqual(plan.fiberGrams, 28, accuracy: 0.000_001)
    }

    func testReferencesRejectNonpositiveGoals() {
        XCTAssertNil(NutritionReferencePlan(calorieGoal: 0))
        XCTAssertNil(NutritionReferencePlan(calorieGoal: -1))
    }
}
