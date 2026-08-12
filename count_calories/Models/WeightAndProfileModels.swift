import Foundation
import SwiftData

@Model
final class WeightEntry {
    private(set) var date: Date
    private(set) var kilograms: Double
    // Defaults preserve compatibility with existing persistent stores.
    private(set) var stableID: UUID = UUID()
    private(set) var sequence: Int64 = 0
    private(set) var identityValidatedForAdaptation: Bool = false
    private(set) var createdAt: Date = Date.now
    private(set) var modifiedAt: Date = Date.now

    init(
        date: Date = .now,
        kilograms: Double,
        stableID: UUID = UUID(),
        sequence: Int64 = 0,
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.date = date
        self.kilograms = kilograms
        self.stableID = stableID
        self.sequence = sequence
        identityValidatedForAdaptation = stableID != .zero
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }

    func validateOrBackfillIdentity(
        with replacement: UUID,
        at date: Date,
        access: PlanEvidenceMutationAccess
    ) {
        if stableID == .zero {
            stableID = replacement
        }
        if !createdAt.timeIntervalSinceReferenceDate.isFinite {
            createdAt = date
        }
        if !modifiedAt.timeIntervalSinceReferenceDate.isFinite {
            modifiedAt = createdAt
        }
        identityValidatedForAdaptation = true
    }

    func applyMeasurement(
        kilograms: Double,
        date: Date,
        sequence: Int64,
        modifiedAt: Date,
        access: PlanEvidenceMutationAccess
    ) {
        self.kilograms = kilograms
        self.date = date
        self.sequence = sequence
        self.modifiedAt = modifiedAt
    }
}

@Model
final class UserProfile {
    private(set) var currentWeight: Double
    private(set) var targetWeight: Double
    private(set) var age: Int
    private(set) var dailyCalorieGoal: Int
    private(set) var targetDate: Date
    // Defaults preserve existing profiles as manual without fabricating calculation inputs.
    private(set) var planGoalSourceRawValue: String = PlanGoalSource.manual.rawValue
    private(set) var calculatedPlanData: Data?
    // Nil means no Slice-D opt-in or migration history has been fabricated.
    private(set) var adaptivePlanData: Data?
    private(set) var currentPlanRevisionID: UUID?
    private(set) var currentPlanRevisionSequence: Int64 = 0
    private(set) var evidenceRevision: Int64 = 0
    // Persisted high-water mark prevents sequence reuse after deletion.
    private(set) var nextWeightSequence: Int64 = 0

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
        rawPlanGoalSource: String? = nil,
        calculatedPlanData: Data? = nil,
        adaptivePlanData: Data? = nil,
        currentPlanRevisionID: UUID? = nil,
        currentPlanRevisionSequence: Int64 = 0,
        evidenceRevision: Int64 = 0,
        nextWeightSequence: Int64 = 0
    ) {
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.age = age
        self.dailyCalorieGoal = dailyCalorieGoal
        self.targetDate = targetDate
        planGoalSourceRawValue = rawPlanGoalSource ?? planGoalSource.rawValue
        self.calculatedPlanData = calculatedPlanData
        self.adaptivePlanData = adaptivePlanData
        self.currentPlanRevisionID = currentPlanRevisionID
        self.currentPlanRevisionSequence = currentPlanRevisionSequence
        self.evidenceRevision = evidenceRevision
        self.nextWeightSequence = nextWeightSequence
    }

    func replaceCalculatedPlan(
        data: Data,
        currentWeight: Double,
        targetWeight: Double,
        age: Int,
        dailyCalorieGoal: Int,
        targetDate: Date,
        access: PlanEvidenceMutationAccess
    ) {
        calculatedPlanData = data
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.age = age
        self.dailyCalorieGoal = dailyCalorieGoal
        self.targetDate = targetDate
        planGoalSourceRawValue = PlanGoalSource.calculated.rawValue
    }

    func replaceManualPlan(
        calories: Int,
        targetWeight: Double,
        targetDate: Date,
        access: PlanEvidenceMutationAccess
    ) {
        dailyCalorieGoal = calories
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        planGoalSourceRawValue = PlanGoalSource.manual.rawValue
    }

    func replaceRestoredCalculatedPlan(
        calories: Int,
        targetWeight: Double,
        targetDate: Date?,
        access: PlanEvidenceMutationAccess
    ) {
        dailyCalorieGoal = calories
        self.targetWeight = targetWeight
        if let targetDate { self.targetDate = targetDate }
        planGoalSourceRawValue = PlanGoalSource.calculated.rawValue
    }

    func replaceAdaptiveGoal(calories: Int, access: PlanEvidenceMutationAccess) {
        dailyCalorieGoal = calories
        planGoalSourceRawValue = PlanGoalSource.adapted.rawValue
    }

    func replaceGoalForRevert(
        calories: Int,
        sourceRawValue: String,
        access: PlanEvidenceMutationAccess
    ) {
        dailyCalorieGoal = calories
        planGoalSourceRawValue = sourceRawValue
    }

    func replaceProfileAge(_ age: Int, access: PlanEvidenceMutationAccess) {
        self.age = age
    }

    func replaceCurrentWeight(_ kilograms: Double, access: PlanEvidenceMutationAccess) {
        currentWeight = kilograms
    }

    func replaceNextWeightSequence(_ sequence: Int64, access: PlanEvidenceMutationAccess) {
        nextWeightSequence = sequence
    }

    func replaceAdaptivePlanData(_ data: Data?, access: PlanEvidenceMutationAccess) {
        adaptivePlanData = data
    }

    func replacePlanRevision(
        id: UUID?,
        sequence: Int64,
        access: PlanEvidenceMutationAccess
    ) {
        currentPlanRevisionID = id
        currentPlanRevisionSequence = sequence
    }

    func replaceEvidenceRevision(_ revision: Int64, access: PlanEvidenceMutationAccess) {
        evidenceRevision = revision
    }
}
