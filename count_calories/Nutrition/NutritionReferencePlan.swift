import Foundation

nonisolated struct MacronutrientReference: Equatable, Sendable {
    let nutrient: Macronutrient
    let energyFractionRange: ClosedRange<Double>
    let gramsRange: ClosedRange<Double>
}

nonisolated struct NutritionReferencePlan: Equatable, Sendable {
    let calorieGoal: Int
    let carbohydrate: MacronutrientReference
    let protein: MacronutrientReference
    let fat: MacronutrientReference
    let fiberGrams: Double

    init?(calorieGoal: Int) {
        guard calorieGoal > 0 else { return nil }

        let calories = Double(calorieGoal)
        guard calories.isFinite else { return nil }

        guard
            let carbohydrate = Self.reference(for: .carbohydrates, calories: calories),
            let protein = Self.reference(for: .protein, calories: calories),
            let fat = Self.reference(for: .fat, calories: calories)
        else {
            return nil
        }

        let fiberGrams = calories * 14 / 1_000
        guard fiberGrams.isFinite else { return nil }

        self.calorieGoal = calorieGoal
        self.carbohydrate = carbohydrate
        self.protein = protein
        self.fat = fat
        self.fiberGrams = fiberGrams
    }

    func reference(for nutrient: Macronutrient) -> MacronutrientReference {
        switch nutrient {
        case .carbohydrates: carbohydrate
        case .protein: protein
        case .fat: fat
        }
    }

    private static func reference(
        for nutrient: Macronutrient,
        calories: Double
    ) -> MacronutrientReference? {
        let energyRange = nutrient.referenceRange
        let lower = calories * energyRange.lowerBound / nutrient.kilocaloriesPerGram
        let upper = calories * energyRange.upperBound / nutrient.kilocaloriesPerGram
        guard lower.isFinite, upper.isFinite else { return nil }

        return MacronutrientReference(
            nutrient: nutrient,
            energyFractionRange: energyRange,
            gramsRange: lower...upper
        )
    }
}

private extension Macronutrient {
    nonisolated var kilocaloriesPerGram: Double {
        switch self {
        case .carbohydrates, .protein: 4
        case .fat: 9
        }
    }
}
