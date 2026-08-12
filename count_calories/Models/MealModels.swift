import Foundation
import SwiftData

@Model
final class Food {
    // Compatibility default lets SwiftData open foods saved before bulk logging.
    // Learning references are accepted only after collision checks.
    private(set) var stableID: UUID = UUID()
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
        stableID: UUID = UUID(),
        servingGrams: Double,
        servingUnit: NutritionUnit = .grams,
        barcode: String? = nil,
        nutrientsPerServing: FoodNutrients = .empty
    ) {
        self.stableID = stableID
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
    // Compatibility defaults let SwiftData open pre-Slice-D rows. Coordinator validates
    // every identity before adaptation and never rewrites a nonzero ID.
    private(set) var stableID: UUID = UUID()
    private(set) var identityValidatedForAdaptation: Bool = false
    private(set) var createdAt: Date = Date.now
    private(set) var modifiedAt: Date = Date.now
    var foodName: String
    private(set) var calories: Int
    var weightGrams: Double
    var quantity: Int
    var portionCount: Double?
    var servingUnitRawValue: String?
    private(set) var date: Date
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
        date: Date = .now,
        stableID: UUID = UUID(),
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.stableID = stableID
        identityValidatedForAdaptation = stableID != .zero
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
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
    func validateOrBackfillIdentity(
        with replacement: UUID,
        access: PlanEvidenceMutationAccess
    ) {
        if stableID == .zero {
            stableID = replacement
        }
    }

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

nonisolated extension UUID {
    static let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

extension PlateEntry {
    func validateOrBackfillIdentity(
        with replacement: UUID,
        at date: Date,
        access: PlanEvidenceMutationAccess
    ) {
        if stableID == .zero {
            stableID = replacement
        }
        if !createdAt.timeIntervalSinceReferenceDate.isFinite {
            createdAt = date
        }
        if !modifiedAt.timeIntervalSinceReferenceDate.isFinite {
            modifiedAt = createdAt
        }
        identityValidatedForAdaptation = true
    }

    func applyEvidenceMutation(
        calories: Int,
        date: Date,
        modifiedAt: Date,
        access: PlanEvidenceMutationAccess
    ) {
        self.calories = calories
        self.date = date
        self.modifiedAt = modifiedAt
    }

    func applyLoggedMeal(
        foodName: String,
        calories: Int,
        weightGrams: Double,
        quantity: Double,
        servingUnitRawValue: String?,
        nutrients: FoodNutrients,
        mealType: String?,
        date: Date,
        modifiedAt: Date,
        access: PlanEvidenceMutationAccess
    ) {
        self.foodName = foodName
        self.calories = calories
        self.weightGrams = weightGrams
        self.quantity = max(1, Int(quantity.rounded()))
        portionCount = quantity
        self.servingUnitRawValue = servingUnitRawValue
        carbohydratesGrams = nutrients.carbohydratesGrams
        proteinGrams = nutrients.proteinGrams
        fatGrams = nutrients.fatGrams
        fiberGrams = nutrients.fiberGrams
        self.mealType = mealType
        self.date = date
        self.modifiedAt = modifiedAt
    }

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
