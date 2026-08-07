import ActivityKit
import Foundation

nonisolated struct CaloriesActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var calories: Int
        var waterGlasses: Int
    }

    var calorieGoal: Int
    var waterGoal: Int
}
