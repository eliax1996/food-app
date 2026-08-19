import Foundation

nonisolated public enum FoodAmountAdjustment {
    static let minimumAmount: Double = 0.01

    static func isValid(_ amount: Double) -> Bool {
        amount.isFinite && amount >= minimumAmount
    }

    public static func isValidPortionCount(_ portionCount: Double) -> Bool {
        portionCount.isFinite
            && portionCount > 0
            && Int(exactly: portionCount.rounded()) != nil
    }

    static func result(for amount: Double, delta: Double) -> Double? {
        guard amount.isFinite, delta.isFinite else { return nil }

        let adjustedAmount = amount + delta
        guard adjustedAmount.isFinite else { return nil }

        if abs(adjustedAmount - minimumAmount) <= boundaryTolerance(for: adjustedAmount) {
            return minimumAmount
        }

        guard adjustedAmount >= minimumAmount else { return nil }
        return adjustedAmount
    }

    private static func boundaryTolerance(for amount: Double) -> Double {
        let scale = max(1, max(abs(amount), minimumAmount))
        return Double.ulpOfOne * 8 * scale
    }
}
