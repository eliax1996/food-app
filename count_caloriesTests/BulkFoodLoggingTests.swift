import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

final class BulkFoodLoggingTests: XCTestCase {
    func testDescriptionAndExtractionValidationBoundsEveryModelField() throws {
        XCTAssertThrowsError(try BulkFoodValidator.validateDescription("  \n ")) {
            XCTAssertEqual($0 as? BulkFoodValidationError, .emptyDescription)
        }
        XCTAssertThrowsError(
            try BulkFoodValidator.validateDescription(String(repeating: "a", count: 1_201))
        ) {
            XCTAssertEqual($0 as? BulkFoodValidationError, .descriptionTooLong)
        }
        XCTAssertEqual(try BulkFoodValidator.validateDescription("  apple and milk \n"), "apple and milk")

        let valid = BulkFoodExtractedItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            query: " Almond Milk ",
            amount: 100,
            unit: .grams,
            amountOrigin: .explicitDescription
        )
        let validated = try BulkFoodValidator.validate(BulkFoodExtraction(items: [valid]))
        XCTAssertEqual(validated.items.first?.query, "Almond Milk")
        XCTAssertEqual(validated.items.first?.sourceQuery, "Almond Milk")

        XCTAssertThrowsError(try BulkFoodValidator.validate(BulkFoodExtraction(items: []))) {
            XCTAssertEqual($0 as? BulkFoodValidationError, .invalidItemCount)
        }
        XCTAssertThrowsError(try BulkFoodValidator.validate(BulkFoodExtraction(
            items: Array(repeating: valid, count: 13)
        ))) {
            XCTAssertEqual($0 as? BulkFoodValidationError, .invalidItemCount)
        }
        XCTAssertThrowsError(try BulkFoodValidator.validate(BulkFoodExtraction(items: [valid, valid]))) {
            XCTAssertEqual($0 as? BulkFoodValidationError, .duplicateItemID)
        }
        XCTAssertThrowsError(try BulkFoodValidator.validate(BulkFoodExtraction(items: [
            BulkFoodExtractedItem(query: "bad\u{0000}query", amount: 1, unit: .grams, amountOrigin: .modelEstimate)
        ]))) {
            XCTAssertEqual($0 as? BulkFoodValidationError, .queryContainsControlCharacters)
        }
        for amount in [0, -1, .infinity, -.infinity, .nan, 5_000.01] {
            XCTAssertThrowsError(try BulkFoodValidator.validateAmount(amount))
        }
        XCTAssertEqual(try BulkFoodValidator.validateAmount(0.01), 0.01)
        XCTAssertEqual(try BulkFoodValidator.validateAmount(5_000), 5_000)
    }

    func testDefaultAmountOriginRoundTripsSafelyAndBlocksReadiness() throws {
        let data = try JSONEncoder().encode(BulkAmountOrigin.defaultAmount)
        XCTAssertEqual(try JSONDecoder().decode(BulkAmountOrigin.self, from: data), .defaultAmount)
        XCTAssertEqual(
            try JSONDecoder().decode(BulkAmountOrigin.self, from: Data("\"future-origin\"".utf8)),
            .modelEstimate
        )

        let selected = match(name: "Almond Milk", identity: .barcode("12345678"), source: .openFoodFacts)
        var item = BulkFoodReviewItem(
            sourceQuery: "almond milk",
            query: "Almond Milk",
            amount: 100,
            unit: .grams,
            amountOrigin: .defaultAmount,
            selectedMatch: selected,
            candidates: [selected],
            matchPhase: .resolved
        )
        XCTAssertFalse(item.isReady)
        item.amountOrigin = .userEdited
        XCTAssertTrue(item.isReady)
    }

    func testInvalidVisibleAmountCanInvalidateReadyReviewItem() {
        let selected = match(
            name: "Almond Milk",
            identity: .barcode("12345678"),
            source: .openFoodFacts
        )
        var item = BulkFoodReviewItem(
            sourceQuery: "almond milk",
            query: "Almond Milk",
            amount: 100,
            unit: .grams,
            amountOrigin: .userEdited,
            selectedMatch: selected,
            candidates: [selected],
            matchPhase: .resolved
        )
        XCTAssertTrue(item.isReady)
        item.amount = .nan
        XCTAssertFalse(item.isReady)
        XCTAssertNil(item.calories)
    }

    func testDraftRoundTripPreservesCommitOperationIdentity() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let store = BulkFoodDraftStore(fileURL: fixture.url)
        let lease = await store.acquireLease()
        let operationID = UUID()
        let commitDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let draft = BulkFoodDraft(
            description: "100 g almond milk",
            mealType: "Lunch",
            reviewItems: [],
            operationID: operationID,
            commitDate: commitDate,
            updatedAt: .now
        )

        try await store.save(draft, lease: lease)
        let restored = await store.load()

        XCTAssertEqual(restored?.operationID, operationID)
        XCTAssertEqual(restored?.commitDate, commitDate)
    }

    func testDraftClearFreshLeaseCanSaveReplacement() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let store = BulkFoodDraftStore(fileURL: fixture.url)
        let firstLease = await store.acquireLease()
        let first = BulkFoodDraft(description: "old", mealType: "Breakfast", reviewItems: [], updatedAt: .now)
        try await store.save(first, lease: firstLease)
        try await store.clear(lease: firstLease)

        let freshLease = await store.acquireLease()
        let replacement = BulkFoodDraft(description: "new", mealType: "Lunch", reviewItems: [], updatedAt: .now)
        try await store.save(replacement, lease: freshLease)
        let loaded = await store.load()
        XCTAssertEqual(loaded, replacement)
    }

    func testMatchScalingKeepsZeroCaloriesAndUnknownNutrientsTruthful() throws {
        let match = BulkFoodMatch(
            identity: .barcode("12345678"),
            displayName: "Zero Drink",
            source: .openFoodFacts,
            servingAmount: 250,
            servingUnit: .milliliters,
            caloriesPerServing: 0,
            nutrientsPerServing: FoodNutrients(carbohydratesGrams: 0)
        )

        XCTAssertEqual(match.calories(for: 500), 0)
        let nutrients = try XCTUnwrap(match.nutrients(for: 500))
        XCTAssertEqual(nutrients.carbohydratesGrams, 0)
        XCTAssertNil(nutrients.proteinGrams)
        XCTAssertNil(match.calories(for: .nan))
        XCTAssertNil(match.nutrients(for: 0))
    }

    func testCandidateRankingIsDeterministicAndOnlyUnambiguousExactSavedMatchAutoSelects() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let saved = candidate(name: "Almond Milk", identity: .savedFood(firstID), source: .saved)
        let remote = candidate(name: "Organic Almond Milk", identity: .barcode("11111111"), source: .openFoodFacts)
        let wrongUnit = candidate(
            name: "Almond Milk",
            identity: .savedFood(secondID),
            source: .saved,
            unit: .milliliters
        )

        let ranked = BulkFoodCandidateRanker.ranked(
            query: "almond milk",
            unit: .grams,
            candidates: [remote, wrongUnit, saved, saved]
        )
        XCTAssertEqual(ranked.map(\.match.identity), [.savedFood(firstID), .barcode("11111111")])
        XCTAssertEqual(
            BulkFoodCandidateRanker.automaticSelection(
                query: "almond milk",
                unit: .grams,
                candidates: [remote, saved]
            )?.identity,
            .savedFood(firstID)
        )

        let duplicateExact = candidate(
            name: "ALMOND MILK",
            identity: .savedFood(secondID),
            source: .saved
        )
        XCTAssertNil(BulkFoodCandidateRanker.automaticSelection(
            query: "almond milk",
            unit: .grams,
            candidates: [saved, duplicateExact]
        ))
        XCTAssertNil(BulkFoodCandidateRanker.automaticSelection(
            query: "milk",
            unit: .grams,
            candidates: [saved]
        ))
    }

    func testRememberedExactMatchWinsAndNormalizationIsCanonical() {
        XCTAssertEqual(BulkFoodText.normalizedKey("  Café\nMILK! "), "café milk")
        let saved = candidate(
            name: "Milk",
            identity: .savedFood(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
            source: .saved,
            useCount: 100
        )
        let remembered = candidate(
            name: "Unsweetened Almond Milk",
            identity: .barcode("12345678"),
            source: .remembered,
            useCount: 1
        )
        XCTAssertEqual(
            BulkFoodCandidateRanker.automaticSelection(
                query: "milk",
                unit: .grams,
                candidates: [saved, remembered]
            )?.identity,
            .barcode("12345678")
        )
    }

    func testAcceptedEstimateRetainsDistinctOriginAndStableInsertIdentity() {
        XCTAssertEqual(
            BulkAmountOrigin.retainedOrigin(for: .acceptedEstimate),
            .acceptedEstimate
        )
        XCTAssertEqual(
            BulkAmountOrigin.retainedOrigin(for: .userEdited),
            .retainedCorrection
        )
        let operationID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let sourceID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        XCTAssertEqual(
            BulkPlateInsert.stableID(operationID: operationID, sourceItemID: sourceID),
            BulkPlateInsert.stableID(operationID: operationID, sourceItemID: sourceID)
        )
        XCTAssertNotEqual(
            BulkPlateInsert.stableID(operationID: operationID, sourceItemID: sourceID),
            BulkPlateInsert.stableID(operationID: UUID(), sourceItemID: sourceID)
        )
    }

    func testLearningStorePersistsExactUnitScopedCorrectionAndReadRecencyOnNextWrite() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 800_000_000))
        let store = try BulkFoodLearningStore(fileURL: fixture.url, now: { clock.value })
        let lease = await store.acquireLease()
        let selection = match(name: "Almond Milk", identity: .barcode("12345678"), source: .openFoodFacts)

        let confirmed = try await store.confirm(
            source: " almond milk ",
            confirmedQuery: "Unsweetened Almond Milk",
            amount: 120,
            unit: .grams,
            amountKnowledge: .userEdited,
            selection: selection,
            lease: lease
        )
        XCTAssertEqual(confirmed.normalizedKey, "almond milk")
        let recordCount = await store.count()
        let wrongUnit = await store.record(for: "almond milk", unit: .milliliters, touch: true)
        XCTAssertEqual(recordCount, 1)
        XCTAssertNil(wrongUnit)

        clock.value = clock.value.addingTimeInterval(60)
        let recalled = await store.record(for: "ALMOND   MILK!", unit: .grams, touch: true)
        XCTAssertEqual(recalled?.confirmedQuery, "Unsweetened Almond Milk")
        XCTAssertEqual(recalled?.lastUsedAt, clock.value)
        XCTAssertEqual(recalled?.useCount, 2)

        _ = try await store.confirm(
            source: "banana",
            confirmedQuery: "Banana",
            amount: 100,
            unit: .grams,
            amountKnowledge: .explicitDescription,
            selection: match(name: "Banana", identity: .barcode("87654321"), source: .openFoodFacts),
            lease: lease
        )
        let reloaded = try BulkFoodLearningStore(fileURL: fixture.url)
        let persisted = await reloaded.allRecords().first {
            $0.normalizedKey == "almond milk"
        }
        XCTAssertEqual(persisted?.lastUsedAt, clock.value)
        XCTAssertEqual(persisted?.useCount, 2)
    }

    func testLearningConfirmationRejectsSelectionUnitMismatch() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let store = try BulkFoodLearningStore(fileURL: fixture.url)
        let lease = await store.acquireLease()
        let selection = match(
            name: "Almond Milk",
            identity: .barcode("12345678"),
            source: .openFoodFacts,
            unit: .milliliters
        )

        do {
            _ = try await store.confirm(
                source: "almond milk",
                confirmedQuery: "Almond Milk",
                amount: 100,
                unit: .grams,
                amountKnowledge: .userEdited,
                selection: selection,
                lease: lease
            )
            XCTFail("Expected unit mismatch rejection")
        } catch {
            XCTAssertEqual(error as? BulkFoodValidationError, .emptyQuery)
        }
        let count = await store.count()
        XCTAssertEqual(count, 0)
    }

    func testLearningStoreEvictsLeastRecentlyUsedAndRecoversFromCorruption() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 800_000_000))
        let store = try BulkFoodLearningStore(
            fileURL: fixture.url,
            maximumRecords: 2,
            maximumBytes: 1_000_000,
            now: { clock.value }
        )
        let lease = await store.acquireLease()

        for index in 0..<3 {
            clock.value = clock.value.addingTimeInterval(1)
            _ = try await store.confirm(
                source: "food \(index)",
                confirmedQuery: "Food \(index)",
                amount: 100,
                unit: .grams,
                amountKnowledge: .explicitDescription,
                selection: match(
                    name: "Food \(index)",
                    identity: .barcode("1234567\(index)"),
                    source: .openFoodFacts
                ),
                lease: lease
            )
        }
        let evicted = await store.record(for: "food 0")
        let retainedOne = await store.record(for: "food 1")
        let retainedTwo = await store.record(for: "food 2")
        XCTAssertNil(evicted)
        XCTAssertNotNil(retainedOne)
        XCTAssertNotNil(retainedTwo)

        try Data("not json".utf8).write(to: fixture.url, options: .atomic)
        let recovered = try BulkFoodLearningStore(fileURL: fixture.url)
        let recoveredCount = await recovered.count()
        XCTAssertEqual(recoveredCount, 0)
    }

    func testDraftStoreExpiresAndCorruptionRecoversWithoutBlocking() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 800_000_000))
        let store = BulkFoodDraftStore(fileURL: fixture.url, now: { clock.value })
        let lease = await store.acquireLease()
        let draft = BulkFoodDraft(
            description: "100 g almond milk",
            mealType: "Breakfast",
            reviewItems: [
                BulkFoodReviewItemSnapshot(
                    id: UUID(),
                    sourceQuery: "almond milk",
                    query: "Almond Milk",
                    amount: 100,
                    unit: .grams,
                    amountOrigin: .explicitDescription,
                    selectedMatch: match(
                        name: "Almond Milk",
                        identity: .barcode("12345678"),
                        source: .openFoodFacts
                    )
                )
            ],
            updatedAt: clock.value
        )
        try await store.save(draft, lease: lease)
        let loaded = await store.load()
        XCTAssertEqual(loaded, draft)

        clock.value = clock.value.addingTimeInterval(BulkFoodLimits.draftLifetime + 1)
        let expired = await store.load()
        let hasExpiredDraft = await store.hasDraft()
        XCTAssertNil(expired)
        XCTAssertFalse(hasExpiredDraft)

        try Data("broken".utf8).write(to: fixture.url, options: .atomic)
        let corrupt = await store.load()
        XCTAssertNil(corrupt)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.url.path()))
    }

    func testApplicationOwnerSharesStoreIdentityAndCoherentRecords() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let owner = BulkFoodApplicationStoreOwner(
            learningFileURL: fixture.url,
            draftFileURL: fixture.directory.appending(path: "draft.json")
        )
        let first = try await owner.learningStore()
        let second = try await owner.learningStore()
        XCTAssertTrue(first === second)

        let lease = await first.acquireLease()
        _ = try await first.confirm(
            source: "shared almond milk",
            confirmedQuery: "Almond Milk",
            amount: 100,
            unit: .grams,
            amountKnowledge: .userEdited,
            selection: match(name: "Almond Milk", identity: .barcode("12345678"), source: .openFoodFacts),
            lease: lease
        )
        let sharedCount = await second.count()
        XCTAssertEqual(sharedCount, 1)

        let firstDraft = try await owner.draftStore()
        let secondDraft = try await owner.draftStore()
        XCTAssertTrue(firstDraft === secondDraft)
    }

    func testClearRejectsStaleLearningAndDraftLeasesButFreshLeaseWrites() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let learningStore = try BulkFoodLearningStore(fileURL: fixture.url)
        let staleLearningLease = await learningStore.acquireLease()
        try await learningStore.clear()

        do {
            _ = try await learningStore.confirm(
                source: "almond milk",
                confirmedQuery: "Almond Milk",
                amount: 100,
                unit: .grams,
                amountKnowledge: .userEdited,
                selection: match(name: "Almond Milk", identity: .barcode("12345678"), source: .openFoodFacts),
                lease: staleLearningLease
            )
            XCTFail("Expected stale learning lease rejection")
        } catch {
            XCTAssertEqual(error as? BulkFoodPersistenceError, .staleLease)
        }

        let freshLearningLease = await learningStore.acquireLease()
        _ = try await learningStore.confirm(
            source: "almond milk",
            confirmedQuery: "Almond Milk",
            amount: 100,
            unit: .grams,
            amountKnowledge: .userEdited,
            selection: match(name: "Almond Milk", identity: .barcode("12345678"), source: .openFoodFacts),
            lease: freshLearningLease
        )
        let freshCount = await learningStore.count()
        XCTAssertEqual(freshCount, 1)

        let draftURL = fixture.directory.appending(path: "draft.json")
        let draftStore = BulkFoodDraftStore(fileURL: draftURL)
        let staleDraftLease = await draftStore.acquireLease()
        try await draftStore.clear(lease: staleDraftLease)
        let draft = BulkFoodDraft(
            description: "100 g almond milk",
            mealType: "Breakfast",
            reviewItems: [],
            updatedAt: .now
        )
        do {
            try await draftStore.save(draft, lease: staleDraftLease)
            XCTFail("Expected stale draft lease rejection")
        } catch {
            XCTAssertEqual(error as? BulkFoodPersistenceError, .staleLease)
        }
        let freshDraftLease = await draftStore.acquireLease()
        try await draftStore.save(draft, lease: freshDraftLease)
        let savedDraft = await draftStore.load()
        XCTAssertEqual(savedDraft, draft)
    }

    func testFailedLearningClearRestoresMemoryAndThrows() async throws {
        let fixture = StoreFixture()
        defer { fixture.remove() }
        let store = try BulkFoodLearningStore(
            fileURL: fixture.url,
            removeItem: { _ in throw ClearFailure.forced }
        )
        let lease = await store.acquireLease()
        _ = try await store.confirm(
            source: "almond milk",
            confirmedQuery: "Almond Milk",
            amount: 100,
            unit: .grams,
            amountKnowledge: .userEdited,
            selection: match(name: "Almond Milk", identity: .barcode("12345678"), source: .openFoodFacts),
            lease: lease
        )

        do {
            try await store.clear()
            XCTFail("Expected clear failure")
        } catch ClearFailure.forced {}
        let countAfterFailure = await store.count()
        let recordAfterFailure = await store.record(for: "almond milk")
        XCTAssertEqual(countAfterFailure, 1)
        XCTAssertNotNil(recordAfterFailure)
    }

    private func candidate(
        name: String,
        identity: BulkFoodIdentity,
        source: BulkFoodMatchSource,
        unit: NutritionUnit = .grams,
        useCount: Int = 0
    ) -> BulkFoodCandidate {
        BulkFoodCandidate(
            match: match(name: name, identity: identity, source: source, unit: unit),
            priorUseCount: useCount
        )
    }

    private func match(
        name: String,
        identity: BulkFoodIdentity,
        source: BulkFoodMatchSource,
        unit: NutritionUnit = .grams
    ) -> BulkFoodMatch {
        BulkFoodMatch(
            identity: identity,
            displayName: name,
            barcode: {
                if case .barcode(let value) = identity { return value }
                return nil
            }(),
            source: source,
            servingAmount: 100,
            servingUnit: unit,
            caloriesPerServing: 15
        )
    }
}

private enum ClearFailure: Error {
    case forced
}

private final class TestClock: @unchecked Sendable {
    var value: Date
    init(_ value: Date) { self.value = value }
}

private struct StoreFixture {
    let directory: URL
    let url: URL

    init() {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "bulk-food-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        url = directory.appending(path: "store.json")
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
