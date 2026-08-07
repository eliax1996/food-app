import Foundation
import SwiftData

@Model
final class Food {
    var name: String
    var calories: Int
    var servingGrams: Double
    var servingUnitRawValue: String?
    var barcode: String?

    init(
        name: String,
        calories: Int,
        servingGrams: Double,
        servingUnit: NutritionUnit = .grams,
        barcode: String? = nil
    ) {
        self.name = name
        self.calories = calories
        self.servingGrams = servingGrams
        servingUnitRawValue = servingUnit.rawValue
        self.barcode = barcode
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

    init(
        foodName: String,
        calories: Int,
        weightGrams: Double,
        quantity: Double,
        servingUnit: NutritionUnit = .grams,
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
    }
}

extension Food {
    var nutritionUnit: NutritionUnit {
        NutritionUnit(rawValue: servingUnitRawValue ?? "") ?? .grams
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
}
