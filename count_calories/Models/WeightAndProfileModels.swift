import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date
    var kilograms: Double
    // Defaults preserve compatibility with existing persistent stores.
    var stableID: UUID = UUID()
    var sequence: Int64 = 0

    init(
        date: Date = .now,
        kilograms: Double,
        stableID: UUID = UUID(),
        sequence: Int64 = 0
    ) {
        self.date = date
        self.kilograms = kilograms
        self.stableID = stableID
        self.sequence = sequence
    }
}

@Model
final class UserProfile {
    var currentWeight: Double
    var targetWeight: Double
    var age: Int
    var dailyCalorieGoal: Int
    var targetDate: Date
    // Defaults preserve existing profiles as manual without fabricating calculation inputs.
    var planGoalSourceRawValue: String = PlanGoalSource.manual.rawValue
    var calculatedPlanData: Data?
    // Persisted high-water mark prevents sequence reuse after deletion.
    var nextWeightSequence: Int64 = 0

    init(
        currentWeight: Double = 70,
        targetWeight: Double = 68,
        age: Int = 30,
        dailyCalorieGoal: Int = 1700,
        targetDate: Date = Calendar.current.date(
            byAdding: .day,
            value: 90,
            to: .now
        ) ?? .now,
        planGoalSource: PlanGoalSource = .manual,
        calculatedPlanData: Data? = nil,
        nextWeightSequence: Int64 = 0
    ) {
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.age = age
        self.dailyCalorieGoal = dailyCalorieGoal
        self.targetDate = targetDate
        self.planGoalSourceRawValue = planGoalSource.rawValue
        self.calculatedPlanData = calculatedPlanData
        self.nextWeightSequence = nextWeightSequence
    }
}
