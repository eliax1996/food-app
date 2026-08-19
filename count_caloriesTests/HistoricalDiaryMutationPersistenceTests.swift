#if !SWIFT_PACKAGE
import Foundation
import SwiftData
import XCTest
@testable import count_calories

@MainActor
final class HistoricalDiaryMutationPersistenceTests: XCTestCase {
    private enum InjectedFailure: Error { case save }

    private final class Clock {
        var value: Date
        init(_ value: Date) { self.value = value }
    }

    func testCreateSnapshotsSavedFoodRejectsFutureAndRequiresDuplicateConfirmation() throws {
        let fixture = try makeFixture()
        let foodID = UUID()
        fixture.context.insert(Food(
            name: "Oat Drink",
            calories: 100,
            stableID: foodID,
            servingGrams: 250,
            servingUnit: .milliliters,
            nutrientsPerServing: FoodNutrients(
                carbohydratesGrams: 12,
                proteinGrams: 3,
                fatGrams: 4,
                fiberGrams: 1
            )
        ))
        try fixture.context.save()
        let timestamp = fixture.clock.value.addingTimeInterval(-3_600)

        let created = try fixture.coordinator.createHistoricalPlate(
            foodStableID: foodID,
            amount: 250,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: timestamp
        )

        XCTAssertEqual(created.foodName, "Oat Drink")
        XCTAssertEqual(created.calories, 100)
        XCTAssertEqual(created.loggedAmount, 250)
        XCTAssertEqual(created.servingUnitRawValue, "ml")
        XCTAssertEqual(created.nutrients.proteinGrams, 3)
        XCTAssertTrue(created.isKnownItem)

        XCTAssertThrowsError(try fixture.coordinator.createHistoricalPlate(
            foodStableID: foodID,
            amount: 250,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: timestamp.addingTimeInterval(300)
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .duplicateHistoricalEntry)
        }
        let duplicate = try fixture.coordinator.createHistoricalPlate(
            foodStableID: foodID,
            amount: 250,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: timestamp.addingTimeInterval(300),
            allowDuplicate: true
        )
        XCTAssertNotEqual(duplicate.stableID, created.stableID)

        XCTAssertThrowsError(try fixture.coordinator.createHistoricalPlate(
            foodStableID: foodID,
            amount: 250,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: fixture.clock.value.addingTimeInterval(1)
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .invalidHistoricalMutation)
        }
    }

