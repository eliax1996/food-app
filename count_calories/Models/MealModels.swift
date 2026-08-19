import Foundation
import SwiftData

nonisolated enum LoggedSnapshotKind: String, Sendable {
    case item
}

nonisolated struct PlateEntryMutationSnapshot: Equatable, Sendable {
    let stableID: UUID
    let foodName: String
    let calories: Int
    let loggedAmount: Double
    let portionCount: Double
    let legacyQuantity: Int
    let storedPortionCount: Double?
    let servingUnitRawValue: String?
    let rawCarbohydratesGrams: Double?
    let rawProteinGrams: Double?
    let rawFatGrams: Double?
    let rawFiberGrams: Double?
    let mealType: String?
    let date: Date
    let createdAt: Date
    let modifiedAt: Date
    let loggedSnapshotKindRawValue: String?
    let loggedCalorieDensity: Double?
    let deletionOperationID: UUID?

    var isKnownItem: Bool {
        loggedSnapshotKindRawValue == LoggedSnapshotKind.item.rawValue
    }

    var nutrients: FoodNutrients {
        FoodNutrients(
            carbohydratesGrams: rawCarbohydratesGrams,
            proteinGrams: rawProteinGrams,
            fatGrams: rawFatGrams,
            fiberGrams: rawFiberGrams
        )
    }

    var hasValidRawNutrients: Bool {
        [rawCarbohydratesGrams, rawProteinGrams, rawFatGrams, rawFiberGrams]
            .allSatisfy { value in
                guard let value else { return true }
                return value.isFinite && value >= 0
            }
    }

    func withDeletionOperationID(_ operationID: UUID) -> PlateEntryMutationSnapshot {
        PlateEntryMutationSnapshot(
            stableID: stableID,
            foodName: foodName,
            calories: calories,
            loggedAmount: loggedAmount,
            portionCount: portionCount,
            legacyQuantity: legacyQuantity,
            storedPortionCount: storedPortionCount,
            servingUnitRawValue: servingUnitRawValue,
            rawCarbohydratesGrams: rawCarbohydratesGrams,
            rawProteinGrams: rawProteinGrams,
            rawFatGrams: rawFatGrams,
            rawFiberGrams: rawFiberGrams,
            mealType: mealType,
            date: date,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            loggedSnapshotKindRawValue: loggedSnapshotKindRawValue,
            loggedCalorieDensity: loggedCalorieDensity,
            deletionOperationID: operationID
        )
    }
}

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
    private static func compatibilityQuantity(from value: Double) -> Int {
        guard value.isFinite,
              let rounded = Int(exactly: value.rounded()) else {
            return 1
        }
        return max(1, rounded)
    }

    private static func calorieDensity(
        calories: Int,
        amount: Double,
        portions: Double
    ) -> Double? {
        guard FoodCaloriePolicy.isValid(calories),
              amount.isFinite,
              amount > 0,
              FoodAmountAdjustment.isValidPortionCount(portions) else {
            return nil
        }
        let quantity = amount * portions
        guard quantity.isFinite, quantity > 0 else { return nil }
        let density = Double(calories) / quantity
        return density.isFinite && density >= 0 ? density : nil
    }

    private static func validatedCalorieDensity(_ density: Double?) -> Double? {
        guard let density, density.isFinite, density >= 0 else { return nil }
        return density
    }

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
    // Nil preserves unknown provenance. One-time migration classifies only rows matching one saved food.
    private(set) var loggedSnapshotKindRawValue: String?
    // Preserves rounded calorie density across repeated historical amount edits.
    private(set) var loggedCalorieDensity: Double?

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
        modifiedAt: Date? = nil,
        loggedSnapshotKind: LoggedSnapshotKind? = .item,
        loggedCalorieDensity: Double? = nil
    ) {
        self.stableID = stableID
        identityValidatedForAdaptation = stableID != .zero
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.foodName = foodName
        self.calories = calories
        self.weightGrams = weightGrams
        self.quantity = Self.compatibilityQuantity(from: quantity)
        portionCount = quantity
        servingUnitRawValue = servingUnit.rawValue
        self.mealType = mealType
        self.date = date
        carbohydratesGrams = nutrients.carbohydratesGrams
        proteinGrams = nutrients.proteinGrams
        fatGrams = nutrients.fatGrams
        fiberGrams = nutrients.fiberGrams
        loggedSnapshotKindRawValue = loggedSnapshotKind?.rawValue
        self.loggedCalorieDensity = Self.validatedCalorieDensity(loggedCalorieDensity)
            ?? Self.calorieDensity(calories: calories, amount: weightGrams, portions: quantity)
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
        loggedCalorieDensity: Double?,
        access: PlanEvidenceMutationAccess
    ) {
        self.foodName = foodName
        self.calories = calories
        self.weightGrams = weightGrams
        self.quantity = Self.compatibilityQuantity(from: quantity)
        portionCount = quantity
        self.servingUnitRawValue = servingUnitRawValue
        carbohydratesGrams = nutrients.carbohydratesGrams
        proteinGrams = nutrients.proteinGrams
        fatGrams = nutrients.fatGrams
        fiberGrams = nutrients.fiberGrams
        self.mealType = mealType
        self.date = date
        self.modifiedAt = modifiedAt
        loggedSnapshotKindRawValue = LoggedSnapshotKind.item.rawValue
        self.loggedCalorieDensity = Self.validatedCalorieDensity(loggedCalorieDensity)
            ?? Self.calorieDensity(calories: calories, amount: weightGrams, portions: quantity)
    }

    func advanceModificationDate(_ date: Date, access: PlanEvidenceMutationAccess) {
        modifiedAt = date
    }

    func classifyAsItemSnapshotIfUnknown(access: PlanEvidenceMutationAccess) {
        guard loggedSnapshotKindRawValue == nil else { return }
        loggedSnapshotKindRawValue = LoggedSnapshotKind.item.rawValue
        if loggedCalorieDensity == nil {
            loggedCalorieDensity = Self.calorieDensity(
                calories: calories,
                amount: loggedAmount,
                portions: portionQuantity
            )
        }
    }

    func restoreLoggedSnapshot(
        _ snapshot: PlateEntryMutationSnapshot,
        access: PlanEvidenceMutationAccess
    ) {
        foodName = snapshot.foodName
        calories = snapshot.calories
        weightGrams = snapshot.loggedAmount
        quantity = snapshot.legacyQuantity
        portionCount = snapshot.storedPortionCount
        servingUnitRawValue = snapshot.servingUnitRawValue
        carbohydratesGrams = snapshot.rawCarbohydratesGrams
        proteinGrams = snapshot.rawProteinGrams
        fatGrams = snapshot.rawFatGrams
        fiberGrams = snapshot.rawFiberGrams
        mealType = snapshot.mealType
        date = snapshot.date
        createdAt = snapshot.createdAt
        modifiedAt = snapshot.modifiedAt
        loggedSnapshotKindRawValue = snapshot.loggedSnapshotKindRawValue
        loggedCalorieDensity = snapshot.loggedCalorieDensity
        identityValidatedForAdaptation = stableID != .zero
    }

    // Legacy property name predates volume servings. Magnitude is expressed in nutritionUnit.
    var loggedAmount: Double {
        weightGrams
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

    var loggedSnapshotKind: LoggedSnapshotKind? {
        loggedSnapshotKindRawValue.flatMap(LoggedSnapshotKind.init(rawValue:))
    }

    var resolvedLoggedCalorieDensity: Double? {
        Self.validatedCalorieDensity(loggedCalorieDensity)
            ?? Self.calorieDensity(
                calories: calories,
                amount: loggedAmount,
                portions: portionQuantity
            )
    }

    var calorieDiaryRecord: CalorieDiaryRecord {
        CalorieDiaryRecord(
            id: stableID,
            date: date,
            mealType: mealType,
            foodName: foodName,
            calories: calories,
            loggedAmount: loggedAmount,
            portionCount: portionQuantity,
            unitRawValue: servingUnitRawValue,
            carbohydratesGrams: carbohydratesGrams,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            modifiedAt: modifiedAt,
            loggedSnapshotKindRawValue: loggedSnapshotKindRawValue,
            loggedCalorieDensity: resolvedLoggedCalorieDensity
        )
    }

    var mutationSnapshot: PlateEntryMutationSnapshot {
        PlateEntryMutationSnapshot(
            stableID: stableID,
            foodName: foodName,
            calories: calories,
            loggedAmount: loggedAmount,
            portionCount: portionQuantity,
            legacyQuantity: quantity,
            storedPortionCount: portionCount,
            servingUnitRawValue: servingUnitRawValue,
            rawCarbohydratesGrams: carbohydratesGrams,
            rawProteinGrams: proteinGrams,
            rawFatGrams: fatGrams,
            rawFiberGrams: fiberGrams,
            mealType: mealType,
            date: date,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            loggedSnapshotKindRawValue: loggedSnapshotKindRawValue,
            loggedCalorieDensity: loggedCalorieDensity,
            deletionOperationID: nil
        )
    }

    func applyNutritionSnapshot(_ nutrients: FoodNutrients) {
        carbohydratesGrams = nutrients.carbohydratesGrams
        proteinGrams = nutrients.proteinGrams
        fatGrams = nutrients.fatGrams
        fiberGrams = nutrients.fiberGrams
    }
}
