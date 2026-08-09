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

    func testFoodNutrientsScaleForAmountAndServingCount() {
        let food = Food(
            name: "Fixture Granola",
            calories: 189,
            servingGrams: 45,
            nutrientsPerServing: FoodNutrients(
                carbohydratesGrams: 28.8,
                proteinGrams: 4.5,
                fatGrams: 6.3,
                fiberGrams: 3.6
            )
        )

        let consumed = food.consumedNutrients(consumedAmount: 90, portionCount: 0.5)

        XCTAssertEqual(consumed.carbohydratesGrams ?? -1, 28.8, accuracy: 0.000_001)
        XCTAssertEqual(consumed.proteinGrams ?? -1, 4.5, accuracy: 0.000_001)
        XCTAssertEqual(consumed.fatGrams ?? -1, 6.3, accuracy: 0.000_001)
        XCTAssertEqual(consumed.fiberGrams ?? -1, 3.6, accuracy: 0.000_001)
    }

    func testPlateEntryKeepsNutrientSnapshotAfterFoodChanges() {
        let original = FoodNutrients(
            carbohydratesGrams: 20,
            proteinGrams: 10,
            fatGrams: 5,
            fiberGrams: 4
        )
        let food = Food(
            name: "Soup",
            calories: 200,
            servingGrams: 250,
            nutrientsPerServing: original
        )
        let entry = PlateEntry(
            foodName: food.name,
            calories: food.calories,
            weightGrams: food.servingGrams,
            quantity: 1,
            nutrients: food.nutrientsPerServing
        )

        food.carbohydratesGramsPerServing = 99
        food.proteinGramsPerServing = nil

        XCTAssertEqual(entry.nutrients, original)
    }

    func testLegacyFoodAndEntryKeepMissingNutrientsUnknown() {
        let food = Food(name: "Apple", calories: 52, servingGrams: 100)
        let entry = PlateEntry(
            foodName: food.name,
            calories: food.calories,
            weightGrams: 100,
            quantity: 1
        )

        XCTAssertTrue(food.nutrientsPerServing.isEmpty)
        XCTAssertTrue(entry.nutrients.isEmpty)
        XCTAssertFalse(entry.nutrients.isComplete)
    }
}
#endif
