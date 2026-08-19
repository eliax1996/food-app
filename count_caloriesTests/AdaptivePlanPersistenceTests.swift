#if !SWIFT_PACKAGE
import Foundation
import SwiftData
import XCTest
@testable import count_calories

@MainActor
final class AdaptivePlanPersistenceTests: XCTestCase {
    private enum InjectedFailure: Error {
        case save
    }

    private final class Clock {
        var value: Date
        init(_ value: Date) { self.value = value }
    }

    func testLegacyManualMigrationBackfillsOnlyMissingIdentityAndFabricatesNoOptIn() throws {
        let fixture = try makeFixture()
        let profile = UserProfile(dailyCalorieGoal: 1_923, planGoalSource: .manual)
        let validID = UUID()
        let plate = PlateEntry(
            foodName: "Legacy",
            calories: 300,
            weightGrams: 1,
            quantity: 1,
            stableID: .zero
        )
        let weight = WeightEntry(
            date: fixture.clock.value.addingTimeInterval(-10),
            kilograms: 70,
            stableID: validID,
            sequence: 91
        )
        fixture.context.insert(profile)
        fixture.context.insert(plate)
        fixture.context.insert(weight)
        try fixture.context.save()

        let result = try fixture.coordinator.validateAndBackfillStableIdentities()

        XCTAssertEqual(result.backfilledPlateIDs, 1)
        XCTAssertEqual(result.backfilledWeightIDs, 0)
        let verification = ModelContext(fixture.container)
        let migratedPlate = try XCTUnwrap(verification.fetch(FetchDescriptor<PlateEntry>()).first)
        let migratedWeight = try XCTUnwrap(verification.fetch(FetchDescriptor<WeightEntry>()).first)
        let migratedProfile = try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertNotEqual(migratedPlate.stableID, .zero)
        XCTAssertEqual(migratedWeight.stableID, validID)
        XCTAssertEqual(migratedWeight.sequence, 91)
        XCTAssertEqual(migratedProfile.dailyCalorieGoal, 1_923)
        XCTAssertEqual(migratedProfile.planGoalSource, .manual)
        XCTAssertFalse(try XCTUnwrap(migratedProfile.adaptivePlanState).checkInsEnabled)
        XCTAssertNil(migratedProfile.adaptivePlanState?.epoch)
        XCTAssertTrue(migratedProfile.adaptivePlanState?.proposals.isEmpty == true)
        XCTAssertTrue(migratedProfile.adaptivePlanState?.goalRevisions.isEmpty == true)
    }

    func testEpochStartsNextCivilDayAfterMidnightAndExcludesSameDayCompletion() throws {
        let noon = date(2026, 3, 10, hour: 12)
        let fixture = try makeFixture(now: noon)
        let calculated = try plan(calendar: fixture.calendar)
        let profile = try fixture.coordinator.acceptCalculatedPlan(
            calculated,
            measurementSystem: .metric,
            acceptedAt: noon
        )

        let epoch = try fixture.coordinator.enableAdaptiveCheckIns(supportedScopeConfirmed: true)
        let today = fixture.calendar.startOfDay(for: noon)
        let tomorrow = try XCTUnwrap(fixture.calendar.date(byAdding: .day, value: 1, to: today))
        XCTAssertEqual(epoch.startDay, tomorrow)

        try fixture.coordinator.insertPlate(PlateEntry(
            foodName: "Pre-epoch same day",
            calories: 2_000,
            weightGrams: 1,
            quantity: 1,
            date: noon
        ))
        _ = try fixture.coordinator.markFoodLogComplete(for: noon)
        fixture.clock.value = tomorrow.addingTimeInterval(12 * 3_600)
        let result = try fixture.coordinator.evaluate(
            expectedPlanRevisionID: profile.currentPlanRevisionID,
            expectedEvidenceRevision: profile.evidenceRevision
        )
        guard case .evaluation(.collecting(let collection)) = result else {
            return XCTFail("Pre-epoch same-day completion must remain excluded: \(result)")
        }
        XCTAssertEqual(collection.completeFoodDays, 0)

        let midnightFixture = try makeFixture(now: today)
        let midnightPlan = try plan(calendar: midnightFixture.calendar)
        _ = try midnightFixture.coordinator.acceptCalculatedPlan(
            midnightPlan,
            measurementSystem: .metric,
            acceptedAt: today
        )
        let midnightEpoch = try midnightFixture.coordinator.enableAdaptiveCheckIns(
            supportedScopeConfirmed: true
        )
        XCTAssertEqual(midnightEpoch.startDay, today)
    }

