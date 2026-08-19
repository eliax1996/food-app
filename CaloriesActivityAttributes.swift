import ActivityKit
import Foundation

nonisolated enum DailyCaloriesAccessibilitySummary {
    static func value(
        calories: Int,
        calorieGoal: Int,
        caloriesAreComplete: Bool
    ) -> String {
        let safeCalories = max(0, calories)
        let safeGoal = max(1, calorieGoal)
        guard caloriesAreComplete else {
            return "Known food entries total \(safeCalories) calories. Daily budget status unavailable because one or more logged foods has invalid calorie data."
        }
        let difference = abs(safeGoal - safeCalories)
        let status = safeCalories > safeGoal ? "calories over goal" : "calories remaining"
        return "\(safeCalories) calories eaten, \(difference) \(status), daily goal \(safeGoal) calories"
    }
}

nonisolated struct CaloriesActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var calories: Int
        var waterGlasses: Int
        var calorieGoal: Int?
        var waterGoal: Int?

        var resolvedCalorieGoal: Int { max(1, calorieGoal ?? 1_700) }
        var resolvedWaterGoal: Int { max(1, waterGoal ?? 8) }

        func calorieStatus(goal: Int? = nil) -> CalorieActivityStatus {
            CalorieActivityStatus(calories: calories, goal: goal ?? resolvedCalorieGoal)
        }
    }

    nonisolated struct CalorieActivityStatus: Equatable, Sendable {
        let value: Int
        let isOverGoal: Bool

        init(calories: Int, goal: Int) {
            let safeCalories = max(0, calories)
            let safeGoal = max(1, goal)
            value = abs(safeGoal - safeCalories)
            isOverGoal = safeCalories > safeGoal
        }

        var label: String { isOverGoal ? "kcal over" : "kcal remaining" }
    }

    var calorieGoal: Int
    var waterGoal: Int
}
