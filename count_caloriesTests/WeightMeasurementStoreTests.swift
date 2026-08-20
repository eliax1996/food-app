#if !SWIFT_PACKAGE
import Foundation
import SwiftData
import XCTest
@testable import count_calories

@MainActor
final class WeightMeasurementStoreTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testAddingTwoSameDayMeasurementsPreservesBoth() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        let morning = now.addingTimeInterval(-7_200)
        let afternoon = now.addingTimeInterval(-3_600)

        try store.add(kilograms: 70, date: morning)
        try store.add(kilograms: 69.5, date: afternoon)

        let savedEntries = try entries(in: context)
        XCTAssertEqual(savedEntries.count, 2, "Adding same-day measurements must not collapse records.")
        XCTAssertEqual(Set(savedEntries.map(\.kilograms)), Set([70, 69.5]), "Both same-day measurement values must persist.")
        XCTAssertEqual(try currentWeight(in: context), 69.5, "Latest same-day measurement must set current weight.")
    }

    func testOverlappingAddsOnEmptyStoreCreateOneProfile() async throws {
        let container = try makeContainer()
        let coordinator = PlanEvidenceMutationCoordinator(
            modelContainer: container,
            now: { self.now }
        )
        let store = WeightMeasurementStore(coordinator: coordinator)

        let first = Task { @MainActor in
            try store.add(kilograms: 70, date: now.addingTimeInterval(-120)).stableID
        }
        let second = Task { @MainActor in
            try store.add(kilograms: 71, date: now.addingTimeInterval(-60)).stableID
        }
        _ = try await first.value
        _ = try await second.value

        let verification = ModelContext(container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<UserProfile>()).count, 1)
        let saved = try verification.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(Set(saved.map(\.sequence)), Set([1, 2]))
    }

    func testBackdatedAddDoesNotReplaceCurrentWeight() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        try store.add(kilograms: 69, date: now.addingTimeInterval(-3_600))

        try store.add(kilograms: 72, date: now.addingTimeInterval(-86_400))

        XCTAssertEqual(try entries(in: context).count, 2, "Backdated add must persist alongside latest measurement.")
        XCTAssertEqual(try currentWeight(in: context), 69, "Backdated add must not replace newer current weight.")
    }

    func testUpdatingOneMeasurementChangesOnlyThatMeasurementAndCanReorderCurrentWeight() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        let older = try store.add(kilograms: 70, date: now.addingTimeInterval(-7_200))
        let newer = try store.add(kilograms: 69, date: now.addingTimeInterval(-3_600))

        try store.update(older, kilograms: 68, date: now.addingTimeInterval(-1_800))

        XCTAssertEqual(older.kilograms, 68, "Updated measurement must contain requested weight.")
        XCTAssertEqual(older.date, now.addingTimeInterval(-1_800), "Updated measurement must contain requested timestamp.")
        XCTAssertEqual(newer.kilograms, 69, "Updating one measurement must not alter another measurement weight.")
        XCTAssertEqual(newer.date, now.addingTimeInterval(-3_600), "Updating one measurement must not alter another measurement timestamp.")
        XCTAssertEqual(try currentWeight(in: context), 68, "Moving measurement latest must reorder current weight.")
    }

    func testDeletingLatestMeasurementReconcilesPreviousMeasurement() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        _ = try store.add(kilograms: 71, date: now.addingTimeInterval(-7_200))
        let latest = try store.add(kilograms: 69, date: now.addingTimeInterval(-3_600))

        _ = try store.delete(latest)

        XCTAssertEqual(try entries(in: context).count, 1, "Deleting latest measurement must remove only that measurement.")
        XCTAssertEqual(try currentWeight(in: context), 71, "Deleting latest measurement must restore previous current weight.")
    }

    func testDeletingLastMeasurementSetsCurrentWeightToZero() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        let onlyEntry = try store.add(kilograms: 70, date: now.addingTimeInterval(-3_600))

        _ = try store.delete(onlyEntry)

        XCTAssertTrue(try entries(in: context).isEmpty, "Deleting last measurement must leave no entries.")
        XCTAssertEqual(try currentWeight(in: context), 0, "Deleting last valid measurement must cache zero current weight.")
    }

    func testRestoreRecoversExactDateValueAndCurrentWeight() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        _ = try store.add(kilograms: 71, date: now.addingTimeInterval(-7_200))
        let timestamp = now.addingTimeInterval(-3_600)
        let latest = try store.add(kilograms: 69.4, date: timestamp)

        let snapshot = try store.delete(latest)
        let restored = try store.restore(snapshot)

        XCTAssertEqual(snapshot.date, timestamp, "Delete snapshot must retain exact measurement date for undo.")
        XCTAssertEqual(snapshot.kilograms, 69.4, "Delete snapshot must retain exact measurement weight for undo.")
        XCTAssertEqual(restored.date, timestamp, "Restore must retain snapshot timestamp exactly.")
        XCTAssertEqual(restored.kilograms, 69.4, "Restore must retain snapshot weight exactly.")
        XCTAssertEqual(restored.stableID, snapshot.stableID, "Restore must retain stable ID exactly.")
        XCTAssertEqual(restored.sequence, snapshot.sequence, "Restore must retain sequence exactly.")
        XCTAssertEqual(try entries(in: context).count, 2, "Restore must recreate deleted measurement without losing other records.")
        XCTAssertEqual(try currentWeight(in: context), 69.4, "Restored latest measurement must become current weight.")
    }

    func testSameTimestampOrderingAgreesAcrossProfileAndReload() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = makeStore(for: context)
        let timestamp = now.addingTimeInterval(-3_600)
        let first = try store.add(kilograms: 70, date: timestamp)
        let second = try store.add(kilograms: 72, date: timestamp)

        XCTAssertLessThan(first.sequence, second.sequence)
        XCTAssertEqual(try currentWeight(in: context), 72)
        XCTAssertEqual(
            ProgressHistory.weightProgress(
                entries: try entries(in: context).map {
                    WeightProgressPoint(date: $0.date, kilograms: $0.kilograms, stableID: $0.stableID, sequence: $0.sequence)
                },
                targetWeight: nil
            ).current,
            72
        )

        let reloadedContext = ModelContext(container)
        let reloadedEntries = try entries(in: reloadedContext)
        XCTAssertEqual(reloadedEntries.count, 2, "Duplicate raw rows must survive reload.")
        XCTAssertEqual(try currentWeight(in: reloadedContext), 72)
        XCTAssertEqual(
            ProgressHistory.weightProgress(
                entries: reloadedEntries.map {
                    WeightProgressPoint(date: $0.date, kilograms: $0.kilograms, stableID: $0.stableID, sequence: $0.sequence)
                },
                targetWeight: nil
            ).current,
            72
        )
    }

    func testUpdateAndUndoPreserveOrderingMetadataAndCurrentWeight() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        let timestamp = now.addingTimeInterval(-3_600)
        let first = try store.add(kilograms: 70, date: timestamp)
        _ = try store.add(kilograms: 72, date: timestamp)

        try store.update(first, kilograms: 69, date: timestamp)
        XCTAssertEqual(try currentWeight(in: context), 69)
        let snapshot = try store.delete(first)
        let restored = try store.restore(snapshot)

        XCTAssertEqual(restored.stableID, snapshot.stableID)
        XCTAssertEqual(restored.sequence, snapshot.sequence)
        XCTAssertEqual(try currentWeight(in: context), 69)
    }

    func testSequenceDoesNotReuseDeletedValue() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        let first = try store.add(kilograms: 70, date: now.addingTimeInterval(-2))
        let second = try store.add(kilograms: 71, date: now.addingTimeInterval(-1))

        _ = try store.delete(second)
        let replacement = try store.add(kilograms: 72, date: now.addingTimeInterval(-1))

        XCTAssertEqual(first.sequence, 1)
        XCTAssertEqual(second.sequence, 2)
        XCTAssertEqual(replacement.sequence, 3)
    }

    func testSequenceOverflowIsRejectedBeforeInsertion() throws {
        let context = try makeContext()
        context.insert(WeightEntry(date: now.addingTimeInterval(-1), kilograms: 70, sequence: .max))
        try context.save()
        let store = makeStore(for: context)

        XCTAssertThrowsError(try store.add(kilograms: 71, date: now.addingTimeInterval(-2))) { error in
            XCTAssertEqual(error as? WeightHistoryError, .sequenceOverflow)
        }
        XCTAssertEqual(try entries(in: context).count, 1)
    }

    func testFutureAndInvalidAddOrUpdateRejectWithoutPartialPersistence() throws {
        let context = try makeContext()
        let store = makeStore(for: context)
        let timestamp = now.addingTimeInterval(-3_600)
        let entry = try store.add(kilograms: 70, date: timestamp)

        XCTAssertThrowsError(try store.add(kilograms: 0, date: timestamp), "Invalid add must fail before insertion.") { error in
            XCTAssertEqual(error as? WeightHistoryError, .invalidWeight, "Invalid add must report invalid weight.")
        }
        XCTAssertThrowsError(try store.add(kilograms: 71, date: now.addingTimeInterval(1)), "Future add must fail before insertion.") { error in
            XCTAssertEqual(error as? WeightHistoryError, .futureTimestamp, "Future add must report future timestamp.")
        }
        XCTAssertThrowsError(try store.update(entry, kilograms: .infinity, date: timestamp), "Invalid update must fail before mutation.") { error in
            XCTAssertEqual(error as? WeightHistoryError, .invalidWeight, "Invalid update must report invalid weight.")
        }
        XCTAssertThrowsError(try store.update(entry, kilograms: 68, date: now.addingTimeInterval(1)), "Future update must fail before mutation.") { error in
            XCTAssertEqual(error as? WeightHistoryError, .futureTimestamp, "Future update must report future timestamp.")
        }

        let savedEntries = try entries(in: context)
        XCTAssertEqual(savedEntries.count, 1, "Rejected add operations must not persist partial entries.")
        XCTAssertEqual(savedEntries.first?.kilograms, 70, "Rejected update must not alter persisted weight.")
        XCTAssertEqual(savedEntries.first?.date, timestamp, "Rejected update must not alter persisted timestamp.")
        XCTAssertEqual(try currentWeight(in: context), 70, "Rejected mutations must not alter cached current weight.")
    }

    func testAddSynchronizesEveryLegacyProfileFromGlobalSequenceHighWaterMark() throws {
        let context = try makeContext()
        let firstProfile = UserProfile(
            currentWeight: 80,
            targetWeight: 63.5,
            age: 41,
            dailyCalorieGoal: 1_950,
            targetDate: now.addingTimeInterval(86_400 * 120),
            nextWeightSequence: 12
        )
        let secondProfile = UserProfile(
            currentWeight: 55,
            targetWeight: 72,
            age: 29,
            dailyCalorieGoal: 2_300,
            targetDate: now.addingTimeInterval(86_400 * 240),
            nextWeightSequence: 50
        )
        context.insert(firstProfile)
        context.insert(secondProfile)
        context.insert(WeightEntry(
            date: now.addingTimeInterval(-7_200),
            kilograms: 68,
            sequence: 75
        ))
        try context.save()

        let entry = try makeStore(for: context)
            .add(kilograms: 70, date: now.addingTimeInterval(-3_600))

        XCTAssertEqual(entry.sequence, 76)
        let verification = ModelContext(context.container)
        let profiles = try verification.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(profiles.count, 2)
        XCTAssertTrue(profiles.allSatisfy { $0.nextWeightSequence == 76 })
        XCTAssertTrue(profiles.allSatisfy { $0.currentWeight == 70 })
        let persistedFirst = try XCTUnwrap(profiles.first { $0.age == 41 })
        XCTAssertEqual(persistedFirst.targetWeight, 63.5)
        XCTAssertEqual(persistedFirst.dailyCalorieGoal, 1_950)
        XCTAssertEqual(persistedFirst.targetDate, now.addingTimeInterval(86_400 * 120))
        let persistedSecond = try XCTUnwrap(profiles.first { $0.age == 29 })
        XCTAssertEqual(persistedSecond.targetWeight, 72)
        XCTAssertEqual(persistedSecond.dailyCalorieGoal, 2_300)
        XCTAssertEqual(persistedSecond.targetDate, now.addingTimeInterval(86_400 * 240))
    }

    func testUndoRestoresLegacyFutureMeasurementExactlyWithoutChangingCurrentWeight() throws {
        let context = try makeContext()
        let past = WeightEntry(
            date: now.addingTimeInterval(-3_600),
            kilograms: 70,
            stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sequence: 3
        )
        let future = WeightEntry(
            date: now.addingTimeInterval(3_600),
            kilograms: 72.4,
            stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            sequence: 9
        )
        context.insert(past)
        context.insert(future)
        context.insert(UserProfile(currentWeight: 72.4, nextWeightSequence: 9))
        try context.save()
        let store = makeStore(for: context)

        let snapshot = try store.delete(future)
        XCTAssertEqual(try currentWeight(in: context), 70)

        let restored = try store.restore(snapshot)
        XCTAssertEqual(restored.date, future.date)
        XCTAssertEqual(restored.kilograms, future.kilograms)
        XCTAssertEqual(restored.stableID, future.stableID)
        XCTAssertEqual(restored.sequence, future.sequence)
        XCTAssertEqual(try currentWeight(in: context), 70)
    }

    func testDedicatedMutationContextDoesNotSaveOrRollBackCallerChanges() throws {
        let context = try makeContext()
        context.insert(UserProfile(age: 30))
        try context.save()
        let dirtyFood = Food(name: "Unsaved", calories: 1, servingGrams: 1)
        context.insert(dirtyFood)
        let store = makeStore(for: context)

        _ = try store.add(kilograms: 70, date: now.addingTimeInterval(-60))

        XCTAssertEqual(try entries(in: context).count, 1)
        XCTAssertTrue(context.hasChanges)
        let verification = ModelContext(context.container)
        XCTAssertTrue(try verification.fetch(FetchDescriptor<Food>()).isEmpty)
    }

    func testExistingProfileGoalFieldsRemainUnchanged() throws {
        let context = try makeContext()
        let profile = UserProfile(
            currentWeight: 80,
            targetWeight: 63.5,
            age: 41,
            dailyCalorieGoal: 1_950,
            targetDate: now.addingTimeInterval(86_400 * 120)
        )
        context.insert(profile)
        try context.save()
        let store = makeStore(for: context)

        try store.add(kilograms: 70, date: now.addingTimeInterval(-3_600))

        let verification = ModelContext(context.container)
        let savedProfiles = try verification.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(savedProfiles.count, 1, "Existing profile must be updated instead of duplicated.")
        let persisted = try XCTUnwrap(savedProfiles.first)
        XCTAssertEqual(persisted.currentWeight, 70, "Store must reconcile current weight on existing profile.")
        XCTAssertEqual(persisted.targetWeight, 63.5, "Reconciling current weight must preserve target weight.")
        XCTAssertEqual(persisted.age, 41, "Reconciling current weight must preserve age.")
        XCTAssertEqual(persisted.dailyCalorieGoal, 1_950, "Reconciling current weight must preserve calorie goal.")
        XCTAssertEqual(persisted.targetDate, now.addingTimeInterval(86_400 * 120), "Reconciling current weight must preserve target date.")
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try makeContainer())
    }

    private func makeStore(for context: ModelContext) -> WeightMeasurementStore {
        WeightMeasurementStore(coordinator: PlanEvidenceMutationCoordinator(
            modelContainer: context.container,
            now: { self.now }
        ))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = AppModelSchema.make()
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    private func entries(in context: ModelContext) throws -> [WeightEntry] {
        try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))
    }

    private func currentWeight(in context: ModelContext) throws -> Double {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        return try XCTUnwrap(profiles.first, "Mutation must create or retain a profile.").currentWeight
    }
}
#endif
