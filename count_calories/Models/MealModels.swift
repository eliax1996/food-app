import Foundation
import SwiftData

@Model
final class Food {
    var name: String
    var calories: Int
    var servingGrams: Double
    var servingUnitRawValue: String?
    var barcode: String?
    var carbohydratesGramsPerServing: Double?
    var proteinGramsPerServing: Double?
    var fatGramsPerServing: Double?
    var fiberGramsPerServing: Double?

    init(
        name: String,
        calories: Int,
        servingGrams: Double,
        servingUnit: NutritionUnit = .grams,
        barcode: String? = nil,
        nutrientsPerServing: FoodNutrients = .empty
    ) {
        self.name = name
        self.calories = calories
        self.servingGrams = servingGrams
        servingUnitRawValue = servingUnit.rawValue
        self.barcode = barcode
        carbohydratesGramsPerServing = nutrientsPerServing.carbohydratesGrams
        proteinGramsPerServing = nutrientsPerServing.proteinGrams
        fatGramsPerServing = nutrientsPerServing.fatGrams
        fiberGramsPerServing = nutrientsPerServing.fiberGrams
    }
}

@Model
final class PlateEntry {
    var foodName: String
    var calories: Int
    var weightGrams: Double
    var quantity: Int
    var portionCount: Double?
    var servingUnitRawValue: String?
    var date: Date
    var mealType: String?
    var carbohydratesGrams: Double?
    var proteinGrams: Double?
    var fatGrams: Double?
    var fiberGrams: Double?

    init(
        foodName: String,
        calories: Int,
        weightGrams: Double,
        quantity: Double,
        servingUnit: NutritionUnit = .grams,
        nutrients: FoodNutrients = .empty,
        mealType: String? = nil,
        date: Date = .now
    ) {
        self.foodName = foodName
        self.calories = calories
        self.weightGrams = weightGrams
        self.quantity = max(1, Int(quantity.rounded()))
        portionCount = quantity
        servingUnitRawValue = servingUnit.rawValue
        self.mealType = mealType
        self.date = date
        carbohydratesGrams = nutrients.carbohydratesGrams
        proteinGrams = nutrients.proteinGrams
        fatGrams = nutrients.fatGrams
        fiberGrams = nutrients.fiberGrams
    }
}

extension Food {
    var nutritionUnit: NutritionUnit {
        NutritionUnit(rawValue: servingUnitRawValue ?? "") ?? .grams
    }

    var nutrientsPerServing: FoodNutrients {
        FoodNutrients(
            carbohydratesGrams: carbohydratesGramsPerServing,
            proteinGrams: proteinGramsPerServing,
            fatGrams: fatGramsPerServing,
            fiberGrams: fiberGramsPerServing
        )
    }

    func consumedNutrients(consumedAmount: Double, portionCount: Double) -> FoodNutrients {
        guard
            servingGrams.isFinite,
            servingGrams > 0,
            consumedAmount.isFinite,
            consumedAmount >= 0,
            portionCount.isFinite,
            portionCount > 0
        else { return .empty }
        return nutrientsPerServing.scaled(by: consumedAmount * portionCount / servingGrams)
    }

    func applyNutrition(_ nutrition: FoodNutrition) {
        let servingNutrients = nutrition.nutrients(for: nutrition.defaultAmount.value)
        carbohydratesGramsPerServing = servingNutrients.carbohydratesGrams
        proteinGramsPerServing = servingNutrients.proteinGrams
        fatGramsPerServing = servingNutrients.fatGrams
        fiberGramsPerServing = servingNutrients.fiberGrams
    }

    func matchesLookupProduct(barcode scannedBarcode: String, name scannedName: String) -> Bool {
        if let barcode, !barcode.isEmpty {
            return barcode == scannedBarcode
        }
        return name.localizedCaseInsensitiveCompare(scannedName) == .orderedSame
    }
}

extension PlateEntry {
    var portionQuantity: Double {
        portionCount ?? Double(quantity)
    }

    var nutritionUnit: NutritionUnit {
        NutritionUnit(rawValue: servingUnitRawValue ?? "") ?? .grams
    }

    var nutrients: FoodNutrients {
        FoodNutrients(
            carbohydratesGrams: carbohydratesGrams,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams
        )
    }

    func applyNutritionSnapshot(_ nutrients: FoodNutrients) {
        carbohydratesGrams = nutrients.carbohydratesGrams
        proteinGrams = nutrients.proteinGrams
        fatGrams = nutrients.fatGrams
        fiberGrams = nutrients.fiberGrams
    }
}
