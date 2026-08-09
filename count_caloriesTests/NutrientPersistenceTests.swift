#if !SWIFT_PACKAGE
import SwiftData
import XCTest
@testable import count_calories

@MainActor
final class NutrientPersistenceTests: XCTestCase {
    func testPlateEntrySnapshotSurvivesFoodNutritionChangeAndReload() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let original = FoodNutrients(
            carbohydratesGrams: 30,
            proteinGrams: 12,
            fatGrams: 8,
            fiberGrams: 5
        )
        let food = Food(
            name: "Snapshot bowl",
            calories: 320,
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
        context.insert(food)
        context.insert(entry)
        try context.save()

        food.carbohydratesGramsPerServing = 99
        food.proteinGramsPerServing = nil
        food.fatGramsPerServing = 1
        food.fiberGramsPerServing = nil
        try context.save()

        let storedEntries = try context.fetch(FetchDescriptor<PlateEntry>())
        let storedFoods = try context.fetch(FetchDescriptor<Food>())
        XCTAssertEqual(storedEntries.count, 1)
        XCTAssertEqual(storedEntries[0].nutrients, original)
        XCTAssertEqual(storedFoods[0].nutrientsPerServing, FoodNutrients(
            carbohydratesGrams: 99,
            proteinGrams: nil,
            fatGrams: 1,
            fiberGrams: nil
        ))
    }

    func testMissingAndExplicitZeroRemainDistinctAfterPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let food = Food(
            name: "Zero drink",
            calories: 0,
            servingGrams: 330,
            servingUnit: .milliliters,
            nutrientsPerServing: FoodNutrients(
                carbohydratesGrams: 0,
                proteinGrams: nil,
                fatGrams: 0,
                fiberGrams: nil
            )
        )
        context.insert(food)
        try context.save()

        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<Food>()).first)
        XCTAssertEqual(stored.carbohydratesGramsPerServing, 0)
        XCTAssertNil(stored.proteinGramsPerServing)
        XCTAssertEqual(stored.fatGramsPerServing, 0)
        XCTAssertNil(stored.fiberGramsPerServing)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Food.self, PlateEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
#endif
