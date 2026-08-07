import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class OpenFoodFactsLiveTests: XCTestCase {
    // Ad hoc only: RUN_OPEN_FOOD_FACTS_LIVE_TEST=1 just test-one OpenFoodFactsLiveTests
    func testLiveV3StructuredNutritionLookup() async throws {
        try requireLiveTestOptIn()

        let result = try await OpenFoodFactsV3Client().fetchNutrition(for: "3017620422003")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected Nutella from Open Food Facts v3.6, got \(result)")
        }
        XCTAssertEqual(nutrition.barcode, "3017620422003")
        XCTAssertFalse(nutrition.name.isEmpty)
        XCTAssertGreaterThan(nutrition.caloriesPer100, 0)
    }

    func testLiveV2FallbackLookup() async throws {
        try requireLiveTestOptIn()

        let result = try await OpenFoodFactsV2Client().fetchNutrition(for: "8032919465535")

        guard case let .found(nutrition) = result else {
            return XCTFail("Expected Limonata from Open Food Facts v2, got \(result)")
        }
        XCTAssertEqual(nutrition.barcode, "8032919465535")
        XCTAssertEqual(nutrition.defaultAmount.unit, .milliliters)
        XCTAssertGreaterThan(nutrition.caloriesPer100, 0)
    }

    private func requireLiveTestOptIn() throws {
        guard ProcessInfo.processInfo.environment["RUN_OPEN_FOOD_FACTS_LIVE_TEST"] == "1" else {
            throw XCTSkip("Live Open Food Facts tests are opt-in.")
        }
    }
}
