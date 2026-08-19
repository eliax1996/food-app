import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class FoodUsageRankingTests: XCTestCase {
    func testRecentNamesUseNewestUniqueValidEvents() {
        let events = [
            event("Banana", 1),
            event("Apple", 3),
            event("banana", 4),
            event("Yogurt", 2),
            FoodUsageEvent(foodName: "Invalid", date: Date(timeIntervalSinceReferenceDate: .nan)),
            event("   ", 9)
        ]

        XCTAssertEqual(
            FoodUsageRanking.recentNames(from: events, limit: 3),
            ["banana", "Apple", "Yogurt"]
        )
    }

    func testFrequentNamesRankCountThenRecencyAndExcludeRecentWithoutPersistence() {
        let events = [
            event("Apple", 1),
            event("Apple", 2),
            event("Apple", 3),
            event("Banana", 1),
            event("Banana", 5),
            event("Yogurt", 4),
            event("Yogurt", 6),
            event("Toast", 7)
        ]

        XCTAssertEqual(
            FoodUsageRanking.frequentNames(
                from: events,
                excluding: ["APPLE"],
                limit: 3
            ),
            ["Yogurt", "Banana", "Toast"]
        )
    }

    func testFutureEventsNeverInfluenceRecentOrFrequentRanking() {
        let now = Date(timeIntervalSinceReferenceDate: 10)
        let events = [event("Past", 9), event("Future", 11), event("Future", 12)]

        XCTAssertEqual(FoodUsageRanking.recentNames(from: events, now: now), ["Past"])
        XCTAssertEqual(FoodUsageRanking.frequentNames(from: events, now: now), ["Past"])
    }

    func testAmbiguousSavedNamesAreExcludedFromShortcuts() {
        XCTAssertEqual(
            FoodUsageRanking.unambiguousNames(
                ["Oat Drink", "Banana", "Missing"],
                among: ["oat drink", "OAT DRINK", "Banana"]
            ),
            ["Banana"]
        )
    }

    func testNonpositiveLimitsReturnNoSuggestions() {
        XCTAssertEqual(FoodUsageRanking.recentNames(from: [event("A", 1)], limit: 0), [])
        XCTAssertEqual(FoodUsageRanking.frequentNames(from: [event("A", 1)], limit: -1), [])
    }

    private func event(_ name: String, _ seconds: TimeInterval) -> FoodUsageEvent {
        FoodUsageEvent(
            foodName: name,
            date: Date(timeIntervalSinceReferenceDate: seconds)
        )
    }
}
