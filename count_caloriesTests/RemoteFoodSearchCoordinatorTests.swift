import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class RemoteFoodSearchCoordinatorTests: XCTestCase {
    func testQualifyingUpdateSetsLoadingSynchronously() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let coordinator = fixture.coordinator()

        coordinator.update(query: "milk", localCandidates: [])

        XCTAssertTrue(coordinator.isLoading)
        await coordinator.waitForIdle()
        XCTAssertFalse(coordinator.isLoading)
    }

    func testQueryShorterThanThreeDoesNotCallService() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let coordinator = fixture.coordinator()

        coordinator.update(query: "ab", localCandidates: [])
        await coordinator.waitForIdle()

        XCTAssertEqual(fixture.fetcher.callCount, 0)
        XCTAssertTrue(coordinator.foods.isEmpty)
    }

    func testFiveUsefulLocalCandidatesSkipAutomaticCall() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let debounce = DebounceCounter()
        let coordinator = fixture.coordinator(debounce: { debounce.increment() })
        let candidates = Array(repeating: FoodSearchLocalCandidate(), count: 5)

        coordinator.update(query: "milk", localCandidates: candidates)
        await coordinator.waitForIdle()

        XCTAssertEqual(fixture.fetcher.callCount, 0)
        XCTAssertEqual(debounce.value, 0)
    }

    func testFewerThanFiveUsefulLocalCandidatesMakeOneAutomaticCall() async throws {
        let fixture = try Fixture(results: [.success(fixturePage(query: "milk", page: 1, foods: [fixtureFood("12345678")], rawHitCount: 1))])
        defer { fixture.remove() }
        let coordinator = fixture.coordinator()

        coordinator.update(
            query: "milk",
            localCandidates: [FoodSearchLocalCandidate(barcode: "87654321")]
        )
        await coordinator.waitForIdle()

        XCTAssertEqual(fixture.fetcher.pages, [1])
        XCTAssertEqual(coordinator.foods.map(\.barcode), ["12345678"])
    }

    func testCachedTerminalResultClearsLoadingWithoutNetwork() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let page = fixturePage(query: "milk", page: 1, foods: [], rawHitCount: 0)
        _ = try await fixture.cache.store(
            page,
            for: fixture.key("milk"),
            fetchedAt: .now,
            replacingPageOne: true
        )
        let coordinator = fixture.coordinator()

        coordinator.update(query: "milk", localCandidates: [])

        XCTAssertTrue(coordinator.isLoading)
        await coordinator.waitForIdle()
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertTrue(coordinator.isComplete)
        XCTAssertTrue(coordinator.foods.isEmpty)
        XCTAssertEqual(fixture.fetcher.callCount, 0)
    }

    func testCachedPagesApplyImmediatelyInPageOrder() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = fixturePage(
            query: "milk",
            page: 1,
            foods: [fixtureFood("11111111")],
            rawHitCount: 5
        )
        let second = fixturePage(
            query: "milk",
            page: 2,
            foods: [fixtureFood("22222222")],
            rawHitCount: 1
        )
        _ = try await fixture.cache.store(
            first,
            for: fixture.key("milk"),
            fetchedAt: .now,
            replacingPageOne: true
        )
        _ = try await fixture.cache.store(
            second,
            for: fixture.key("milk"),
            fetchedAt: .now,
            expectedGeneration: 1
        )

        let coordinator = fixture.coordinator()
        coordinator.update(
            query: "milk",
            localCandidates: Array(repeating: FoodSearchLocalCandidate(), count: 5)
        )
        await coordinator.waitForIdle()

        XCTAssertEqual(coordinator.foods.map(\.barcode), ["11111111", "22222222"])
        XCTAssertEqual(fixture.fetcher.callCount, 0)
    }

    func testRemoteBarcodesDeduplicateAndSuppressOnlyValidLocalBarcode() async throws {
        let pageFoods = [
            fixtureFood("11111111", name: "Saved"),
            fixtureFood("22222222", name: "First remote"),
            fixtureFood("22222222", name: "Duplicate remote"),
            fixtureFood("123", name: "Short invalid"),
            fixtureFood("123456789012345", name: "Long invalid")
        ]
        let fixture = try Fixture(
            results: [.success(fixturePage(query: "milk", page: 1, foods: pageFoods, rawHitCount: 5))]
        )
        defer { fixture.remove() }
        let coordinator = fixture.coordinator()

        coordinator.update(
            query: "milk",
            localCandidates: [FoodSearchLocalCandidate(barcode: "11111111")]
        )
        await coordinator.waitForIdle()

        XCTAssertEqual(coordinator.foods.map(\.barcode), ["22222222"])
    }

    func testTerminalEmptyResultCompletesWithoutFailure() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let coordinator = fixture.coordinator()

        coordinator.update(query: "milk", localCandidates: [])
        await coordinator.waitForIdle()

        XCTAssertTrue(coordinator.foods.isEmpty)
        XCTAssertTrue(coordinator.isComplete)
        XCTAssertNil(coordinator.failure)
        XCTAssertFalse(coordinator.isLoading)
    }

    func testNewQueryIgnoresCanceledOldCompletion() async throws {
        let fetcher = ControlledFetcher()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FoodSearchCache(fileURL: directory.appending(path: "cache.json"))
        let service = RemoteFoodSearchService(fetcher: fetcher, cache: cache)
        let coordinator = RemoteFoodSearchCoordinator(
            service: service,
            languages: ["en"],
            debounce: {}
        )

        coordinator.update(query: "old", localCandidates: [])
        await fetcher.waitForRequest("old")
        coordinator.update(query: "new", localCandidates: [])
        await fetcher.waitForRequest("new")

        await fetcher.succeed("old", foods: [fixtureFood("11111111", name: "Old")], rawHitCount: 1)
        await fetcher.fail("new")
        await coordinator.waitForIdle()

        XCTAssertTrue(coordinator.foods.isEmpty)
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertFalse(coordinator.isLoading)
    }

    func testCancelClearsLoadingImmediately() async throws {
        let fetcher = ControlledFetcher()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FoodSearchCache(fileURL: directory.appending(path: "cache.json"))
        let coordinator = RemoteFoodSearchCoordinator(
            service: RemoteFoodSearchService(fetcher: fetcher, cache: cache),
            languages: ["en"],
            debounce: {}
        )

        coordinator.update(query: "milk", localCandidates: [])
        await fetcher.waitForRequest("milk")
        coordinator.cancel()

        XCTAssertFalse(coordinator.isLoading)
        await fetcher.succeed("milk", foods: [], rawHitCount: 0)
    }

    func testExplicitLoadMoreCallsRemoteEvenWithFiveLocalCandidates() async throws {
        let fixture = try Fixture(
            results: [.success(fixturePage(query: "milk", page: 1, foods: [fixtureFood("33333333")], rawHitCount: 1))]
        )
        defer { fixture.remove() }
        let coordinator = fixture.coordinator()

        coordinator.loadMore(
            query: "milk",
            localCandidates: Array(repeating: FoodSearchLocalCandidate(), count: 5)
        )
        await coordinator.waitForIdle()

        XCTAssertEqual(fixture.fetcher.pages, [1])
        XCTAssertEqual(coordinator.foods.map(\.barcode), ["33333333"])
    }

    func testFailureClassification() async throws {
        func searchFailure(_ error: Error) async throws -> RemoteFoodSearchFailure {
            let fixture = try Fixture(results: [.failure(error)])
            defer { fixture.remove() }
            let coordinator = fixture.coordinator()
            coordinator.update(query: "milk", localCandidates: [])
            await coordinator.waitForIdle()
            return try XCTUnwrap(coordinator.failure)
        }

        let offline = try await searchFailure(URLError(.notConnectedToInternet))
        let rateLimited = try await searchFailure(
            FoodSearchRateLimitError(retryAfter: 1, retryAt: .now)
        )
        let unavailable = try await searchFailure(FoodSearchError.timedOut)
        let generic = try await searchFailure(TestError.failed)

        XCTAssertEqual(offline, .offline)
        XCTAssertEqual(rateLimited, .rateLimited)
        XCTAssertEqual(unavailable, .unavailable)
        XCTAssertEqual(generic, .generic)
    }

    func testFailureKeepsCachedRowsAndSurfacesError() async throws {
        let fixture = try Fixture(results: [.failure(TestError.failed)])
        defer { fixture.remove() }
        let cachedFood = fixtureFood("44444444", name: "Cached")
        let cachedPage = fixturePage(
            query: "milk",
            page: 1,
            foods: [cachedFood],
            rawHitCount: 5
        )
        _ = try await fixture.cache.store(
            cachedPage,
            for: fixture.key("milk"),
            fetchedAt: .now,
            replacingPageOne: true
        )
        let coordinator = fixture.coordinator()

        coordinator.update(query: "milk", localCandidates: [])
        await coordinator.waitForIdle()

        XCTAssertEqual(coordinator.foods, [cachedFood])
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertEqual(fixture.fetcher.pages, [2])
    }
}

