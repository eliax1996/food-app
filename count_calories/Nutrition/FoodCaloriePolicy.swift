import Foundation

nonisolated public struct FoodCalorieTotal: Equatable, Sendable {
    public let calories: Int
    public let validCount: Int
    public let entryCount: Int

    public var isComplete: Bool { validCount == entryCount }
}

nonisolated public enum FoodCaloriePolicy {
    public static let maximumCaloriesPerFood = 5_000

    public static func isValid(_ calories: Int) -> Bool {
        (0...maximumCaloriesPerFood).contains(calories)
    }

    public static func assessedTotal<S: Sequence>(_ values: S) -> FoodCalorieTotal where S.Element == Int {
        var total = 0
        var validCount = 0
        var entryCount = 0
        for value in values {
            entryCount += 1
            guard isValid(value) else { continue }
            let result = total.addingReportingOverflow(value)
            guard !result.overflow else { continue }
            total = result.partialValue
            validCount += 1
        }
        return FoodCalorieTotal(
            calories: total,
            validCount: validCount,
            entryCount: entryCount
        )
    }

    public static func total<S: Sequence>(_ values: S) -> Int where S.Element == Int {
        assessedTotal(values).calories
    }
}
