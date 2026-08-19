import Foundation
#if SWIFT_PACKAGE
import CaloriesCore
#endif

nonisolated struct HistoricalFoodScaleResult: Equatable, Sendable {
    let calories: Int
    let multiplier: Double
    let calorieDensity: Double
}

nonisolated enum HistoricalFoodMutation {
    static func scaledSnapshot(
        originalCalories: Int,
        originalAmount: Double,
        originalPortions: Double,
        newAmount: Double,
        newPortions: Double,
        calorieDensity: Double? = nil
    ) -> HistoricalFoodScaleResult? {
        guard
            FoodCaloriePolicy.isValid(originalCalories),
            originalAmount.isFinite,
            originalAmount > 0,
            FoodAmountAdjustment.isValidPortionCount(originalPortions),
            newAmount.isFinite,
            newAmount > 0,
            FoodAmountAdjustment.isValidPortionCount(newPortions)
        else { return nil }

        let oldQuantity = originalAmount * originalPortions
        let newQuantity = newAmount * newPortions
        guard oldQuantity.isFinite, oldQuantity > 0, newQuantity.isFinite else { return nil }

        let multiplier = newQuantity / oldQuantity
        let resolvedDensity: Double
        if let calorieDensity, calorieDensity.isFinite, calorieDensity >= 0 {
            resolvedDensity = calorieDensity
        } else {
            resolvedDensity = Double(originalCalories) / oldQuantity
        }
        let scaledCalories = resolvedDensity * newQuantity
        guard multiplier.isFinite,
              multiplier > 0,
              resolvedDensity.isFinite,
              resolvedDensity >= 0,
              scaledCalories.isFinite,
              scaledCalories >= 0,
              scaledCalories <= Double(FoodCaloriePolicy.maximumCaloriesPerFood) else {
            return nil
        }
        let calories = Int(scaledCalories.rounded())
        guard FoodCaloriePolicy.isValid(calories) else { return nil }
        return HistoricalFoodScaleResult(
            calories: calories,
            multiplier: multiplier,
            calorieDensity: resolvedDensity
        )
    }

    static func isValidTimestamp(_ date: Date, now: Date = .now) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite
            && now.timeIntervalSinceReferenceDate.isFinite
            && date <= now
    }
}