    func testMetadataEditScalesSnapshotAndStalesFullAttestation() throws {
        let fixture = try makeFixture()
        let timestamp = fixture.clock.value.addingTimeInterval(-3_600)
        let plate = PlateEntry(
            foodName: "Milk",
            calories: 100,
            weightGrams: 250,
            quantity: 1,
            servingUnit: .milliliters,
            nutrients: FoodNutrients(proteinGrams: 8),
            mealType: MealType.breakfast.rawValue,
            date: timestamp
        )
        try fixture.coordinator.insertPlate(plate)
        let completion = try fixture.coordinator.markFoodLogComplete(for: timestamp)
        let persistedBeforeEdit = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).first { $0.stableID == plate.stableID }
        )
        XCTAssertEqual(completion.evidenceSchemaVersion, 2)
        XCTAssertEqual(completion.plateSnapshot?.first?.foodName, "Milk")
        XCTAssertEqual(completion.plateSnapshot?.first?.loggedAmountBitPattern, 250.0.bitPattern)
        XCTAssertEqual(completion.plateSnapshot?.first?.loggedCalorieDensityBitPattern, 0.4.bitPattern)
        let revisionBefore = currentEvidenceRevision(fixture)

        let edited = try fixture.coordinator.updateHistoricalPlate(
            stableID: plate.stableID,
            expectedModifiedAt: persistedBeforeEdit.modifiedAt,
            amount: 375,
            portionCount: 1,
            mealType: MealType.lunch.rawValue,
            date: timestamp
        )

        XCTAssertEqual(edited.calories, 150)
        XCTAssertEqual(edited.loggedAmount, 375)
        XCTAssertEqual(edited.nutrients.proteinGrams ?? -1, 12, accuracy: 0.000_001)
        let verification = ModelContext(fixture.container)
        XCTAssertTrue(try XCTUnwrap(verification.fetch(FetchDescriptor<FoodLogCompletion>()).first).isStale)
        XCTAssertEqual(currentEvidenceRevision(fixture), revisionBefore + 1)
    }

    func testDateMoveStalesBothDaysAndStaleEditorFailsClosed() throws {
        let fixture = try makeFixture()
        let today = fixture.calendar.startOfDay(for: fixture.clock.value)
        let yesterday = try XCTUnwrap(fixture.calendar.date(byAdding: .day, value: -1, to: today))
        let source = PlateEntry(
            foodName: "Rice",
            calories: 200,
            weightGrams: 100,
            quantity: 1,
            nutrients: FoodNutrients(carbohydratesGrams: 45),
            mealType: MealType.dinner.rawValue,
            date: yesterday.addingTimeInterval(18 * 3_600)
        )
        let destination = PlateEntry(
            foodName: "Apple",
            calories: 80,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.snack.rawValue,
            date: today.addingTimeInterval(8 * 3_600)
        )
        try fixture.coordinator.insertPlate(source)
        try fixture.coordinator.insertPlate(destination)
        _ = try fixture.coordinator.markFoodLogComplete(for: yesterday)
        _ = try fixture.coordinator.markFoodLogComplete(for: today)
        let expectedModifiedAt = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).first { $0.stableID == source.stableID }
        ).modifiedAt

        let moved = try fixture.coordinator.updateHistoricalPlate(
            stableID: source.stableID,
            expectedModifiedAt: expectedModifiedAt,
            amount: 100,
            portionCount: 1,
            mealType: MealType.lunch.rawValue,
            date: today.addingTimeInterval(10 * 3_600)
        )
        XCTAssertEqual(fixture.calendar.startOfDay(for: moved.date), today)

        let completions = try ModelContext(fixture.container).fetch(FetchDescriptor<FoodLogCompletion>())
        XCTAssertEqual(completions.count, 2)
        XCTAssertTrue(completions.allSatisfy(\.isStale))
        XCTAssertThrowsError(try fixture.coordinator.updateHistoricalPlate(
            stableID: source.stableID,
            expectedModifiedAt: expectedModifiedAt,
            amount: 110,
            portionCount: 1,
            mealType: MealType.lunch.rawValue,
            date: moved.date
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .historicalMutationUnavailable)
        }
        XCTAssertThrowsError(try fixture.coordinator.copyHistoricalPlate(
            stableID: source.stableID,
            expectedModifiedAt: expectedModifiedAt,
            to: today.addingTimeInterval(11 * 3_600),
            mealType: MealType.lunch.rawValue
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .compareAndSetFailed)
        }
        XCTAssertThrowsError(try fixture.coordinator.deleteHistoricalPlate(
            stableID: source.stableID,
            expectedModifiedAt: expectedModifiedAt
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .compareAndSetFailed)
        }
        XCTAssertNotNil(
            try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>())
                .first { $0.stableID == source.stableID }
        )
    }

    func testCopyPreservesSnapshotAndDeleteUndoRestoresExactLegacyRow() throws {
        let fixture = try makeFixture()
        let today = fixture.calendar.startOfDay(for: fixture.clock.value)
        let yesterday = try XCTUnwrap(fixture.calendar.date(byAdding: .day, value: -1, to: today))
        let source = PlateEntry(
            foodName: "Soup",
            calories: 240,
            weightGrams: 350,
            quantity: 1.5,
            servingUnit: .milliliters,
            nutrients: FoodNutrients(
                carbohydratesGrams: 20,
                proteinGrams: 12,
                fatGrams: 8,
                fiberGrams: nil
            ),
            mealType: MealType.lunch.rawValue,
            date: yesterday.addingTimeInterval(12 * 3_600)
        )
        try fixture.coordinator.insertPlate(source)
        let copied = try fixture.coordinator.copyHistoricalPlate(
            stableID: source.stableID,
            expectedModifiedAt: source.modifiedAt,
            to: today.addingTimeInterval(12 * 3_600),
            mealType: MealType.dinner.rawValue
        )
        XCTAssertNotEqual(copied.stableID, source.stableID)
        XCTAssertEqual(copied.foodName, source.foodName)
        XCTAssertEqual(copied.calories, source.calories)
        XCTAssertEqual(copied.loggedAmount, source.loggedAmount)
        XCTAssertEqual(copied.portionCount, source.portionQuantity)
        XCTAssertEqual(copied.servingUnitRawValue, "ml")
        XCTAssertEqual(copied.nutrients, source.nutrients)
        XCTAssertEqual(copied.mealType, MealType.dinner.rawValue)

        let legacyID = UUID()
        let legacy = PlateEntry(
            foodName: "Recorded meals",
            calories: Int.max,
            weightGrams: 42.25,
            quantity: 2.5,
            mealType: nil,
            date: yesterday.addingTimeInterval(9 * 3_600),
            stableID: legacyID,
            loggedSnapshotKind: nil
        )
        legacy.servingUnitRawValue = "oz"
        legacy.carbohydratesGrams = -.infinity
        fixture.context.insert(legacy)
        try fixture.context.save()

        XCTAssertThrowsError(try fixture.coordinator.updatePlate(
            stableID: legacyID,
            expectedModifiedAt: legacy.modifiedAt,
            foodName: "Upgraded aggregate",
            calories: 10,
            weightGrams: 10,
            quantity: 1,
            servingUnitRawValue: NutritionUnit.grams.rawValue,
            nutrients: .empty,
            mealType: MealType.snack.rawValue,
            date: legacy.date
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .historicalMutationUnavailable)
        }

        let deleted = try fixture.coordinator.deleteHistoricalPlate(stableID: legacyID)
        XCTAssertFalse(deleted.isKnownItem)
        XCTAssertEqual(deleted.servingUnitRawValue, "oz")
        XCTAssertNil(try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).first { $0.stableID == legacyID })

        let restored = try fixture.coordinator.restoreHistoricalPlate(deleted)
        XCTAssertEqual(restored.stableID, deleted.stableID)
        XCTAssertEqual(restored.foodName, deleted.foodName)
        XCTAssertEqual(restored.calories, deleted.calories)
        XCTAssertEqual(restored.loggedAmount, deleted.loggedAmount)
        XCTAssertEqual(restored.portionCount, deleted.portionCount)
        XCTAssertEqual(restored.servingUnitRawValue, deleted.servingUnitRawValue)
        XCTAssertGreaterThan(restored.modifiedAt, deleted.modifiedAt)
        let restoredRow = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).first { $0.stableID == legacyID }
        )
        XCTAssertEqual(restoredRow.calories, Int.max)
        XCTAssertEqual(restoredRow.servingUnitRawValue, "oz")
        XCTAssertEqual(restoredRow.carbohydratesGrams, -.infinity)
        XCTAssertNil(restoredRow.loggedCalorieDensity)
        XCTAssertNil(restoredRow.loggedSnapshotKind)
        XCTAssertThrowsError(try fixture.coordinator.deleteHistoricalPlate(
            stableID: legacyID,
            expectedModifiedAt: deleted.modifiedAt
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .compareAndSetFailed)
        }
    }

    func testRepeatedRoundedHistoricalEditsPreserveOriginalCalorieDensity() throws {
        let fixture = try makeFixture()
        let foodID = UUID()
        fixture.context.insert(Food(
            name: "Almond Milk",
            calories: 15,
            stableID: foodID,
            servingGrams: 100
        ))
        try fixture.context.save()
        let created = try fixture.coordinator.createHistoricalPlate(
            foodStableID: foodID,
            amount: 100,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: fixture.clock.value.addingTimeInterval(-3_600)
        )
        let tiny = try fixture.coordinator.updateHistoricalPlate(
            stableID: created.stableID,
            expectedModifiedAt: created.modifiedAt,
            amount: 1,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: created.date
        )
        XCTAssertEqual(tiny.calories, 0)

        let restoredAmount = try fixture.coordinator.updateHistoricalPlate(
            stableID: tiny.stableID,
            expectedModifiedAt: tiny.modifiedAt,
            amount: 100,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: tiny.date
        )

        XCTAssertEqual(restoredAmount.calories, 15)
        XCTAssertEqual(restoredAmount.loggedCalorieDensity ?? -1, 0.15, accuracy: 0.000_001)
    }

    func testConsumedDeletionTokenCannotResurrectSnapshotAfterNewerDelete() throws {
        let fixture = try makeFixture()
        let entry = PlateEntry(
            foodName: "Toast",
            calories: 100,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.breakfast.rawValue,
            date: fixture.clock.value.addingTimeInterval(-3_600)
        )
        try fixture.coordinator.insertPlate(entry)
        let firstDeletion = try fixture.coordinator.deleteHistoricalPlate(
            stableID: entry.stableID,
            expectedModifiedAt: entry.modifiedAt
        )
        let firstRestore = try fixture.coordinator.restoreHistoricalPlate(firstDeletion)
        let edited = try fixture.coordinator.updateHistoricalPlate(
            stableID: firstRestore.stableID,
            expectedModifiedAt: firstRestore.modifiedAt,
            amount: 200,
            portionCount: 1,
            mealType: MealType.breakfast.rawValue,
            date: firstRestore.date
        )
        let secondDeletion = try fixture.coordinator.deleteHistoricalPlate(
            stableID: edited.stableID,
            expectedModifiedAt: edited.modifiedAt
        )

        XCTAssertThrowsError(try fixture.coordinator.restoreHistoricalPlate(firstDeletion)) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .compareAndSetFailed)
        }
        XCTAssertNil(
            try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>())
                .first { $0.stableID == entry.stableID }
        )
        XCTAssertEqual(
            try fixture.coordinator.restoreHistoricalPlate(secondDeletion).calories,
            200
        )
    }

    func testProfilelessStorePersistsMigrationDecisionAndNeverReconsidersUnknownRow() throws {
        let schema = Schema([
            Food.self,
            PlateEntry.self,
            UserProfile.self,
            FoodLogCompletion.self,
            AppMigrationState.self,
            HistoricalPlateDeletionOperation.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        context.insert(PlateEntry(
            foodName: "Aggregate",
            calories: 300,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.lunch.rawValue,
            stableID: UUID(),
            loggedSnapshotKind: nil
        ))
        try context.save()
        let coordinator = PlanEvidenceMutationCoordinator(modelContainer: container)

        XCTAssertEqual(try coordinator.migrateLegacyPlateProvenanceIfNeeded(), 0)
        XCTAssertEqual(
            try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<AppMigrationState>()).first)
                .plateProvenanceVersion,
            1
        )

        let later = ModelContext(container)
        later.insert(Food(name: "Aggregate", calories: 300, servingGrams: 100))
        try later.save()
        XCTAssertEqual(try coordinator.migrateLegacyPlateProvenanceIfNeeded(), 0)
        XCTAssertNil(
            try ModelContext(container).fetch(FetchDescriptor<PlateEntry>()).first?.loggedSnapshotKind
        )
    }

    func testOneTimeProvenanceMigrationClassifiesOnlyUnambiguousSavedFoodRows() throws {
        let fixture = try makeFixture()
        fixture.context.insert(Food(
            name: "Known Food",
            calories: 120,
            servingGrams: 100
        ))
        fixture.context.insert(PlateEntry(
            foodName: "Known Food",
            calories: 120,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.lunch.rawValue,
            date: fixture.clock.value.addingTimeInterval(-3_600),
            stableID: .zero,
            loggedSnapshotKind: nil
        ))
        fixture.context.insert(PlateEntry(
            foodName: "Recorded meals",
            calories: 500,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.dinner.rawValue,
            date: fixture.clock.value.addingTimeInterval(-7_200),
            stableID: .zero,
            loggedSnapshotKind: nil
        ))
        try fixture.context.save()

        XCTAssertEqual(try fixture.coordinator.migrateLegacyPlateProvenanceIfNeeded(), 1)
        let verification = ModelContext(fixture.container)
        let rows = try verification.fetch(FetchDescriptor<PlateEntry>())
        let known = try XCTUnwrap(rows.first { $0.foodName == "Known Food" })
        let aggregate = try XCTUnwrap(rows.first { $0.foodName == "Recorded meals" })
        XCTAssertNotEqual(known.stableID, .zero)
        XCTAssertNotEqual(aggregate.stableID, .zero)
        XCTAssertNotEqual(known.stableID, aggregate.stableID)
        XCTAssertEqual(known.loggedSnapshotKind, .item)
        XCTAssertNil(aggregate.loggedSnapshotKind)
        XCTAssertEqual(
            try XCTUnwrap(verification.fetch(FetchDescriptor<AppMigrationState>()).first)
                .plateProvenanceVersion,
            1
        )

        let laterContext = ModelContext(fixture.container)
        laterContext.insert(Food(name: "Recorded meals", calories: 500, servingGrams: 100))
        laterContext.insert(PlateEntry(
            foodName: "Late unknown",
            calories: 50,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.snack.rawValue,
            date: fixture.clock.value.addingTimeInterval(-10_800),
            stableID: .zero,
            loggedSnapshotKind: nil
        ))
        try laterContext.save()
        XCTAssertEqual(try fixture.coordinator.migrateLegacyPlateProvenanceIfNeeded(), 0)
        let finalRows = try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>())
        XCTAssertNil(finalRows.first { $0.foodName == "Recorded meals" }?.loggedSnapshotKind)
        let lateUnknown = try XCTUnwrap(finalRows.first { $0.foodName == "Late unknown" })
        XCTAssertNotEqual(lateUnknown.stableID, .zero)
        XCTAssertNil(lateUnknown.loggedSnapshotKind)
    }

    func testDeleteUndoRestoresTrustedSnapshotWithPreviouslyUnsupportedName() throws {
        let fixture = try makeFixture()
        let stableID = UUID()
        let unusualName = String(repeating: "x", count: 201) + "\u{0001}"
        fixture.context.insert(PlateEntry(
            foodName: unusualName,
            calories: 100,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.snack.rawValue,
            date: fixture.clock.value.addingTimeInterval(-3_600),
            stableID: stableID,
            loggedSnapshotKind: nil
        ))
        try fixture.context.save()

        let deleted = try fixture.coordinator.deleteHistoricalPlate(stableID: stableID)
        let restored = try fixture.coordinator.restoreHistoricalPlate(deleted)

        XCTAssertEqual(restored.stableID, deleted.stableID)
        XCTAssertEqual(restored.foodName, unusualName)
        XCTAssertGreaterThan(restored.modifiedAt, deleted.modifiedAt)
    }

    func testHistoricalMutationRejectsCollidingStableIdentityWithoutTouchingEitherRow() throws {
        let fixture = try makeFixture()
        let stableID = UUID()
        let timestamp = fixture.clock.value.addingTimeInterval(-3_600)
        let first = PlateEntry(
            foodName: "First",
            calories: 100,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.breakfast.rawValue,
            date: timestamp,
            stableID: stableID
        )
        let second = PlateEntry(
            foodName: "Second",
            calories: 200,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.lunch.rawValue,
            date: timestamp,
            stableID: stableID
        )
        fixture.context.insert(first)
        fixture.context.insert(second)
        try fixture.context.save()

        XCTAssertThrowsError(try fixture.coordinator.deleteHistoricalPlate(
            stableID: stableID,
            expectedModifiedAt: first.modifiedAt
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .identityVerificationFailed)
        }
        XCTAssertThrowsError(try fixture.coordinator.copyHistoricalPlate(
            stableID: stableID,
            expectedModifiedAt: first.modifiedAt,
            to: timestamp.addingTimeInterval(-3_600),
            mealType: MealType.dinner.rawValue
        )) { error in
            XCTAssertEqual(error as? PlanEvidenceMutationError, .identityVerificationFailed)
        }
        XCTAssertEqual(
            try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>())
                .filter { $0.stableID == stableID }.count,
            2
        )
    }

    func testEmptySchemaOneCompletionFailsClosedWithoutAnyMigratedPlate() throws {
        let fixture = try makeFixture()
        let day = fixture.calendar.startOfDay(for: fixture.clock.value)
        let components = fixture.calendar.dateComponents([.era, .year, .month, .day], from: day)
        fixture.context.insert(FoodLogCompletion(
            components: components,
            calendarIdentifier: String(describing: fixture.calendar.identifier),
            timeZoneIdentifier: fixture.calendar.timeZone.identifier,
            dayStart: day,
            attestedAt: fixture.clock.value,
            attestedCalories: 0,
            canonicalPlateSnapshotData: try AdaptivePlanPersistenceCoding.encodePlateSnapshot([]),
            evidenceSchemaVersion: 1
        ))
        try fixture.context.save()

        XCTAssertEqual(try fixture.coordinator.migrateLegacyPlateProvenanceIfNeeded(), 0)
        XCTAssertEqual(try fixture.coordinator.refreshFoodLogStaleness(), 1)
        XCTAssertTrue(
            try XCTUnwrap(ModelContext(fixture.container)
                .fetch(FetchDescriptor<FoodLogCompletion>()).first).isStale
        )
    }

    func testSchemaOneCompletionFailsClosedAndMutationSaveFailureRollsBackEverything() throws {
        let fixture = try makeFixture()
        let timestamp = fixture.clock.value.addingTimeInterval(-3_600)
        let plate = PlateEntry(
            foodName: "Toast",
            calories: 100,
            weightGrams: 50,
            quantity: 1,
            mealType: MealType.breakfast.rawValue,
            date: timestamp
        )
        try fixture.coordinator.insertPlate(plate)
        let day = fixture.calendar.startOfDay(for: timestamp)
        let components = fixture.calendar.dateComponents([.era, .year, .month, .day], from: day)
        let legacyData = try AdaptivePlanPersistenceCoding.encodePlateSnapshot([
            PlateEvidenceSnapshot(
                stableID: plate.stableID,
                dateBitPattern: plate.date.timeIntervalSinceReferenceDate.bitPattern,
                calories: plate.calories
            )
        ])
        fixture.context.insert(FoodLogCompletion(
            components: components,
            calendarIdentifier: String(describing: fixture.calendar.identifier),
            timeZoneIdentifier: fixture.calendar.timeZone.identifier,
            dayStart: day,
            attestedAt: fixture.clock.value,
            attestedCalories: 100,
            canonicalPlateSnapshotData: legacyData,
            evidenceSchemaVersion: 1
        ))
        try fixture.context.save()

        XCTAssertEqual(try fixture.coordinator.refreshFoodLogStaleness(), 1)
        XCTAssertTrue(try XCTUnwrap(ModelContext(fixture.container).fetch(FetchDescriptor<FoodLogCompletion>()).first).isStale)

        let beforeCount = try ModelContext(fixture.container).fetchCount(FetchDescriptor<PlateEntry>())
        let beforeRevision = currentEvidenceRevision(fixture)
        let failing = PlanEvidenceMutationCoordinator(
            modelContainer: fixture.container,
            calendar: fixture.calendar,
            now: { fixture.clock.value },
            beforeSave: { phase in
                if phase == .mutation { throw InjectedFailure.save }
            }
        )
        XCTAssertThrowsError(try failing.copyHistoricalPlate(
            stableID: plate.stableID,
            expectedModifiedAt: plate.modifiedAt,
            to: timestamp.addingTimeInterval(-86_400),
            mealType: MealType.breakfast.rawValue
        ))
        XCTAssertEqual(try ModelContext(fixture.container).fetchCount(FetchDescriptor<PlateEntry>()), beforeCount)
        XCTAssertEqual(currentEvidenceRevision(fixture), beforeRevision)
    }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let coordinator: PlanEvidenceMutationCoordinator
        let clock: Clock
        let calendar: Calendar
    }

    private func makeFixture() throws -> Fixture {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let clock = Clock(try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 18,
            hour: 12
        ))))
        let schema = Schema([
            Food.self,
            PlateEntry.self,
            UserProfile.self,
            FoodLogCompletion.self,
            AppMigrationState.self,
            HistoricalPlateDeletionOperation.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        context.insert(UserProfile())
        try context.save()
        let coordinator = PlanEvidenceMutationCoordinator(
            modelContainer: container,
            calendar: calendar,
            now: { clock.value }
        )
        return Fixture(
            container: container,
            context: context,
            coordinator: coordinator,
            clock: clock,
            calendar: calendar
        )
    }

    private func currentEvidenceRevision(_ fixture: Fixture) -> Int64 {
        let context = ModelContext(fixture.container)
        return (try? context.fetch(FetchDescriptor<UserProfile>()).first?.evidenceRevision) ?? -1
    }
}
#endif
