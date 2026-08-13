import CryptoKit
import Foundation
import SwiftData
import SwiftUI

struct PlanEvidenceMutationAccess {
    fileprivate init() {}
}

private struct PlanEvidenceMutationCoordinatorKey: EnvironmentKey {
    static let defaultValue: PlanEvidenceMutationCoordinator? = nil
}

extension EnvironmentValues {
    var planEvidenceMutationCoordinator: PlanEvidenceMutationCoordinator? {
        get { self[PlanEvidenceMutationCoordinatorKey.self] }
        set { self[PlanEvidenceMutationCoordinatorKey.self] = newValue }
    }
}

nonisolated enum PlanEvidenceMutationError: Error, Equatable {
    case missingProfile
    case multipleProfiles
    case corruptAdaptivePayload
    case unsupportedAdaptiveSchema(Int)
    case uncommittedChanges
    case coordinatorUnavailable
    case identityCollision(entity: String, id: UUID)
    case identityVerificationFailed
    case identityMigrationRequired
    case unsupportedSource
    case supportedScopeConfirmationRequired
    case missingCalculatedBasis
    case calendarOrTimeZoneChanged
    case epochBasisChanged
    case invalidCompletionDay
    case invalidCalories
    case invalidBulkBatch
    case duplicateCompletion
    case revisionOverflow
    case evidenceOverflow
    case compareAndSetFailed
    case missingPendingProposal
    case proposalNotCurrent
    case proposalExpired
    case evidenceSignatureChanged
    case revertConflict
}

nonisolated struct PlanIdentityMigrationResult: Equatable, Sendable {
    let plateRows: Int
    let weightRows: Int
    let foodRows: Int
    let backfilledPlateIDs: Int
    let backfilledWeightIDs: Int
    let backfilledFoodIDs: Int
}

nonisolated enum PlanEvidenceEvaluationResult {
    case evaluation(AdaptiveCaloriePlanEvaluation)
    case pending(AdaptivePlanProposalRecord)
    case cadence(nextEligibleDay: Date)
}

@MainActor
final class PlanEvidenceMutationCoordinator {
    static let evidenceSchemaVersion = 1
    private static let maximumBulkOperationHistory = 256

    enum SavePhase: Equatable {
        case identityBackfill
        case identityMigrationFlag
        case mutation
        case bulkFoodBatch
    }

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let now: () -> Date
    private var calendar: Calendar
    private let makeUUID: () -> UUID
    private let beforeSave: (SavePhase) throws -> Void
    private let access = PlanEvidenceMutationAccess()

    init(
        modelContainer: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now },
        makeUUID: @escaping () -> UUID = { UUID() },
        beforeSave: @escaping (SavePhase) throws -> Void = { _ in }
    ) {
        self.modelContainer = modelContainer
        modelContext = ModelContext(modelContainer)
        self.calendar = calendar
        self.now = now
        self.makeUUID = makeUUID
        self.beforeSave = beforeSave
    }

    func synchronizeCalendar(_ calendar: Calendar) {
        self.calendar = calendar
    }

