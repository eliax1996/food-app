import Foundation

nonisolated struct LoggedNutrition: Equatable, Sendable {
    let calories: Int
    let nutrients: FoodNutrients
    let hasValidCalories: Bool

    init(calories: Int, nutrients: FoodNutrients) {
        hasValidCalories = FoodCaloriePolicy.isValid(calories)
        self.calories = hasValidCalories ? calories : 0
        self.nutrients = nutrients
    }
}

nonisolated enum Macronutrient: String, CaseIterable, Equatable, Hashable, Sendable {
    case carbohydrates = "Carbs"
    case protein = "Protein"
    case fat = "Fat"

    var referenceRange: ClosedRange<Double> {
        switch self {
        case .carbohydrates: 0.45...0.65
        case .protein: 0.10...0.35
        case .fat: 0.20...0.35
        }
    }

    fileprivate var guidancePriority: Int {
        switch self {
        case .protein: 0
        case .fat: 1
        case .carbohydrates: 2
        }
    }
}

extension FoodNutrients {
    func grams(for nutrient: Macronutrient) -> Double? {
        switch nutrient {
        case .carbohydrates: carbohydratesGrams
        case .protein: proteinGrams
        case .fat: fatGrams
        }
    }
}

nonisolated struct MacroEnergySplit: Equatable, Sendable {
    let carbohydrates: Double
    let protein: Double
    let fat: Double

    func fraction(for nutrient: Macronutrient) -> Double {
        switch nutrient {
        case .carbohydrates: carbohydrates
        case .protein: protein
        case .fat: fat
        }
    }
}

nonisolated struct MacroEnergyShare: Equatable, Sendable {
    let carbohydrates: Double
    let protein: Double
    let fat: Double

    func fraction(for nutrient: Macronutrient) -> Double {
        switch nutrient {
        case .carbohydrates: carbohydrates
        case .protein: protein
        case .fat: fat
        }
    }
}

nonisolated enum MacroGuidanceStatus: Equatable, Sendable {
    case belowReference
    case aboveReference
    case withinReferences
}

nonisolated struct MacroGuidance: Equatable, Sendable {
    let nutrient: Macronutrient?
    let status: MacroGuidanceStatus
    let measuredFraction: Double?
    let referenceRange: ClosedRange<Double>?

    static let withinReferences = MacroGuidance(
        nutrient: nil,
        status: .withinReferences,
        measuredFraction: nil,
        referenceRange: nil
    )
}

nonisolated struct DailyNutritionSummary: Equatable, Sendable {
    let entryCount: Int
    let totalCalories: Int
    let knownNutrients: FoodNutrients
    let carbohydrateKnownCount: Int
    let proteinKnownCount: Int
    let fatKnownCount: Int
    let fiberKnownCount: Int
    let macroCompleteCount: Int
    let completeCount: Int
    let calorieValidCount: Int
    let macroSplit: MacroEnergySplit?
    let macroEnergyShare: MacroEnergyShare?
    let fiberReferenceGrams: Double?
    let guidance: [MacroGuidance]

    var hasEntries: Bool { entryCount > 0 }
    var hasCompleteMacroCoverage: Bool { entryCount > 0 && macroCompleteCount == entryCount }
    var hasCompleteFiberCoverage: Bool { entryCount > 0 && fiberKnownCount == entryCount }
    var hasCompleteCoverage: Bool { entryCount > 0 && completeCount == entryCount }
    var hasCompleteCalorieCoverage: Bool { entryCount > 0 && calorieValidCount == entryCount }

    func knownCount(for nutrient: Macronutrient) -> Int {
        switch nutrient {
        case .carbohydrates: carbohydrateKnownCount
        case .protein: proteinKnownCount
        case .fat: fatKnownCount
        }
    }
}

