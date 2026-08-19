import Foundation
import SwiftData

nonisolated enum AdaptiveProposalLifecycle: String, Codable, Sendable {
    case pending
    case applied
    case declined
    case expired
    case superseded
    case reverted
}

nonisolated enum AdaptivePlanOperationKind: String, Codable, Sendable {
    case generation
    case apply
    case decline
    case revert
}

nonisolated struct PlateEvidenceSnapshot: Codable, Equatable, Sendable {
    let stableID: UUID
    let dateBitPattern: UInt64
    let calories: Int
    // Optional fields decode schema-1 energy-only attestations. Schema version still fails them closed.
    let foodName: String?
    let loggedAmountBitPattern: UInt64?
    let portionCountBitPattern: UInt64?
    let servingUnitRawValue: String?
    let mealType: String?
    let carbohydratesBitPattern: UInt64?
    let proteinBitPattern: UInt64?
    let fatBitPattern: UInt64?
    let fiberBitPattern: UInt64?
    let loggedSnapshotKindRawValue: String?
    let loggedCalorieDensityBitPattern: UInt64?

    init(
        stableID: UUID,
        dateBitPattern: UInt64,
        calories: Int,
        foodName: String? = nil,
        loggedAmountBitPattern: UInt64? = nil,
        portionCountBitPattern: UInt64? = nil,
        servingUnitRawValue: String? = nil,
        mealType: String? = nil,
        carbohydratesBitPattern: UInt64? = nil,
        proteinBitPattern: UInt64? = nil,
        fatBitPattern: UInt64? = nil,
        fiberBitPattern: UInt64? = nil,
        loggedSnapshotKindRawValue: String? = nil,
        loggedCalorieDensityBitPattern: UInt64? = nil
    ) {
        self.stableID = stableID
        self.dateBitPattern = dateBitPattern
        self.calories = calories
        self.foodName = foodName
        self.loggedAmountBitPattern = loggedAmountBitPattern
        self.portionCountBitPattern = portionCountBitPattern
        self.servingUnitRawValue = servingUnitRawValue
        self.mealType = mealType
        self.carbohydratesBitPattern = carbohydratesBitPattern
        self.proteinBitPattern = proteinBitPattern
        self.fatBitPattern = fatBitPattern
        self.fiberBitPattern = fiberBitPattern
        self.loggedSnapshotKindRawValue = loggedSnapshotKindRawValue
        self.loggedCalorieDensityBitPattern = loggedCalorieDensityBitPattern
    }

    init(plate: PlateEntry) {
        self.init(
            stableID: plate.stableID,
            dateBitPattern: plate.date.timeIntervalSinceReferenceDate.bitPattern,
            calories: plate.calories,
            foodName: plate.foodName,
            loggedAmountBitPattern: plate.loggedAmount.bitPattern,
            portionCountBitPattern: plate.portionQuantity.bitPattern,
            servingUnitRawValue: plate.servingUnitRawValue,
            mealType: plate.mealType,
            carbohydratesBitPattern: plate.carbohydratesGrams?.bitPattern,
            proteinBitPattern: plate.proteinGrams?.bitPattern,
            fatBitPattern: plate.fatGrams?.bitPattern,
            fiberBitPattern: plate.fiberGrams?.bitPattern,
            loggedSnapshotKindRawValue: plate.loggedSnapshotKindRawValue,
            loggedCalorieDensityBitPattern: plate.loggedCalorieDensity?.bitPattern
        )
    }
}

nonisolated struct WeightEvidenceSnapshot: Codable, Equatable, Sendable {
    let stableID: UUID
    let sequence: Int64
    let dateBitPattern: UInt64
    let kilogramsBitPattern: UInt64
}

nonisolated struct AdaptivePlanEpoch: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    let startDay: Date
    let calendarIdentifier: String
    let timeZoneIdentifier: String
    let algorithmVersion: Int
    let startingGoal: Int
    let startingSourceRawValue: String
    let calculatedBasisSignature: String
}

