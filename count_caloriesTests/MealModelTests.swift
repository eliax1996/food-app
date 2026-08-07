#if !SWIFT_PACKAGE
import XCTest
@testable import count_calories

@MainActor
final class MealModelTests: XCTestCase {
    func testPlateEntryStoresFractionalQuantityAndVolumeUnit() {
        let entry = PlateEntry(
            foodName: "La Nostra Limonata",
            calories: 44,
            weightGrams: 275,
            quantity: 0.25,
            servingUnit: .milliliters
        )

        XCTAssertEqual(entry.portionQuantity, 0.25)
        XCTAssertEqual(entry.nutritionUnit, .milliliters)
    }

    func testLegacyPlateEntryFallsBackToStoredIntegerQuantity() {
        let entry = PlateEntry(
            foodName: "Apple",
            calories: 104,
            weightGrams: 100,
            quantity: 2
        )
        entry.portionCount = nil

        XCTAssertEqual(entry.portionQuantity, 2)
    }

    func testBarcodeLookupDoesNotOverwriteDifferentScannedProductWithSameName() {
        let existingScannedFood = Food(
            name: "Cola",
            calories: 42,
            servingGrams: 330,
            barcode: "11111111"
        )
        let manuallyAddedFood = Food(name: "Cola", calories: 42, servingGrams: 330)

        XCTAssertFalse(
            existingScannedFood.matchesLookupProduct(barcode: "22222222", name: "Cola")
        )
        XCTAssertTrue(
            existingScannedFood.matchesLookupProduct(barcode: "11111111", name: "Different label")
        )
        XCTAssertTrue(
            manuallyAddedFood.matchesLookupProduct(barcode: "22222222", name: "cola")
        )
    }

    func testLegacyFoodWithoutUnitFallsBackToGrams() {
        let food = Food(name: "Apple", calories: 52, servingGrams: 100)
        food.servingUnitRawValue = nil

        XCTAssertEqual(food.nutritionUnit, .grams)
    }
}
#endif