private enum TestError: Error {
    case failed
}

private final class DebounceCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.withLock { count += 1 }
    }

    var value: Int {
        lock.withLock { count }
    }
}

private final class Fixture {
    let directory: URL
    let cache: FoodSearchCache
    let fetcher: ScriptedFetcher

    init(results: [Result<FoodSearchPage, Error>] = []) throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cache = try FoodSearchCache(fileURL: directory.appending(path: "cache.json"))
        fetcher = ScriptedFetcher(results: results)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    func key(_ query: String) -> FoodSearchCacheKey {
        FoodSearchCacheKey(query: query, languages: ["en"])
    }

    @MainActor
    func coordinator(
        debounce: @escaping @Sendable () async throws -> Void = {}
    ) -> RemoteFoodSearchCoordinator {
        RemoteFoodSearchCoordinator(service: service, languages: ["en"], debounce: debounce)
    }

    private var service: RemoteFoodSearchService {
        RemoteFoodSearchService(fetcher: fetcher, cache: cache)
    }
}

private final class ScriptedFetcher: FoodSearchFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<FoodSearchPage, Error>]
    private(set) var pages: [Int] = []

    init(results: [Result<FoodSearchPage, Error>]) {
        self.results = results
    }

    var callCount: Int {
        lock.withLock { pages.count }
    }

    func search(query: String, page: Int, pageSize: Int, languages: [String]) async throws -> FoodSearchPage {
        let result = lock.withLock {
            pages.append(page)
            return results.isEmpty
                ? .success(fixturePage(query: query, page: page, foods: [], rawHitCount: 0))
                : results.removeFirst()
        }
        let response = try result.get()
        return FoodSearchPage(
            query: FoodSearchQuery(query),
            foods: response.foods,
            page: page,
            pageSize: pageSize,
            rawHitCount: response.rawHitCount
        )
    }
}