    func testIdentityCollisionFailsClosedWithoutRewritingEitherRow() throws {
        let fixture = try makeFixture()
        let collision = UUID()
        let first = PlateEntry(foodName: "A", calories: 1, weightGrams: 1, quantity: 1, stableID: collision)
        let second = PlateEntry(foodName: "B", calories: 1, weightGrams: 1, quantity: 1, stableID: collision)
        fixture.context.insert(UserProfile())
        fixture.context.insert(first)
        fixture.context.insert(second)
        try fixture.context.save()

        XCTAssertThrowsError(try fixture.coordinator.validateAndBackfillStableIdentities()) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .identityCollision(entity: "PlateEntry", id: collision))
        }
        XCTAssertEqual(first.stableID, collision)
        XCTAssertEqual(second.stableID, collision)
        XCTAssertNil(try fixture.context.fetch(FetchDescriptor<UserProfile>()).first?.adaptivePlanData)
    }

    func testCompletionRoundTripsCanonicalSnapshotAndStalesForAddEditDeleteAndDateMove() throws {
        let fixture = try makeFixture(now: date(2026, 3, 10, hour: 12))
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        _ = try fixture.coordinator.validateAndBackfillStableIdentities()
        let today = fixture.calendar.startOfDay(for: fixture.clock.value)
        let yesterday = try XCTUnwrap(fixture.calendar.date(byAdding: .day, value: -1, to: today))
        let todayPlate = PlateEntry(
            foodName: "Today",
            calories: 100,
            weightGrams: 1,
            quantity: 1,
            date: today.addingTimeInterval(8 * 3_600)
        )
        let yesterdayPlate = PlateEntry(
            foodName: "Yesterday",
            calories: 200,
            weightGrams: 1,
            quantity: 1,
            date: yesterday.addingTimeInterval(9 * 3_600)
        )
        try fixture.coordinator.insertPlate(todayPlate)
        try fixture.coordinator.insertPlate(yesterdayPlate)
        let todayCompletion = try fixture.coordinator.markFoodLogComplete(for: today)
        let yesterdayCompletion = try fixture.coordinator.markFoodLogComplete(for: yesterday)

        XCTAssertEqual(todayCompletion.attestedCalories, 100)
        XCTAssertEqual(todayCompletion.plateSnapshot?.first?.stableID, todayPlate.stableID)
        XCTAssertEqual(todayCompletion.plateSnapshot?.first?.dateBitPattern, todayPlate.date.timeIntervalSinceReferenceDate.bitPattern)
        XCTAssertFalse(todayCompletion.isStale)
        XCTAssertFalse(yesterdayCompletion.isStale)

        let evidenceBeforeRepeatedAttestation = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<UserProfile>()).first
        ).evidenceRevision
        let originalAttestedAt = todayCompletion.attestedAt
        let originalSnapshotRevision = todayCompletion.canonicalSnapshotRevision
        let repeatedCompletion = try fixture.coordinator.markFoodLogComplete(for: today)
        XCTAssertEqual(repeatedCompletion.attestedAt, originalAttestedAt)
        XCTAssertEqual(repeatedCompletion.canonicalSnapshotRevision, originalSnapshotRevision)
        XCTAssertEqual(
            try XCTUnwrap(ModelContext(fixture.container).fetch(FetchDescriptor<UserProfile>()).first).evidenceRevision,
            evidenceBeforeRepeatedAttestation
        )

        let evidenceBeforeMetadataEdit = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<UserProfile>()).first
        ).evidenceRevision
        let currentToday = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>())
                .first { $0.stableID == todayPlate.stableID }
        )
        try fixture.coordinator.updatePlate(
            stableID: todayPlate.stableID,
            expectedModifiedAt: currentToday.modifiedAt,
            foodName: "Renamed Today",
            calories: todayPlate.calories,
            weightGrams: 2,
            quantity: 2,
            servingUnitRawValue: NutritionUnit.grams.rawValue,
            nutrients: FoodNutrients(proteinGrams: 4),
            mealType: MealType.lunch.rawValue,
            date: todayPlate.date
        )
        XCTAssertTrue(todayCompletion.isStale, "Any logged snapshot edit must require food-log reconfirmation.")
        XCTAssertEqual(
            try XCTUnwrap(ModelContext(fixture.container).fetch(FetchDescriptor<UserProfile>()).first).evidenceRevision,
            evidenceBeforeMetadataEdit + 1
        )
        _ = try fixture.coordinator.reconfirmFoodLog(for: today)

        let currentTodayAfterEdit = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>())
                .first { $0.stableID == todayPlate.stableID }
        )
        try fixture.coordinator.updatePlateEvidence(
            currentTodayAfterEdit,
            calories: 125,
            date: yesterday.addingTimeInterval(10 * 3_600)
        )
        XCTAssertTrue(todayCompletion.isStale, "Source completion must stale after date move.")
        XCTAssertTrue(yesterdayCompletion.isStale, "Destination completion must stale after date move.")

        let reconfirmed = try fixture.coordinator.reconfirmFoodLog(for: yesterday)
        XCTAssertFalse(reconfirmed.isStale)
        XCTAssertEqual(reconfirmed.attestedCalories, 325)
        XCTAssertEqual(reconfirmed.canonicalSnapshotRevision, 2)

        let added = PlateEntry(
            foodName: "Added",
            calories: 50,
            weightGrams: 1,
            quantity: 1,
            date: yesterday.addingTimeInterval(11 * 3_600)
        )
        try fixture.coordinator.insertPlate(added)
        XCTAssertTrue(reconfirmed.isStale)
        _ = try fixture.coordinator.reconfirmFoodLog(for: yesterday)
        try fixture.coordinator.updatePlateEvidence(added, calories: 60, date: added.date)
        XCTAssertTrue(reconfirmed.isStale)
        _ = try fixture.coordinator.reconfirmFoodLog(for: yesterday)
        try fixture.coordinator.deletePlate(added)
        XCTAssertTrue(reconfirmed.isStale)
    }

    func testDebugProposalFixtureAppliesAfterTodaySeedsUnrelatedModels() throws {
        let fixture = try makeFixture(now: date(2026, 3, 10, hour: 12))
        try PreviewData.seedAdaptiveProposal(
            fixture.context,
            coordinator: fixture.coordinator,
            now: fixture.clock.value,
            calendar: fixture.calendar
        )
        fixture.context.insert(Food(name: "Today seed", calories: 15, servingGrams: 100))
        fixture.context.insert(WaterDay(date: fixture.clock.value, glasses: 0))
        try fixture.context.save()

        let reloaded = ModelContext(fixture.container)
        let profile = try XCTUnwrap(reloaded.fetch(FetchDescriptor<UserProfile>()).first)
        let proposal = try XCTUnwrap(profile.adaptivePlanState?.pendingProposal)
        let revision = try fixture.coordinator.applyPendingProposal(
            id: proposal.id,
            expectedPlanRevisionID: proposal.expectedPlanRevisionID,
            expectedEvidenceRevision: proposal.expectedEvidenceRevision,
            expectedEvidenceSignature: proposal.evidenceSignature
        )
        XCTAssertEqual(revision.calories, proposal.proposedGoal)
    }

    func testDebugProposalFixtureReloadsAsOneCalculatedProfile() throws {
        let fixture = try makeFixture(now: date(2026, 3, 10, hour: 12))
        try PreviewData.seedAdaptiveProposal(
            fixture.context,
            coordinator: fixture.coordinator,
            now: fixture.clock.value,
            calendar: fixture.calendar
        )

        let reloaded = ModelContext(fixture.container)
        let profiles = try reloaded.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.planGoalSource, .calculated)
        XCTAssertNotNil(profiles.first?.adaptivePlanState?.pendingProposal)
    }

    func testUnknownRawSourceNeverDecodesAsManual() {
        let profile = UserProfile(dailyCalorieGoal: 1_777, rawPlanGoalSource: "future-source")

        XCTAssertEqual(profile.planGoalSource, .unknown)
        XCTAssertNotEqual(profile.planGoalSource, .manual)
        XCTAssertEqual(profile.dailyCalorieGoal, 1_777)
    }

    func testGenerationWaitsForCompleteEvidenceThenApplyReplaysAcrossRelaunchAndExactRevert() throws {
        let ready = try makeReadyProposalFixture()
        let profile = ready.profile
        let proposal = ready.proposal
        let originalGoal = profile.dailyCalorieGoal
        let originalSource = profile.planGoalSourceRawValue

        let revision = try ready.coordinator.applyPendingProposal(
            id: proposal.id,
            expectedPlanRevisionID: proposal.expectedPlanRevisionID,
            expectedEvidenceRevision: proposal.expectedEvidenceRevision,
            expectedEvidenceSignature: proposal.evidenceSignature
        )
        XCTAssertEqual(profile.dailyCalorieGoal, proposal.proposedGoal)
        XCTAssertEqual(profile.planGoalSource, .adapted)
        XCTAssertEqual(profile.calculatedPlanData, ready.calculatedPlanData)

        ready.clock.value = try XCTUnwrap(ready.calendar.date(
            byAdding: .day,
            value: 7,
            to: ready.calendar.startOfDay(for: ready.clock.value)
        )).addingTimeInterval(12 * 3_600)
        let cadence = try ready.coordinator.evaluate(
            expectedPlanRevisionID: profile.currentPlanRevisionID,
            expectedEvidenceRevision: profile.evidenceRevision
        )
        guard case .cadence = cadence else {
            return XCTFail("Accepted decision requires seven fresh complete days and newer weight.")
        }

        let relaunchedContext = ModelContext(ready.container)
        let relaunched = PlanEvidenceMutationCoordinator(
            modelContainer: ready.container,
            calendar: ready.calendar,
            now: { ready.clock.value }
        )
        let replay = try relaunched.applyPendingProposal(
            id: proposal.id,
            expectedPlanRevisionID: proposal.expectedPlanRevisionID,
            expectedEvidenceRevision: proposal.expectedEvidenceRevision,
            expectedEvidenceSignature: proposal.evidenceSignature
        )
        XCTAssertEqual(replay.id, revision.id)
        let reloadedProfile = try XCTUnwrap(relaunchedContext.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(reloadedProfile.adaptivePlanState?.acceptedSteps.count, 1)

        let reverted = try relaunched.revertAppliedProposal(appliedRevisionID: revision.id)
        let revertedContext = ModelContext(ready.container)
        let revertedProfile = try XCTUnwrap(revertedContext.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(revertedProfile.dailyCalorieGoal, originalGoal)
        XCTAssertEqual(revertedProfile.planGoalSourceRawValue, originalSource)
        XCTAssertGreaterThan(reverted.sequence, revision.sequence)
        XCTAssertNotEqual(revertedProfile.adaptivePlanState?.epoch?.id, ready.epochID)
        let revertReplay = try relaunched.revertAppliedProposal(appliedRevisionID: revision.id)
        XCTAssertEqual(revertReplay.id, reverted.id)
    }

    func testDeclineIsStableAndNewerGoalRevisionBlocksStaleApplyAndRevert() throws {
        let declinedFixture = try makeReadyProposalFixture()
        try declinedFixture.coordinator.declinePendingProposal(id: declinedFixture.proposal.id)
        try declinedFixture.coordinator.declinePendingProposal(id: declinedFixture.proposal.id)
        let declinedReplay = try declinedFixture.coordinator.evaluate(
            expectedPlanRevisionID: declinedFixture.profile.currentPlanRevisionID,
            expectedEvidenceRevision: declinedFixture.profile.evidenceRevision
        )
        guard case .cadence = declinedReplay else {
            return XCTFail("Declined identical evidence must not regenerate proposal.")
        }
        XCTAssertEqual(
            declinedFixture.profile.adaptivePlanState?.operations.filter { $0.kind == .decline }.count,
            1
        )
        XCTAssertEqual(declinedFixture.profile.adaptivePlanState?.proposals.last?.lifecycle, .declined)

        let conflictFixture = try makeReadyProposalFixture()
        let staleGoal = conflictFixture.profile.dailyCalorieGoal
        try conflictFixture.coordinator.editManualPlan(
            calories: staleGoal + 11,
            targetWeight: conflictFixture.profile.targetWeight,
            targetDate: conflictFixture.profile.targetDate
        )
        XCTAssertThrowsError(try conflictFixture.coordinator.applyPendingProposal(
            id: conflictFixture.proposal.id,
            expectedPlanRevisionID: conflictFixture.proposal.expectedPlanRevisionID,
            expectedEvidenceRevision: conflictFixture.proposal.expectedEvidenceRevision,
            expectedEvidenceSignature: conflictFixture.proposal.evidenceSignature
        ))
        XCTAssertEqual(conflictFixture.profile.dailyCalorieGoal, staleGoal + 11)

        let appliedFixture = try makeReadyProposalFixture()
        let applied = try appliedFixture.coordinator.applyPendingProposal(
            id: appliedFixture.proposal.id,
            expectedPlanRevisionID: appliedFixture.proposal.expectedPlanRevisionID,
            expectedEvidenceRevision: appliedFixture.proposal.expectedEvidenceRevision,
            expectedEvidenceSignature: appliedFixture.proposal.evidenceSignature
        )
        try appliedFixture.coordinator.editManualPlan(
            calories: 2_111,
            targetWeight: appliedFixture.profile.targetWeight,
            targetDate: appliedFixture.profile.targetDate
        )
        XCTAssertThrowsError(try appliedFixture.coordinator.revertAppliedProposal(appliedRevisionID: applied.id)) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .revertConflict)
        }
        XCTAssertEqual(appliedFixture.profile.dailyCalorieGoal, 2_111)
    }

    func testStaleSignatureAndWeightMutationLeaveGoalAndSupersedePendingTransactionally() throws {
        let ready = try makeReadyProposalFixture()
        let oldGoal = ready.profile.dailyCalorieGoal
        let oldEvidence = ready.profile.evidenceRevision
        let store = WeightMeasurementStore(coordinator: ready.coordinator)
        _ = try store.add(kilograms: 70.2, date: ready.clock.value.addingTimeInterval(-60))

        XCTAssertEqual(ready.profile.evidenceRevision, oldEvidence + 1)
        XCTAssertEqual(ready.profile.adaptivePlanState?.proposals.last?.lifecycle, .superseded)
        XCTAssertThrowsError(try ready.coordinator.applyPendingProposal(
            id: ready.proposal.id,
            expectedPlanRevisionID: ready.proposal.expectedPlanRevisionID,
            expectedEvidenceRevision: ready.proposal.expectedEvidenceRevision,
            expectedEvidenceSignature: ready.proposal.evidenceSignature
        ))
        XCTAssertEqual(ready.profile.dailyCalorieGoal, oldGoal)
    }

    func testApplyRejectsPersistedProposalWhoseGoalNoLongerMatchesFreshEvaluation() throws {
        let ready = try makeReadyProposalFixture()
        let oldGoal = ready.profile.dailyCalorieGoal
        let corruptionContext = ModelContext(ready.container)
        let persisted = try XCTUnwrap(corruptionContext.fetch(FetchDescriptor<UserProfile>()).first)
        let encodedState = try XCTUnwrap(persisted.adaptivePlanData)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedState) as? [String: Any])
        var proposals = try XCTUnwrap(root["proposals"] as? [[String: Any]])
        var pending = try XCTUnwrap(proposals.last)
        pending["proposedGoal"] = ready.proposal.proposedGoal + 100
        proposals[proposals.count - 1] = pending
        root["proposals"] = proposals
        let corruptedData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        let replacement = UserProfile(
            currentWeight: persisted.currentWeight,
            targetWeight: persisted.targetWeight,
            age: persisted.age,
            dailyCalorieGoal: persisted.dailyCalorieGoal,
            targetDate: persisted.targetDate,
            rawPlanGoalSource: persisted.planGoalSourceRawValue,
            calculatedPlanData: persisted.calculatedPlanData,
            adaptivePlanData: corruptedData,
            currentPlanRevisionID: persisted.currentPlanRevisionID,
            currentPlanRevisionSequence: persisted.currentPlanRevisionSequence,
            evidenceRevision: persisted.evidenceRevision,
            nextWeightSequence: persisted.nextWeightSequence
        )
        corruptionContext.delete(persisted)
        corruptionContext.insert(replacement)
        try corruptionContext.save()

        let verification = ModelContext(ready.container)
        let corruptedProfile = try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first)
        let corruptedProposal = try XCTUnwrap(corruptedProfile.adaptivePlanState?.pendingProposal)
        XCTAssertThrowsError(try ready.coordinator.applyPendingProposal(
            id: corruptedProposal.id,
            expectedPlanRevisionID: corruptedProposal.expectedPlanRevisionID,
            expectedEvidenceRevision: corruptedProposal.expectedEvidenceRevision,
            expectedEvidenceSignature: corruptedProposal.evidenceSignature
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .proposalNotCurrent)
        }
        XCTAssertEqual(
            try XCTUnwrap(ModelContext(ready.container).fetch(FetchDescriptor<UserProfile>()).first).dailyCalorieGoal,
            oldGoal
        )
    }

    func testSameDayGoalRevisionSequenceIsStrictlyIncreasing() throws {
        let fixture = try makeFixture()
        let profile = UserProfile()
        fixture.context.insert(profile)
        try fixture.context.save()

        try fixture.coordinator.editManualPlan(calories: 1_800, targetWeight: 68, targetDate: fixture.clock.value)
        try fixture.coordinator.editManualPlan(calories: 1_900, targetWeight: 68, targetDate: fixture.clock.value)

        let verification = ModelContext(fixture.container)
        let persisted = try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first)
        let revisions = try XCTUnwrap(persisted.adaptivePlanState).goalRevisions
        XCTAssertEqual(revisions.map(\.sequence), [1, 2])
        XCTAssertEqual(revisions[0].effectiveDay, revisions[1].effectiveDay)
        XCTAssertEqual(persisted.currentPlanRevisionID, revisions.last?.id)
        XCTAssertEqual(persisted.evidenceRevision, 2)
    }

    func testProfileContextChangeSupersedesPendingAndStartsNoImplicitEpoch() throws {
        let ready = try makeReadyProposalFixture()
        let previousRevision = ready.profile.currentPlanRevisionSequence

        try ready.coordinator.changeProfileContext(age: ready.profile.age + 1)

        let state = try XCTUnwrap(ready.profile.adaptivePlanState)
        XCTAssertEqual(state.proposals.last?.lifecycle, .superseded)
        XCTAssertFalse(state.checkInsEnabled)
        XCTAssertNil(state.supportedScopeConfirmedAt)
        XCTAssertNil(state.epoch)
        XCTAssertEqual(ready.profile.currentPlanRevisionSequence, previousRevision + 1)
    }

    func testCalendarChangeSupersedesPendingAndStartsFreshEpochWithoutOldCadence() throws {
        let ready = try makeReadyProposalFixture()
        let oldEpochID = try XCTUnwrap(ready.profile.adaptivePlanState?.epoch?.id)
        let oldEvidenceRevision = ready.profile.evidenceRevision
        var shiftedCalendar = ready.calendar
        shiftedCalendar.timeZone = TimeZone(secondsFromGMT: 3_600)!
        ready.coordinator.synchronizeCalendar(shiftedCalendar)

        let result = try ready.coordinator.evaluate(
            expectedPlanRevisionID: ready.profile.currentPlanRevisionID,
            expectedEvidenceRevision: oldEvidenceRevision
        )

        guard case .evaluation(.collecting) = result else {
            return XCTFail("Calendar change must start a fresh collecting epoch: \(result)")
        }
        let state = try XCTUnwrap(ready.profile.adaptivePlanState)
        XCTAssertTrue(state.checkInsEnabled)
        XCTAssertNotNil(state.supportedScopeConfirmedAt)
        XCTAssertNotEqual(state.epoch?.id, oldEpochID)
        XCTAssertEqual(state.epoch?.timeZoneIdentifier, shiftedCalendar.timeZone.identifier)
        XCTAssertEqual(state.proposals.last?.lifecycle, .superseded)
        XCTAssertNil(state.lastGenerationDay)
        XCTAssertNil(state.lastGenerationAt)
        XCTAssertNil(state.lastGenerationEvidenceSignature)
        XCTAssertNil(state.lastDecisionDay)
        XCTAssertEqual(ready.profile.evidenceRevision, oldEvidenceRevision + 1)
    }

    func testStaleContextCASCannotOverwriteNewerPlanMutation() throws {
        let ready = try makeReadyProposalFixture()
        let staleContext = ModelContext(ready.container)
        let staleProfile = try XCTUnwrap(staleContext.fetch(FetchDescriptor<UserProfile>()).first)
        let staleRevisionID = staleProfile.currentPlanRevisionID
        let staleEvidenceRevision = staleProfile.evidenceRevision

        try ready.coordinator.editManualPlan(
            calories: 2_111,
            targetWeight: ready.profile.targetWeight,
            targetDate: ready.profile.targetDate
        )

        XCTAssertThrowsError(try ready.coordinator.evaluate(
            expectedPlanRevisionID: staleRevisionID,
            expectedEvidenceRevision: staleEvidenceRevision
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .compareAndSetFailed)
        }
        let verification = ModelContext(ready.container)
        let persisted = try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(persisted.dailyCalorieGoal, 2_111)
        XCTAssertEqual(persisted.planGoalSource, .manual)
    }

    func testAdaptiveSchemaMismatchFailsClosedBeforeMigrationMutation() throws {
        let fixture = try makeFixture()
        var invalid = AdaptivePlanPersistenceState()
        invalid.schemaVersion = AdaptivePlanPersistenceState.schemaVersion + 1
        let profile = UserProfile(adaptivePlanData: try AdaptivePlanPersistenceCoding.encode(invalid))
        let plate = PlateEntry(foodName: "Legacy", calories: 10, weightGrams: 1, quantity: 1, stableID: .zero)
        fixture.context.insert(profile)
        fixture.context.insert(plate)
        try fixture.context.save()

        XCTAssertThrowsError(try fixture.coordinator.validateAndBackfillStableIdentities()) { error in
            XCTAssertEqual(
                error as? PlanEvidenceMutationError,
                .unsupportedAdaptiveSchema(AdaptivePlanPersistenceState.schemaVersion + 1)
            )
        }
        XCTAssertEqual(plate.stableID, .zero)
        XCTAssertEqual(profile.adaptivePlanSchemaVersion, AdaptivePlanPersistenceState.schemaVersion + 1)
        XCTAssertFalse(try XCTUnwrap(AdaptivePlanPersistenceCoding.decodeUnvalidated(profile.adaptivePlanData)).identityMigrationCompleted)
    }

    func testFileBackedIdentityMigrationSurvivesCloseReopenAndReplaysIdempotently() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdaptiveMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("adaptive.store")
        let schema = Schema([PlateEntry.self, WeightEntry.self, UserProfile.self, FoodLogCompletion.self])
        var migratedPlateID: UUID?
        var migratedWeightID: UUID?

        do {
            let container = try makeFileContainer(schema: schema, url: storeURL)
            let setup = ModelContext(container)
            setup.insert(UserProfile(dailyCalorieGoal: 1_923))
            setup.insert(PlateEntry(
                foodName: "Legacy",
                calories: 300,
                weightGrams: 1,
                quantity: 1,
                stableID: .zero
            ))
            setup.insert(WeightEntry(
                date: date(2026, 1, 1, hour: 8),
                kilograms: 70,
                stableID: .zero,
                sequence: 17
            ))
            try setup.save()

            let coordinator = PlanEvidenceMutationCoordinator(modelContainer: container)
            let first = try coordinator.validateAndBackfillStableIdentities()
            let replay = try coordinator.validateAndBackfillStableIdentities()
            XCTAssertEqual(first.backfilledPlateIDs, 1)
            XCTAssertEqual(first.backfilledWeightIDs, 1)
            XCTAssertEqual(replay.backfilledPlateIDs, 0)
            XCTAssertEqual(replay.backfilledWeightIDs, 0)

            let verification = ModelContext(container)
            migratedPlateID = try XCTUnwrap(verification.fetch(FetchDescriptor<PlateEntry>()).first).stableID
            let weight = try XCTUnwrap(verification.fetch(FetchDescriptor<WeightEntry>()).first)
            migratedWeightID = weight.stableID
            XCTAssertEqual(weight.sequence, 17)
            XCTAssertTrue(try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first).adaptivePlanState?.identityMigrationCompleted == true)
        }

        do {
            let reopened = try makeFileContainer(schema: schema, url: storeURL)
            let context = ModelContext(reopened)
            XCTAssertEqual(try context.fetch(FetchDescriptor<PlateEntry>()).first?.stableID, migratedPlateID)
            XCTAssertEqual(try context.fetch(FetchDescriptor<WeightEntry>()).first?.stableID, migratedWeightID)
            XCTAssertEqual(try context.fetch(FetchDescriptor<WeightEntry>()).first?.sequence, 17)
            XCTAssertTrue(try XCTUnwrap(context.fetch(FetchDescriptor<UserProfile>()).first).adaptivePlanState?.identityMigrationCompleted == true)

            let replay = try PlanEvidenceMutationCoordinator(modelContainer: reopened)
                .validateAndBackfillStableIdentities()
            XCTAssertEqual(replay.backfilledPlateIDs, 0)
            XCTAssertEqual(replay.backfilledWeightIDs, 0)
        }
    }

    func testIdentityMigrationFlagSaveFailureStaysDisabledUntilVerifiedRetry() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        fixture.context.insert(PlateEntry(
            foodName: "Legacy",
            calories: 1,
            weightGrams: 1,
            quantity: 1,
            stableID: .zero
        ))
        try fixture.context.save()
        let failing = PlanEvidenceMutationCoordinator(
            modelContainer: fixture.container,
            calendar: fixture.calendar,
            now: { fixture.clock.value },
            beforeSave: { phase in
                if phase == .identityMigrationFlag { throw InjectedFailure.save }
            }
        )

        XCTAssertThrowsError(try failing.validateAndBackfillStableIdentities())
        let failedStateContext = ModelContext(fixture.container)
        let backfilled = try XCTUnwrap(failedStateContext.fetch(FetchDescriptor<PlateEntry>()).first)
        XCTAssertNotEqual(backfilled.stableID, .zero)
        XCTAssertFalse(try XCTUnwrap(failedStateContext.fetch(FetchDescriptor<UserProfile>()).first).adaptivePlanState?.identityMigrationCompleted == true)

        let retry = PlanEvidenceMutationCoordinator(
            modelContainer: fixture.container,
            calendar: fixture.calendar,
            now: { fixture.clock.value }
        )
        let result = try retry.validateAndBackfillStableIdentities()
        XCTAssertEqual(result.backfilledPlateIDs, 0)
        let verified = ModelContext(fixture.container)
        XCTAssertTrue(try XCTUnwrap(verified.fetch(FetchDescriptor<UserProfile>()).first).adaptivePlanState?.identityMigrationCompleted == true)
    }

    func testInjectedMutationSaveFailureRollsBackPlanAtomically() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile(dailyCalorieGoal: 1_700))
        try fixture.context.save()
        let failing = PlanEvidenceMutationCoordinator(
            modelContainer: fixture.container,
            calendar: fixture.calendar,
            now: { fixture.clock.value },
            beforeSave: { phase in
                if phase == .mutation { throw InjectedFailure.save }
            }
        )

        XCTAssertThrowsError(try failing.editManualPlan(
            calories: 1_900,
            targetWeight: 68,
            targetDate: fixture.clock.value
        ))
        let verification = ModelContext(fixture.container)
        let persisted = try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(persisted.dailyCalorieGoal, 1_700)
        XCTAssertEqual(persisted.evidenceRevision, 0)
        XCTAssertNil(persisted.adaptivePlanData)
    }

    func testInjectedApplySaveFailureKeepsGoalAndProposalPending() throws {
        let ready = try makeReadyProposalFixture()
        let oldGoal = ready.profile.dailyCalorieGoal
        let failing = PlanEvidenceMutationCoordinator(
            modelContainer: ready.container,
            calendar: ready.calendar,
            now: { ready.clock.value },
            beforeSave: { phase in
                if phase == .mutation { throw InjectedFailure.save }
            }
        )

        XCTAssertThrowsError(try failing.applyPendingProposal(
            id: ready.proposal.id,
            expectedPlanRevisionID: ready.proposal.expectedPlanRevisionID,
            expectedEvidenceRevision: ready.proposal.expectedEvidenceRevision,
            expectedEvidenceSignature: ready.proposal.evidenceSignature
        ))
        let verification = ModelContext(ready.container)
        let persisted = try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(persisted.dailyCalorieGoal, oldGoal)
        XCTAssertEqual(persisted.planGoalSource, .calculated)
        XCTAssertEqual(persisted.adaptivePlanState?.pendingProposal?.id, ready.proposal.id)
        XCTAssertTrue(persisted.adaptivePlanState?.operations.contains(where: { $0.kind == .apply }) == false)
    }

    func testIdentityGenerationFailureCommitsNeitherBackfillNorMigrationFlag() throws {
        let firstID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        var calls = 0
        let fixture = try makeFixture(makeUUID: {
            calls += 1
            return calls == 1 ? firstID : .zero
        })
        let profile = UserProfile()
        let first = PlateEntry(foodName: "A", calories: 1, weightGrams: 1, quantity: 1, stableID: .zero)
        let second = PlateEntry(foodName: "B", calories: 1, weightGrams: 1, quantity: 1, stableID: .zero)
        fixture.context.insert(profile)
        fixture.context.insert(first)
        fixture.context.insert(second)
        try fixture.context.save()

        XCTAssertThrowsError(try fixture.coordinator.validateAndBackfillStableIdentities()) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .identityVerificationFailed)
        }
        XCTAssertEqual(first.stableID, .zero)
        XCTAssertEqual(second.stableID, .zero)
        XCTAssertNil(profile.adaptivePlanData)
    }

    func testOverlappingTasksReplayOneGenerationApplyAndRevert() async throws {
        let ready = try makeReadyProposalFixture()
        let expectedRevisionID = ready.profile.currentPlanRevisionID
        let expectedEvidenceRevision = ready.profile.evidenceRevision

        let generationTaskA = Task { @MainActor in
            try ready.coordinator.evaluate(
                expectedPlanRevisionID: expectedRevisionID,
                expectedEvidenceRevision: expectedEvidenceRevision
            )
        }
        let generationTaskB = Task { @MainActor in
            try ready.coordinator.evaluate(
                expectedPlanRevisionID: expectedRevisionID,
                expectedEvidenceRevision: expectedEvidenceRevision
            )
        }
        let firstGeneration = try await generationTaskA.value
        let secondGeneration = try await generationTaskB.value
        guard case .pending(let firstProposal) = firstGeneration,
              case .pending(let secondProposal) = secondGeneration else {
            return XCTFail("Overlapping generation calls must replay pending result.")
        }
        XCTAssertEqual(firstProposal.id, secondProposal.id)

        let applyTaskA = Task { @MainActor in
            try ready.coordinator.applyPendingProposal(
                id: firstProposal.id,
                expectedPlanRevisionID: firstProposal.expectedPlanRevisionID,
                expectedEvidenceRevision: firstProposal.expectedEvidenceRevision,
                expectedEvidenceSignature: firstProposal.evidenceSignature
            )
        }
        let applyTaskB = Task { @MainActor in
            try ready.coordinator.applyPendingProposal(
                id: secondProposal.id,
                expectedPlanRevisionID: secondProposal.expectedPlanRevisionID,
                expectedEvidenceRevision: secondProposal.expectedEvidenceRevision,
                expectedEvidenceSignature: secondProposal.evidenceSignature
            )
        }
        let firstRevision = try await applyTaskA.value
        let secondRevision = try await applyTaskB.value
        XCTAssertEqual(firstRevision.id, secondRevision.id)

        let revertTaskA = Task { @MainActor in
            try ready.coordinator.revertAppliedProposal(appliedRevisionID: firstRevision.id)
        }
        let revertTaskB = Task { @MainActor in
            try ready.coordinator.revertAppliedProposal(appliedRevisionID: firstRevision.id)
        }
        let firstRevert = try await revertTaskA.value
        let secondRevert = try await revertTaskB.value
        XCTAssertEqual(firstRevert.id, secondRevert.id)

        let verificationContext = ModelContext(ready.container)
        let persisted = try XCTUnwrap(verificationContext.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(persisted.adaptivePlanState?.proposals.count, 1)
        XCTAssertEqual(persisted.adaptivePlanState?.operations.filter { $0.kind == .generation }.count, 1)
        XCTAssertEqual(persisted.adaptivePlanState?.operations.filter { $0.kind == .apply }.count, 1)
        XCTAssertEqual(persisted.adaptivePlanState?.operations.filter { $0.kind == .revert }.count, 1)
        XCTAssertEqual(persisted.adaptivePlanState?.goalRevisions.filter { $0.reason == "adaptive-proposal-applied" }.count, 1)
        XCTAssertEqual(persisted.adaptivePlanState?.goalRevisions.filter { $0.reason == "adaptive-proposal-reverted" }.count, 1)
    }

    func testSupersededGenerationWaitsSevenLocalDaysAndFreshCivilEvidence() throws {
        let ready = try makeReadyProposalFixture()
        let generationDay = try XCTUnwrap(ready.profile.adaptivePlanState?.lastGenerationDay)
        XCTAssertEqual(ready.profile.adaptivePlanState?.lastGenerationAt, ready.proposal.createdAt)

        for offset in 0...7 {
            let day = try XCTUnwrap(ready.calendar.date(byAdding: .day, value: offset, to: generationDay))
            ready.clock.value = day.addingTimeInterval(20 * 3_600)
            try ready.coordinator.insertPlate(PlateEntry(
                foodName: "Fresh day",
                calories: 2_000,
                weightGrams: 1,
                quantity: 1,
                date: day.addingTimeInterval(12 * 3_600)
            ))
            _ = try ready.coordinator.addWeightMeasurement(
                kilograms: 70,
                date: day.addingTimeInterval(8 * 3_600)
            )
            _ = try ready.coordinator.markFoodLogComplete(for: day)
            if offset == 6 {
                let cadence = try ready.coordinator.evaluate(
                    expectedPlanRevisionID: ready.profile.currentPlanRevisionID,
                    expectedEvidenceRevision: ready.profile.evidenceRevision
                )
                guard case .cadence = cadence else {
                    return XCTFail("Generation must remain held before seven fresh civil days: \(cadence)")
                }
                XCTAssertEqual(ready.profile.adaptivePlanState?.proposals.count, 1)
            }
        }

        ready.clock.value = try XCTUnwrap(ready.calendar.date(byAdding: .day, value: 8, to: generationDay))
            .addingTimeInterval(12 * 3_600)
        let regenerated = try ready.coordinator.evaluate(
            expectedPlanRevisionID: ready.profile.currentPlanRevisionID,
            expectedEvidenceRevision: ready.profile.evidenceRevision
        )
        guard case .pending = regenerated else {
            return XCTFail("Seven post-generation civil days plus newer weights must permit new generation: \(regenerated)")
        }
        XCTAssertEqual(ready.profile.adaptivePlanState?.proposals.count, 2)
    }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let coordinator: PlanEvidenceMutationCoordinator
        let calendar: Calendar
        let clock: Clock
    }

    private struct ReadyFixture {
        let container: ModelContainer
        let context: ModelContext
        let coordinator: PlanEvidenceMutationCoordinator
        let calendar: Calendar
        let clock: Clock
        let profile: UserProfile
        let proposal: AdaptivePlanProposalRecord
        let calculatedPlanData: Data?
        let epochID: UUID
    }

    private func makeFixture(
        now: Date? = nil,
        makeUUID: @escaping () -> UUID = { UUID() }
    ) throws -> Fixture {
        let now = now ?? date(2026, 1, 1, hour: 12)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let clock = Clock(now)
        let schema = Schema([
            PlateEntry.self,
            WeightEntry.self,
            UserProfile.self,
            FoodLogCompletion.self,
            HistoricalPlateDeletionOperation.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        let coordinator = PlanEvidenceMutationCoordinator(
            modelContainer: container,
            calendar: calendar,
            now: { clock.value },
            makeUUID: makeUUID
        )
        return Fixture(container: container, context: context, coordinator: coordinator, calendar: calendar, clock: clock)
    }

    private func makeFileContainer(schema: Schema, url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "AdaptiveMigration",
            schema: schema,
            url: url,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeReadyProposalFixture() throws -> ReadyFixture {
        let start = date(2026, 1, 1, hour: 7)
        let fixture = try makeFixture(now: start)
        let calculated = try plan(calendar: fixture.calendar)
        let profile = try fixture.coordinator.acceptCalculatedPlan(
            calculated,
            measurementSystem: .metric,
            acceptedAt: start
        )
        XCTAssertThrowsError(
            try fixture.coordinator.enableAdaptiveCheckIns(supportedScopeConfirmed: false)
        ) { error in
            XCTAssertEqual(
                error as? PlanEvidenceMutationError,
                .supportedScopeConfirmationRequired
            )
        }
        let epoch = try fixture.coordinator.enableAdaptiveCheckIns(supportedScopeConfirmed: true)

        for offset in 0..<42 {
            let day = try XCTUnwrap(fixture.calendar.date(byAdding: .day, value: offset, to: epoch.startDay))
            fixture.clock.value = day.addingTimeInterval(20 * 3_600)
            try fixture.coordinator.insertPlate(PlateEntry(
                foodName: "Complete day",
                calories: 2_000,
                weightGrams: 1,
                quantity: 1,
                date: day.addingTimeInterval(12 * 3_600)
            ))
            _ = try fixture.coordinator.addWeightMeasurement(
                kilograms: 70,
                date: day.addingTimeInterval(8 * 3_600)
            )
            _ = try fixture.coordinator.markFoodLogComplete(for: day)
            if offset == 40 {
                fixture.clock.value = try XCTUnwrap(fixture.calendar.date(
                    byAdding: .day,
                    value: 41,
                    to: epoch.startDay
                )).addingTimeInterval(12 * 3_600)
                let collecting = try fixture.coordinator.evaluate(
                    expectedPlanRevisionID: profile.currentPlanRevisionID,
                    expectedEvidenceRevision: profile.evidenceRevision
                )
                guard case .evaluation(.collecting) = collecting else {
                    XCTFail("Forty-one complete days must remain collecting: \(collecting)")
                    throw PlanEvidenceMutationError.missingPendingProposal
                }
            }
        }
        fixture.clock.value = try XCTUnwrap(fixture.calendar.date(byAdding: .day, value: 42, to: epoch.startDay))
            .addingTimeInterval(12 * 3_600)

        let expectedRevision = profile.currentPlanRevisionID
        let expectedEvidence = profile.evidenceRevision
        let result = try fixture.coordinator.evaluate(
            expectedPlanRevisionID: expectedRevision,
            expectedEvidenceRevision: expectedEvidence
        )
        guard case .pending(let proposal) = result else {
            XCTFail("Forty-two complete days and distributed weights must generate pending proposal: \(result)")
            throw PlanEvidenceMutationError.missingPendingProposal
        }
        return ReadyFixture(
            container: fixture.container,
            context: fixture.context,
            coordinator: fixture.coordinator,
            calendar: fixture.calendar,
            clock: fixture.clock,
            profile: profile,
            proposal: proposal,
            calculatedPlanData: profile.calculatedPlanData,
            epochID: epoch.id
        )
    }

    private func plan(calendar: Calendar) throws -> CalculatedCaloriePlan {
        let input = CaloriePlanInput(
            goalMode: .maintain,
            currentWeightKilograms: 70,
            targetWeightKilograms: 70,
            age: 30,
            heightCentimeters: 170,
            equation: .female,
            activityLevel: .low,
            paceBasis: .weeklyRate,
            weeklyRateKilograms: 0.25,
            targetDate: nil
        )
        guard case .recommendation(let plan) = CalculatedCaloriePlanCalculator.evaluate(
            input,
            now: date(2026, 1, 1, hour: 7),
            calendar: calendar
        ) else {
            throw PlanEvidenceMutationError.unsupportedSource
        }
        return plan
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        Self.date(year, month, day, hour: hour)
    }
}
#endif
