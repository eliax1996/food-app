import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class FoodSearchClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SearchMockURLProtocol.reset()
    }

    func testRequestNormalizesQueryAndProtectsTransportContract() async throws {
        SearchMockURLProtocol.responseData = hits([])
        let client = OpenFoodFactsSearchClient(
            session: mockSession(),
            baseURL: URL(string: "https://example.com/search")!,
            requestTimeout: 4
        )

        let result = try await client.search(
            query: "  OAT\u{00A0}  MILK  ",
            page: 2,
            pageSize: 25,
            languages: ["fr", "en"]
        )

        let request = try XCTUnwrap(SearchMockURLProtocol.lastRequest)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/search")
        XCTAssertEqual(components.queryItems?.map(\.name), ["q", "langs", "page", "page_size", "fields"])
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "oat milk")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "langs" })?.value, "fr,en")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "page" })?.value, "2")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "page_size" })?.value, "25")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "fields" })?.value,
            OpenFoodFactsSearchClient.requestedFields
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("CountCalories/") == true)
        XCTAssertEqual(request.timeoutInterval, 4)
        XCTAssertEqual(result.query.displayQuery, "  OAT\u{00A0}  MILK  ")
        XCTAssertEqual(result.query.normalizedQuery, "oat milk")
    }

    func testQueryNormalizesCanonicallyEquivalentAccents() {
        XCTAssertEqual(
            FoodSearchQuery("Cafe\u{301}\u{00A0}LATTE").normalizedQuery,
            FoodSearchQuery("Café latte").normalizedQuery
        )
        XCTAssertEqual(FoodSearchQuery("Cafe\u{301}\u{00A0}LATTE").normalizedQuery, "café latte")
    }

    func testFlatHitMapsLiquidServingAndZeroCalories() async throws {
        SearchMockURLProtocol.responseData = hits([
            [
                "code": "3274080005003",
                "product_name": "Water",
                "quantity": "500 ml",
                "nutrition": ["aggregated_set": [
                    "per": "100ml",
                    "nutrients": ["energy-kcal": ["value": 0]]
                ]]
            ]
        ])

        let page = try await client().search(query: "water", page: 1, pageSize: 10, languages: ["en"])

        XCTAssertEqual(page.rawHitCount, 1)
        XCTAssertEqual(page.foods, [FoodNutrition(
            barcode: "3274080005003",
            name: "Water",
            defaultAmount: NutritionAmount(value: 500, unit: .milliliters),
            caloriesPer100: 0
        )])
    }

    func testLegacyHitsKeepOrderAndSameNameDistinctBarcodes() async throws {
        SearchMockURLProtocol.responseData = hits([
            legacy(code: "12345678", name: "Soup"),
            legacy(code: "12345679", name: "Soup")
        ])

        let page = try await client().search(query: "soup", page: 1, pageSize: 10, languages: ["en"])

        XCTAssertEqual(page.foods.map(\.barcode), ["12345678", "12345679"])
        XCTAssertEqual(page.foods.map(\.name), ["Soup", "Soup"])
        XCTAssertEqual(page.foods.map(\.caloriesPer100), [42, 42])
    }

    func testUnusableHitsAreSkippedButFullRawPageIsNotTerminal() async throws {
        SearchMockURLProtocol.responseData = hits([
            legacy(code: "123", name: "Bad barcode"),
            legacy(code: "12345678", name: "Missing calories", calories: nil)
        ])

        let page = try await client().search(query: "bad", page: 1, pageSize: 2, languages: ["en"])

        XCTAssertEqual(page.foods, [])
        XCTAssertEqual(page.rawHitCount, 2)
        XCTAssertFalse(page.isTerminal)
    }

    func testShortAndEmptyRawPagesAreTerminal() async throws {
        SearchMockURLProtocol.responseData = hits([legacy(code: "12345678", name: "One")])
        let shortPage = try await client().search(query: "one", page: 3, pageSize: 2, languages: ["en"])
        XCTAssertTrue(shortPage.isTerminal)

        SearchMockURLProtocol.responseData = hits([])
        let emptyPage = try await client().search(query: "none", page: 4, pageSize: 2, languages: ["en"])
        XCTAssertTrue(emptyPage.isTerminal)
    }

    func testTimedOutResponseWithUsableHitsRejectsEntirePage() async {
        SearchMockURLProtocol.responseData = hits(
            [legacy(code: "12345678", name: "Partial result")],
            timedOut: true
        )

        do {
            _ = try await client().search(query: "partial", page: 1, pageSize: 2, languages: ["en"])
            XCTFail("Expected timeout error.")
        } catch let error as FoodSearchError {
            XCTAssertEqual(error, .timedOut)
            XCTAssertTrue(error.localizedDescription.localizedCaseInsensitiveContains("try again"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchMapsRateLimitAndServiceUnavailableStatuses() async {
        for status in [429, 503] {
            SearchMockURLProtocol.statusCode = status
            do {
                _ = try await client().search(query: "milk", page: 1, pageSize: 10, languages: ["en"])
                XCTFail("Expected HTTP status \(status).")
            } catch let error as FoodSearchError {
                XCTAssertEqual(error, .serverError(status))
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testSearchPropagatesTransportURLError() async {
        SearchMockURLProtocol.transportError = URLError(.notConnectedToInternet)

        do {
            _ = try await client().search(query: "milk", page: 1, pageSize: 10, languages: ["en"])
            XCTFail("Expected transport failure.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchMapsMalformedEnvelopeToInvalidResponse() async {
        SearchMockURLProtocol.responseData = #"{"hits":{"total":{"value":1}}}"#.data(using: .utf8)!
        do {
            _ = try await client().search(query: "milk", page: 1, pageSize: 10, languages: ["en"])
            XCTFail("Expected invalid response.")
        } catch let error as FoodSearchError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchMapsMissingTimedOutToInvalidResponse() async {
        SearchMockURLProtocol.responseData = #"{"hits":[]}"#.data(using: .utf8)!
        do {
            _ = try await client().search(query: "milk", page: 1, pageSize: 10, languages: ["en"])
            XCTFail("Expected invalid response.")
        } catch let error as FoodSearchError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func client() -> OpenFoodFactsSearchClient {
        OpenFoodFactsSearchClient(
            session: mockSession(),
            baseURL: URL(string: "https://example.com/search")!
        )
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func legacy(code: String, name: String, calories: Double? = 42) -> [String: Any] {
        var product: [String: Any] = ["code": code, "product_name": name, "serving_size": "250 ml"]
        if let calories {
            product["nutriments"] = ["energy-kcal_100g": calories]
        }
        return product
    }

    private func hits(_ products: [[String: Any]], timedOut: Bool = false) -> Data {
        try! JSONSerialization.data(withJSONObject: ["hits": products, "timed_out": timedOut])
    }
}

private final class SearchMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var transportError: Error?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func reset() {
        responseData = Data()
        statusCode = 200
        transportError = nil
        lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        if let transportError = Self.transportError {
            client?.urlProtocol(self, didFailWithError: transportError)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
