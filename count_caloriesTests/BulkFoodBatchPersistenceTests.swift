#if !SWIFT_PACKAGE
import Foundation
import SwiftData
import XCTest
@testable import count_calories

@MainActor
final class BulkFoodBatchPersistenceTests: XCTestCase {
    private enum InjectedFailure: Error { case save }

    func testBatchCommitsAllRowsStalesCompletionAndBumpsEvidenceOnce() throws {
        let fixture = try makeFixture()
        let profile = UserProfile(dailyCalorieGoal: 1_700)
        fixture.context.insert(profile)
        try fixture.context.save()
        try fixture.coordinator.insertPlate(PlateEntry(
            foodName: "Existing",
            calories: 100,
            weightGrams: 100,
            quantity: 1,
            date: fixture.now.addingTimeInterval(-600)
        ))
        _ = try fixture.coordinator.markFoodLogComplete(for: fixture.now)
        let evidenceBefore = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<UserProfile>()).first
        ).evidenceRevision
        let operationID = UUID()
        let inserts = makeInserts(now: fixture.now)

        let ids = try fixture.coordinator.insertPlateBatch(
            inserts,
            expectedDay: fixture.now,
            operationID: operationID
        )

        let verification = ModelContext(fixture.container)
        XCTAssertEqual(ids, inserts.map(\.id))
        XCTAssertEqual(try verification.fetch(FetchDescriptor<PlateEntry>()).count, 3)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<BulkFoodBatchOperation>()).count, 1)
        XCTAssertEqual(try XCTUnwrap(verification.fetch(FetchDescriptor<FoodLogCompletion>()).first).isStale, true)
        XCTAssertEqual(try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first).evidenceRevision, evidenceBefore + 1)
        let persistedBarcodes = Set(try verification.fetch(FetchDescriptor<Food>()).compactMap(\.barcode))
        XCTAssertTrue(persistedBarcodes.isSuperset(of: ["12345678", "87654321"]))
    }

    func testBatchReplayIsIdempotentButChangedPayloadFailsClosed() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        let operationID = UUID()
        let inserts = makeInserts(now: fixture.now)
        let first = try fixture.coordinator.insertPlateBatch(
            inserts,
            expectedDay: fixture.now,
            operationID: operationID
        )

        let replay = try fixture.coordinator.insertPlateBatch(
            inserts,
            expectedDay: fixture.now,
            operationID: operationID
        )
        XCTAssertEqual(replay, first)
        XCTAssertEqual(try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).count, 2)

        var changed = inserts
        changed[0] = BulkPlateInsert(
            id: changed[0].id,
            sourceItemID: changed[0].sourceItemID,
            match: changed[0].match,
            amount: 101,
            unit: changed[0].unit,
            mealType: changed[0].mealType,
            date: changed[0].date
        )
        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            changed,
            expectedDay: fixture.now,
            operationID: operationID
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .compareAndSetFailed)
        }

        var changedNutrients = inserts
        let original = changedNutrients[0]
        changedNutrients[0] = BulkPlateInsert(
            id: original.id,
            sourceItemID: original.sourceItemID,
            match: BulkFoodMatch(
                identity: original.match.identity,
                displayName: original.match.displayName,
                barcode: original.match.barcode,
                source: original.match.source,
                servingAmount: original.match.servingAmount,
                servingUnit: original.match.servingUnit,
                caloriesPerServing: original.match.caloriesPerServing,
                nutrientsPerServing: FoodNutrients(proteinGrams: 99)
            ),
            amount: original.amount,
            unit: original.unit,
            mealType: original.mealType,
            date: original.date
        )
        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            changedNutrients,
            expectedDay: fixture.now,
            operationID: operationID
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .compareAndSetFailed)
        }
    }

    func testCrashResumeCanRebuildSamePayloadFromOperationAndSourceIdentity() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        let operationID = UUID()
        let first = makeInserts(now: fixture.now)
        let rebuilt = first.map { insert in
            BulkPlateInsert(
                id: BulkPlateInsert.stableID(
                    operationID: operationID,
                    sourceItemID: insert.sourceItemID
                ),
                sourceItemID: insert.sourceItemID,
                match: insert.match,
                amount: insert.amount,
                unit: insert.unit,
                mealType: insert.mealType,
                date: insert.date
            )
        }
        let firstStable = first.map { insert in
            BulkPlateInsert(
                id: BulkPlateInsert.stableID(
                    operationID: operationID,
                    sourceItemID: insert.sourceItemID
                ),
                sourceItemID: insert.sourceItemID,
                match: insert.match,
                amount: insert.amount,
                unit: insert.unit,
                mealType: insert.mealType,
                date: insert.date
            )
        }

        let inserted = try fixture.coordinator.insertPlateBatch(
            firstStable,
            expectedDay: fixture.now,
            operationID: operationID
        )
        let replayed = try fixture.coordinator.insertPlateBatch(
            rebuilt,
            expectedDay: fixture.now,
            operationID: operationID
        )

        XCTAssertEqual(replayed, inserted)
        XCTAssertEqual(try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).count, 2)
    }

    func testSeparateCoordinatorReplaysCommittedBatchWithoutDuplicateMutation() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        let operationID = UUID()
        let inserts = makeInserts(now: fixture.now)
        let first = try fixture.coordinator.insertPlateBatch(
            inserts,
            expectedDay: fixture.now,
            operationID: operationID
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let secondCoordinator = PlanEvidenceMutationCoordinator(
            modelContainer: fixture.container,
            calendar: calendar,
            now: { fixture.now }
        )

        let replay = try secondCoordinator.insertPlateBatch(
            inserts,
            expectedDay: fixture.now,
            operationID: operationID
        )

        XCTAssertEqual(replay, first)
        XCTAssertEqual(try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).count, 2)
    }

    func testNutrientScalingOverflowRejectsBatchWithoutMutation() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        let insert = BulkPlateInsert(
            id: UUID(),
            sourceItemID: UUID(),
            match: BulkFoodMatch(
                identity: .barcode("12345678"),
                displayName: "Overflow Food",
                barcode: "12345678",
                source: .openFoodFacts,
                servingAmount: 0.01,
                servingUnit: .grams,
                caloriesPerServing: 1,
                nutrientsPerServing: FoodNutrients(proteinGrams: Double.greatestFiniteMagnitude)
            ),
            amount: BulkFoodLimits.maximumAmount,
            unit: .grams,
            mealType: MealType.lunch.rawValue,
            date: fixture.now.addingTimeInterval(-60)
        )

        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            [insert],
            expectedDay: fixture.now,
            operationID: UUID()
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }
        let verification = ModelContext(fixture.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<PlateEntry>()).count, 0)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<Food>()).count, 0)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<BulkFoodBatchOperation>()).count, 0)
    }

    func testInjectedSaveFailureRollsBackFoodsPlatesOperationCompletionAndEvidence() throws {
        var shouldFail = true
        let fixture = try makeFixture(beforeSave: { phase in
            if phase == .bulkFoodBatch, shouldFail {
                shouldFail = false
                throw InjectedFailure.save
            }
        })
        let profile = UserProfile()
        fixture.context.insert(profile)
        try fixture.context.save()
        try fixture.coordinator.insertPlate(PlateEntry(
            foodName: "Existing",
            calories: 100,
            weightGrams: 100,
            quantity: 1,
            date: fixture.now.addingTimeInterval(-600)
        ))
        _ = try fixture.coordinator.markFoodLogComplete(for: fixture.now)
        let evidenceBefore = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<UserProfile>()).first
        ).evidenceRevision

        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            makeInserts(now: fixture.now),
            expectedDay: fixture.now,
            operationID: UUID()
        )) {
            XCTAssertTrue($0 is InjectedFailure)
        }

        let verification = ModelContext(fixture.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<PlateEntry>()).count, 1)
        XCTAssertTrue(try verification.fetch(FetchDescriptor<Food>()).allSatisfy { food in
            food.barcode != "12345678" && food.barcode != "87654321"
        })
        XCTAssertEqual(try verification.fetch(FetchDescriptor<BulkFoodBatchOperation>()).count, 0)
        XCTAssertEqual(try XCTUnwrap(verification.fetch(FetchDescriptor<FoodLogCompletion>()).first).isStale, false)
        XCTAssertEqual(try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first).evidenceRevision, evidenceBefore)
    }

    func testSavedFoodPayloadMustMatchCurrentRecord() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        let saved = Food(
            name: "Current Apple",
            calories: 52,
            stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
            servingGrams: 100
        )
        fixture.context.insert(saved)
        try fixture.context.save()
        let forged = BulkPlateInsert(
            sourceItemID: UUID(),
            match: BulkFoodMatch(
                identity: .savedFood(saved.stableID),
                displayName: "Forged Apple",
                source: .saved,
                servingAmount: 100,
                servingUnit: .grams,
                caloriesPerServing: 999
            ),
            amount: 100,
            unit: .grams,
            mealType: "Lunch",
            date: fixture.now
        )

        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            [forged],
            expectedDay: fixture.now,
            operationID: UUID()
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }
        XCTAssertEqual(try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).count, 0)
    }

    func testMatchingSavedBarcodeSnapshotAccepted() throws {
        let fixture = try makeFixture()
        let nutrients = FoodNutrients(proteinGrams: 0.6)
        let saved = Food(
            name: "Almond Milk",
            calories: 15,
            stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
            servingGrams: 100,
            servingUnit: .grams,
            barcode: "12345678",
            nutrientsPerServing: nutrients
        )
        fixture.context.insert(UserProfile())
        fixture.context.insert(saved)
        try fixture.context.save()
        let insert = BulkPlateInsert(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!,
            sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
            match: BulkFoodMatch(
                identity: .barcode("12345678"),
                displayName: "Almond Milk",
                barcode: "12345678",
                source: .openFoodFacts,
                servingAmount: 100,
                servingUnit: .grams,
                caloriesPerServing: 15,
                nutrientsPerServing: nutrients
            ),
            amount: 200,
            unit: .grams,
            mealType: "Lunch",
            date: fixture.now
        )

        let ids = try fixture.coordinator.insertPlateBatch(
            [insert],
            expectedDay: fixture.now,
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
        )

        let verification = ModelContext(fixture.container)
        XCTAssertEqual(ids, [insert.id])
        XCTAssertEqual(try verification.fetch(FetchDescriptor<Food>()).count, 1)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<PlateEntry>()).count, 1)
        let plate = try XCTUnwrap(verification.fetch(FetchDescriptor<PlateEntry>()).first)
        XCTAssertEqual(plate.calories, 30)
        XCTAssertEqual(try XCTUnwrap(verification.fetch(FetchDescriptor<Food>()).first).stableID, saved.stableID)
    }

    func testConflictingSavedBarcodeSnapshotRejectsWithoutMutation() throws {
        let fixture = try makeFixture()
        let nutrients = FoodNutrients(proteinGrams: 0.6)
        let saved = Food(
            name: "Almond Milk",
            calories: 15,
            stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
            servingGrams: 100,
            servingUnit: .grams,
            barcode: "12345678",
            nutrientsPerServing: nutrients
        )
        fixture.context.insert(UserProfile())
        fixture.context.insert(saved)
        try fixture.context.save()
        let evidenceBefore = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<UserProfile>()).first
        ).evidenceRevision
        let conflict = BulkPlateInsert(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000061")!,
            sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000062")!,
            match: BulkFoodMatch(
                identity: .barcode("12345678"),
                displayName: "Almond Milk",
                barcode: "12345678",
                source: .openFoodFacts,
                servingAmount: 100,
                servingUnit: .grams,
                caloriesPerServing: 16,
                nutrientsPerServing: nutrients
            ),
            amount: 100,
            unit: .grams,
            mealType: "Lunch",
            date: fixture.now
        )

        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            [conflict],
            expectedDay: fixture.now,
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000063")!
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }

        let verification = ModelContext(fixture.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<PlateEntry>()).count, 0)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<BulkFoodBatchOperation>()).count, 0)
        let persisted = try XCTUnwrap(verification.fetch(FetchDescriptor<Food>()).first)
        XCTAssertEqual(persisted.name, "Almond Milk")
        XCTAssertEqual(persisted.calories, 15)
        XCTAssertEqual(persisted.barcode, "12345678")
        XCTAssertEqual(persisted.nutrientsPerServing, nutrients)
        XCTAssertEqual(
            try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first).evidenceRevision,
            evidenceBefore
        )
    }

    func testSameNewBarcodeMatchingSnapshotCreatesOneFoodAndTwoPlates() throws {
        let fixture = try makeFixture()
        let nutrients = FoodNutrients(carbohydratesGrams: 3, proteinGrams: 1)
        let match = BulkFoodMatch(
            identity: .barcode("11112222"),
            displayName: "New Oat Drink",
            barcode: "11112222",
            source: .openFoodFacts,
            servingAmount: 100,
            servingUnit: .grams,
            caloriesPerServing: 40,
            nutrientsPerServing: nutrients
        )
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        let inserts = [
            BulkPlateInsert(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
                sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000072")!,
                match: match,
                amount: 100,
                unit: .grams,
                mealType: "Lunch",
                date: fixture.now.addingTimeInterval(-120)
            ),
            BulkPlateInsert(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000073")!,
                sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000074")!,
                match: match,
                amount: 200,
                unit: .grams,
                mealType: "Lunch",
                date: fixture.now.addingTimeInterval(-60)
            )
        ]

        let ids = try fixture.coordinator.insertPlateBatch(
            inserts,
            expectedDay: fixture.now,
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000075")!
        )

        let verification = ModelContext(fixture.container)
        XCTAssertEqual(ids, inserts.map(\.id))
        let foods = try verification.fetch(FetchDescriptor<Food>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods[0].stableID, inserts[0].sourceItemID)
        XCTAssertEqual(foods[0].name, "New Oat Drink")
        XCTAssertEqual(foods[0].barcode, "11112222")
        XCTAssertEqual(foods[0].nutrientsPerServing, nutrients)
        let plates = try verification.fetch(FetchDescriptor<PlateEntry>())
        XCTAssertEqual(plates.count, 2)
        XCTAssertEqual(Set(plates.map(\.calories)), Set([40, 80]))
    }

    func testConflictingSameNewBarcodeSnapshotRejectsWithoutMutation() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        let firstMatch = BulkFoodMatch(
            identity: .barcode("22223333"),
            displayName: "New Food",
            barcode: "22223333",
            source: .openFoodFacts,
            servingAmount: 100,
            servingUnit: .grams,
            caloriesPerServing: 40
        )
        let conflictingMatch = BulkFoodMatch(
            identity: .barcode("22223333"),
            displayName: "New Food",
            barcode: "22223333",
            source: .openFoodFacts,
            servingAmount: 100,
            servingUnit: .grams,
            caloriesPerServing: 41
        )
        let inserts = [
            BulkPlateInsert(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!,
                sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000082")!,
                match: firstMatch,
                amount: 100,
                unit: .grams,
                mealType: "Lunch",
                date: fixture.now
            ),
            BulkPlateInsert(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000083")!,
                sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000084")!,
                match: conflictingMatch,
                amount: 100,
                unit: .grams,
                mealType: "Lunch",
                date: fixture.now
            )
        ]

        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            inserts,
            expectedDay: fixture.now,
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000085")!
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }

        let verification = ModelContext(fixture.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<Food>()).count, 0)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<PlateEntry>()).count, 0)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<BulkFoodBatchOperation>()).count, 0)
        XCTAssertEqual(
            try XCTUnwrap(verification.fetch(FetchDescriptor<UserProfile>()).first).evidenceRevision,
            0
        )
    }

    func testBarcodeIdentityRequiresExactMatchBarcode() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        let insert = BulkPlateInsert(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000091")!,
            sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000092")!,
            match: BulkFoodMatch(
                identity: .barcode("33334444"),
                displayName: "Mismatched Barcode Food",
                barcode: "99998888",
                source: .openFoodFacts,
                servingAmount: 100,
                servingUnit: .grams,
                caloriesPerServing: 20
            ),
            amount: 100,
            unit: .grams,
            mealType: "Lunch",
            date: fixture.now
        )

        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            [insert],
            expectedDay: fixture.now,
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000093")!
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }
        let verification = ModelContext(fixture.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<Food>()).count, 0)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<PlateEntry>()).count, 0)
    }

    func testOperationHistoryIsBoundedWithDeterministicOldestEvictionAndRetainedReplay() throws {
        let fixture = try makeFixture()
        let saved = Food(
            name: "History Food",
            calories: 10,
            stableID: deterministicID(31),
            servingGrams: 100,
            servingUnit: .grams,
            barcode: "44445555"
        )
        fixture.context.insert(UserProfile())
        fixture.context.insert(saved)
        try fixture.context.save()

        for index in 1...257 {
            let insert = makeHistoryInsert(index: index, now: fixture.now)
            _ = try fixture.coordinator.insertPlateBatch(
                [insert],
                expectedDay: fixture.now,
                operationID: deterministicID(index)
            )
        }

        let verification = ModelContext(fixture.container)
        let operations = try verification.fetch(FetchDescriptor<BulkFoodBatchOperation>())
        let operationIDs = Set(operations.map(\.operationID))
        XCTAssertEqual(operations.count, 256)
        XCTAssertEqual(
            operationIDs,
            Set((2...257).map { deterministicID($0) })
        )
        XCTAssertFalse(operationIDs.contains(deterministicID(1)))

        let retainedInsert = makeHistoryInsert(index: 2, now: fixture.now)
        let evidenceBeforeReplay = try XCTUnwrap(
            verification.fetch(FetchDescriptor<UserProfile>()).first
        ).evidenceRevision
        let replay = try fixture.coordinator.insertPlateBatch(
            [retainedInsert],
            expectedDay: fixture.now,
            operationID: deterministicID(2)
        )

        let afterReplay = ModelContext(fixture.container)
        XCTAssertEqual(replay, [retainedInsert.id])
        XCTAssertEqual(try afterReplay.fetch(FetchDescriptor<PlateEntry>()).count, 257)
        XCTAssertEqual(try afterReplay.fetch(FetchDescriptor<BulkFoodBatchOperation>()).count, 256)
        XCTAssertEqual(
            try XCTUnwrap(afterReplay.fetch(FetchDescriptor<UserProfile>()).first).evidenceRevision,
            evidenceBeforeReplay
        )
    }

    func testInvalidMixedDayAndMissingSavedIdentityRejectBeforeMutation() throws {
        let fixture = try makeFixture()
        fixture.context.insert(UserProfile())
        try fixture.context.save()
        var mixed = makeInserts(now: fixture.now)
        mixed[1] = BulkPlateInsert(
            id: mixed[1].id,
            sourceItemID: mixed[1].sourceItemID,
            match: mixed[1].match,
            amount: mixed[1].amount,
            unit: mixed[1].unit,
            mealType: mixed[1].mealType,
            date: fixture.now.addingTimeInterval(86_400)
        )
        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            mixed,
            expectedDay: fixture.now,
            operationID: UUID()
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }

        var mixedMeals = makeInserts(now: fixture.now)
        mixedMeals[1] = BulkPlateInsert(
            id: mixedMeals[1].id,
            sourceItemID: mixedMeals[1].sourceItemID,
            match: mixedMeals[1].match,
            amount: mixedMeals[1].amount,
            unit: mixedMeals[1].unit,
            mealType: "Dinner",
            date: mixedMeals[1].date
        )
        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            mixedMeals,
            expectedDay: fixture.now,
            operationID: UUID()
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }

        let missingSaved = BulkPlateInsert(
            sourceItemID: UUID(),
            match: BulkFoodMatch(
                identity: .savedFood(UUID()),
                displayName: "Missing",
                source: .saved,
                servingAmount: 100,
                servingUnit: .grams,
                caloriesPerServing: 10
            ),
            amount: 100,
            unit: .grams,
            mealType: "Lunch",
            date: fixture.now
        )
        XCTAssertThrowsError(try fixture.coordinator.insertPlateBatch(
            [missingSaved],
            expectedDay: fixture.now,
            operationID: UUID()
        )) {
            XCTAssertEqual($0 as? PlanEvidenceMutationError, .invalidBulkBatch)
        }
        XCTAssertEqual(try ModelContext(fixture.container).fetch(FetchDescriptor<PlateEntry>()).count, 0)
    }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let coordinator: PlanEvidenceMutationCoordinator
        let now: Date
    }

    private func makeFixture(
        beforeSave: @escaping (PlanEvidenceMutationCoordinator.SavePhase) throws -> Void = { _ in }
    ) throws -> Fixture {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let schema = Schema([
            Food.self,
            PlateEntry.self,
            FoodLogCompletion.self,
            BulkFoodBatchOperation.self,
            WeightEntry.self,
            UserProfile.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return Fixture(
            container: container,
            context: ModelContext(container),
            coordinator: PlanEvidenceMutationCoordinator(
                modelContainer: container,
                calendar: calendar,
                now: { now },
                beforeSave: beforeSave
            ),
            now: now
        )
    }

    private func deterministicID(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }

    private func makeHistoryInsert(index: Int, now: Date) -> BulkPlateInsert {
        BulkPlateInsert(
            id: deterministicID(1_000 + index),
            sourceItemID: deterministicID(2_000 + index),
            match: BulkFoodMatch(
                identity: .barcode("44445555"),
                displayName: "History Food",
                barcode: "44445555",
                source: .openFoodFacts,
                servingAmount: 100,
                servingUnit: .grams,
                caloriesPerServing: 10
            ),
            amount: 100,
            unit: .grams,
            mealType: "Lunch",
            date: now
        )
    }

    private func makeInserts(now: Date) -> [BulkPlateInsert] {
        [
            BulkPlateInsert(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
                sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
                match: BulkFoodMatch(
                    identity: .barcode("12345678"),
                    displayName: "Almond Milk",
                    barcode: "12345678",
                    source: .openFoodFacts,
                    servingAmount: 100,
                    servingUnit: .grams,
                    caloriesPerServing: 15,
                    nutrientsPerServing: FoodNutrients(proteinGrams: 0.6)
                ),
                amount: 100,
                unit: .grams,
                mealType: "Lunch",
                date: now.addingTimeInterval(-120)
            ),
            BulkPlateInsert(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
                sourceItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
                match: BulkFoodMatch(
                    identity: .barcode("87654321"),
                    displayName: "Apple",
                    barcode: "87654321",
                    source: .openFoodFacts,
                    servingAmount: 100,
                    servingUnit: .grams,
                    caloriesPerServing: 52
                ),
                amount: 150,
                unit: .grams,
                mealType: "Lunch",
                date: now.addingTimeInterval(-60)
            )
        ]
    }
}
#endif
