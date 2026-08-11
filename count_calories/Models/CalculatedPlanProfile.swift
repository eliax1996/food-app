import Foundation

nonisolated struct StoredCalculatedPlan: Codable, Equatable, Sendable {
    let plan: CalculatedCaloriePlan
    let measurementSystem: PlanMeasurementSystem
    let acceptedAt: Date
}

extension UserProfile {
    var planGoalSource: PlanGoalSource {
        get { PlanGoalSource(rawValue: planGoalSourceRawValue) ?? .manual }
        set { planGoalSourceRawValue = newValue.rawValue }
    }

    var storedCalculatedPlan: StoredCalculatedPlan? {
        guard let calculatedPlanData else { return nil }
        return try? JSONDecoder().decode(StoredCalculatedPlan.self, from: calculatedPlanData)
    }

    func applyCalculatedPlan(
        _ plan: CalculatedCaloriePlan,
        measurementSystem: PlanMeasurementSystem,
        acceptedAt: Date = .now
    ) throws {
        let stored = StoredCalculatedPlan(
            plan: plan,
            measurementSystem: measurementSystem,
            acceptedAt: acceptedAt
        )
        calculatedPlanData = try JSONEncoder().encode(stored)
        currentWeight = plan.input.currentWeightKilograms
        targetWeight = plan.input.targetWeightKilograms
        age = plan.input.age
        dailyCalorieGoal = plan.calorieGoal
        targetDate = plan.forecastDate ?? acceptedAt
        planGoalSource = .calculated
    }

    func applyManualGoal(
        calories: Int,
        targetWeight: Double,
        targetDate: Date
    ) {
        dailyCalorieGoal = calories
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        planGoalSource = .manual
    }

    func restoreStoredCalculatedGoal() -> Bool {
        guard let storedCalculatedPlan else { return false }
        let plan = storedCalculatedPlan.plan
        dailyCalorieGoal = plan.calorieGoal
        targetWeight = plan.input.targetWeightKilograms
        if let forecastDate = plan.forecastDate {
            targetDate = forecastDate
        }
        planGoalSource = .calculated
        return true
    }
}
