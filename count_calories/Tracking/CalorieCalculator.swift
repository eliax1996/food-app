import Foundation

enum CalorieCalculator {
    static func calories(
        caloriesPerServing: Int,
        servingAmount: Double,
        consumedAmount: Double,
        portionCount: Double
    ) -> Int {
        guard
            caloriesPerServing >= 0,
            servingAmount > 0,
            consumedAmount > 0,
            portionCount > 0
        else {
            return 0
        }

        let result = Double(caloriesPerServing) / servingAmount * consumedAmount * portionCount
        guard result.isFinite else { return 0 }
        guard result < Double(Int.max) else { return Int.max }
        return Int(result.rounded())
    }
}
