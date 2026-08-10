import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

final class DailyNutritionTests: XCTestCase {
    func testEmptyDayHasNoCoverageSplitOrGuidance() {
        let summary = DailyNutrition.summary(records: [], calorieGoal: 1_700)

        XCTAssertFalse(summary.hasEntries)
        XCTAssertFalse(summary.hasCompleteMacroCoverage)
        XCTAssertNil(summary.macroSplit)
        XCTAssertNil(summary.macroEnergyShare)
        XCTAssertEqual(summary.guidance, [])
        XCTAssertEqual(summary.fiberReferenceGrams ?? -1, 23.8, accuracy: 0.000_001)
    }

    func testCompleteFactsProduceMeasuredSplitAndRankedGuidance() throws {
        let summary = DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 500,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 20,
                        proteinGrams: 5,
                        fatGrams: 40,
                        fiberGrams: 3
                    )
                ),
                LoggedNutrition(
                    calories: 300,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 30,
                        proteinGrams: 5,
                        fatGrams: 20,
                        fiberGrams: 7
                    )
                )
            ],
            calorieGoal: 2_000
        )

        XCTAssertTrue(summary.hasCompleteCoverage)
        XCTAssertEqual(summary.totalCalories, 800)
        XCTAssertEqual(summary.knownNutrients, FoodNutrients(
            carbohydratesGrams: 50,
            proteinGrams: 10,
            fatGrams: 60,
            fiberGrams: 10
        ))
        let split = try XCTUnwrap(summary.macroSplit)
        XCTAssertEqual(split.carbohydrates, 200.0 / 780.0, accuracy: 0.000_001)
        XCTAssertEqual(split.protein, 40.0 / 780.0, accuracy: 0.000_001)
        XCTAssertEqual(split.fat, 540.0 / 780.0, accuracy: 0.000_001)
        let share = try XCTUnwrap(summary.macroEnergyShare)
        XCTAssertEqual(share.carbohydrates, 200.0 / 800.0, accuracy: 0.000_001)
        XCTAssertEqual(share.protein, 40.0 / 800.0, accuracy: 0.000_001)
        XCTAssertEqual(share.fat, 540.0 / 800.0, accuracy: 0.000_001)
        XCTAssertEqual(summary.guidance.count, 2)
        XCTAssertEqual(summary.guidance.map(\.nutrient), [.fat, .carbohydrates])
        XCTAssertEqual(summary.guidance.map(\.status), [.aboveReference, .belowReference])
    }

    func testPartialFactsRemainVisibleButSuppressSplitAndGuidance() {
        let summary = DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 200,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 20,
                        proteinGrams: 10,
                        fatGrams: 5,
                        fiberGrams: 4
                    )
                ),
                LoggedNutrition(
                    calories: 100,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: nil,
                        proteinGrams: 8,
                        fatGrams: 2,
                        fiberGrams: nil
                    )
                )
            ],
            calorieGoal: 1_700
        )

        XCTAssertEqual(summary.knownNutrients.carbohydratesGrams, 20)
        XCTAssertEqual(summary.knownNutrients.proteinGrams, 18)
        XCTAssertEqual(summary.knownNutrients.fatGrams, 7)
        XCTAssertEqual(summary.knownNutrients.fiberGrams, 4)
        XCTAssertEqual(summary.macroCompleteCount, 1)
        XCTAssertEqual(summary.fiberKnownCount, 1)
        XCTAssertFalse(summary.hasCompleteMacroCoverage)
        XCTAssertFalse(summary.hasCompleteFiberCoverage)
        XCTAssertNil(summary.macroSplit)
        XCTAssertNil(summary.macroEnergyShare)
        XCTAssertTrue(summary.guidance.isEmpty)
    }

    func testExplicitZerosCountAsKnownAndCanCompleteCoverage() {
        let summary = DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 0,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 0,
                        proteinGrams: 0,
                        fatGrams: 0,
                        fiberGrams: 0
                    )
                )
            ],
            calorieGoal: 1_700
        )

        XCTAssertTrue(summary.hasCompleteCoverage)
        XCTAssertEqual(summary.carbohydrateKnownCount, 1)
        XCTAssertEqual(summary.fiberKnownCount, 1)
        XCTAssertNil(summary.macroSplit)
        XCTAssertNil(summary.macroEnergyShare)
        XCTAssertTrue(summary.guidance.isEmpty)
    }

    func testWithinReferenceSplitProducesTransparentWithinStatus() throws {
        let summary = DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 400,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 50,
                        proteinGrams: 25,
                        fatGrams: 11.111_111,
                        fiberGrams: 8
                    )
                )
            ],
            calorieGoal: 2_000
        )

        let split = try XCTUnwrap(summary.macroSplit)
        XCTAssertEqual(split.carbohydrates, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(split.protein, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(split.fat, 0.25, accuracy: 0.000_001)
        let share = try XCTUnwrap(summary.macroEnergyShare)
        XCTAssertEqual(share.carbohydrates, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(share.protein, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(share.fat, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(summary.guidance, [.withinReferences])
    }

    func testAdultRangeGuidanceUsesFoodLabelEnergyNotNormalizedMacroSplit() throws {
        let summary = DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 1_000,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 112.5,
                        proteinGrams: 25,
                        fatGrams: 22.222_222,
                        fiberGrams: 14
                    )
                )
            ],
            calorieGoal: 2_000
        )

        let split = try XCTUnwrap(summary.macroSplit)
        XCTAssertEqual(split.carbohydrates, 0.6, accuracy: 0.000_001)
        XCTAssertEqual(split.protein, 0.133_333, accuracy: 0.000_001)
        XCTAssertEqual(split.fat, 0.266_667, accuracy: 0.000_001)

        let share = try XCTUnwrap(summary.macroEnergyShare)
        XCTAssertEqual(share.carbohydrates, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(share.protein, 0.10, accuracy: 0.000_001)
        XCTAssertEqual(share.fat, 0.20, accuracy: 0.000_001)
        XCTAssertEqual(summary.guidance, [.withinReferences])
    }

    func testInvalidFactsBecomeUnknownInsteadOfZero() {
        let nutrients = FoodNutrients(
            carbohydratesGrams: -.infinity,
            proteinGrams: -1,
            fatGrams: .nan,
            fiberGrams: 0
        )

        XCTAssertNil(nutrients.carbohydratesGrams)
        XCTAssertNil(nutrients.proteinGrams)
        XCTAssertNil(nutrients.fatGrams)
        XCTAssertEqual(nutrients.fiberGrams, 0)
        XCTAssertFalse(nutrients.isComplete)
    }

    func testReportedCaloriesStayIndependentFromMacroEnergy() {
        let summary = DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 999,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 25,
                        proteinGrams: 25,
                        fatGrams: 0,
                        fiberGrams: 1
                    )
                )
            ],
            calorieGoal: 2_000
        )

        XCTAssertEqual(summary.totalCalories, 999)
        XCTAssertEqual(summary.macroSplit?.carbohydrates, 0.5)
        XCTAssertEqual(summary.macroSplit?.protein, 0.5)
        XCTAssertEqual(summary.macroEnergyShare?.carbohydrates ?? -1, 100.0 / 999.0, accuracy: 0.000_001)
        XCTAssertEqual(summary.macroEnergyShare?.protein ?? -1, 100.0 / 999.0, accuracy: 0.000_001)
        XCTAssertNotEqual(summary.guidance, [.withinReferences])
    }
}
