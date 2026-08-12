import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

final class BulkFoodMatcherTests: XCTestCase {
    func testUniqueExactSavedMatchAvoidsRemoteRequest() async throws {
        let fixture = try MatcherFixture(results: [:])
        defer { fixture.remove() }
        let saved = BulkFoodSavedCandidate(match: match(
            name: "Almond Milk",
            identity: .savedFood(UUID()),
            source: .saved
        ))

        let result = await fixture.matcher.match(
            request: request(query: "almond milk"),
            savedCandidates: [saved]
        )

        XCTAssertEqual(result.automaticSelection?.identity, saved.match.identity)
        XCTAssertEqual(result.candidates.map(\.identity), [saved.match.identity])
        XCTAssertNil(result.failure)
        let callCount = await fixture.fetcher.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testOfflineRemoteFailurePreservesRelevantSavedCandidate() async throws {
        let fixture = try MatcherFixture(results: [
            "apple": .failure(URLError(.notConnectedToInternet))
        ])
        defer { fixture.remove() }
        let saved = BulkFoodSavedCandidate(match: match(
            name: "Apple Sauce",
            identity: .savedFood(UUID()),
            source: .saved
        ))

        let result = await fixture.matcher.match(
            request: request(query: "apple"),
            savedCandidates: [saved]
        )

        XCTAssertEqual(result.candidates.map(\.identity), [saved.match.identity])
        XCTAssertNil(result.automaticSelection)
        XCTAssertEqual(result.failure, .offline)
        let callCount = await fixture.fetcher.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testIrrelevantSavedFoodsDoNotPolluteResults() async throws {
        let fixture = try MatcherFixture(results: [
            "almond milk": .success(matcherPage(
                query: "almond milk",
                foods: [remoteFood(name: "Unsweetened Almond Milk", barcode: "12345678")]
            ))
        ])
        defer { fixture.remove() }
        let unrelated = BulkFoodSavedCandidate(match: match(
            name: "Banana",
            identity: .savedFood(UUID()),
            source: .saved
        ))

        let result = await fixture.matcher.match(
            request: request(query: "almond milk"),
            savedCandidates: [unrelated]
        )

        XCTAssertEqual(result.candidates.map(\.displayName), ["Unsweetened Almond Milk"])
        XCTAssertFalse(result.candidates.contains(where: { $0.displayName == "Banana" }))
    }

    func testRememberedCandidateWinsDuplicateIdentityAfterRanking() async throws {
        let identity = BulkFoodIdentity.barcode("12345678")
        let fixture = try MatcherFixture(results: [:])
        defer { fixture.remove() }
        let saved = BulkFoodSavedCandidate(match: match(
            name: "Unsweetened Milk",
            identity: identity,
            source: .saved,
            barcode: "12345678"
        ))
        let rememberedMatch = match(
            name: "Unsweetened Milk",
            identity: identity,
            source: .openFoodFacts,
            barcode: "12345678"
        )
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let record = BulkFoodLearningRecord(
            normalizedKey: "milk",
            confirmedQuery: "Milk",
            amount: 100,
            unit: .grams,
            amountKnowledge: .userEdited,
            selectedIdentity: identity,
            selectionSnapshot: rememberedMatch,
            useCount: 4,
            createdAt: date,
            lastUsedAt: date,
            lastConfirmedAt: date
        )

        let result = await fixture.matcher.match(
            request: request(query: "milk"),
            savedCandidates: [saved],
            learnedRecord: record,
            allowRemote: false
        )

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates.first?.source, .remembered)
        XCTAssertEqual(result.automaticSelection?.source, .remembered)
    }

    func testRememberedBarcodeWithoutCurrentSavedRecordDoesNotAutoSelect() async throws {
        let identity = BulkFoodIdentity.barcode("12345678")
        let fixture = try MatcherFixture(results: [:])
        defer { fixture.remove() }
        let rememberedMatch = match(name: "Milk", identity: identity, source: .openFoodFacts)
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let record = BulkFoodLearningRecord(
            normalizedKey: "milk",
            confirmedQuery: "Milk",
            amount: 100,
            unit: .grams,
            amountKnowledge: .userEdited,
            selectedIdentity: identity,
            selectionSnapshot: rememberedMatch,
            createdAt: date,
            lastUsedAt: date,
            lastConfirmedAt: date
        )

        let result = await fixture.matcher.match(
            request: request(query: "milk"),
            savedCandidates: [],
            learnedRecord: record,
            allowRemote: false
        )

        XCTAssertNil(result.automaticSelection)
        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testRemoteConcurrencyNeverExceedsConfiguredLimit() async throws {
        let fetcher = ConcurrencyBulkFetcher()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "bulk-matcher-concurrency-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FoodSearchCache(fileURL: directory.appending(path: "cache.json"))
        let service = RemoteFoodSearchService(fetcher: fetcher, cache: cache)
        let matcher = BulkFoodMatcher(
            remoteService: service,
            learningStore: nil,
            languages: ["en"],
            maximumRemoteConcurrency: 2
        )

        let requests = (1...4).map { index in
            BulkFoodMatchRequest(
                draftID: UUID(),
                generation: 1,
                itemID: UUID(),
                revision: 0,
                query: "food \(index)",
                unit: .grams
            )
        }
        async let first = matcher.match(request: requests[0], savedCandidates: [])
        async let second = matcher.match(request: requests[1], savedCandidates: [])
        async let third = matcher.match(request: requests[2], savedCandidates: [])
        async let fourth = matcher.match(request: requests[3], savedCandidates: [])
        _ = await [first, second, third, fourth]

        let callCount = await fetcher.callCount()
        let maximum = await fetcher.maximumConcurrentCalls()
        XCTAssertEqual(callCount, 4)
        XCTAssertLessThanOrEqual(maximum, 2)
    }

    private func request(query: String) -> BulkFoodMatchRequest {
        BulkFoodMatchRequest(
            draftID: UUID(),
            generation: 1,
            itemID: UUID(),
            revision: 0,
            query: query,
            unit: .grams
        )
    }

    private func match(
        name: String,
        identity: BulkFoodIdentity,
        source: BulkFoodMatchSource,
        barcode: String? = nil
    ) -> BulkFoodMatch {
        BulkFoodMatch(
            identity: identity,
            displayName: name,
            barcode: barcode,
            source: source,
            servingAmount: 100,
            servingUnit: .grams,
            caloriesPerServing: 15
        )
    }
}

private struct MatcherFixture {
    let directory: URL
    let fetcher: ResultBulkFetcher
    let matcher: BulkFoodMatcher

    init(results: [String: Result<FoodSearchPage, Error>]) throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "bulk-matcher-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        fetcher = ResultBulkFetcher(results: results)
        let cache = try FoodSearchCache(fileURL: directory.appending(path: "cache.json"))
        let service = RemoteFoodSearchService(fetcher: fetcher, cache: cache)
        matcher = BulkFoodMatcher(
            remoteService: service,
            learningStore: nil,
            languages: ["en"]
        )
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
}

private actor ResultBulkFetcher: FoodSearchFetching {
    private let results: [String: Result<FoodSearchPage, Error>]
    private var calls = 0

    init(results: [String: Result<FoodSearchPage, Error>]) {
        self.results = results
    }

    func search(
        query: String,
        page: Int,
        pageSize: Int,
        languages: [String]
    ) async throws -> FoodSearchPage {
        calls += 1
        return try results[FoodSearchQuery.normalize(query)]?.get()
            ?? matcherPage(query: query, foods: [])
    }

    func callCount() -> Int { calls }
}

private actor ConcurrencyBulkFetcher: FoodSearchFetching {
    private var calls = 0
    private var active = 0
    private var maximum = 0

    func search(
        query: String,
        page: Int,
        pageSize: Int,
        languages: [String]
    ) async throws -> FoodSearchPage {
        calls += 1
        active += 1
        maximum = max(maximum, active)
        defer { active -= 1 }
        try await Task.sleep(for: .milliseconds(100))
        return matcherPage(query: query, foods: [])
    }

    func callCount() -> Int { calls }
    func maximumConcurrentCalls() -> Int { maximum }
}

private func remoteFood(name: String, barcode: String) -> FoodNutrition {
    FoodNutrition(
        barcode: barcode,
        name: name,
        defaultAmount: NutritionAmount(value: 100, unit: .grams),
        caloriesPer100: 15
    )
}

private func matcherPage(query: String, foods: [FoodNutrition]) -> FoodSearchPage {
    FoodSearchPage(
        query: FoodSearchQuery(query),
        foods: foods,
        page: 1,
        pageSize: 5,
        rawHitCount: foods.count
    )
}
