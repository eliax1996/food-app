import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class OpenFoodFactsAPITests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    func testV3MapsStructuredNutritionAndServing() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "errors": [],
          "warnings": [],
          "product": {
            "code": "3017620422003",
            "product_name": "Nutella",
            "serving_quantity": 30,
            "serving_quantity_unit": "g",
            "nutrition": {
              "aggregated_set": {
                "per": "100g",
                "preparation": "as_sold",
                "nutrients": {
                  "energy-kcal": { "unit": "kcal", "value": 539 },
                  "carbohydrates": { "unit": "g", "value": 57.5 },
                  "proteins": { "unit": "g", "value": 6.3 },
                  "fat": { "unit": "g", "value": 30.9 },
                  "fiber": { "unit": "g", "value": 3 }
                }
              },
              "input_sets": [
                {
                  "per": "serving",
                  "per_quantity": 15,
                  "per_unit": "g",
                  "preparation": "as_sold",
                  "source": "manufacturer",
                  "nutrients": {
                    "energy-kcal": { "unit": "kcal", "value": 80 }
                  }
                }
              ]
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(
            session: mockSession(),
            baseURL: URL(string: "https://example.com/api/v3.6/product")!
        ).fetchNutrition(for: "3017620422003")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected mapped v3 nutrition, got \(result)")
        }
        XCTAssertEqual(nutrition.barcode, "3017620422003")
        XCTAssertEqual(nutrition.name, "Nutella")
        XCTAssertEqual(nutrition.defaultAmount, NutritionAmount(value: 15, unit: .grams))
        XCTAssertEqual(nutrition.caloriesPer100, 539)
        XCTAssertEqual(nutrition.nutrientsPer100, FoodNutrients(
            carbohydratesGrams: 57.5,
            proteinGrams: 6.3,
            fatGrams: 30.9,
            fiberGrams: 3
        ))
        let servingNutrients = nutrition.nutrients(for: 30)
        XCTAssertEqual(servingNutrients.carbohydratesGrams ?? -1, 17.25, accuracy: 0.000_001)
        XCTAssertEqual(servingNutrients.proteinGrams ?? -1, 1.89, accuracy: 0.000_001)
        XCTAssertEqual(servingNutrients.fatGrams ?? -1, 9.27, accuracy: 0.000_001)
        XCTAssertEqual(servingNutrients.fiberGrams ?? -1, 0.9, accuracy: 0.000_001)
        XCTAssertEqual(nutrition.calories(for: 30), 161.7)
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/v3.6/product/3017620422003")
        XCTAssertEqual(MockURLProtocol.lastRequest?.timeoutInterval, 6)
        XCTAssertTrue(MockURLProtocol.lastRequest?.url?.query?.contains("nutrition") == true)
    }

    func testV3NormalizesServingNutrientsAndKeepsMissingValuesUnknown() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "product": {
            "code": "12345678",
            "product_name": "Serving-based food",
            "nutrition": {
              "input_sets": [
                {
                  "per": "serving",
                  "per_quantity": 50,
                  "per_unit": "g",
                  "preparation": "as_sold",
                  "nutrients": {
                    "energy-kcal": { "unit": "kcal", "value": 100 },
                    "carbohydrates": { "unit": "g", "value": 20 },
                    "proteins": { "unit": "g", "value": 5 },
                    "fat": { "unit": "g", "value": 2 }
                  }
                }
              ]
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "12345678")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected normalized serving nutrition, got \(result)")
        }
        XCTAssertEqual(nutrition.caloriesPer100, 200)
        XCTAssertEqual(nutrition.nutrientsPer100, FoodNutrients(
            carbohydratesGrams: 40,
            proteinGrams: 10,
            fatGrams: 4,
            fiberGrams: nil
        ))
        XCTAssertFalse(nutrition.nutrientsPer100.isComplete)
    }

    func testV3PreservesExplicitZeroWithoutInventingInvalidNutrients() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "product": {
            "code": "12345678",
            "product_name": "Partial nutrition",
            "nutrition": {
              "aggregated_set": {
                "per": "100g",
                "nutrients": {
                  "energy-kcal": { "value": 20 },
                  "carbohydrates": { "unit": "g", "value": 0 },
                  "proteins": { "unit": "g", "value": -1 },
                  "fat": { "unit": "%", "value": 5 },
                  "fiber": { "unit": "g", "value": 0 }
                }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "12345678")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected partial nutrition, got \(result)")
        }
        XCTAssertEqual(nutrition.nutrientsPer100.carbohydratesGrams, 0)
        XCTAssertNil(nutrition.nutrientsPer100.proteinGrams)
        XCTAssertNil(nutrition.nutrientsPer100.fatGrams)
        XCTAssertEqual(nutrition.nutrientsPer100.fiberGrams, 0)
    }

    func testV3MapsBeveragePackageToMilliliters() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "product": {
            "code": "8032919465535",
            "product_name": "La Nostra Limonata",
            "quantity": "275 ml",
            "product_quantity": 275,
            "product_quantity_unit": "ml",
            "categories_tags": ["en:beverages", "en:lemonades"],
            "nutrition": {
              "aggregated_set": {
                "per": "100ml",
                "preparation": "as_sold",
                "nutrients": {
                  "energy-kcal": { "unit": "kcal", "value": 64 }
                }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "8032919465535")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected mapped beverage, got \(result)")
        }
        XCTAssertEqual(nutrition.defaultAmount, NutritionAmount(value: 275, unit: .milliliters))
        XCTAssertEqual(nutrition.calories(for: 275), 176)
    }

    func testV3UsesStandardReferenceWhenServingAndPackageAreMissing() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "product": {
            "code": "12345678",
            "product_name": "Food without amount metadata",
            "nutrition": {
              "aggregated_set": {
                "per": "100ml",
                "nutrients": {
                  "energy-kcal": { "value": 120 }
                }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "12345678")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected normalized food, got \(result)")
        }
        XCTAssertEqual(nutrition.defaultAmount, NutritionAmount(value: 100, unit: .milliliters))
        XCTAssertEqual(nutrition.caloriesPer100, 120)
    }

    func testV3IgnoresAggregateCaloriesUnlessBasisIsPer100() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "product": {
            "code": "3017620422003",
            "product_name": "Nutella",
            "nutrition": {
              "aggregated_set": {
                "per": "serving",
                "nutrients": {
                  "energy-kcal": { "value": 80 }
                }
              },
              "input_sets": [
                {
                  "per": "100g",
                  "per_quantity": 100,
                  "per_unit": "g",
                  "preparation": "as_sold",
                  "nutrients": {
                    "energy-kcal": { "value": 539 }
                  }
                }
              ]
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "3017620422003")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected normalized food, got \(result)")
        }
        XCTAssertEqual(nutrition.caloriesPer100, 539)
    }

    func testV3PreservesValidZeroCalories() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "product": {
            "code": "3274080005003",
            "product_name": "Water",
            "categories_tags": ["en:beverages", "en:waters"],
            "nutrition": {
              "aggregated_set": {
                "per": "100ml",
                "nutrients": {
                  "energy-kcal": { "value": 0 }
                }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "3274080005003")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected zero-calorie product, got \(result)")
        }
        XCTAssertEqual(nutrition.caloriesPer100, 0)
        XCTAssertEqual(nutrition.defaultAmount.unit, .milliliters)
    }

    func testV3ReportsIncompleteProductWhenCaloriesAreMissing() async throws {
        MockURLProtocol.responseData = """
        {
          "status": "success",
          "product": {
            "code": "12345678",
            "product_name": "Product without nutrition"
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "12345678")

        XCTAssertEqual(result, .incompleteProduct)
    }

    func testV2FallbackMapsLegacyNutriments() async throws {
        MockURLProtocol.responseData = """
        {
          "status": 1,
          "product": {
            "code": "3017620422003",
            "product_name": "Nutella",
            "serving_quantity": "15",
            "serving_quantity_unit": "g",
            "nutriments": {
              "energy-kcal_100g": "539",
              "carbohydrates_100g": "57.5",
              "proteins_100g": "6.3",
              "fat_100g": "30.9",
              "fiber_100g": "3"
            }
          }
        }
        """.data(using: .utf8)!

        let result = try await OpenFoodFactsV2Client(
            session: mockSession(),
            baseURL: URL(string: "https://example.com/api/v2/product")!
        ).fetchNutrition(for: "3017620422003")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected mapped v2 nutrition, got \(result)")
        }
        XCTAssertEqual(nutrition.defaultAmount, NutritionAmount(value: 15, unit: .grams))
        XCTAssertEqual(nutrition.caloriesPer100, 539)
        XCTAssertEqual(nutrition.nutrientsPer100, FoodNutrients(
            carbohydratesGrams: 57.5,
            proteinGrams: 6.3,
            fatGrams: 30.9,
            fiberGrams: 3
        ))
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/v2/product/3017620422003")
        XCTAssertTrue(MockURLProtocol.lastRequest?.url?.query?.contains("nutriments") == true)
    }

    func testCompositeFallsBackFromIncompleteV3PayloadToV2() async throws {
        let v3Payload = """
        {
          "status": "success",
          "product": {
            "code": "3017620422003",
            "product_name": "Nutella"
          }
        }
        """.data(using: .utf8)!
        let v2Payload = """
        {
          "status": 1,
          "product": {
            "code": "3017620422003",
            "product_name": "Nutella",
            "serving_quantity": 15,
            "serving_quantity_unit": "g",
            "nutriments": { "energy-kcal_100g": 539 }
          }
        }
        """.data(using: .utf8)!
        MockURLProtocol.responseProvider = { request in
            request.url?.path.contains("/v3.6/") == true
                ? (200, v3Payload)
                : (200, v2Payload)
        }
        let client = OpenFoodFactsClient(
            session: mockSession(),
            primaryBaseURL: URL(string: "https://example.com/api/v3.6/product")!,
            fallbackBaseURL: URL(string: "https://example.com/api/v2/product")!,
            fallbackDelay: .milliseconds(1),
            responseTimeout: .seconds(1)
        )

        let result = try await client.fetchNutrition(for: "3017620422003")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected v2 fallback nutrition, got \(result)")
        }
        XCTAssertEqual(nutrition.defaultAmount, NutritionAmount(value: 15, unit: .grams))
        XCTAssertEqual(nutrition.caloriesPer100, 539)
    }

    func testV2ReturnsNotFoundForLegacyStatusPayload() async throws {
        MockURLProtocol.responseData = #"{"status": 0, "product": null}"#.data(using: .utf8)!

        let result = try await OpenFoodFactsV2Client(session: mockSession())
            .fetchNutrition(for: "12345678")

        XCTAssertEqual(result, .notFound)
    }

    func testClientsReturnNotFoundForHTTP404() async throws {
        MockURLProtocol.statusCode = 404
        MockURLProtocol.responseData = #"{"status":"failure"}"#.data(using: .utf8)!

        let v3Result = try await OpenFoodFactsV3Client(session: mockSession())
            .fetchNutrition(for: "12345678")
        let v2Result = try await OpenFoodFactsV2Client(session: mockSession())
            .fetchNutrition(for: "12345678")

        XCTAssertEqual(v3Result, .notFound)
        XCTAssertEqual(v2Result, .notFound)
    }

    func testClientRejectsInvalidBarcodeBeforeNetworkRequest() async {
        do {
            _ = try await OpenFoodFactsV3Client(session: mockSession()).fetchNutrition(for: "123")
            XCTFail("Expected an invalid barcode error.")
        } catch let error as FoodNutritionFetchError {
            XCTAssertEqual(error, .invalidBarcode)
            XCTAssertNil(MockURLProtocol.lastRequest)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClientRejectsMalformedPayload() async {
        MockURLProtocol.responseData = #"{"status":"success","product":{"#.data(using: .utf8)!

        do {
            _ = try await OpenFoodFactsV3Client(session: mockSession()).fetchNutrition(for: "12345678")
            XCTFail("Expected a decoding error.")
        } catch is DecodingError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClientPropagatesTransportFailure() async {
        MockURLProtocol.error = URLError(.notConnectedToInternet)

        do {
            _ = try await OpenFoodFactsV3Client(session: mockSession()).fetchNutrition(for: "12345678")
            XCTFail("Expected a transport error.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClientReportsRateLimitResponse() async {
        MockURLProtocol.statusCode = 429
        MockURLProtocol.responseData = Data()

        do {
            _ = try await OpenFoodFactsV3Client(session: mockSession()).fetchNutrition(for: "12345678")
            XCTFail("Expected a server error.")
        } catch let error as FoodNutritionFetchError {
            XCTAssertEqual(error, .serverError(429))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var error: Error?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var responseProvider: (@Sendable (URLRequest) -> (Int, Data))?

    static func reset() {
        responseData = Data()
        statusCode = 200
        error = nil
        lastRequest = nil
        responseProvider = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let providedResponse = Self.responseProvider?(request)
        let statusCode = providedResponse?.0 ?? Self.statusCode
        let data = providedResponse?.1 ?? Self.responseData
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
