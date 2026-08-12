import Foundation

nonisolated struct StoredCalculatedPlan: Codable, Equatable, Sendable {
    let plan: CalculatedCaloriePlan
    let measurementSystem: PlanMeasurementSystem
    let acceptedAt: Date
}

extension UserProfile {
    var planGoalSource: PlanGoalSource {
        PlanGoalSource(rawValue: planGoalSourceRawValue) ?? .unknown
    }

    var storedCalculatedPlan: StoredCalculatedPlan? {
        guard let calculatedPlanData else { return nil }
        return try? JSONDecoder().decode(StoredCalculatedPlan.self, from: calculatedPlanData)
    }

    var adaptivePlanState: AdaptivePlanPersistenceState? {
        AdaptivePlanPersistenceCoding.decode(adaptivePlanData)
    }

    var adaptivePlanSchemaVersion: Int? {
        AdaptivePlanPersistenceCoding.decodeUnvalidated(adaptivePlanData)?.schemaVersion
    }

    var hasCorruptAdaptivePlanPayload: Bool {
        adaptivePlanData != nil && adaptivePlanState == nil
    }

    func persistAdaptivePlanState(
        _ state: AdaptivePlanPersistenceState,
        access: PlanEvidenceMutationAccess
    ) throws {
        replaceAdaptivePlanData(
            try AdaptivePlanPersistenceCoding.encode(state),
            access: access
        )
    }
}

extension AdaptivePlanPersistenceState {
    mutating func resetCadence() {
        lastGenerationDay = nil
        lastGenerationAt = nil
        lastGenerationEvidenceSignature = nil
        lastDecisionDay = nil
        lastDecisionAt = nil
        lastDecisionEvidenceSignature = nil
    }

    mutating func invalidateEpoch() {
        checkInsEnabled = false
        supportedScopeConfirmedAt = nil
        epoch = nil
        resetCadence()
    }
}
