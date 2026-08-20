import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class NutritionLookupTests: XCTestCase {
    func testPrimaryResponseCancelsDelayedFallback() async throws {
        let primaryNutrition = sampleNutrition(barcode: "12345678", name: "V3 product")
        let primary = StubNutritionClient(result: .found(primaryNutrition))
        let fallback = StubNutritionClient(result: .found(sampleNutrition(barcode: "12345678", name: "V2 product")))
        let client = OpenFoodFactsClient(
            primary: primary,
            fallback: fallback,
            fallbackDelay: .milliseconds(100),
            responseTimeout: .seconds(1)
        )

        let result = try await client.fetchNutrition(for: "12345678")

        let primaryCallCount = await primary.callCount
        let fallbackCallCount = await fallback.callCount
        XCTAssertEqual(result, .found(primaryNutrition))
        XCTAssertEqual(primaryCallCount, 1)
        XCTAssertEqual(fallbackCallCount, 0)
    }

    func testFallbackWinsWhenPrimaryIsSlow() async throws {
        let fallbackNutrition = sampleNutrition(barcode: "12345678", name: "V2 fallback")
        let primary = StubNutritionClient(
            result: .found(sampleNutrition(barcode: "12345678", name: "Slow v3")),
            delay: .milliseconds(250)
        )
        let fallback = StubNutritionClient(
            result: .found(fallbackNutrition),
            delay: .milliseconds(10)
        )
        let client = OpenFoodFactsClient(
            primary: primary,
            fallback: fallback,
            fallbackDelay: .milliseconds(20),
            responseTimeout: .seconds(1)
        )

        let result = try await client.fetchNutrition(for: "12345678")

        let primaryCallCount = await primary.callCount
        let fallbackCallCount = await fallback.callCount
        XCTAssertEqual(result, .found(fallbackNutrition))
        XCTAssertEqual(primaryCallCount, 1)
        XCTAssertEqual(fallbackCallCount, 1)
    }

    func testFallbackReplacesIncompletePrimaryProduct() async throws {
        let fallbackNutrition = sampleNutrition(barcode: "12345678", name: "Complete v2 product")
        let primary = StubNutritionClient(result: .incompleteProduct)
        let fallback = StubNutritionClient(result: .found(fallbackNutrition))
        let client = OpenFoodFactsClient(
            primary: primary,
            fallback: fallback,
            fallbackDelay: .seconds(1),
            responseTimeout: .milliseconds(100)
        )

        let result = try await client.fetchNutrition(for: "12345678")

        XCTAssertEqual(result, .found(fallbackNutrition))
    }

    func testSharedRateLimitDoesNotSpendAnotherRequestOnFallback() async {
        for statusCode in [429, 503] {
            let primary = StubNutritionClient(error: .serverError(statusCode))
            let fallback = StubNutritionClient(result: .notFound)
            let client = OpenFoodFactsClient(
                primary: primary,
                fallback: fallback,
                fallbackDelay: .milliseconds(100),
                responseTimeout: .seconds(1)
            )

            do {
                _ = try await client.fetchNutrition(for: "12345678")
                XCTFail("Expected shared rate-limit error.")
            } catch let error as FoodNutritionFetchError {
                XCTAssertEqual(error, .serverError(statusCode))
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            let fallbackCallCount = await fallback.callCount
            XCTAssertEqual(fallbackCallCount, 0)
        }
    }

    func testInFlightFallbackCanFindProductAfterSlowPrimaryNotFound() async throws {
        let fallbackNutrition = sampleNutrition(barcode: "12345678", name: "V2 product")
        let primary = StubNutritionClient(result: .notFound, delay: .milliseconds(20))
        let fallback = StubNutritionClient(
            result: .found(fallbackNutrition),
            delay: .milliseconds(40)
        )
        let client = OpenFoodFactsClient(
            primary: primary,
            fallback: fallback,
            fallbackDelay: .milliseconds(1),
            responseTimeout: .seconds(1)
        )

        let result = try await client.fetchNutrition(for: "12345678")

        XCTAssertEqual(result, .found(fallbackNutrition))
    }

    func testInFlightFallbackCanCompleteAfterLatePrimaryRateLimit() async throws {
        let fallbackNutrition = sampleNutrition(barcode: "12345678", name: "In-flight v2 fallback")
        let primary = StubNutritionClient(error: .serverError(429), delay: .milliseconds(20))
        let fallback = StubNutritionClient(
            result: .found(fallbackNutrition),
            delay: .milliseconds(40)
        )
        let client = OpenFoodFactsClient(
            primary: primary,
            fallback: fallback,
            fallbackDelay: .milliseconds(1),
            responseTimeout: .seconds(1)
        )

        let result = try await client.fetchNutrition(for: "12345678")

        XCTAssertEqual(result, .found(fallbackNutrition))
    }

    func testLookupStopsAtOverallUXDeadline() async {
        let primary = StubNutritionClient(result: .notFound, delay: .seconds(1))
        let fallback = StubNutritionClient(result: .notFound, delay: .seconds(1))
        let client = OpenFoodFactsClient(
            primary: primary,
            fallback: fallback,
            fallbackDelay: .milliseconds(1),
            responseTimeout: .milliseconds(30)
        )

        do {
            _ = try await client.fetchNutrition(for: "12345678")
            XCTFail("Expected timeout.")
        } catch let error as FoodNutritionFetchError {
            XCTAssertEqual(error, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDefinitivePrimaryNotFoundDoesNotSpendFallbackRequest() async throws {
        let fallback = StubNutritionClient(result: .notFound)
        let client = OpenFoodFactsClient(
            primary: StubNutritionClient(result: .notFound),
            fallback: fallback,
            fallbackDelay: .seconds(1),
            responseTimeout: .seconds(2)
        )

        let result = try await client.fetchNutrition(for: "12345678")
        let fallbackCallCount = await fallback.callCount

        XCTAssertEqual(result, .notFound)
        XCTAssertEqual(fallbackCallCount, 0)
    }

    func testLookupPropagatesOneParentOperationIDIntoRemoteClient() async throws {
        let cache = try NutritionCache(fileURL: temporaryFileURL(), maximumBytes: 10_000)
        let client = StubNutritionClient(result: .notFound)
        let service = NutritionLookupService(client: client, cache: cache)

        _ = try await service.lookup(barcode: "12345678")

        let parentIDs = await client.parentOperationIDs
        XCTAssertEqual(parentIDs.count, 1)
        XCTAssertNotNil(parentIDs[0])
    }

    func testLookupUsesPersistentCacheBeforeNetwork() async throws {
        let fileURL = try temporaryFileURL()
        let cache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let nutrition = sampleNutrition(barcode: "12345678")
        let client = StubNutritionClient(result: .found(nutrition))
        let service = NutritionLookupService(client: client, cache: cache)

        let firstResult = try await service.lookup(barcode: "12345678")
        let secondResult = try await service.lookup(barcode: "12345678")

        let clientCallCount = await client.callCount
        let reopenedCache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let persistedNutrition = await reopenedCache.nutrition(for: "12345678")
        XCTAssertEqual(firstResult, .found(nutrition))
        XCTAssertEqual(secondResult, .found(nutrition))
        XCTAssertEqual(clientCallCount, 1)
        XCTAssertEqual(persistedNutrition, nutrition)
    }

    func testCacheDecodesLegacyOptionalNutritionShape() async throws {
        let fileURL = try temporaryFileURL()
        let legacyNutrition = LegacyFoodNutrition(
            barcode: "8032919465535",
            name: "La Nostra Limonata",
            brand: "Lurisia",
            quantityDescription: "275 ml",
            servingGrams: 275,
            servingUnit: nil,
            caloriesPer100Grams: 64,
            proteinGramsPer100Grams: 0,
            carbohydrateGramsPer100Grams: 16,
            fatGramsPer100Grams: 0,
            fiberGramsPer100Grams: nil,
            sugarGramsPer100Grams: 16,
            saltGramsPer100Grams: 0
        )
        let legacyEntry = LegacyCacheEntry(nutrition: legacyNutrition, lastAccessed: .now)
        try JSONEncoder().encode([legacyNutrition.barcode: legacyEntry]).write(to: fileURL)

        let cache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let migrated = await cache.nutrition(for: legacyNutrition.barcode)

        XCTAssertEqual(migrated, FoodNutrition(
            barcode: legacyNutrition.barcode,
            name: legacyNutrition.name,
            defaultAmount: NutritionAmount(value: 275, unit: .milliliters),
            caloriesPer100: 64,
            nutrientsPer100: FoodNutrients(
                carbohydratesGrams: 16,
                proteinGrams: 0,
                fatGrams: 0,
                fiberGrams: nil
            )
        ))
    }

    func testCacheEvictsLeastRecentlyUsedEntryWhenOverBudget() async throws {
        let cache = try NutritionCache(fileURL: temporaryFileURL(), maximumBytes: 2_000)
        let first = sampleNutrition(barcode: "11111111", name: String(repeating: "A", count: 600))
        let second = sampleNutrition(barcode: "22222222", name: String(repeating: "B", count: 600))
        let third = sampleNutrition(barcode: "33333333", name: String(repeating: "C", count: 600))

        try await cache.store(first)
        try await cache.store(second)
        let accessedFirst = await cache.nutrition(for: first.barcode)
        XCTAssertNotNil(accessedFirst)
        try await cache.store(third)

        let retainedFirst = await cache.nutrition(for: first.barcode)
        let evictedSecond = await cache.nutrition(for: second.barcode)
        let retainedThird = await cache.nutrition(for: third.barcode)
        XCTAssertEqual(retainedFirst, first)
        XCTAssertNil(evictedSecond)
        XCTAssertEqual(retainedThird, third)
    }

    func testCacheRecoversFromCorruptPersistence() async throws {
        let fileURL = try temporaryFileURL()
        try Data("not json".utf8).write(to: fileURL)
        let cache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let nutrition = sampleNutrition(barcode: "12345678")
        let client = StubNutritionClient(result: .found(nutrition))
        let service = NutritionLookupService(client: client, cache: cache)

        let result = try await service.lookup(barcode: "12345678")

        let clientCallCount = await client.callCount
        let reopenedCache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let persistedNutrition = await reopenedCache.nutrition(for: "12345678")
        XCTAssertEqual(result, .found(nutrition))
        XCTAssertEqual(clientCallCount, 1)
        XCTAssertEqual(persistedNutrition, nutrition)
    }

    func testFailedNutritionCacheWriteRollsBackInMemoryEntry() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let blockedParent = directory.appending(path: "not-a-directory")
        try Data("block".utf8).write(to: blockedParent)
        let cache = try NutritionCache(
            fileURL: blockedParent.appending(path: "cache.json"),
            maximumBytes: 10_000
        )
        let nutrition = sampleNutrition(barcode: "12345678")

        do {
            try await cache.store(nutrition)
            XCTFail("Blocked cache path should fail.")
        } catch {
            // Expected storage failure.
        }
        let retained = await cache.nutrition(for: nutrition.barcode)
        XCTAssertNil(retained)
    }

    private func sampleNutrition(
        barcode: String,
        name: String = "Sample food"
    ) -> FoodNutrition {
        FoodNutrition(
            barcode: barcode,
            name: name,
            defaultAmount: NutritionAmount(value: 100, unit: .grams),
            caloriesPer100: 100
        )
    }

    private func temporaryFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "nutrition.json")
    }
}

private actor StubNutritionClient: FoodNutritionFetching {
    private(set) var callCount = 0
    private(set) var parentOperationIDs: [UUID?] = []
    private let result: FoodNutritionFetchResult?
    private let error: FoodNutritionFetchError?
    private let delay: Duration

    init(
        result: FoodNutritionFetchResult,
        delay: Duration = .zero
    ) {
        self.result = result
        error = nil
        self.delay = delay
    }

    init(
        error: FoodNutritionFetchError,
        delay: Duration = .zero
    ) {
        result = nil
        self.error = error
        self.delay = delay
    }

    func fetchNutrition(for barcode: String) async throws -> FoodNutritionFetchResult {
        callCount += 1
        parentOperationIDs.append(NutritionOperationContext.parentOperationID)
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        if let error {
            throw error
        }
        return result ?? .notFound
    }
}

private struct LegacyCacheEntry: Codable {
    let nutrition: LegacyFoodNutrition
    let lastAccessed: Date
}

private struct LegacyFoodNutrition: Codable {
    let barcode: String
    let name: String
    let brand: String?
    let quantityDescription: String?
    let servingGrams: Double?
    let servingUnit: NutritionUnit?
    let caloriesPer100Grams: Double?
    let proteinGramsPer100Grams: Double?
    let carbohydrateGramsPer100Grams: Double?
    let fatGramsPer100Grams: Double?
    let fiberGramsPer100Grams: Double?
    let sugarGramsPer100Grams: Double?
    let saltGramsPer100Grams: Double?
}