nonisolated struct AdaptiveGoalRevision: Codable, Equatable, Sendable {
    let id: UUID
    let sequence: Int64
    let effectiveDay: Date
    let acceptedAt: Date
    let calories: Int
    let sourceRawValue: String
    let reason: String
    let epochID: UUID?
    let evidenceRevision: Int64
    let priorRevisionID: UUID?
}

nonisolated struct AdaptiveAcceptedStepRecord: Codable, Equatable, Sendable {
    let proposalID: UUID
    let revisionID: UUID
    let effectiveDate: Date
    let calories: Int
}

nonisolated struct AdaptivePreApplySnapshot: Codable, Equatable, Sendable {
    let calories: Int
    let sourceRawValue: String
    let revisionID: UUID?
    let revisionSequence: Int64
    let evidenceRevision: Int64
}

nonisolated struct AdaptiveWindowEstimateRecord: Codable, Equatable, Sendable {
    let nominalDays: Int
    let trendStart: Date
    let trendEnd: Date
    let meanLoggedCalories: Double
    let kilogramsPerDay: Double
    let observedMaintenanceCalories: Double
}

nonisolated struct AdaptivePlanProposalRecord: Codable, Equatable, Sendable {
    let id: UUID
    let epochID: UUID
    let generationOperationKey: String
    let createdAt: Date
    let expiresAt: Date
    let effectiveEvidenceDay: Date
    var lifecycle: AdaptiveProposalLifecycle
    var decidedAt: Date?
    var decisionOperationKey: String?
    let expectedPlanRevisionID: UUID?
    let expectedPlanRevisionSequence: Int64
    let expectedEvidenceRevision: Int64
    let evidenceSignature: String
    let currentGoal: Int
    let currentSourceRawValue: String
    let proposedGoal: Int
    let stepCalories: Int
    let candidateCalories: Double
    let rawDifferenceCalories: Double
    let completeFoodDays: Int
    let weighInDays: Int
    let estimates: [AdaptiveWindowEstimateRecord]
    var appliedRevisionID: UUID?
    var preApplySnapshot: AdaptivePreApplySnapshot?
}

nonisolated struct AdaptivePlanOperationRecord: Codable, Equatable, Sendable {
    let key: String
    let kind: AdaptivePlanOperationKind
    let recordedAt: Date
    let proposalID: UUID?
    let revisionID: UUID?
    let result: String
}

nonisolated struct AdaptivePlanPersistenceState: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let algorithmVersion = 1

    var schemaVersion: Int = Self.schemaVersion
    var identityMigrationCompleted = false
    var checkInsEnabled = false
    var supportedScopeConfirmedAt: Date?
    var epoch: AdaptivePlanEpoch?
    var goalRevisions: [AdaptiveGoalRevision] = []
    var proposals: [AdaptivePlanProposalRecord] = []
    var operations: [AdaptivePlanOperationRecord] = []
    var acceptedSteps: [AdaptiveAcceptedStepRecord] = []
    var lastGenerationDay: Date?
    var lastGenerationAt: Date?
    var lastGenerationEvidenceSignature: String?
    var lastDecisionDay: Date?
    var lastDecisionAt: Date?
    var lastDecisionEvidenceSignature: String?

    var pendingProposal: AdaptivePlanProposalRecord? {
        proposals.last { $0.lifecycle == .pending }
    }

    var latestAppliedProposal: AdaptivePlanProposalRecord? {
        proposals.last { $0.lifecycle == .applied }
    }
}

@Model
final class BulkFoodBatchOperation {
    @Attribute(.unique) private(set) var operationID: UUID = UUID()
    private(set) var committedAt: Date = Date.now
    private(set) var expectedDay: Date = Date(timeIntervalSinceReferenceDate: 0)
    private(set) var requestSignature: String = ""
    private(set) var plateIDsData: Data = Data()

