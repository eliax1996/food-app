import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

final class PersonalNutritionTargetsTests: XCTestCase {
    func testTargetInputRequiresCompleteLocaleAwareNumericSyntax() {
        let english = Locale(identifier: "en_US")
        let german = Locale(identifier: "de_DE")

        XCTAssertEqual(PersonalNutritionTargetInput.value(from: "1.25", locale: english), 1.25)
        XCTAssertEqual(PersonalNutritionTargetInput.value(from: "1,25", locale: german), 1.25)
        XCTAssertEqual(PersonalNutritionTargetInput.value(from: "1e-4", locale: english), 0.0001)
        for invalid in ["1.2.3", "1+2", "1,25", "1,2,3", "--1", "1e", "1 2"] {
            XCTAssertNil(PersonalNutritionTargetInput.value(from: invalid, locale: english))
        }
        XCTAssertNil(PersonalNutritionTargetInput.value(from: "1.25", locale: german))
    }

    func testTargetInputLosslesslyRoundTripsPersistedDouble() throws {
        let locale = Locale(identifier: "de_DE")
        let value = 12.345_678_901_234_5
        let text = PersonalNutritionTargetInput.text(for: value, locale: locale)
        XCTAssertEqual(try XCTUnwrap(PersonalNutritionTargetInput.value(from: text, locale: locale)), value)
    }

    func testValidTargetsExposeExactGramsAndMacroEnergy() throws {
        let targets = try XCTUnwrap(PersonalNutritionTargets(
            carbohydratesGrams: 220,
            proteinGrams: 120,
            fatGrams: 60,
            fiberGrams: 28
        ))

        XCTAssertEqual(targets.grams(for: .carbohydrates), 220)
        XCTAssertEqual(targets.grams(for: .protein), 120)
        XCTAssertEqual(targets.grams(for: .fat), 60)
        XCTAssertEqual(targets.fiberGrams, 28)
        XCTAssertEqual(targets.macroEnergyCalories, 1_900)
    }

    func testTargetsRejectPartialSentinelsNonfiniteAndUnsupportedBounds() {
        XCTAssertNil(PersonalNutritionTargets(
            carbohydratesGrams: 0,
            proteinGrams: 120,
            fatGrams: 60,
            fiberGrams: 28
        ))
        XCTAssertNil(PersonalNutritionTargets(
            carbohydratesGrams: .infinity,
            proteinGrams: 120,
            fatGrams: 60,
            fiberGrams: 28
        ))
        XCTAssertNil(PersonalNutritionTargets(
            carbohydratesGrams: 220,
            proteinGrams: 120,
            fatGrams: 60,
            fiberGrams: 201
        ))
        XCTAssertNil(PersonalNutritionTargets(
            carbohydratesGrams: 1_000,
            proteinGrams: 1_000,
            fatGrams: 1,
            fiberGrams: 28
        ))
    }

    func testTargetsRoundTripAndCorruptPayloadFailsClosed() throws {
        let targets = try XCTUnwrap(PersonalNutritionTargets(
            carbohydratesGrams: 220,
            proteinGrams: 120,
            fatGrams: 60,
            fiberGrams: 28
        ))
        let data = try JSONEncoder().encode(targets)
        XCTAssertEqual(try JSONDecoder().decode(PersonalNutritionTargets.self, from: data), targets)

        let corrupt = Data("""
        {"carbohydratesGrams":220,"proteinGrams":120,"fatGrams":60,"fiberGrams":500}
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(PersonalNutritionTargets.self, from: corrupt))
    }
}