nonisolated enum DailyNutrition {
    private static let referenceTolerance = 0.000_001

    static func summary(
        records: [LoggedNutrition],
        calorieGoal: Int
    ) -> DailyNutritionSummary {
        var carbohydrateTotal: Double?
        var proteinTotal: Double?
        var fatTotal: Double?
        var fiberTotal: Double?
        var carbohydrateKnownCount = 0
        var proteinKnownCount = 0
        var fatKnownCount = 0
        var fiberKnownCount = 0
        var macroCompleteCount = 0
        var completeCount = 0

        for record in records {
            let nutrients = record.nutrients
            if let value = nutrients.carbohydratesGrams {
                carbohydrateTotal = (carbohydrateTotal ?? 0) + value
                carbohydrateKnownCount += 1
            }
            if let value = nutrients.proteinGrams {
                proteinTotal = (proteinTotal ?? 0) + value
                proteinKnownCount += 1
            }
            if let value = nutrients.fatGrams {
                fatTotal = (fatTotal ?? 0) + value
                fatKnownCount += 1
            }
            if let value = nutrients.fiberGrams {
                fiberTotal = (fiberTotal ?? 0) + value
                fiberKnownCount += 1
            }
            if nutrients.hasCompleteMacros {
                macroCompleteCount += 1
            }
            if nutrients.isComplete {
                completeCount += 1
            }
        }

        let knownNutrients = FoodNutrients(
            carbohydratesGrams: carbohydrateTotal,
            proteinGrams: proteinTotal,
            fatGrams: fatTotal,
            fiberGrams: fiberTotal
        )
        let totalCalories = FoodCaloriePolicy.total(records.map(\.calories))
        let macrosAreComplete = !records.isEmpty && macroCompleteCount == records.count
        let caloriesAreComplete = records.allSatisfy(\.hasValidCalories)
        let split = macrosAreComplete ? macroEnergySplit(for: knownNutrients) : nil
        let energyShare = macrosAreComplete && caloriesAreComplete
            ? macroEnergyShare(for: knownNutrients, totalCalories: totalCalories)
            : nil

        return DailyNutritionSummary(
            entryCount: records.count,
            totalCalories: totalCalories,
            knownNutrients: knownNutrients,
            carbohydrateKnownCount: carbohydrateKnownCount,
            proteinKnownCount: proteinKnownCount,
            fatKnownCount: fatKnownCount,
            fiberKnownCount: fiberKnownCount,
            macroCompleteCount: macroCompleteCount,
            completeCount: completeCount,
            calorieValidCount: records.count(where: \.hasValidCalories),
            macroSplit: split,
            macroEnergyShare: energyShare,
            fiberReferenceGrams: calorieGoal > 0 ? 14 * Double(calorieGoal) / 1_000 : nil,
            guidance: energyShare.map(guidance(for:)) ?? []
        )
    }

    private static func macroEnergySplit(for nutrients: FoodNutrients) -> MacroEnergySplit? {
        guard
            let carbohydrates = nutrients.carbohydratesGrams,
            let protein = nutrients.proteinGrams,
            let fat = nutrients.fatGrams
        else { return nil }

        let carbohydrateEnergy = carbohydrates * 4
        let proteinEnergy = protein * 4
        let fatEnergy = fat * 9
        let total = carbohydrateEnergy + proteinEnergy + fatEnergy
        guard total.isFinite, total > 0 else { return nil }

        return MacroEnergySplit(
            carbohydrates: carbohydrateEnergy / total,
            protein: proteinEnergy / total,
            fat: fatEnergy / total
        )
    }

    private static func macroEnergyShare(
        for nutrients: FoodNutrients,
        totalCalories: Int
    ) -> MacroEnergyShare? {
        guard
            totalCalories > 0,
            let carbohydrates = nutrients.carbohydratesGrams,
            let protein = nutrients.proteinGrams,
            let fat = nutrients.fatGrams
        else { return nil }

        let calories = Double(totalCalories)
        let share = MacroEnergyShare(
            carbohydrates: carbohydrates * 4 / calories,
            protein: protein * 4 / calories,
            fat: fat * 9 / calories
        )
        guard
            share.carbohydrates.isFinite,
            share.protein.isFinite,
            share.fat.isFinite
        else { return nil }
        return share
    }

    private static func guidance(for share: MacroEnergyShare) -> [MacroGuidance] {
        let gaps = Macronutrient.allCases.compactMap { nutrient -> (Double, MacroGuidance)? in
            let measured = share.fraction(for: nutrient)
            let range = nutrient.referenceRange
            if measured < range.lowerBound - referenceTolerance {
                return (
                    range.lowerBound - measured,
                    MacroGuidance(
                        nutrient: nutrient,
                        status: .belowReference,
                        measuredFraction: measured,
                        referenceRange: range
                    )
                )
            }
            if measured > range.upperBound + referenceTolerance {
                return (
                    measured - range.upperBound,
                    MacroGuidance(
                        nutrient: nutrient,
                        status: .aboveReference,
                        measuredFraction: measured,
                        referenceRange: range
                    )
                )
            }
            return nil
        }

        let ranked = gaps.sorted { lhs, rhs in
            if lhs.0 != rhs.0 {
                return lhs.0 > rhs.0
            }
            return (lhs.1.nutrient?.guidancePriority ?? .max)
                < (rhs.1.nutrient?.guidancePriority ?? .max)
        }
        let guidance = ranked.prefix(2).map(\.1)
        return guidance.isEmpty ? [.withinReferences] : guidance
    }
}