    init(
        operationID: UUID,
        committedAt: Date,
        expectedDay: Date,
        requestSignature: String,
        plateIDs: [UUID]
    ) throws {
        self.operationID = operationID
        self.committedAt = committedAt
        self.expectedDay = expectedDay
        self.requestSignature = requestSignature
        plateIDsData = try JSONEncoder().encode(plateIDs)
    }

    var plateIDs: [UUID]? {
        try? JSONDecoder().decode([UUID].self, from: plateIDsData)
    }
}

@Model
final class FoodLogCompletion {
    @Attribute(.unique) private(set) var stableID: UUID = UUID()
    @Attribute(.unique) private(set) var civilDayIdentifier: String = ""
    private(set) var localEra: Int = 1
    private(set) var localYear: Int = 1
    private(set) var localMonth: Int = 1
    private(set) var localDay: Int = 1
    private(set) var calendarIdentifier: String = "gregorian"
    private(set) var timeZoneIdentifier: String = "GMT"
    private(set) var dayStart: Date = Date(timeIntervalSinceReferenceDate: 0)
    private(set) var attestedAt: Date = Date(timeIntervalSinceReferenceDate: 0)
    private(set) var attestedCalories: Int = 0
    private(set) var isStale: Bool = false
    private(set) var canonicalPlateSnapshotData: Data = Data()
    private(set) var evidenceSchemaVersion: Int = 2
    private(set) var canonicalSnapshotRevision: Int64 = 1

    init(
        stableID: UUID = UUID(),
        components: DateComponents,
        calendarIdentifier: String,
        timeZoneIdentifier: String,
        dayStart: Date,
        attestedAt: Date,
        attestedCalories: Int,
        isStale: Bool = false,
        canonicalPlateSnapshotData: Data,
        evidenceSchemaVersion: Int = 2,
        canonicalSnapshotRevision: Int64 = 1
    ) {
        self.stableID = stableID
        let era = components.era ?? 1
        let year = components.year ?? 1
        let month = components.month ?? 1
        let day = components.day ?? 1
        civilDayIdentifier = "\(calendarIdentifier)|\(timeZoneIdentifier)|\(era)|\(year)|\(month)|\(day)"
        localEra = era
        localYear = year
        localMonth = month
        localDay = day
        self.calendarIdentifier = calendarIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayStart = dayStart
        self.attestedAt = attestedAt
        self.attestedCalories = attestedCalories
        self.isStale = isStale
        self.canonicalPlateSnapshotData = canonicalPlateSnapshotData
        self.evidenceSchemaVersion = evidenceSchemaVersion
        self.canonicalSnapshotRevision = canonicalSnapshotRevision
    }

    var civilDayKey: String { civilDayIdentifier }

    func replaceAttestation(
        dayStart: Date,
        attestedAt: Date,
        calories: Int,
        snapshotData: Data,
        schemaVersion: Int,
        snapshotRevision: Int64,
        access: PlanEvidenceMutationAccess
    ) {
        self.dayStart = dayStart
        self.attestedAt = attestedAt
        attestedCalories = calories
        isStale = false
        canonicalPlateSnapshotData = snapshotData
        evidenceSchemaVersion = schemaVersion
        canonicalSnapshotRevision = snapshotRevision
    }

    func markStale(access: PlanEvidenceMutationAccess) {
        isStale = true
    }

    var plateSnapshot: [PlateEvidenceSnapshot]? {
        try? JSONDecoder().decode([PlateEvidenceSnapshot].self, from: canonicalPlateSnapshotData)
    }
}

nonisolated enum AdaptivePlanPersistenceCoding {
    static func encode(_ state: AdaptivePlanPersistenceState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    static func decode(_ data: Data?) -> AdaptivePlanPersistenceState? {
        guard let state = decodeUnvalidated(data), state.schemaVersion == AdaptivePlanPersistenceState.schemaVersion else {
            return nil
        }
        return state
    }

    static func decodeUnvalidated(_ data: Data?) -> AdaptivePlanPersistenceState? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(AdaptivePlanPersistenceState.self, from: data)
    }

    static func encodePlateSnapshot(_ snapshot: [PlateEvidenceSnapshot]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }
}
