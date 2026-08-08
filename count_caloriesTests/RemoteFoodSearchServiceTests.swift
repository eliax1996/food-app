import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class RemoteFoodSearchServiceTests: XCTestCase {
    func testDefaultPageSizeIsFive() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage)], pageSize: nil)
        defer { fixture.remove() }

        _ = try await fixture.service.load(query: "milk", languages: ["en"])

        XCTAssertEqual(fixture.fetcher.pageSizes, [5])
    }

    func testCacheOnlySnapshotNormalizesAndNeverStartsNetwork() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        _ = try await fixture.cache.store(
            ServiceFixture.positivePage,
            for: fixture.key("milk"),
            fetchedAt: fixture.clock.date,
            replacingPageOne: true
        )
        fixture.advance(1)

        let hit = try await fixture.service.snapshot(query: "  MILK  ", languages: ["en"])
        let miss = try await fixture.service.snapshot(query: "water", languages: ["en"])

        XCTAssertEqual(hit?.key.normalizedQuery, "milk")
        XCTAssertEqual(hit?.lastAccess, fixture.clock.date)
        XCTAssertNil(miss)
        XCTAssertEqual(fixture.fetcher.callCount, 0)
    }

    func testCachedFreshTerminalDoesNotDuplicateRequest() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        _ = try await fixture.service.load(query: "milk", languages: ["en"])
        let second = try await fixture.service.load(query: "milk", languages: ["en"])
        XCTAssertNotNil(second.snapshot)
        XCTAssertEqual(fixture.fetcher.callCount, 1)
    }

    func testAutomaticFetchesNextMissingPage() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.positivePage), .success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        let first = try await fixture.service.load(query: "milk", languages: ["en"])
        let second = try await fixture.service.load(query: "milk", languages: ["en"])
        XCTAssertEqual(first.snapshot?.pages.keys.sorted(), [1])
        XCTAssertEqual(second.snapshot?.pages.keys.sorted(), [1, 2])
        XCTAssertEqual(fixture.fetcher.pages, [1, 2])
    }

    func testFreshAndStaleTerminalRules() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage), .success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        _ = try await fixture.service.load(query: "milk", languages: ["en"])
        let fresh = try await fixture.service.load(query: "milk", languages: ["en"])
        XCTAssertNotNil(fresh.snapshot)
        fixture.advance(RemoteFoodSearchService.terminalTTL + 1)
        let stale = try await fixture.service.load(query: "milk", languages: ["en"])
        XCTAssertEqual(stale.snapshot?.pages.keys.sorted(), [1])
        XCTAssertEqual(fixture.fetcher.pages, [1, 1])
    }

    func testPositiveTerminalPageExpiresBeforeEmptyTerminalKnowledge() async throws {
        let positiveFixture = try ServiceFixture(results: [
            .success(ServiceFixture.terminalPage),
            .success(ServiceFixture.terminalPage)
        ])
        defer { positiveFixture.remove() }
        _ = try await positiveFixture.service.load(query: "milk", languages: ["en"])
        positiveFixture.advance(RemoteFoodSearchService.positiveTTL + 1)

        let refreshed = try await positiveFixture.service.load(query: "milk", languages: ["en"])

        XCTAssertEqual(refreshed.snapshot?.pages.keys.sorted(), [1])
        XCTAssertEqual(positiveFixture.fetcher.pages, [1, 1])

        let emptyFixture = try ServiceFixture(results: [.success(ServiceFixture.emptyTerminalPage)])
        defer { emptyFixture.remove() }
        _ = try await emptyFixture.service.load(query: "none", languages: ["en"])
        emptyFixture.advance(RemoteFoodSearchService.positiveTTL + 1)

        let cached = try await emptyFixture.service.load(query: "none", languages: ["en"])

        XCTAssertNotNil(cached.snapshot)
        XCTAssertEqual(emptyFixture.fetcher.pages, [1])
    }

    func testStalePositivePageReplacesGeneration() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.positivePage), .success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        _ = try await fixture.service.load(query: "milk", languages: ["en"])
        fixture.advance(RemoteFoodSearchService.positiveTTL + 1)
        _ = try await fixture.service.load(query: "milk", languages: ["en"])
        let cachedSnapshot = await fixture.cache.snapshot(for: fixture.key("milk"))
        let snapshot = try XCTUnwrap(cachedSnapshot)
        XCTAssertEqual(fixture.fetcher.pages, [1, 1])
        XCTAssertEqual(snapshot.generation, 2)
        XCTAssertEqual(snapshot.pages.keys.sorted(), [1])
    }

    func testAutomaticStaleLaterPositivePageReplacesGeneration() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        let key = fixture.key("milk")
        _ = try await fixture.cache.store(
            ServiceFixture.positivePage,
            for: key,
            fetchedAt: fixture.clock.date,
            replacingPageOne: true
        )
        _ = try await fixture.cache.store(
            FoodSearchPage(
                query: FoodSearchQuery("milk"),
                foods: [],
                page: 2,
                pageSize: 2,
                rawHitCount: 2
            ),
            for: key,
            fetchedAt: fixture.clock.date.addingTimeInterval(-RemoteFoodSearchService.positiveTTL - 1),
            expectedGeneration: 1
        )

        let result = try await fixture.service.load(query: "milk", languages: ["en"])
        let cachedSnapshot = await fixture.cache.snapshot(for: key)
        let snapshot = try XCTUnwrap(cachedSnapshot)

        XCTAssertEqual(result.snapshot?.pages.keys.sorted(), [1])
        XCTAssertEqual(fixture.fetcher.pages, [1])
        XCTAssertEqual(snapshot.generation, 2)
        XCTAssertEqual(snapshot.pages.keys.sorted(), [1])
    }

    func testExplicitLoadMoreRevalidatesFreshTerminal() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage), .success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        _ = try await fixture.service.load(query: "milk", languages: ["en"])
        _ = try await fixture.service.load(query: "milk", languages: ["en"], intent: .explicitLoadMore)
        XCTAssertEqual(fixture.fetcher.pages, [1, 1])
    }

    func testExplicitLoadMoreUsesNextMissingPageForStaleNonterminalCache() async throws {
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage)])
        defer { fixture.remove() }
        let key = fixture.key("milk")
        _ = try await fixture.cache.store(
            ServiceFixture.positivePage,
            for: key,
            fetchedAt: fixture.clock.date,
            replacingPageOne: true
        )
        _ = try await fixture.cache.store(
            FoodSearchPage(
                query: FoodSearchQuery("milk"),
                foods: [],
                page: 2,
                pageSize: 2,
                rawHitCount: 2
            ),
            for: key,
            fetchedAt: fixture.clock.date.addingTimeInterval(-RemoteFoodSearchService.positiveTTL - 1),
            expectedGeneration: 1
        )

        let result = try await fixture.service.load(
            query: "milk",
            languages: ["en"],
            intent: .explicitLoadMore
        )

        XCTAssertEqual(result.snapshot?.pages.keys.sorted(), [1, 2, 3])
        XCTAssertEqual(fixture.fetcher.pages, [3])
    }

    func testCoalescesSameCacheKeyPageAndGeneration() async throws {
        let fixture = try ServiceFixture(gate: SearchGate())
        defer { fixture.remove() }
        let gate = try XCTUnwrap(fixture.gate)
        let service = fixture.service
        async let first = service.load(query: "milk", languages: ["en"])
        async let second = service.load(query: "milk", languages: ["en"])
        await gate.waitForStart()
        await gate.succeed(ServiceFixture.terminalPage)
        _ = try await first
        _ = try await second
        let calls = await gate.callCount()
        XCTAssertEqual(calls, 1)
    }

    func testCoalescedReplacementLosingGenerationReturnsCurrentSnapshot() async throws {
        let fixture = try ServiceFixture(gate: SearchGate())
        defer { fixture.remove() }
        let gate = try XCTUnwrap(fixture.gate)
        let service = fixture.service
        async let first = service.load(query: "milk", languages: ["en"])
        async let second = service.load(query: "milk", languages: ["en"])

        await gate.waitForStart()
        await gate.succeed(ServiceFixture.terminalPage)
        let firstResult = try await first
        let secondResult = try await second

        XCTAssertEqual(firstResult.snapshot?.generation, 1)
        XCTAssertEqual(secondResult.snapshot?.generation, 1)
        XCTAssertEqual(firstResult.snapshot?.pages.keys.sorted(), [1])
        XCTAssertEqual(secondResult.snapshot?.pages.keys.sorted(), [1])
    }

    func testRateLimitAllowsTenStartsThenExpiresWindow() async throws {
        let fixture = try ServiceFixture(results: Array(repeating: .success(ServiceFixture.terminalPage), count: 11))
        defer { fixture.remove() }
        for number in 0 ..< 10 {
            _ = try await fixture.service.load(query: "milk \(number)", languages: ["en"])
        }
        do {
            _ = try await fixture.service.load(query: "milk 11", languages: ["en"])
            XCTFail("Expected local rate limit.")
        } catch let error as FoodSearchRateLimitError {
            XCTAssertEqual(error.retryAfter, RemoteFoodSearchService.rateLimitWindow)
            XCTAssertEqual(error.retryAt, fixture.clock.date.addingTimeInterval(RemoteFoodSearchService.rateLimitWindow))
        }
        fixture.advance(RemoteFoodSearchService.rateLimitWindow)
        _ = try await fixture.service.load(query: "milk 11", languages: ["en"])
        XCTAssertEqual(fixture.fetcher.callCount, 11)
    }

    func testCancelledWaiterLeavesSharedRequestRunning() async throws {
        let fixture = try ServiceFixture(gate: SearchGate())
        defer { fixture.remove() }
        let gate = try XCTUnwrap(fixture.gate)
        let service = fixture.service
        let oldWaiter = Task { try await service.load(query: "milk", languages: ["en"]) }
        await gate.waitForStart()
        oldWaiter.cancel()
        await gate.succeed(ServiceFixture.terminalPage)
        _ = await oldWaiter.result
        _ = try await service.load(query: "milk", languages: ["en"])
        let calls = await gate.callCount()
        XCTAssertEqual(calls, 1)
    }

    func testRemoteErrorPreservesCachedPages() async throws {
        let transportError = URLError(.notConnectedToInternet)
        let fixture = try ServiceFixture(results: [.success(ServiceFixture.terminalPage), .failure(transportError)])
        defer { fixture.remove() }
        _ = try await fixture.service.load(query: "milk", languages: ["en"])
        fixture.advance(RemoteFoodSearchService.terminalTTL + 1)
        do {
            _ = try await fixture.service.load(query: "milk", languages: ["en"])
            XCTFail("Expected transport error.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }
        let cachedSnapshot = await fixture.cache.snapshot(for: fixture.key("milk"))
        let snapshot = try XCTUnwrap(cachedSnapshot)
        XCTAssertEqual(snapshot.pages[1]?.page, ServiceFixture.terminalPage)
    }
}

private final class ServiceClock: @unchecked Sendable {
    var date = Date(timeIntervalSinceReferenceDate: 10_000)
}

private final class ServiceFixture {
    static let positivePage = FoodSearchPage(query: FoodSearchQuery("milk"), foods: [], page: 1, pageSize: 2, rawHitCount: 2)
    static let terminalPage = FoodSearchPage(query: FoodSearchQuery("milk"), foods: [], page: 1, pageSize: 2, rawHitCount: 1)
    static let emptyTerminalPage = FoodSearchPage(query: FoodSearchQuery("none"), foods: [], page: 1, pageSize: 2, rawHitCount: 0)

    let directory: URL
    let clock = ServiceClock()
    let fetcher: ImmediateSearchFetcher
    let cache: FoodSearchCache
    let service: RemoteFoodSearchService
    let gate: SearchGate?

    init(
        results: [Result<FoodSearchPage, Error>] = [],
        gate: SearchGate? = nil,
        pageSize: Int? = 2
    ) throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        clock.date = Date(timeIntervalSinceReferenceDate: 10_000)
        self.gate = gate
        fetcher = ImmediateSearchFetcher(results: results, gate: gate)
        cache = try FoodSearchCache(fileURL: directory.appending(path: "cache.json"), now: { [clock] in clock.date })
        if let pageSize {
            service = RemoteFoodSearchService(fetcher: fetcher, cache: cache, pageSize: pageSize, now: { [clock] in clock.date })
        } else {
            service = RemoteFoodSearchService(fetcher: fetcher, cache: cache, now: { [clock] in clock.date })
        }
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
    func advance(_ seconds: TimeInterval) { clock.date = clock.date.addingTimeInterval(seconds) }
    func key(_ query: String) -> FoodSearchCacheKey { FoodSearchCacheKey(query: query, languages: ["en"]) }
}

private final class ImmediateSearchFetcher: FoodSearchFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<FoodSearchPage, Error>]
    private let gate: SearchGate?
    private(set) var pages: [Int] = []
    private(set) var pageSizes: [Int] = []

    init(results: [Result<FoodSearchPage, Error>], gate: SearchGate?) {
        self.results = results
        self.gate = gate
    }

    var callCount: Int { lock.withLock { pages.count } }

    func search(query: String, page: Int, pageSize: Int, languages: [String]) async throws -> FoodSearchPage {
        let result = lock.withLock {
            pages.append(page)
            pageSizes.append(pageSize)
            return results.isEmpty ? .success(ServiceFixture.terminalPage) : results.removeFirst()
        }
        let response: FoodSearchPage
        if let gate {
            response = try await gate.next()
        } else {
            response = try result.get()
        }
        return FoodSearchPage(
            query: response.query,
            foods: response.foods,
            page: page,
            pageSize: pageSize,
            rawHitCount: response.rawHitCount
        )
    }
}

private actor SearchGate {
    private var calls = 0
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var pageWaiters: [CheckedContinuation<FoodSearchPage, Error>] = []

    func next() async throws -> FoodSearchPage {
        calls += 1
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return try await withCheckedThrowingContinuation { pageWaiters.append($0) }
    }

    func waitForStart() async {
        guard calls == 0 else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func succeed(_ page: FoodSearchPage) {
        let waiters = pageWaiters
        pageWaiters.removeAll()
        waiters.forEach { $0.resume(returning: page) }
    }

    func callCount() -> Int { calls }
}
