import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class FoodSearchCacheTests: XCTestCase {
    func testPersistsAcrossRecreation() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let key = fixture.key("oat milk")
        let cache = try fixture.cache()
        _ = try await cache.store(fixture.page(query: "oat milk", page: 1, rawHitCount: 1), for: key, fetchedAt: fixture.clock.date, replacingPageOne: true)

        let recreated = try fixture.cache()
        let recreatedSnapshot = await recreated.snapshot(for: key)
        let snapshot = try XCTUnwrap(recreatedSnapshot)
        XCTAssertEqual(snapshot.pages[1]?.page.query.normalizedQuery, "oat milk")
        XCTAssertEqual(snapshot.generation, 1)
    }

    func testProjectionVersionKeepsCalorieOnlySearchCacheOutOfNutrientResults() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let cache = try fixture.cache()
        let oldKey = FoodSearchCacheKey(
            query: "oat milk",
            languages: ["en"],
            projectionSchemaVersion: 1
        )
        _ = try await cache.store(
            fixture.page(query: "oat milk", page: 1, rawHitCount: 1),
            for: oldKey,
            fetchedAt: fixture.clock.date,
            replacingPageOne: true
        )

        let currentSnapshot = await cache.snapshot(for: fixture.key("oat milk"))
        let oldSnapshot = await cache.snapshot(for: oldKey)

        XCTAssertEqual(FoodSearchCacheKey.currentProjectionSchemaVersion, 2)
        XCTAssertNil(currentSnapshot)
        XCTAssertNotNil(oldSnapshot)
    }

    func testPagesTerminalAndPageOneReplacement() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let cache = try fixture.cache()
        let key = fixture.key("milk")
        _ = try await cache.store(fixture.page(query: "milk", page: 1, rawHitCount: 2), for: key, fetchedAt: fixture.clock.date, expectedGeneration: 0, replacingPageOne: true)
        _ = try await cache.store(fixture.page(query: "milk", page: 2, rawHitCount: 1), for: key, fetchedAt: fixture.clock.date, expectedGeneration: 1)
        let terminalSnapshot = await cache.snapshot(for: key)
        let terminal = try XCTUnwrap(terminalSnapshot)
        XCTAssertEqual(terminal.terminalPage, 2)

        _ = try await cache.store(fixture.page(query: "milk", page: 1, rawHitCount: 1), for: key, fetchedAt: fixture.clock.date, expectedGeneration: 1, replacingPageOne: true)
        let replacedSnapshot = await cache.snapshot(for: key)
        let replaced = try XCTUnwrap(replacedSnapshot)
        XCTAssertEqual(replaced.generation, 2)
        XCTAssertEqual(replaced.pages.keys.sorted(), [1])
        XCTAssertEqual(replaced.terminalPage, 1)
    }

    func testReadTouchesMemoryButDoesNotRewriteFile() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let cache = try fixture.cache()
        let key = fixture.key("water")
        _ = try await cache.store(fixture.page(query: "water", page: 1, rawHitCount: 1), for: key, fetchedAt: fixture.clock.date, replacingPageOne: true)
        let before = try Data(contentsOf: fixture.fileURL)
        fixture.clock.date = fixture.clock.date.addingTimeInterval(10)

        _ = await cache.snapshot(for: key)
        XCTAssertEqual(try Data(contentsOf: fixture.fileURL), before)
    }

    func testCorruptionRecoversAsEmptyCache() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try Data("not json".utf8).write(to: fixture.fileURL)
        let cache = try fixture.cache()
        let snapshot = await cache.snapshot(for: fixture.key("broken"))
        XCTAssertNil(snapshot)
    }

    func testCountAndEncodedByteCapsEvictLeastRecentlyUsedQuery() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let countCache = try fixture.cache(maximumQueries: 2)
        let first = fixture.key("first")
        let second = fixture.key("second")
        let third = fixture.key("third")
        _ = try await countCache.store(fixture.page(query: "first", page: 1, rawHitCount: 1), for: first, fetchedAt: fixture.clock.date, replacingPageOne: true)
        fixture.advance()
        _ = try await countCache.store(fixture.page(query: "second", page: 1, rawHitCount: 1), for: second, fetchedAt: fixture.clock.date, replacingPageOne: true)
        fixture.advance()
        _ = await countCache.snapshot(for: first)
        fixture.advance()
        _ = try await countCache.store(fixture.page(query: "third", page: 1, rawHitCount: 1), for: third, fetchedAt: fixture.clock.date, replacingPageOne: true)
        let firstSnapshot = await countCache.snapshot(for: first)
        let secondSnapshot = await countCache.snapshot(for: second)
        let thirdSnapshot = await countCache.snapshot(for: third)
        XCTAssertNotNil(firstSnapshot)
        XCTAssertNil(secondSnapshot)
        XCTAssertNotNil(thirdSnapshot)

        let sizingCache = try fixture.cache(fileName: "sizing.json")
        _ = try await sizingCache.store(fixture.page(query: "byte one", page: 1, rawHitCount: 1), for: fixture.key("byte one"), fetchedAt: fixture.clock.date, replacingPageOne: true)
        let oneEntryBytes = try Data(contentsOf: fixture.directory.appending(path: "sizing.json")).count
        let byteCache = try fixture.cache(fileName: "bytes.json", maximumBytes: oneEntryBytes + 20)
        _ = try await byteCache.store(fixture.page(query: "byte one", page: 1, rawHitCount: 1), for: fixture.key("byte one"), fetchedAt: fixture.clock.date, replacingPageOne: true)
        _ = try await byteCache.store(fixture.page(query: "byte two", page: 1, rawHitCount: 1), for: fixture.key("byte two"), fetchedAt: fixture.clock.date, replacingPageOne: true)
        let byteOneSnapshot = await byteCache.snapshot(for: fixture.key("byte one"))
        let byteTwoSnapshot = await byteCache.snapshot(for: fixture.key("byte two"))
        XCTAssertNil(byteOneSnapshot)
        XCTAssertNotNil(byteTwoSnapshot)
    }

    func testRepresentativeQueryFootprintFitsDefaultCountAndByteCaps() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let sampleCount = 64
        let cache = try fixture.cache()

        for queryIndex in 0 ..< sampleCount {
            let query = "representative packaged food query \(queryIndex)"
            let foods = (0 ..< 5).map { foodIndex in
                FoodNutrition(
                    barcode: String(format: "%013d", queryIndex * 10 + foodIndex + 1),
                    name: "Representative packaged food \(queryIndex)-\(foodIndex)",
                    defaultAmount: NutritionAmount(value: 250, unit: .grams),
                    caloriesPer100: 412.5
                )
            }
            let page = FoodSearchPage(
                query: FoodSearchQuery(query),
                foods: foods,
                page: 1,
                pageSize: 5,
                rawHitCount: 5
            )
            _ = try await cache.store(
                page,
                for: fixture.key(query),
                fetchedAt: fixture.clock.date,
                replacingPageOne: true
            )
            fixture.advance()
        }

        let measuredBytes = try Data(contentsOf: fixture.fileURL).count
        let projectedBytes = Int(
            (Double(measuredBytes) / Double(sampleCount) * Double(FoodSearchCache.defaultMaximumQueries)).rounded(.up)
        )
        print("Food search cache measurement: \(sampleCount) representative queries = \(measuredBytes) bytes; 2,048-query projection = \(projectedBytes) bytes")
        XCTAssertLessThan(projectedBytes, FoodSearchCache.defaultMaximumBytes)
    }
}

private final class FoodSearchCacheClock: @unchecked Sendable {
    var date = Date(timeIntervalSinceReferenceDate: 1_000)
}

private final class Fixture {
    let directory: URL
    let fileURL: URL
    let clock = FoodSearchCacheClock()

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "cache.json")
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }

    func cache(fileName: String = "cache.json", maximumQueries: Int = 2_048, maximumBytes: Int = FoodSearchCache.defaultMaximumBytes) throws -> FoodSearchCache {
        try FoodSearchCache(fileURL: directory.appending(path: fileName), maximumQueries: maximumQueries, maximumBytes: maximumBytes, now: { [clock] in clock.date })
    }

    func key(_ query: String) -> FoodSearchCacheKey { FoodSearchCacheKey(query: query, languages: ["en"]) }

    func advance(_ seconds: TimeInterval = 1) { clock.date = clock.date.addingTimeInterval(seconds) }

    func page(query: String, page: Int, rawHitCount: Int) -> FoodSearchPage {
        FoodSearchPage(query: FoodSearchQuery(query), foods: [], page: page, pageSize: 2, rawHitCount: rawHitCount)
    }
}