#if DEBUG
    var testingModelContext: ModelContext { modelContext }

    func ensureAppliedFixtureVisibleForTesting() throws {
        try beginOperation()
        do {
            let profile = try requiredProfile()
            guard let state = profile.adaptivePlanState,
                  let index = state.proposals.lastIndex(where: { $0.lifecycle == .applied }),
                  let appliedRevisionID = state.proposals[index].appliedRevisionID,
                  let appliedRevision = state.goalRevisions.first(where: { $0.id == appliedRevisionID }) else {
                throw PlanEvidenceMutationError.proposalNotCurrent
            }
            profile.replaceAdaptiveGoal(calories: appliedRevision.calories, access: access)
            try profile.persistAdaptivePlanState(state, access: access)
            try save(.mutation)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func configurePartialCapProposalForTesting(usedCalories: Int) throws {
        guard usedCalories > 100, usedCalories < 200 else {
            throw PlanEvidenceMutationError.invalidCalories
        }
        try beginOperation()
        do {
            let profile = try requiredProfile()
            guard var state = profile.adaptivePlanState,
                  let index = state.proposals.lastIndex(where: { $0.lifecycle == .pending }) else {
                throw PlanEvidenceMutationError.missingPendingProposal
            }
            let proposal = state.proposals[index]
            let remaining = 200 - usedCalories
            let adjustedStep = proposal.stepCalories < 0 ? -remaining : remaining
            state.acceptedSteps.append(AdaptiveAcceptedStepRecord(
                proposalID: makeUUID(),
                revisionID: profile.currentPlanRevisionID ?? makeUUID(),
                effectiveDate: calendar.startOfDay(for: now()),
                calories: usedCalories
            ))
            state.proposals[index] = AdaptivePlanProposalRecord(
                id: proposal.id,
                epochID: proposal.epochID,
                generationOperationKey: proposal.generationOperationKey,
                createdAt: proposal.createdAt,
                expiresAt: proposal.expiresAt,
                effectiveEvidenceDay: proposal.effectiveEvidenceDay,
                lifecycle: proposal.lifecycle,
                decidedAt: proposal.decidedAt,
                decisionOperationKey: proposal.decisionOperationKey,
                expectedPlanRevisionID: proposal.expectedPlanRevisionID,
                expectedPlanRevisionSequence: proposal.expectedPlanRevisionSequence,
                expectedEvidenceRevision: proposal.expectedEvidenceRevision,
                evidenceSignature: proposal.evidenceSignature,
                currentGoal: proposal.currentGoal,
                currentSourceRawValue: proposal.currentSourceRawValue,
                proposedGoal: proposal.currentGoal + adjustedStep,
                stepCalories: adjustedStep,
                candidateCalories: proposal.candidateCalories,
                rawDifferenceCalories: proposal.rawDifferenceCalories,
                completeFoodDays: proposal.completeFoodDays,
                weighInDays: proposal.weighInDays,
                estimates: proposal.estimates,
                appliedRevisionID: proposal.appliedRevisionID,
                preApplySnapshot: proposal.preApplySnapshot
            )
            try profile.persistAdaptivePlanState(state, access: access)
            try save(.mutation)
        } catch {
            modelContext.rollback()
            throw error
        }
    }
#endif

    func validateAndBackfillStableIdentities() throws -> PlanIdentityMigrationResult {
        let operationDate = now()
        try beginOperation()
        do {
            let plates = try modelContext.fetch(FetchDescriptor<PlateEntry>())
            let weights = try modelContext.fetch(FetchDescriptor<WeightEntry>())
            let foods = try modelContext.fetch(FetchDescriptor<Food>())
            let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())

            // Schema and collision checks happen before any staged identity mutation.
            for profile in profiles where profile.adaptivePlanData != nil {
                guard let version = profile.adaptivePlanSchemaVersion else {
                    throw PlanEvidenceMutationError.corruptAdaptivePayload
                }
                guard version == AdaptivePlanPersistenceState.schemaVersion else {
                    throw PlanEvidenceMutationError.unsupportedAdaptiveSchema(version)
                }
            }
            try rejectCollisions(plates.map(\.stableID).filter { $0 != .zero }, entity: "PlateEntry")
            try rejectCollisions(weights.map(\.stableID).filter { $0 != .zero }, entity: "WeightEntry")
            try rejectCollisions(foods.map(\.stableID).filter { $0 != .zero }, entity: "Food")

            var usedPlateIDs = Set(plates.map(\.stableID).filter { $0 != .zero })
            var usedWeightIDs = Set(weights.map(\.stableID).filter { $0 != .zero })
            var usedFoodIDs = Set(foods.map(\.stableID).filter { $0 != .zero })
            var stagedPlateIDs: [ObjectIdentifier: UUID] = [:]
            var stagedWeightIDs: [ObjectIdentifier: UUID] = [:]
            var stagedFoodIDs: [ObjectIdentifier: UUID] = [:]
            for plate in plates {
                stagedPlateIDs[ObjectIdentifier(plate)] = plate.stableID == .zero
                    ? try freshID(excluding: &usedPlateIDs)
                    : plate.stableID
            }
            for weight in weights {
                stagedWeightIDs[ObjectIdentifier(weight)] = weight.stableID == .zero
                    ? try freshID(excluding: &usedWeightIDs)
                    : weight.stableID
            }
            for food in foods {
                stagedFoodIDs[ObjectIdentifier(food)] = food.stableID == .zero
                    ? try freshID(excluding: &usedFoodIDs)
                    : food.stableID
            }

            let projectedPlateIDs = plates.compactMap { stagedPlateIDs[ObjectIdentifier($0)] }
            let projectedWeightIDs = weights.compactMap { stagedWeightIDs[ObjectIdentifier($0)] }
            let projectedFoodIDs = foods.compactMap { stagedFoodIDs[ObjectIdentifier($0)] }
            guard projectedPlateIDs.count == plates.count,
                  projectedWeightIDs.count == weights.count,
                  projectedFoodIDs.count == foods.count,
                  projectedPlateIDs.allSatisfy({ $0 != .zero }),
                  projectedWeightIDs.allSatisfy({ $0 != .zero }),
                  projectedFoodIDs.allSatisfy({ $0 != .zero }),
                  Set(projectedPlateIDs).count == plates.count,
                  Set(projectedWeightIDs).count == weights.count,
                  Set(projectedFoodIDs).count == foods.count else {
                throw PlanEvidenceMutationError.identityVerificationFailed
            }

            let backfilledPlates = zip(plates, projectedPlateIDs).filter { $0.0.stableID == .zero }.count
            let backfilledWeights = zip(weights, projectedWeightIDs).filter { $0.0.stableID == .zero }.count
            let backfilledFoods = zip(foods, projectedFoodIDs).filter { $0.0.stableID == .zero }.count
            let expectedWeightSequences = Dictionary(uniqueKeysWithValues: zip(projectedWeightIDs, weights.map(\.sequence)))
            for plate in plates {
                guard let id = stagedPlateIDs[ObjectIdentifier(plate)] else {
                    throw PlanEvidenceMutationError.identityVerificationFailed
                }
                plate.validateOrBackfillIdentity(with: id, at: operationDate, access: access)
            }
            for weight in weights {
                guard let id = stagedWeightIDs[ObjectIdentifier(weight)] else {
                    throw PlanEvidenceMutationError.identityVerificationFailed
                }
                weight.validateOrBackfillIdentity(with: id, at: operationDate, access: access)
            }
            for food in foods {
                guard let id = stagedFoodIDs[ObjectIdentifier(food)] else {
                    throw PlanEvidenceMutationError.identityVerificationFailed
                }
                food.validateOrBackfillIdentity(with: id, access: access)
            }

            // Identity rows commit first. Migration remains disabled until fresh-context proof succeeds.
            try save(.identityBackfill)
            let verificationContext = ModelContext(modelContainer)
            let verifiedPlates = try verificationContext.fetch(FetchDescriptor<PlateEntry>())
            let verifiedWeights = try verificationContext.fetch(FetchDescriptor<WeightEntry>())
            let verifiedFoods = try verificationContext.fetch(FetchDescriptor<Food>())
            guard verifiedPlates.count == projectedPlateIDs.count,
                  verifiedWeights.count == projectedWeightIDs.count,
                  verifiedFoods.count == projectedFoodIDs.count,
                  Set(verifiedPlates.map(\.stableID)) == Set(projectedPlateIDs),
                  Set(verifiedWeights.map(\.stableID)) == Set(projectedWeightIDs),
                  Set(verifiedFoods.map(\.stableID)) == Set(projectedFoodIDs),
                  verifiedPlates.allSatisfy({
                      $0.stableID != .zero
                          && $0.identityValidatedForAdaptation
                          && $0.createdAt.timeIntervalSinceReferenceDate.isFinite
                          && $0.modifiedAt.timeIntervalSinceReferenceDate.isFinite
                  }),
                  verifiedWeights.allSatisfy({
                      $0.stableID != .zero
                          && $0.identityValidatedForAdaptation
                          && $0.createdAt.timeIntervalSinceReferenceDate.isFinite
                          && $0.modifiedAt.timeIntervalSinceReferenceDate.isFinite
                          && expectedWeightSequences[$0.stableID] == $0.sequence
                  }),
                  verifiedFoods.allSatisfy({ $0.stableID != .zero }) else {
                throw PlanEvidenceMutationError.identityVerificationFailed
            }

            for profile in profiles {
                var state = profile.adaptivePlanState ?? AdaptivePlanPersistenceState()
                state.identityMigrationCompleted = true
                try profile.persistAdaptivePlanState(state, access: access)
                if backfilledPlates + backfilledWeights > 0 {
                    try bumpEvidence(profile, reason: "identity-backfill", at: operationDate)
                }
            }
            try save(.identityMigrationFlag)
            return PlanIdentityMigrationResult(
                plateRows: plates.count,
                weightRows: weights.count,
                foodRows: foods.count,
                backfilledPlateIDs: backfilledPlates,
                backfilledWeightIDs: backfilledWeights,
                backfilledFoodIDs: backfilledFoods
            )
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func enableAdaptiveCheckIns(
        supportedScopeConfirmed: Bool,
        enabledAt: Date? = nil
    ) throws -> AdaptivePlanEpoch {
        guard supportedScopeConfirmed else {
            throw PlanEvidenceMutationError.supportedScopeConfirmationRequired
        }
        _ = try validateAndBackfillStableIdentities()
        let operationDate = enabledAt ?? now()
        do {
            let profile = try requiredProfile()
            guard !profile.hasCorruptAdaptivePlanPayload else { throw PlanEvidenceMutationError.corruptAdaptivePayload }
            guard profile.planGoalSource == .calculated || profile.planGoalSource == .adapted else {
                throw PlanEvidenceMutationError.unsupportedSource
            }
            guard profile.storedCalculatedPlan != nil else { throw PlanEvidenceMutationError.missingCalculatedBasis }
            var state = profile.adaptivePlanState ?? AdaptivePlanPersistenceState()
            state.identityMigrationCompleted = true
            state.checkInsEnabled = true
            state.supportedScopeConfirmedAt = operationDate
            supersedePending(in: &state, at: operationDate, reason: "epoch-enabled")
            if profile.currentPlanRevisionID == nil {
                _ = try appendRevision(profile: profile, state: &state, reason: "slice-d-migration", at: operationDate)
            }
            let epoch = makeEpoch(profile: profile, at: operationDate)
            state.epoch = epoch
            state.resetCadence()
            try profile.persistAdaptivePlanState(state, access: access)
            try bumpEvidence(profile, reason: "epoch-enabled", at: operationDate, supersedePending: false)
            try modelContext.save()
            return epoch
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func disableAdaptiveCheckIns() throws {
        let operationDate = now()
        try mutateState { profile, state in
            supersedePending(in: &state, at: operationDate, reason: "check-ins-disabled")
            state.invalidateEpoch()
            try bumpEvidence(profile, reason: "check-ins-disabled", at: operationDate, supersedePending: false)
        }
    }

    @discardableResult
    func acceptCalculatedPlan(
        _ plan: CalculatedCaloriePlan,
        measurementSystem: PlanMeasurementSystem,
        acceptedAt: Date? = nil
    ) throws -> UserProfile {
        let operationDate = acceptedAt ?? now()
        try beginOperation()
        do {
            let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
            guard profiles.count <= 1 else { throw PlanEvidenceMutationError.multipleProfiles }
            let stored = StoredCalculatedPlan(plan: plan, measurementSystem: measurementSystem, acceptedAt: operationDate)
            let storedData = try JSONEncoder().encode(stored)
            let profile: UserProfile
            if let existing = profiles.first {
                profile = existing
                try validateAdaptivePayload(profile)
                profile.replaceCalculatedPlan(
                    data: storedData,
                    currentWeight: plan.input.currentWeightKilograms,
                    targetWeight: plan.input.targetWeightKilograms,
                    age: plan.input.age,
                    dailyCalorieGoal: plan.calorieGoal,
                    targetDate: plan.forecastDate ?? operationDate,
                    access: access
                )
            } else {
                profile = UserProfile(
                    currentWeight: plan.input.currentWeightKilograms,
                    targetWeight: plan.input.targetWeightKilograms,
                    age: plan.input.age,
                    dailyCalorieGoal: plan.calorieGoal,
                    targetDate: plan.forecastDate ?? operationDate,
                    planGoalSource: .calculated,
                    calculatedPlanData: storedData
                )
                modelContext.insert(profile)
            }
            try resetPlanMutation(profile: profile, reason: "calculated-plan-accepted", at: operationDate)
            try modelContext.save()
            WidgetDailySummaryStore.refreshCalorieGoal(profile.dailyCalorieGoal)
            Task {
                await CaloriesLiveActivityManager.refreshCalorieGoalIfActive(profile.dailyCalorieGoal)
            }
            return profile
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func editManualPlan(
        calories: Int,
        targetWeight: Double,
        targetDate: Date,
        changedAt: Date? = nil
    ) throws {
        let operationDate = changedAt ?? now()
        try mutateState { profile, state in
            profile.replaceManualPlan(
                calories: calories,
                targetWeight: targetWeight,
                targetDate: targetDate,
                access: access
            )
            try resetPlanMutation(profile: profile, state: &state, reason: "manual-goal", at: operationDate)
        }
    }

    @discardableResult
    func restoreCalculatedPlan(restoredAt: Date? = nil) throws -> Bool {
        let operationDate = restoredAt ?? now()
        var restored = false
        try mutateState { profile, state in
            guard let stored = profile.storedCalculatedPlan else { return }
            profile.replaceRestoredCalculatedPlan(
                calories: stored.plan.calorieGoal,
                targetWeight: stored.plan.input.targetWeightKilograms,
                targetDate: stored.plan.forecastDate,
                access: access
            )
            try resetPlanMutation(profile: profile, state: &state, reason: "calculated-plan-restored", at: operationDate)
            restored = true
        }
        return restored
    }

    func changeProfileContext(age: Int) throws {
        let operationDate = now()
        try mutateState { profile, state in
            guard profile.age != age else { return }
            profile.replaceProfileAge(age, access: access)
            try resetPlanMutation(profile: profile, state: &state, reason: "profile-age-changed", at: operationDate)
        }
    }

    @discardableResult
    func resetEvidenceEpoch() throws -> AdaptivePlanEpoch {
        let operationDate = now()
        var result: AdaptivePlanEpoch?
        var basisMismatch = false
        try mutateState { profile, state in
            guard state.checkInsEnabled, state.supportedScopeConfirmedAt != nil else {
                throw PlanEvidenceMutationError.supportedScopeConfirmationRequired
            }
            guard profile.planGoalSource == .calculated || profile.planGoalSource == .adapted else {
                throw PlanEvidenceMutationError.unsupportedSource
            }
            guard profile.storedCalculatedPlan != nil else { throw PlanEvidenceMutationError.missingCalculatedBasis }
            guard let currentEpoch = state.epoch, epochPlanBasisMatches(currentEpoch, profile: profile) else {
                supersedePending(in: &state, at: operationDate, reason: "epoch-basis-changed")
                state.invalidateEpoch()
                basisMismatch = true
                return
            }
            supersedePending(in: &state, at: operationDate, reason: "epoch-reset")
            let epoch = makeEpoch(profile: profile, at: operationDate)
            state.epoch = epoch
            state.resetCadence()
            try bumpEvidence(profile, reason: "epoch-reset", at: operationDate, supersedePending: false)
            result = epoch
        }
        if basisMismatch { throw PlanEvidenceMutationError.epochBasisChanged }
        return try result ?? { throw PlanEvidenceMutationError.corruptAdaptivePayload }()
    }

    @discardableResult
    func markFoodLogComplete(for date: Date) throws -> FoodLogCompletion {
        let operationDate = now()
        try beginOperation()
        guard let requestedDay = finiteDay(date), let today = finiteDay(operationDate),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              requestedDay == today || requestedDay == yesterday else {
            throw PlanEvidenceMutationError.invalidCompletionDay
        }
        do {
            let snapshot = try plateSnapshot(for: requestedDay)
            let total = try calorieTotal(snapshot)
            let identifiers = calendarIdentity
            let components = calendar.dateComponents([.era, .year, .month, .day], from: requestedDay)
            let matches = try modelContext.fetch(FetchDescriptor<FoodLogCompletion>()).filter {
                $0.calendarIdentifier == identifiers.calendar
                    && $0.timeZoneIdentifier == identifiers.timeZone
                    && $0.localEra == (components.era ?? 1)
                    && $0.localYear == (components.year ?? 1)
                    && $0.localMonth == (components.month ?? 1)
                    && $0.localDay == (components.day ?? 1)
            }
            guard matches.count <= 1 else { throw PlanEvidenceMutationError.duplicateCompletion }
            if let existing = matches.first,
               !existing.isStale,
               existing.attestedCalories == total,
               existing.evidenceSchemaVersion == Self.evidenceSchemaVersion,
               existing.plateSnapshot == snapshot {
                return existing
            }
            let data = try AdaptivePlanPersistenceCoding.encodePlateSnapshot(snapshot)
            let completion: FoodLogCompletion
            if let existing = matches.first {
                guard existing.canonicalSnapshotRevision < Int64.max else {
                    throw PlanEvidenceMutationError.evidenceOverflow
                }
                existing.replaceAttestation(
                    dayStart: requestedDay,
                    attestedAt: operationDate,
                    calories: total,
                    snapshotData: data,
                    schemaVersion: Self.evidenceSchemaVersion,
                    snapshotRevision: existing.canonicalSnapshotRevision + 1,
                    access: access
                )
                completion = existing
            } else {
                completion = FoodLogCompletion(
                    components: components,
                    calendarIdentifier: identifiers.calendar,
                    timeZoneIdentifier: identifiers.timeZone,
                    dayStart: requestedDay,
                    attestedAt: operationDate,
                    attestedCalories: total,
                    canonicalPlateSnapshotData: data
                )
                modelContext.insert(completion)
            }
            for profile in try modelContext.fetch(FetchDescriptor<UserProfile>()) {
                try bumpEvidence(profile, reason: "food-day-attested", at: operationDate)
            }
            try modelContext.save()
            return completion
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func reconfirmFoodLog(for date: Date) throws -> FoodLogCompletion {
        try markFoodLogComplete(for: date)
    }

    @discardableResult
    func refreshFoodLogStaleness() throws -> Int {
        let operationDate = now()
        try beginOperation()
        do {
            let changed = try refreshStalenessWithoutSaving()
            if changed > 0 {
                for profile in try modelContext.fetch(FetchDescriptor<UserProfile>()) {
                    try bumpEvidence(profile, reason: "food-snapshot-stale", at: operationDate)
                }
                try modelContext.save()
            }
            return changed
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func insertPlate(_ entry: PlateEntry) throws {
        let operationDate = now()
        try beginOperation()
        guard CalorieCalculator.isValidCalories(entry.calories),
              entry.date.timeIntervalSinceReferenceDate.isFinite else {
            throw PlanEvidenceMutationError.invalidCalories
        }
        do {
            let IDs = try modelContext.fetch(FetchDescriptor<PlateEntry>()).map(\.stableID)
            guard entry.stableID != .zero, !IDs.contains(entry.stableID) else {
                throw PlanEvidenceMutationError.identityCollision(entity: "PlateEntry", id: entry.stableID)
            }
            entry.validateOrBackfillIdentity(with: entry.stableID, at: operationDate, access: access)
            entry.applyEvidenceMutation(
                calories: entry.calories,
                date: entry.date,
                modifiedAt: operationDate,
                access: access
            )
            modelContext.insert(entry)
            try staleCompletions(containing: [entry.date])
            try bumpAllProfiles(reason: "food-added", at: operationDate)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func insertPlateBatch(
        _ inserts: [BulkPlateInsert],
        expectedDay: Date,
        operationID: UUID
    ) throws -> [UUID] {
        let operationDate = now()
        try beginOperation()
        guard operationID != .zero,
              let canonicalDay = finiteDay(expectedDay),
              !inserts.isEmpty,
              inserts.count <= BulkFoodLimits.maximumItems,
              Set(inserts.map(\.id)).count == inserts.count,
              inserts.allSatisfy({ $0.sourceItemID != .zero }),
              Set(inserts.map(\.sourceItemID)).count == inserts.count,
              Set(inserts.map(\.mealType)).count == 1 else {
            throw PlanEvidenceMutationError.invalidBulkBatch
        }
        do {
            let requestSignature = bulkFoodBatchSignature(inserts, expectedDay: canonicalDay)
            let operations = try modelContext.fetch(FetchDescriptor<BulkFoodBatchOperation>())
            guard operations.count(where: { $0.operationID == operationID }) <= 1 else {
                throw PlanEvidenceMutationError.identityVerificationFailed
            }
            if let replay = operations.first(where: { $0.operationID == operationID }) {
                guard replay.expectedDay == canonicalDay,
                      replay.requestSignature == requestSignature,
                      let plateIDs = replay.plateIDs,
                      plateIDs.count == inserts.count else {
                    throw PlanEvidenceMutationError.compareAndSetFailed
                }
                return plateIDs
            }

            let existingPlateIDs = Set(try modelContext.fetch(FetchDescriptor<PlateEntry>()).map(\.stableID))
            guard inserts.allSatisfy({ insert in
                insert.id != .zero
                    && !existingPlateIDs.contains(insert.id)
                    && finiteDay(insert.date) == canonicalDay
                    && insert.date <= operationDate
                    && !insert.mealType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && insert.unit == insert.match.servingUnit
                    && insert.match.isValid
                    && insert.match.displayName.count <= 200
                    && !insert.match.displayName.unicodeScalars.contains(where: {
                        CharacterSet.controlCharacters.contains($0)
                    })
                    && MealType(rawValue: insert.mealType) != nil
                    && insert.amount.isFinite
                    && insert.amount >= BulkFoodLimits.minimumAmount
                    && insert.amount <= BulkFoodLimits.maximumAmount
                    && insert.match.calories(for: insert.amount).map(CalorieCalculator.isValidCalories) == true
                    && insert.match.nutrients(for: insert.amount) != nil
            }) else {
                throw PlanEvidenceMutationError.invalidBulkBatch
            }

            let savedFoods = try modelContext.fetch(FetchDescriptor<Food>())
            let savedFoodIDs = savedFoods.map(\.stableID)
            guard savedFoodIDs.allSatisfy({ $0 != .zero }),
                  Set(savedFoodIDs).count == savedFoodIDs.count else {
                throw PlanEvidenceMutationError.identityVerificationFailed
            }
            let savedByID = Dictionary(uniqueKeysWithValues: savedFoods.map { ($0.stableID, $0) })
            let savedBarcodePairs: [(String, Food)] = savedFoods.compactMap { food in
                guard let barcode = food.barcode, !barcode.isEmpty else { return nil }
                return (barcode, food)
            }
            guard Set(savedBarcodePairs.map(\.0)).count == savedBarcodePairs.count else {
                throw PlanEvidenceMutationError.identityVerificationFailed
            }
            let savedByBarcode = Dictionary(uniqueKeysWithValues: savedBarcodePairs)

            var allocatedFoodIDs = Set(savedFoodIDs)
            var newFoods: [(barcode: String, insert: BulkPlateInsert)] = []
            var newFoodMatches: [String: BulkFoodMatch] = [:]
            for insert in inserts {
                switch insert.match.identity {
                case .savedFood(let foodID):
                    guard let savedFood = savedByID[foodID],
                          bulkMatch(insert.match, represents: savedFood) else {
                        throw PlanEvidenceMutationError.invalidBulkBatch
                    }
                case .barcode(let barcode):
                    guard isValidFoodBarcode(barcode),
                          insert.match.barcode == barcode else {
                        throw PlanEvidenceMutationError.invalidBulkBatch
                    }
                    if let savedFood = savedByBarcode[barcode] {
                        guard bulkBarcodeMatch(insert.match, barcode: barcode, represents: savedFood) else {
                            throw PlanEvidenceMutationError.invalidBulkBatch
                        }
                    } else if let firstMatch = newFoodMatches[barcode] {
                        guard bulkNutritionSnapshotMatches(insert.match, firstMatch) else {
                            throw PlanEvidenceMutationError.invalidBulkBatch
                        }
                    } else {
                        guard allocatedFoodIDs.insert(insert.sourceItemID).inserted else {
                            throw PlanEvidenceMutationError.identityCollision(
                                entity: "Food",
                                id: insert.sourceItemID
                            )
                        }
                        newFoodMatches[barcode] = insert.match
                        newFoods.append((barcode: barcode, insert: insert))
                    }
                }
            }

            for newFood in newFoods {
                let insert = newFood.insert
                let food = Food(
                    name: insert.match.displayName,
                    calories: insert.match.caloriesPerServing,
                    stableID: insert.sourceItemID,
                    servingGrams: insert.match.servingAmount,
                    servingUnit: insert.match.servingUnit,
                    barcode: newFood.barcode,
                    nutrientsPerServing: insert.match.nutrientsPerServing
                )
                modelContext.insert(food)
            }
            for insert in inserts {
                guard let calories = insert.match.calories(for: insert.amount),
                      let nutrients = insert.match.nutrients(for: insert.amount) else {
                    throw PlanEvidenceMutationError.invalidBulkBatch
                }
                let entry = PlateEntry(
                    foodName: insert.match.displayName,
                    calories: calories,
                    weightGrams: insert.amount,
                    quantity: 1,
                    servingUnit: insert.unit,
                    nutrients: nutrients,
                    mealType: insert.mealType,
                    date: insert.date,
                    stableID: insert.id,
                    createdAt: operationDate,
                    modifiedAt: operationDate
                )
                entry.validateOrBackfillIdentity(with: insert.id, at: operationDate, access: access)
                modelContext.insert(entry)
            }

            try staleCompletions(containing: [canonicalDay])
            try bumpAllProfiles(reason: "bulk-food-added", at: operationDate)
            for expired in operations
                .sorted(by: bulkOperationOrder)
                .prefix(max(0, operations.count - Self.maximumBulkOperationHistory + 1)) {
                modelContext.delete(expired)
            }
            modelContext.insert(try BulkFoodBatchOperation(
                operationID: operationID,
                committedAt: operationDate,
                expectedDay: canonicalDay,
                requestSignature: requestSignature,
                plateIDs: inserts.map(\.id)
            ))
            try save(.bulkFoodBatch)
            return inserts.map(\.id)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func updatePlateEvidence(_ entry: PlateEntry, calories: Int, date: Date) throws {
        try updatePlate(
            stableID: entry.stableID,
            foodName: entry.foodName,
            calories: calories,
            weightGrams: entry.weightGrams,
            quantity: entry.portionQuantity,
            servingUnitRawValue: entry.servingUnitRawValue,
            nutrients: entry.nutrients,
            mealType: entry.mealType,
            date: date
        )
    }

    func updatePlate(
        stableID: UUID,
        foodName: String,
        calories: Int,
        weightGrams: Double,
        quantity: Double,
        servingUnitRawValue: String?,
        nutrients: FoodNutrients,
        mealType: String?,
        date: Date
    ) throws {
        let operationDate = now()
        try beginOperation()
        guard CalorieCalculator.isValidCalories(calories),
              date.timeIntervalSinceReferenceDate.isFinite else {
            throw PlanEvidenceMutationError.invalidCalories
        }
        do {
            let entry = try requiredPlate(stableID: stableID)
            let oldDate = entry.date
            let changesAdaptationEvidence = entry.calories != calories || oldDate != date
            entry.applyLoggedMeal(
                foodName: foodName,
                calories: calories,
                weightGrams: weightGrams,
                quantity: quantity,
                servingUnitRawValue: servingUnitRawValue,
                nutrients: nutrients,
                mealType: mealType,
                date: date,
                modifiedAt: operationDate,
                access: access
            )
            if changesAdaptationEvidence {
                try staleCompletions(containing: [oldDate, date])
                try bumpAllProfiles(reason: "food-updated", at: operationDate)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func deletePlate(_ entry: PlateEntry) throws {
        try deletePlate(stableID: entry.stableID)
    }

    func deletePlate(stableID: UUID) throws {
        let operationDate = now()
        try beginOperation()
        do {
            let entry = try requiredPlate(stableID: stableID)
            let oldDate = entry.date
            modelContext.delete(entry)
            try staleCompletions(containing: [oldDate])
            try bumpAllProfiles(reason: "food-deleted", at: operationDate)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func addWeightMeasurement(kilograms: Double, date: Date) throws -> WeightEntry {
        let operationDate = now()
        try beginOperation()
        let validWeight = try validatedWeight(kilograms, date: date, at: operationDate)
        do {
            let entry = WeightEntry(
                date: date,
                kilograms: validWeight,
                sequence: try nextWeightSequence(),
                createdAt: operationDate,
                modifiedAt: operationDate
            )
            modelContext.insert(entry)
            try reconcileWeightProfileWithoutSaving(at: operationDate)
            try bumpAllProfiles(reason: "weight-added", at: operationDate)
            try modelContext.save()
            return entry
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func updateWeightMeasurement(_ entry: WeightEntry, kilograms: Double, date: Date) throws {
        let operationDate = now()
        try beginOperation()
        let validWeight = try validatedWeight(kilograms, date: date, at: operationDate)
        do {
            let persistedEntry = try requiredWeight(stableID: entry.stableID)
            persistedEntry.applyMeasurement(
                kilograms: validWeight,
                date: date,
                sequence: try nextWeightSequence(),
                modifiedAt: operationDate,
                access: access
            )
            try reconcileWeightProfileWithoutSaving(at: operationDate)
            try bumpAllProfiles(reason: "weight-updated", at: operationDate)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func deleteWeightMeasurement(_ entry: WeightEntry) throws -> WeightMeasurementSnapshot {
        let operationDate = now()
        try beginOperation()
        do {
            let persistedEntry = try requiredWeight(stableID: entry.stableID)
            let snapshot = WeightMeasurementSnapshot(
                date: persistedEntry.date,
                kilograms: persistedEntry.kilograms,
                stableID: persistedEntry.stableID,
                sequence: persistedEntry.sequence,
                createdAt: persistedEntry.createdAt,
                modifiedAt: persistedEntry.modifiedAt
            )
            modelContext.delete(persistedEntry)
            try reconcileWeightProfileWithoutSaving(at: operationDate)
            try bumpAllProfiles(reason: "weight-deleted", at: operationDate)
            try modelContext.save()
            return snapshot
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func restoreWeightMeasurement(_ snapshot: WeightMeasurementSnapshot) throws -> WeightEntry {
        let operationDate = now()
        try beginOperation()
        do {
            let IDs = try modelContext.fetch(FetchDescriptor<WeightEntry>()).map(\.stableID)
            guard snapshot.stableID != .zero, !IDs.contains(snapshot.stableID) else {
                throw PlanEvidenceMutationError.identityCollision(entity: "WeightEntry", id: snapshot.stableID)
            }
            let entry = WeightEntry(
                date: snapshot.date,
                kilograms: snapshot.kilograms,
                stableID: snapshot.stableID,
                sequence: snapshot.sequence,
                createdAt: snapshot.createdAt,
                modifiedAt: snapshot.modifiedAt
            )
            modelContext.insert(entry)
            try reconcileWeightProfileWithoutSaving(at: operationDate)
            try bumpAllProfiles(reason: "weight-restored", at: operationDate)
            try modelContext.save()
            return entry
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func reconcileWeightProfile() throws {
        let operationDate = now()
        try beginOperation()
        do {
            try reconcileWeightProfileWithoutSaving(at: operationDate)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func evaluateCurrent() throws -> PlanEvidenceEvaluationResult {
        let expected = try currentCompareAndSetValues()
        do {
            return try evaluate(
                expectedPlanRevisionID: expected.revisionID,
                expectedEvidenceRevision: expected.evidenceRevision
            )
        } catch PlanEvidenceMutationError.compareAndSetFailed {
            // Staleness discovery commits its evidence bump before rejecting stale CAS values.
            // Retry once from a fresh context so UI receives current status, never a dead retry loop.
            let refreshed = try currentCompareAndSetValues()
            return try evaluate(
                expectedPlanRevisionID: refreshed.revisionID,
                expectedEvidenceRevision: refreshed.evidenceRevision
            )
        }
    }

    private func currentCompareAndSetValues() throws -> (revisionID: UUID?, evidenceRevision: Int64) {
        try beginOperation()
        let profile = try requiredProfile()
        let values = (profile.currentPlanRevisionID, profile.evidenceRevision)
        modelContext.rollback()
        return values
    }

    func evaluate(
        expectedPlanRevisionID: UUID?,
        expectedEvidenceRevision: Int64
    ) throws -> PlanEvidenceEvaluationResult {
        let operationDate = now()
        try beginOperation()
        do {
            let profile = try requiredProfile()
            try validateCAS(profile, revisionID: expectedPlanRevisionID, evidenceRevision: expectedEvidenceRevision)
            if try refreshStalenessWithoutSaving() > 0 {
                try bumpEvidence(profile, reason: "food-snapshot-stale", at: operationDate)
                try modelContext.save()
                throw PlanEvidenceMutationError.compareAndSetFailed
            }
            guard var state = profile.adaptivePlanState else { throw PlanEvidenceMutationError.identityMigrationRequired }
            guard state.identityMigrationCompleted else { throw PlanEvidenceMutationError.identityMigrationRequired }
            guard state.checkInsEnabled, let epoch = state.epoch else {
                return .evaluation(.paused(profile.planGoalSource == .unknown ? .unknownSource : .manualSource))
            }
            guard epochPlanBasisMatches(epoch, profile: profile) else {
                supersedePending(in: &state, at: operationDate, reason: "epoch-basis-changed")
                state.invalidateEpoch()
                try profile.persistAdaptivePlanState(state, access: access)
                try modelContext.save()
                return .evaluation(.paused(.unsupportedScope))
            }
            if !epochCalendarMatches(epoch) {
                supersedePending(in: &state, at: operationDate, reason: "calendar-or-time-zone-changed")
                state.epoch = makeEpoch(profile: profile, at: operationDate)
                state.resetCadence()
                try bumpEvidence(profile, reason: "calendar-or-time-zone-changed", at: operationDate, supersedePending: false)
                try profile.persistAdaptivePlanState(state, access: access)
                try modelContext.save()
                return .evaluation(try domainEvaluation(profile: profile, state: state, now: operationDate))
            }
            expirePending(in: &state, at: operationDate)

            let signature = try evidenceSignature(profile: profile, state: state, through: operationDate)
            if let pending = state.pendingProposal {
                if pending.evidenceSignature == signature && pending.expiresAt > operationDate {
                    try profile.persistAdaptivePlanState(state, access: access)
                    try modelContext.save()
                    return .pending(pending)
                }
                supersedePending(in: &state, at: operationDate, reason: "evidence-signature-changed")
            }
            if let next = try cadenceHoldDate(state: state, epoch: epoch, now: operationDate) {
                try profile.persistAdaptivePlanState(state, access: access)
                try modelContext.save()
                return .cadence(nextEligibleDay: next)
            }

            let domain = try domainEvaluation(profile: profile, state: state, now: operationDate)
            guard case .proposal(let proposal) = domain else {
                try profile.persistAdaptivePlanState(state, access: access)
                try modelContext.save()
                return .evaluation(domain)
            }
            if state.lastDecisionEvidenceSignature == signature {
                let next = calendar.date(byAdding: .day, value: 7, to: state.lastDecisionDay ?? epoch.startDay) ?? operationDate
                return .cadence(nextEligibleDay: next)
            }

            let operationKey = "generation|\(epoch.id.uuidString)|\(signature)|\(epoch.algorithmVersion)"
            if let replay = state.proposals.first(where: { $0.generationOperationKey == operationKey }) {
                return replay.lifecycle == .pending ? .pending(replay) : .cadence(nextEligibleDay: replay.expiresAt)
            }
            guard let expiry = calendar.date(byAdding: .day, value: 7, to: finiteDay(operationDate) ?? operationDate) else {
                throw PlanEvidenceMutationError.invalidCompletionDay
            }
            let id = deterministicUUID(operationKey)
            let record = AdaptivePlanProposalRecord(
                id: id,
                epochID: epoch.id,
                generationOperationKey: operationKey,
                createdAt: operationDate,
                expiresAt: expiry,
                effectiveEvidenceDay: calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: operationDate)) ?? operationDate,
                lifecycle: .pending,
                decidedAt: nil,
                decisionOperationKey: nil,
                expectedPlanRevisionID: profile.currentPlanRevisionID,
                expectedPlanRevisionSequence: profile.currentPlanRevisionSequence,
                expectedEvidenceRevision: profile.evidenceRevision,
                evidenceSignature: signature,
                currentGoal: profile.dailyCalorieGoal,
                currentSourceRawValue: profile.planGoalSourceRawValue,
                proposedGoal: proposal.proposedDailyGoal,
                stepCalories: proposal.stepCalories,
                candidateCalories: proposal.candidateCalories,
                rawDifferenceCalories: proposal.rawDifferenceCalories,
                completeFoodDays: proposal.evidence.completeFoodDays,
                weighInDays: proposal.evidence.weighInDays,
                estimates: proposal.evidence.estimates.map {
                    AdaptiveWindowEstimateRecord(
                        nominalDays: $0.nominalDays,
                        trendStart: $0.trendStart,
                        trendEnd: $0.trendEnd,
                        meanLoggedCalories: $0.meanLoggedCalories,
                        kilogramsPerDay: $0.kilogramsPerDay,
                        observedMaintenanceCalories: $0.observedMaintenanceCalories
                    )
                },
                appliedRevisionID: nil,
                preApplySnapshot: nil
            )
            state.proposals.append(record)
            state.lastGenerationDay = finiteDay(operationDate)
            state.lastGenerationAt = operationDate
            state.lastGenerationEvidenceSignature = signature
            state.operations.append(AdaptivePlanOperationRecord(
                key: operationKey,
                kind: .generation,
                recordedAt: operationDate,
                proposalID: id,
                revisionID: nil,
                result: "pending"
            ))
            let checkSignature = try evidenceSignature(profile: profile, state: state, through: operationDate)
            guard checkSignature == signature else { throw PlanEvidenceMutationError.evidenceSignatureChanged }
            try profile.persistAdaptivePlanState(state, access: access)
            try modelContext.save()
            return .pending(record)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func applyPendingProposal(
        id proposalID: UUID,
        expectedPlanRevisionID: UUID?,
        expectedEvidenceRevision: Int64,
        expectedEvidenceSignature: String
    ) throws -> AdaptiveGoalRevision {
        let operationDate = now()
        let operationKey = "\(proposalID.uuidString)|apply"
        try beginOperation()
        do {
            let profile = try requiredProfile()
            guard var state = profile.adaptivePlanState else { throw PlanEvidenceMutationError.missingPendingProposal }
            if let replay = state.operations.first(where: { $0.key == operationKey }),
               let revisionID = replay.revisionID,
               let revision = state.goalRevisions.first(where: { $0.id == revisionID }) {
                return revision
            }
            try validateCAS(profile, revisionID: expectedPlanRevisionID, evidenceRevision: expectedEvidenceRevision)
            guard let epoch = state.epoch, epochPlanBasisMatches(epoch, profile: profile) else {
                supersedePending(in: &state, at: operationDate, reason: "epoch-basis-changed")
                state.invalidateEpoch()
                try profile.persistAdaptivePlanState(state, access: access)
                try modelContext.save()
                throw PlanEvidenceMutationError.epochBasisChanged
            }
            guard epochCalendarMatches(epoch) else {
                supersedePending(in: &state, at: operationDate, reason: "calendar-or-time-zone-changed")
                state.epoch = makeEpoch(profile: profile, at: operationDate)
                state.resetCadence()
                try bumpEvidence(profile, reason: "calendar-or-time-zone-changed", at: operationDate, supersedePending: false)
                try profile.persistAdaptivePlanState(state, access: access)
                try modelContext.save()
                throw PlanEvidenceMutationError.calendarOrTimeZoneChanged
            }
            guard let index = state.proposals.firstIndex(where: { $0.id == proposalID }) else {
                throw PlanEvidenceMutationError.missingPendingProposal
            }
            let proposal = state.proposals[index]
            guard proposal.lifecycle == .pending else { throw PlanEvidenceMutationError.proposalNotCurrent }
            guard proposal.expiresAt > operationDate else { throw PlanEvidenceMutationError.proposalExpired }
            guard proposal.expectedPlanRevisionID == expectedPlanRevisionID,
                  proposal.expectedEvidenceRevision == expectedEvidenceRevision,
                  proposal.evidenceSignature == expectedEvidenceSignature else {
                throw PlanEvidenceMutationError.compareAndSetFailed
            }
            if try refreshStalenessWithoutSaving() > 0 {
                throw PlanEvidenceMutationError.evidenceSignatureChanged
            }
            let signature = try evidenceSignature(profile: profile, state: state, through: operationDate)
            guard signature == expectedEvidenceSignature else { throw PlanEvidenceMutationError.evidenceSignatureChanged }
            guard case .proposal(let currentEvaluation) = try domainEvaluation(
                profile: profile,
                state: state,
                now: operationDate
            ) else {
                throw PlanEvidenceMutationError.proposalNotCurrent
            }
            let currentEstimates = currentEvaluation.evidence.estimates.map {
                AdaptiveWindowEstimateRecord(
                    nominalDays: $0.nominalDays,
                    trendStart: $0.trendStart,
                    trendEnd: $0.trendEnd,
                    meanLoggedCalories: $0.meanLoggedCalories,
                    kilogramsPerDay: $0.kilogramsPerDay,
                    observedMaintenanceCalories: $0.observedMaintenanceCalories
                )
            }
            guard proposal.currentGoal == profile.dailyCalorieGoal,
                  proposal.currentSourceRawValue == profile.planGoalSourceRawValue,
                  proposal.proposedGoal == currentEvaluation.proposedDailyGoal,
                  proposal.stepCalories == currentEvaluation.stepCalories,
                  proposal.candidateCalories.bitPattern == currentEvaluation.candidateCalories.bitPattern,
                  proposal.rawDifferenceCalories.bitPattern == currentEvaluation.rawDifferenceCalories.bitPattern,
                  proposal.completeFoodDays == currentEvaluation.evidence.completeFoodDays,
                  proposal.weighInDays == currentEvaluation.evidence.weighInDays,
                  proposal.estimates == currentEstimates else {
                throw PlanEvidenceMutationError.proposalNotCurrent
            }

            let before = AdaptivePreApplySnapshot(
                calories: profile.dailyCalorieGoal,
                sourceRawValue: profile.planGoalSourceRawValue,
                revisionID: profile.currentPlanRevisionID,
                revisionSequence: profile.currentPlanRevisionSequence,
                evidenceRevision: profile.evidenceRevision
            )
            profile.replaceAdaptiveGoal(calories: proposal.proposedGoal, access: access)
            try bumpEvidence(profile, reason: "proposal-applied", at: operationDate, supersedePending: false)
            let revision = try appendRevision(profile: profile, state: &state, reason: "adaptive-proposal-applied", at: operationDate)
            state.proposals[index].lifecycle = .applied
            state.proposals[index].decidedAt = operationDate
            state.proposals[index].decisionOperationKey = operationKey
            state.proposals[index].appliedRevisionID = revision.id
            state.proposals[index].preApplySnapshot = before
            state.acceptedSteps.append(AdaptiveAcceptedStepRecord(
                proposalID: proposalID,
                revisionID: revision.id,
                effectiveDate: revision.effectiveDay,
                calories: proposal.stepCalories
            ))
            state.lastDecisionDay = revision.effectiveDay
            state.lastDecisionAt = operationDate
            state.lastDecisionEvidenceSignature = expectedEvidenceSignature
            state.operations.append(AdaptivePlanOperationRecord(
                key: operationKey,
                kind: .apply,
                recordedAt: operationDate,
                proposalID: proposalID,
                revisionID: revision.id,
                result: "applied"
            ))
            try profile.persistAdaptivePlanState(state, access: access)
            try save(.mutation)
            return revision
        } catch PlanEvidenceMutationError.epochBasisChanged {
            throw PlanEvidenceMutationError.epochBasisChanged
        } catch PlanEvidenceMutationError.calendarOrTimeZoneChanged {
            throw PlanEvidenceMutationError.calendarOrTimeZoneChanged
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func declinePendingProposal(id proposalID: UUID) throws {
        let operationDate = now()
        let operationKey = "\(proposalID.uuidString)|decline"
        try mutateState { profile, state in
            if let epoch = state.epoch, !epochPlanBasisMatches(epoch, profile: profile) {
                supersedePending(in: &state, at: operationDate, reason: "epoch-basis-changed")
                state.invalidateEpoch()
                return
            }
            if let epoch = state.epoch, !epochCalendarMatches(epoch) {
                supersedePending(in: &state, at: operationDate, reason: "calendar-or-time-zone-changed")
                state.epoch = makeEpoch(profile: profile, at: operationDate)
                state.resetCadence()
                try bumpEvidence(profile, reason: "calendar-or-time-zone-changed", at: operationDate, supersedePending: false)
                return
            }
            if state.operations.contains(where: { $0.key == operationKey }) { return }
            guard let index = state.proposals.firstIndex(where: { $0.id == proposalID }),
                  state.proposals[index].lifecycle == .pending else {
                throw PlanEvidenceMutationError.missingPendingProposal
            }
            state.proposals[index].lifecycle = .declined
            state.proposals[index].decidedAt = operationDate
            state.proposals[index].decisionOperationKey = operationKey
            state.lastDecisionDay = finiteDay(operationDate)
            state.lastDecisionAt = operationDate
            state.lastDecisionEvidenceSignature = state.proposals[index].evidenceSignature
            state.operations.append(AdaptivePlanOperationRecord(
                key: operationKey,
                kind: .decline,
                recordedAt: operationDate,
                proposalID: proposalID,
                revisionID: nil,
                result: "declined"
            ))
        }
    }

    @discardableResult
    func revertAppliedProposal(appliedRevisionID: UUID) throws -> AdaptiveGoalRevision {
        let operationDate = now()
        let operationKey = "\(appliedRevisionID.uuidString)|revert"
        try beginOperation()
        do {
            let profile = try requiredProfile()
            guard var state = profile.adaptivePlanState else { throw PlanEvidenceMutationError.revertConflict }
            if let replay = state.operations.first(where: { $0.key == operationKey }),
               let revisionID = replay.revisionID,
               let revision = state.goalRevisions.first(where: { $0.id == revisionID }) {
                return revision
            }
            let basisWasCurrent = state.epoch.map { epochPlanBasisMatches($0, profile: profile) } ?? false
            guard profile.currentPlanRevisionID == appliedRevisionID,
                  let index = state.proposals.firstIndex(where: {
                      $0.appliedRevisionID == appliedRevisionID && $0.lifecycle == .applied
                  }),
                  let before = state.proposals[index].preApplySnapshot else {
                throw PlanEvidenceMutationError.revertConflict
            }
            profile.replaceGoalForRevert(
                calories: before.calories,
                sourceRawValue: before.sourceRawValue,
                access: access
            )
            try bumpEvidence(profile, reason: "adaptive-proposal-reverted", at: operationDate, supersedePending: false)
            let revision = try appendRevision(profile: profile, state: &state, reason: "adaptive-proposal-reverted", at: operationDate)
            state.proposals[index].lifecycle = .reverted
            state.proposals[index].decidedAt = operationDate
            state.proposals[index].decisionOperationKey = operationKey
            supersedePending(in: &state, at: operationDate, reason: "revert")
            if basisWasCurrent, state.checkInsEnabled {
                state.epoch = makeEpoch(profile: profile, at: operationDate)
                state.resetCadence()
            } else {
                state.invalidateEpoch()
            }
            state.operations.append(AdaptivePlanOperationRecord(
                key: operationKey,
                kind: .revert,
                recordedAt: operationDate,
                proposalID: state.proposals[index].id,
                revisionID: revision.id,
                result: "reverted"
            ))
            try profile.persistAdaptivePlanState(state, access: access)
            try save(.mutation)
            return revision
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Transaction helpers

    private func beginOperation() throws {
        modelContext.processPendingChanges()
        try ensureNoUnrelatedChanges()
        // Refresh registered snapshots before every CAS transaction. One long-lived
        // app context must not overwrite a newer store value from a stale snapshot.
        modelContext.rollback()
    }

    private func save(_ phase: SavePhase) throws {
        try beforeSave(phase)
        try modelContext.save()
        synchronizeAuxiliaryGoalSurfacesIfNeeded(for: phase)
    }

    private func synchronizeAuxiliaryGoalSurfacesIfNeeded(for phase: SavePhase) {
        guard phase == .mutation,
              let profile = try? requiredProfile() else { return }
        WidgetDailySummaryStore.refreshCalorieGoal(profile.dailyCalorieGoal)
        Task {
            await CaloriesLiveActivityManager.refreshCalorieGoalIfActive(profile.dailyCalorieGoal)
        }
    }

    private func ensureNoUnrelatedChanges(allowing allowed: [any PersistentModel] = []) throws {
        let allowedObjects = Set(allowed.map { ObjectIdentifier($0 as AnyObject) })
        let pending = modelContext.insertedModelsArray
            + modelContext.changedModelsArray
            + modelContext.deletedModelsArray
        guard pending.allSatisfy({ allowedObjects.contains(ObjectIdentifier($0 as AnyObject)) }) else {
            throw PlanEvidenceMutationError.uncommittedChanges
        }
    }

    private func validateAdaptivePayload(_ profile: UserProfile) throws {
        guard profile.adaptivePlanData != nil else { return }
        guard let state = AdaptivePlanPersistenceCoding.decodeUnvalidated(profile.adaptivePlanData) else {
            throw PlanEvidenceMutationError.corruptAdaptivePayload
        }
        guard state.schemaVersion == AdaptivePlanPersistenceState.schemaVersion else {
            throw PlanEvidenceMutationError.unsupportedAdaptiveSchema(state.schemaVersion)
        }
    }

    private func resetPlanMutation(profile: UserProfile, reason: String, at date: Date) throws {
        var state = profile.adaptivePlanState ?? AdaptivePlanPersistenceState()
        try resetPlanMutation(profile: profile, state: &state, reason: reason, at: date)
        try profile.persistAdaptivePlanState(state, access: access)
    }

    private func resetPlanMutation(
        profile: UserProfile,
        state: inout AdaptivePlanPersistenceState,
        reason: String,
        at date: Date
    ) throws {
        guard profile.evidenceRevision < Int64.max else { throw PlanEvidenceMutationError.evidenceOverflow }
        profile.replaceEvidenceRevision(profile.evidenceRevision + 1, access: access)
        supersedePending(in: &state, at: date, reason: reason)
        state.invalidateEpoch()
        _ = try appendRevision(profile: profile, state: &state, reason: reason, at: date)
    }

    private func validatedWeight(_ kilograms: Double, date: Date, at operationDate: Date) throws -> Double {
        let weight = try WeightHistory.validatedWeight(kilograms)
        guard date <= operationDate else { throw WeightHistoryError.futureTimestamp }
        return weight
    }

    private func nextWeightSequence() throws -> Int64 {
        let entries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        let highWaterMark = max(
            entries.map(\.sequence).max() ?? 0,
            profiles.map(\.nextWeightSequence).max() ?? 0
        )
        guard highWaterMark < Int64.max else { throw WeightHistoryError.sequenceOverflow }
        let next = highWaterMark + 1
        if profiles.isEmpty {
            modelContext.insert(UserProfile(nextWeightSequence: next))
        } else {
            for profile in profiles {
                profile.replaceNextWeightSequence(next, access: access)
            }
        }
        return next
    }

    private func reconcileWeightProfileWithoutSaving(at operationDate: Date) throws {
        let entries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
        let currentWeight = WeightHistory.latestValidMeasurement(
            from: entries.map {
                WeightProgressPoint(
                    date: $0.date,
                    kilograms: $0.kilograms,
                    stableID: $0.stableID,
                    sequence: $0.sequence
                )
            },
            now: operationDate
        )?.kilograms ?? 0
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        if profiles.isEmpty {
            modelContext.insert(UserProfile(currentWeight: currentWeight))
        } else {
            for profile in profiles {
                profile.replaceCurrentWeight(currentWeight, access: access)
            }
        }
    }

    private func mutateState(
        _ mutation: (UserProfile, inout AdaptivePlanPersistenceState) throws -> Void
    ) throws {
        try beginOperation()
        do {
            let profile = try requiredProfile()
            try validateAdaptivePayload(profile)
            var state = profile.adaptivePlanState ?? AdaptivePlanPersistenceState()
            try mutation(profile, &state)
            try profile.persistAdaptivePlanState(state, access: access)
            try save(.mutation)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func requiredProfile() throws -> UserProfile {
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        guard !profiles.isEmpty else { throw PlanEvidenceMutationError.missingProfile }
        guard profiles.count == 1 else { throw PlanEvidenceMutationError.multipleProfiles }
        return profiles[0]
    }

    private func requiredPlate(stableID: UUID) throws -> PlateEntry {
        guard stableID != .zero,
              let entry = try modelContext.fetch(FetchDescriptor<PlateEntry>()).first(where: {
                  $0.stableID == stableID
              }) else {
            throw PlanEvidenceMutationError.identityVerificationFailed
        }
        return entry
    }

    private func requiredWeight(stableID: UUID) throws -> WeightEntry {
        guard stableID != .zero,
              let entry = try modelContext.fetch(FetchDescriptor<WeightEntry>()).first(where: {
                  $0.stableID == stableID
              }) else {
            throw PlanEvidenceMutationError.identityVerificationFailed
        }
        return entry
    }

    private func validateCAS(_ profile: UserProfile, revisionID: UUID?, evidenceRevision: Int64) throws {
        guard profile.currentPlanRevisionID == revisionID,
              profile.evidenceRevision == evidenceRevision else {
            throw PlanEvidenceMutationError.compareAndSetFailed
        }
    }

    private func bumpEvidence(
        _ profile: UserProfile,
        reason: String,
        at date: Date,
        supersedePending shouldSupersede: Bool = true
    ) throws {
        guard profile.evidenceRevision < Int64.max else { throw PlanEvidenceMutationError.evidenceOverflow }
        profile.replaceEvidenceRevision(profile.evidenceRevision + 1, access: access)
        if shouldSupersede, var state = profile.adaptivePlanState {
            supersedePending(in: &state, at: date, reason: reason)
            try profile.persistAdaptivePlanState(state, access: access)
        }
    }

    private func bumpAllProfiles(reason: String, at date: Date) throws {
        for profile in try modelContext.fetch(FetchDescriptor<UserProfile>()) {
            try bumpEvidence(profile, reason: reason, at: date)
        }
    }

    private func appendRevision(
        profile: UserProfile,
        state: inout AdaptivePlanPersistenceState,
        reason: String,
        at date: Date
    ) throws -> AdaptiveGoalRevision {
        guard profile.currentPlanRevisionSequence < Int64.max else { throw PlanEvidenceMutationError.revisionOverflow }
        let revision = AdaptiveGoalRevision(
            id: makeUUID(),
            sequence: profile.currentPlanRevisionSequence + 1,
            effectiveDay: calendar.startOfDay(for: date),
            acceptedAt: date,
            calories: profile.dailyCalorieGoal,
            sourceRawValue: profile.planGoalSourceRawValue,
            reason: reason,
            epochID: state.epoch?.id,
            evidenceRevision: profile.evidenceRevision,
            priorRevisionID: profile.currentPlanRevisionID
        )
        state.goalRevisions.append(revision)
        profile.replacePlanRevision(id: revision.id, sequence: revision.sequence, access: access)
        return revision
    }

    private func makeEpoch(profile: UserProfile, at date: Date) -> AdaptivePlanEpoch {
        let operationDay = calendar.startOfDay(for: date)
        let startDay = date == operationDay
            ? operationDay
            : (calendar.date(byAdding: .day, value: 1, to: operationDay) ?? operationDay)
        return AdaptivePlanEpoch(
            id: makeUUID(),
            startedAt: date,
            startDay: startDay,
            calendarIdentifier: calendarIdentity.calendar,
            timeZoneIdentifier: calendarIdentity.timeZone,
            algorithmVersion: AdaptivePlanPersistenceState.algorithmVersion,
            startingGoal: profile.dailyCalorieGoal,
            startingSourceRawValue: profile.planGoalSourceRawValue,
            calculatedBasisSignature: calculatedBasisSignature(profile: profile)
        )
    }

    private func epochPlanBasisMatches(_ epoch: AdaptivePlanEpoch, profile: UserProfile) -> Bool {
        epoch.algorithmVersion == AdaptivePlanPersistenceState.algorithmVersion
            && epoch.calculatedBasisSignature == calculatedBasisSignature(profile: profile)
    }

    private func epochCalendarMatches(_ epoch: AdaptivePlanEpoch) -> Bool {
        epoch.calendarIdentifier == calendarIdentity.calendar
            && epoch.timeZoneIdentifier == calendarIdentity.timeZone
    }

    private func calculatedBasisSignature(profile: UserProfile) -> String {
        let value = [
            profile.calculatedPlanData?.base64EncodedString() ?? "nil",
            String(profile.targetWeight.bitPattern),
            String(profile.targetDate.timeIntervalSinceReferenceDate.bitPattern),
            String(profile.age),
            String(AdaptivePlanPersistenceState.algorithmVersion)
        ].joined(separator: "|")
        return SHA256.hash(data: Data(value.utf8)).hex
    }

    private var calendarIdentity: (calendar: String, timeZone: String) {
        (String(describing: calendar.identifier), calendar.timeZone.identifier)
    }

    private func finiteDay(_ date: Date) -> Date? {
        guard date.timeIntervalSinceReferenceDate.isFinite else { return nil }
        return calendar.startOfDay(for: date)
    }

    private func rejectCollisions(_ IDs: [UUID], entity: String) throws {
        var seen: Set<UUID> = []
        for id in IDs where !seen.insert(id).inserted {
            throw PlanEvidenceMutationError.identityCollision(entity: entity, id: id)
        }
    }

    private func freshID(excluding used: inout Set<UUID>) throws -> UUID {
        for _ in 0..<100 {
            let candidate = makeUUID()
            if candidate != .zero, used.insert(candidate).inserted { return candidate }
        }
        throw PlanEvidenceMutationError.identityVerificationFailed
    }

    private func plateSnapshot(for day: Date) throws -> [PlateEvidenceSnapshot] {
        try modelContext.fetch(FetchDescriptor<PlateEntry>()).compactMap { plate in
            guard finiteDay(plate.date) == day else { return nil }
            return PlateEvidenceSnapshot(
                stableID: plate.stableID,
                dateBitPattern: plate.date.timeIntervalSinceReferenceDate.bitPattern,
                calories: plate.calories
            )
        }.sorted(by: plateSnapshotOrder)
    }

    private func plateSnapshotOrder(_ lhs: PlateEvidenceSnapshot, _ rhs: PlateEvidenceSnapshot) -> Bool {
        if lhs.stableID.uuidString != rhs.stableID.uuidString {
            return lhs.stableID.uuidString < rhs.stableID.uuidString
        }
        if lhs.dateBitPattern != rhs.dateBitPattern { return lhs.dateBitPattern < rhs.dateBitPattern }
        return lhs.calories < rhs.calories
    }

    private func calorieTotal(_ snapshot: [PlateEvidenceSnapshot]) throws -> Int {
        var total = 0
        for plate in snapshot {
            guard FoodCaloriePolicy.isValid(plate.calories) else {
                throw PlanEvidenceMutationError.invalidCalories
            }
            let result = total.addingReportingOverflow(plate.calories)
            guard !result.overflow else { throw PlanEvidenceMutationError.invalidCalories }
            total = result.partialValue
        }
        return total
    }

    private func bulkFoodBatchSignature(
        _ inserts: [BulkPlateInsert],
        expectedDay: Date
    ) -> String {
        let values = inserts.map { insert in
            let identity: String
            switch insert.match.identity {
            case .barcode(let barcode): identity = "barcode:\(barcode)"
            case .savedFood(let id): identity = "saved:\(id.uuidString)"
            }
            return [
                insert.id.uuidString,
                insert.sourceItemID.uuidString,
                identity,
                insert.match.displayName,
                String(insert.match.servingAmount.bitPattern),
                insert.match.barcode ?? "",
                insert.match.source.rawValue,
                insert.match.servingUnit.rawValue,
                String(insert.match.caloriesPerServing),
                nutrientSignature(insert.match.nutrientsPerServing),
                String(insert.amount.bitPattern),
                insert.unit.rawValue,
                insert.mealType,
                String(insert.date.timeIntervalSinceReferenceDate.bitPattern)
            ].joined(separator: "|")
        }
        return SHA256.hash(data: Data(
            ([String(expectedDay.timeIntervalSinceReferenceDate.bitPattern)] + values)
                .joined(separator: "\n").utf8
        )).hex
    }

    private func nutrientSignature(_ nutrients: FoodNutrients) -> String {
        [
            nutrients.carbohydratesGrams.map { String($0.bitPattern) } ?? "nil",
            nutrients.proteinGrams.map { String($0.bitPattern) } ?? "nil",
            nutrients.fatGrams.map { String($0.bitPattern) } ?? "nil",
            nutrients.fiberGrams.map { String($0.bitPattern) } ?? "nil"
        ].joined(separator: ",")
    }

    private func isValidFoodBarcode(_ barcode: String) -> Bool {
        guard (8...14).contains(barcode.utf8.count) else { return false }
        return barcode.utf8.allSatisfy { (48...57).contains($0) }
    }

    private func bulkMatch(_ match: BulkFoodMatch, represents food: Food) -> Bool {
        match.identity == .savedFood(food.stableID)
            && bulkNutritionSnapshotMatches(match, represents: food)
    }

    private func bulkBarcodeMatch(
        _ match: BulkFoodMatch,
        barcode: String,
        represents food: Food
    ) -> Bool {
        match.identity == .barcode(barcode)
            && match.barcode == barcode
            && bulkNutritionSnapshotMatches(match, represents: food)
    }

    private func bulkNutritionSnapshotMatches(
        _ match: BulkFoodMatch,
        represents food: Food
    ) -> Bool {
        match.displayName == food.name
            && match.barcode == food.barcode
            && match.servingAmount.bitPattern == food.servingGrams.bitPattern
            && match.servingUnit == food.nutritionUnit
            && match.caloriesPerServing == food.calories
            && match.nutrientsPerServing == food.nutrientsPerServing
    }

    private func bulkNutritionSnapshotMatches(
        _ lhs: BulkFoodMatch,
        _ rhs: BulkFoodMatch
    ) -> Bool {
        lhs.displayName == rhs.displayName
            && lhs.barcode == rhs.barcode
            && lhs.servingAmount.bitPattern == rhs.servingAmount.bitPattern
            && lhs.servingUnit == rhs.servingUnit
            && lhs.caloriesPerServing == rhs.caloriesPerServing
            && lhs.nutrientsPerServing == rhs.nutrientsPerServing
    }

    private func bulkOperationOrder(
        _ lhs: BulkFoodBatchOperation,
        _ rhs: BulkFoodBatchOperation
    ) -> Bool {
        if lhs.committedAt != rhs.committedAt { return lhs.committedAt < rhs.committedAt }
        return lhs.operationID.uuidString < rhs.operationID.uuidString
    }

    private func staleCompletions(containing dates: [Date]) throws {
        let days = Set(dates.compactMap(finiteDay))
        guard !days.isEmpty else { return }
        let identity = calendarIdentity
        for completion in try modelContext.fetch(FetchDescriptor<FoodLogCompletion>())
        where completion.calendarIdentifier == identity.calendar
            && completion.timeZoneIdentifier == identity.timeZone
            && days.contains(completion.dayStart) {
            completion.markStale(access: access)
        }
    }

    private func refreshStalenessWithoutSaving() throws -> Int {
        let identity = calendarIdentity
        var changed = 0
        for completion in try modelContext.fetch(FetchDescriptor<FoodLogCompletion>())
        where !completion.isStale
            && completion.calendarIdentifier == identity.calendar
            && completion.timeZoneIdentifier == identity.timeZone {
            let current = try plateSnapshot(for: completion.dayStart)
            guard let saved = completion.plateSnapshot,
                  saved == current,
                  (try? calorieTotal(current)) == completion.attestedCalories,
                  completion.evidenceSchemaVersion == Self.evidenceSchemaVersion else {
                completion.markStale(access: access)
                changed += 1
                continue
            }
        }
        return changed
    }

    private func supersedePending(
        in state: inout AdaptivePlanPersistenceState,
        at date: Date,
        reason: String
    ) {
        for index in state.proposals.indices where state.proposals[index].lifecycle == .pending {
            state.proposals[index].lifecycle = .superseded
            state.proposals[index].decidedAt = date
            state.proposals[index].decisionOperationKey = "superseded:\(reason)"
        }
    }

    private func expirePending(in state: inout AdaptivePlanPersistenceState, at date: Date) {
        for index in state.proposals.indices
        where state.proposals[index].lifecycle == .pending && state.proposals[index].expiresAt <= date {
            state.proposals[index].lifecycle = .expired
            state.proposals[index].decidedAt = date
            state.proposals[index].decisionOperationKey = "expired"
        }
    }

    private func cadenceHoldDate(
        state: AdaptivePlanPersistenceState,
        epoch: AdaptivePlanEpoch,
        now: Date
    ) throws -> Date? {
        let generationReference = state.lastGenerationDay.flatMap { day in
            state.lastGenerationAt.map { (day: day, at: $0) }
        }
        let decisionReference = state.lastDecisionDay.flatMap { day in
            state.lastDecisionAt.map { (day: day, at: $0) }
        }
        guard let reference = [generationReference, decisionReference]
            .compactMap({ $0 })
            .max(by: { $0.at < $1.at }) else { return nil }
        guard let next = calendar.date(byAdding: .day, value: 7, to: reference.day) else { return now }
        let today = calendar.startOfDay(for: now)
        if today < next { return next }

        let identity = calendarIdentity
        let completions = try modelContext.fetch(FetchDescriptor<FoodLogCompletion>()).filter {
            !$0.isStale
                && $0.calendarIdentifier == identity.calendar
                && $0.timeZoneIdentifier == identity.timeZone
                && $0.dayStart > reference.day
                && $0.dayStart < today
                && $0.attestedAt > reference.at
                && $0.attestedAt >= epoch.startedAt
        }
        let completeDays = Set(completions.map(\.civilDayKey)).count
        let weights = try modelContext.fetch(FetchDescriptor<WeightEntry>()).filter {
            guard let day = finiteDay($0.date) else { return false }
            return day > reference.day
                && day < today
                && $0.date > reference.at
                && $0.date >= epoch.startedAt
        }
        return completeDays >= 7 && !weights.isEmpty ? nil : next
    }

    private func domainEvaluation(
        profile: UserProfile,
        state: AdaptivePlanPersistenceState,
        now: Date
    ) throws -> AdaptiveCaloriePlanEvaluation {
        guard let epoch = state.epoch else { return .paused(.manualSource) }
        let identity = calendarIdentity
        let completions = try modelContext.fetch(FetchDescriptor<FoodLogCompletion>()).filter {
            $0.calendarIdentifier == identity.calendar
                && $0.timeZoneIdentifier == identity.timeZone
                && $0.attestedAt >= epoch.startedAt
                && $0.dayStart >= epoch.startDay
        }
        let weights = try modelContext.fetch(FetchDescriptor<WeightEntry>()).filter {
            $0.date >= epoch.startedAt
        }
        let source = profile.planGoalSource
        let stored = profile.storedCalculatedPlan
        let scopeMatches = state.supportedScopeConfirmedAt != nil && (stored.map {
            $0.plan.input.age == profile.age
                && $0.plan.input.targetWeightKilograms == profile.targetWeight
        } ?? false)
        return AdaptiveCaloriePlanEvaluator.evaluate(
            AdaptiveCaloriePlanInput(
                source: source,
                currentSupportedScope: scopeMatches,
                currentDailyGoal: profile.dailyCalorieGoal,
                calculatedPlan: stored?.plan,
                foodDays: completions.map {
                    AdaptiveCalorieFoodDay(
                        date: $0.dayStart,
                        calories: Double($0.attestedCalories),
                        isComplete: true,
                        isStale: $0.isStale
                    )
                },
                weights: weights.map { AdaptiveCalorieWeight(date: $0.date, kilograms: $0.kilograms) },
                acceptedSteps: state.acceptedSteps.map {
                    AdaptiveCalorieAcceptedStep(effectiveDate: $0.effectiveDate, calories: $0.calories)
                }
            ),
            now: now,
            calendar: calendar
        )
    }

    private func cadenceRelevantRecords(
        profile: UserProfile,
        state: AdaptivePlanPersistenceState
    ) throws -> SignaturePayload {
        let plates = try modelContext.fetch(FetchDescriptor<PlateEntry>()).map {
            PlateEvidenceSnapshot(
                stableID: $0.stableID,
                dateBitPattern: $0.date.timeIntervalSinceReferenceDate.bitPattern,
                calories: $0.calories
            )
        }.sorted(by: plateSnapshotOrder)
        let completions = try modelContext.fetch(FetchDescriptor<FoodLogCompletion>()).map {
            CompletionSignatureRecord(
                stableID: $0.stableID,
                civilDayKey: $0.civilDayKey,
                dayStartBitPattern: $0.dayStart.timeIntervalSinceReferenceDate.bitPattern,
                attestedAtBitPattern: $0.attestedAt.timeIntervalSinceReferenceDate.bitPattern,
                calories: $0.attestedCalories,
                stale: $0.isStale,
                schemaVersion: $0.evidenceSchemaVersion,
                snapshotRevision: $0.canonicalSnapshotRevision,
                snapshotBase64: $0.canonicalPlateSnapshotData.base64EncodedString()
            )
        }.sorted { $0.stableID.uuidString < $1.stableID.uuidString }
        let weights = try modelContext.fetch(FetchDescriptor<WeightEntry>()).map {
            WeightEvidenceSnapshot(
                stableID: $0.stableID,
                sequence: $0.sequence,
                dateBitPattern: $0.date.timeIntervalSinceReferenceDate.bitPattern,
                kilogramsBitPattern: $0.kilograms.bitPattern
            )
        }.sorted {
            if $0.sequence != $1.sequence { return $0.sequence < $1.sequence }
            return $0.stableID.uuidString < $1.stableID.uuidString
        }
        return SignaturePayload(
            epochID: state.epoch?.id,
            algorithmVersion: state.epoch?.algorithmVersion,
            plate: plates,
            completions: completions,
            weights: weights,
            goal: profile.dailyCalorieGoal,
            source: profile.planGoalSourceRawValue,
            targetWeightBitPattern: profile.targetWeight.bitPattern,
            targetDateBitPattern: profile.targetDate.timeIntervalSinceReferenceDate.bitPattern,
            age: profile.age,
            calculatedPlanBase64: profile.calculatedPlanData?.base64EncodedString(),
            planRevisionID: profile.currentPlanRevisionID,
            planRevisionSequence: profile.currentPlanRevisionSequence
        )
    }

    private func evidenceSignature(
        profile: UserProfile,
        state: AdaptivePlanPersistenceState,
        through _: Date
    ) throws -> String {
        let payload = try cadenceRelevantRecords(profile: profile, state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(payload)).hex
    }

    private func deterministicUUID(_ key: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(key.utf8)))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

private struct CompletionSignatureRecord: Codable {
    let stableID: UUID
    let civilDayKey: String
    let dayStartBitPattern: UInt64
    let attestedAtBitPattern: UInt64
    let calories: Int
    let stale: Bool
    let schemaVersion: Int
    let snapshotRevision: Int64
    let snapshotBase64: String
}

private struct SignaturePayload: Codable {
    let epochID: UUID?
    let algorithmVersion: Int?
    let plate: [PlateEvidenceSnapshot]
    let completions: [CompletionSignatureRecord]
    let weights: [WeightEvidenceSnapshot]
    let goal: Int
    let source: String
    let targetWeightBitPattern: UInt64
    let targetDateBitPattern: UInt64
    let age: Int
    let calculatedPlanBase64: String?
    let planRevisionID: UUID?
    let planRevisionSequence: Int64
}

private extension SHA256.Digest {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
