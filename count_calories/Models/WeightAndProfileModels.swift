import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date
    var kilograms: Double

    init(date: Date = .now, kilograms: Double) {
        self.date = date
        self.kilograms = kilograms
    }
}

@Model
final class UserProfile {
    var currentWeight: Double
    var targetWeight: Double
    var age: Int
    var dailyCalorieGoal: Int
    var targetDate: Date

    init(currentWeight: Double = 70, targetWeight: Double = 68, age: Int = 30, dailyCalorieGoal: Int = 1700, targetDate: Date = .now.addingTimeInterval(60 * 60 * 24 * 90)) {
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.age = age
        self.dailyCalorieGoal = dailyCalorieGoal
        self.targetDate = targetDate
    }
}
