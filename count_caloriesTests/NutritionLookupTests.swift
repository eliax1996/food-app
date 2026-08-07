import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class NutritionLookupTests: XCTestCase {
    func testClientMapsOpenFoodFactsResponse() async throws {
        MockURLProtocol.responseData = """
        {
          "status": 1,
          "product": {
            "code": "3017620422003",
            "product_name": "Nutella",
            "brands": "Ferrero",
            "quantity": "350 g",
            "serving_quantity": "15",
            "nutriments": {
              "energy-kcal_100g": 539,
              "proteins_100g": 6.3,
              "carbohydrates_100g": 57.5,
              "fat_100g": 30.9,
              "fiber_100g": 0,
              "sugars_100g": 56.3,
              "salt_100g": 0.107
            }
          }
        }
        """.data(using: .utf8)!

        let client = OpenFoodFactsClient(session: mockSession())
        let nutrition = try await client.fetchNutrition(for: "3017620422003")

        XCTAssertEqual(nutrition?.name, "Nutella")
        XCTAssertEqual(nutrition?.brand, "Ferrero")
        XCTAssertEqual(nutrition?.servingAmount, 15)
        XCTAssertEqual(nutrition?.resolvedServingUnit, .grams)
        XCTAssertEqual(nutrition?.caloriesPer100Grams, 539)
        XCTAssertEqual(nutrition?.proteinGramsPer100Grams, 6.3)
        XCTAssertEqual(nutrition?.calories(for: 30), 161.7)
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.query?.contains("fields="), true)
    }

    func testClientMapsBeveragePackageToMilliliters() async throws {
        MockURLProtocol.responseData = """
        {
          "status": 1,
          "product": {
            "code": "8032919465535",
            "product_name": "La Nostra Limonata",
            "quantity": "275 ml",
            "product_quantity": 275,
            "product_quantity_unit": "ml",
            "categories_tags": ["en:beverages", "en:lemonades"],
            "nutrition_data_per": "100ml",
            "nutriments": {
              "energy-kcal_100g": 64
            }
          }
        }
        """.data(using: .utf8)!

        let nutrition = try await OpenFoodFactsClient(session: mockSession())
            .fetchNutrition(for: "8032919465535")

        XCTAssertEqual(nutrition?.name, "La Nostra Limonata")
        XCTAssertEqual(nutrition?.servingAmount, 275)
        XCTAssertEqual(nutrition?.resolvedServingUnit, .milliliters)
        XCTAssertEqual(nutrition?.calories(for: 275), 176)
    }

    func testClientReturnsNilForUnknownProduct() async throws {
        MockURLProtocol.responseData = #"{"status": 0, "product": null}"#.data(using: .utf8)!

        let nutrition = try await OpenFoodFactsClient(session: mockSession()).fetchNutrition(for: "12345678")

        XCTAssertNil(nutrition)
    }

    func testClientRejectsInvalidBarcodeBeforeNetworkRequest() async {
        let client = OpenFoodFactsClient(session: mockSession())

        do {
            _ = try await client.fetchNutrition(for: "123")
            XCTFail("Expected an invalid barcode error.")
        } catch let error as FoodNutritionFetchError {
            XCTAssertEqual(error, .invalidBarcode)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClientRejectsMalformedPayload() async {
        MockURLProtocol.responseData = #"{"status": 1, "product": {"#.data(using: .utf8)!

        do {
            _ = try await OpenFoodFactsClient(session: mockSession()).fetchNutrition(for: "12345678")
            XCTFail("Expected a decoding error.")
        } catch is DecodingError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClientPropagatesTransportFailure() async {
        MockURLProtocol.error = URLError(.notConnectedToInternet)
        defer { MockURLProtocol.error = nil }

        do {
            _ = try await OpenFoodFactsClient(session: mockSession()).fetchNutrition(for: "12345678")
            XCTFail("Expected a transport error.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLookupUsesPersistentCacheBeforeNetwork() async throws {
        let fileURL = try temporaryFileURL()
        let cache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let client = CountingClient(result: sampleNutrition(barcode: "12345678"))
        let service = NutritionLookupService(client: client, cache: cache)

        _ = try await service.nutrition(for: "12345678")
        _ = try await service.nutrition(for: "12345678")

        let callCount = client.callCount
        XCTAssertEqual(callCount, 1)
        let reopenedCache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let persistedNutrition = await reopenedCache.nutrition(for: "12345678")
        XCTAssertEqual(persistedNutrition, sampleNutrition(barcode: "12345678"))
    }

    func testLookupRefreshesLegacyCacheWithoutServingUnit() async throws {
        let cache = try NutritionCache(fileURL: temporaryFileURL(), maximumBytes: 10_000)
        let legacyNutrition = sampleNutrition(barcode: "12345678", servingUnit: nil)
        try await cache.store(legacyNutrition)
        let refreshedNutrition = sampleNutrition(barcode: "12345678", servingUnit: .milliliters)
        let client = CountingClient(result: refreshedNutrition)
        let service = NutritionLookupService(client: client, cache: cache)

        let nutrition = try await service.nutrition(for: "12345678")

        XCTAssertEqual(nutrition, refreshedNutrition)
        XCTAssertEqual(client.callCount, 1)
    }

    func testLookupUsesLegacyCacheWhenMetadataRefreshFails() async throws {
        let cache = try NutritionCache(fileURL: temporaryFileURL(), maximumBytes: 10_000)
        let legacyNutrition = sampleNutrition(barcode: "12345678", servingUnit: nil)
        try await cache.store(legacyNutrition)
        let service = NutritionLookupService(client: FailingClient(), cache: cache)

        let nutrition = try await service.nutrition(for: "12345678")

        XCTAssertEqual(nutrition, legacyNutrition)
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
        let client = CountingClient(result: sampleNutrition(barcode: "12345678"))
        let service = NutritionLookupService(client: client, cache: cache)

        let nutrition = try await service.nutrition(for: "12345678")

        XCTAssertEqual(nutrition, sampleNutrition(barcode: "12345678"))
        XCTAssertEqual(client.callCount, 1)
        let reopenedCache = try NutritionCache(fileURL: fileURL, maximumBytes: 10_000)
        let persistedNutrition = await reopenedCache.nutrition(for: "12345678")
        XCTAssertEqual(persistedNutrition, nutrition)
    }

    // Set RUN_OPEN_FOOD_FACTS_LIVE_TEST=1 to validate the public service from a networked environment.
    func testLiveOpenFoodFactsLookup() async throws {
        guard ProcessInfo.processInfo.environment["RUN_OPEN_FOOD_FACTS_LIVE_TEST"] == "1" else {
            throw XCTSkip("Live API tests are opt-in.")
        }

        let nutrition = try await OpenFoodFactsClient().fetchNutrition(for: "3017620422003")
        XCTAssertEqual(nutrition?.barcode, "3017620422003")
        XCTAssertFalse(nutrition?.name.isEmpty ?? true)
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func sampleNutrition(
        barcode: String,
        name: String = "Sample food",
        servingUnit: NutritionUnit? = .grams
    ) -> FoodNutrition {
        FoodNutrition(
            barcode: barcode,
            name: name,
            brand: nil,
            quantityDescription: nil,
            servingGrams: 100,
            servingUnit: servingUnit,
            caloriesPer100Grams: 100,
            proteinGramsPer100Grams: 10,
            carbohydrateGramsPer100Grams: 10,
            fatGramsPer100Grams: 2,
            fiberGramsPer100Grams: 1,
            sugarGramsPer100Grams: 1,
            saltGramsPer100Grams: 0.1
        )
    }

    private func temporaryFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "nutrition.json")
    }
}

@MainActor
private final class CountingClient: FoodNutritionFetching {
    private(set) var callCount = 0
    private let result: FoodNutrition?

    init(result: FoodNutrition?) {
        self.result = result
    }

    func fetchNutrition(for barcode: String) async -> FoodNutrition? {
        callCount += 1
        return result
    }
}

private struct FailingClient: FoodNutritionFetching {
    func fetchNutrition(for barcode: String) async throws -> FoodNutrition? {
        throw URLError(.notConnectedToInternet)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var error: Error?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