private actor ControlledFetcher: FoodSearchFetching {
    private var requestedQueries = Set<String>()
    private var requestWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var responseWaiters: [String: [CheckedContinuation<FoodSearchPage, Error>]] = [:]

    func search(query: String, page: Int, pageSize: Int, languages: [String]) async throws -> FoodSearchPage {
        let normalized = FoodSearchQuery.normalize(query)
        requestedQueries.insert(normalized)
        let startWaiters = requestWaiters.removeValue(forKey: normalized) ?? []
        startWaiters.forEach { $0.resume() }
        let response = try await withCheckedThrowingContinuation { continuation in
            responseWaiters[normalized, default: []].append(continuation)
        }
        return FoodSearchPage(
            query: FoodSearchQuery(query),
            foods: response.foods,
            page: page,
            pageSize: pageSize,
            rawHitCount: response.rawHitCount
        )
    }

    func waitForRequest(_ query: String) async {
        let normalized = FoodSearchQuery.normalize(query)
        guard !requestedQueries.contains(normalized) else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[normalized, default: []].append(continuation)
        }
    }

    func succeed(_ query: String, foods: [FoodNutrition], rawHitCount: Int) {
        let normalized = FoodSearchQuery.normalize(query)
        let waiters = responseWaiters.removeValue(forKey: normalized) ?? []
        let page = FoodSearchPage(
            query: FoodSearchQuery(query),
            foods: foods,
            page: 1,
            pageSize: 5,
            rawHitCount: rawHitCount
        )
        waiters.forEach { $0.resume(returning: page) }
    }

    func fail(_ query: String, error: Error = TestError.failed) {
        let normalized = FoodSearchQuery.normalize(query)
        let waiters = responseWaiters.removeValue(forKey: normalized) ?? []
        waiters.forEach { $0.resume(throwing: error) }
    }
}

private func fixturePage(
    query: String,
    page: Int,
    foods: [FoodNutrition],
    rawHitCount: Int
) -> FoodSearchPage {
    FoodSearchPage(
        query: FoodSearchQuery(query),
        foods: foods,
        page: page,
        pageSize: 5,
        rawHitCount: rawHitCount
    )
}

private func fixtureFood(_ barcode: String, name: String = "Food") -> FoodNutrition {
    FoodNutrition(
        barcode: barcode,
        name: name,
        defaultAmount: NutritionAmount(value: 100, unit: .grams),
        caloriesPer100: 10
    )
}
