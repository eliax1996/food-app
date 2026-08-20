import XCTest
#if SWIFT_PACKAGE
@testable import WidgetCore
#else
@testable import count_calories
#endif

final class WidgetDailySummaryCoreTests: XCTestCase {
    func testWaterMutationClampsAndAdvancesRevisionOnlyWhenValueChanges() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let empty = WidgetDailySummary.empty(date: now)

        let added = try WidgetDailySummaryMutation.adjustWater(empty, by: 1, now: now)
        XCTAssertEqual(added.waterGlasses, 1)
        XCTAssertEqual(added.resolvedRevision, 1)
        XCTAssertEqual(added.lastWaterRecordedAt, now)

        var maximum = added
        maximum.waterGlasses = 30
        maximum.revision = 9
        let unchanged = try WidgetDailySummaryMutation.adjustWater(maximum, by: 1, now: now)
        XCTAssertEqual(unchanged.waterGlasses, 30)
        XCTAssertEqual(unchanged.resolvedRevision, 9)
    }

    func testWaterMutationRejectsRevisionOverflowWithoutPartialChange() {
        var summary = WidgetDailySummary.empty()
        summary.waterGlasses = 4
        summary.revision = Int64.max

        XCTAssertThrowsError(try WidgetDailySummaryMutation.adjustWater(summary, by: 1))
        XCTAssertEqual(summary.waterGlasses, 4)
        XCTAssertEqual(summary.resolvedRevision, Int64.max)
    }

    func testMissingAppGroupStorageFailsClosedWithoutPrivateFallback() {
        XCTAssertThrowsError(try WidgetSharedStorageRequirement.requireContainer(nil))
        XCTAssertThrowsError(try WidgetSharedStorageRequirement.requireDefaults(nil))
    }

    func testUnavailableSummaryNeverLooksLikeCompleteZeroCalorieDay() {
        let summary = WidgetDailySummary.unavailable()
        XCTAssertFalse(summary.hasCompleteCalories)
        XCTAssertEqual(
            WidgetLiveActivityUpdateDecision.resolve(summary: summary),
            .stop
        )
    }

    func testWaterMutationOnUnavailableSummaryPreservesIncompleteCalories() throws {
        let adjusted = try WidgetDailySummaryMutation.adjustWater(
            .unavailable(),
            by: 1
        )
        XCTAssertEqual(adjusted.waterGlasses, 1)
        XCTAssertFalse(adjusted.hasCompleteCalories)
    }

    func testIncompleteCaloriesStopWidgetDrivenLiveActivityUpdate() {
        var summary = WidgetDailySummary.empty()
        summary.caloriesAreComplete = false
        XCTAssertEqual(
            WidgetLiveActivityUpdateDecision.resolve(summary: summary),
            .stop
        )

        summary.caloriesAreComplete = true
        XCTAssertEqual(
            WidgetLiveActivityUpdateDecision.resolve(summary: summary),
            .update
        )
    }

    func testLegacySharedSummaryDecodesWithSafeDefaults() throws {
        let data = #"{"date":0,"calories":120,"waterGlasses":2}"#.data(using: .utf8)!
        let summary = try JSONDecoder().decode(WidgetDailySummary.self, from: data)

        XCTAssertFalse(summary.hasCompleteCalories)
        XCTAssertEqual(summary.resolvedCalorieGoal, 1_700)
        XCTAssertEqual(summary.resolvedWaterGoal, 8)
        XCTAssertEqual(summary.resolvedRevision, 0)
    }
}
