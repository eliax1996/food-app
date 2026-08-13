import Foundation
#if SWIFT_PACKAGE
import CaloriesCore
#endif

nonisolated public enum CalorieCalculator {
    public static let maximumCalories = FoodCaloriePolicy.maximumCaloriesPerFood

    public static func isValidCalories(_ calories: Int) -> Bool {
        FoodCaloriePolicy.isValid(calories)
    }

    public static func assessedTotal<S: Sequence>(_ values: S) -> FoodCalorieTotal where S.Element == Int {
        FoodCaloriePolicy.assessedTotal(values)
    }

    public static func total<S: Sequence>(_ values: S) -> Int where S.Element == Int {
        assessedTotal(values).calories
    }

    public static func calculatedCalories(
        caloriesPerServing: Int,
        servingAmount: Double,
        consumedAmount: Double,
        portionCount: Double
    ) -> Int? {
        guard
            isValidCalories(caloriesPerServing),
            servingAmount.isFinite,
            consumedAmount.isFinite,
            portionCount.isFinite,
            servingAmount > 0,
            consumedAmount > 0,
            portionCount > 0
        else {
            return nil
        }

        let result = Double(caloriesPerServing) / servingAmount * consumedAmount * portionCount
        guard result.isFinite, result >= 0, result <= Double(maximumCalories) else { return nil }
        return Int(result.rounded())
    }

    public static func calories(
        caloriesPerServing: Int,
        servingAmount: Double,
        consumedAmount: Double,
        portionCount: Double
    ) -> Int {
        calculatedCalories(
            caloriesPerServing: caloriesPerServing,
            servingAmount: servingAmount,
            consumedAmount: consumedAmount,
            portionCount: portionCount
        ) ?? 0
    }
}
