import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class WeightEntryDraftTests: XCTestCase {
    func testLatestValidChronologicalMeasurementWinsOverProfileDefault() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let measurements = [
            WeightProgressPoint(
                date: now.addingTimeInterval(-200),
                kilograms: 70.4,
                stableID: UUID(),
                sequence: 1
            ),
            WeightProgressPoint(
                date: now.addingTimeInterval(-100),
                kilograms: 71.2,
                stableID: UUID(),
                sequence: 2
            ),
            WeightProgressPoint(
                date: now.addingTimeInterval(100),
                kilograms: 99,
                stableID: UUID(),
                sequence: 3
            )
        ]

        XCTAssertEqual(
            WeightEntryDraft.defaultKilograms(
                measurements: measurements,
                profileCurrentWeight: 68,
                now: now
            ),
            71.2
        )
    }

    func testDefaultFallsBackToValidProfileThenSeventyKilograms() {
        XCTAssertEqual(
            WeightEntryDraft.defaultKilograms(
                measurements: [],
                profileCurrentWeight: 68.5
            ),
            68.5
        )
        XCTAssertEqual(
            WeightEntryDraft.defaultKilograms(
                measurements: [],
                profileCurrentWeight: .nan
            ),
            70
        )
        XCTAssertEqual(
            WeightEntryDraft.defaultKilograms(
                measurements: [],
                profileCurrentWeight: nil
            ),
            70
        )
    }

    func testFineAndCoarseAdjustmentsRoundToOneDecimal() {
        XCTAssertEqual(WeightEntryDraft.adjustedKilograms(71.2, by: -1), 70.2)
        XCTAssertEqual(WeightEntryDraft.adjustedKilograms(71.2, by: -0.1), 71.1)
        XCTAssertEqual(WeightEntryDraft.adjustedKilograms(71.2, by: 0.1), 71.3)
        XCTAssertEqual(WeightEntryDraft.adjustedKilograms(71.2, by: 1), 72.2)
        XCTAssertEqual(WeightEntryDraft.adjustedKilograms(71.24, by: 0.1), 71.3)
    }

    func testAdjustmentsRejectNonfiniteAndNonpositiveResults() {
        XCTAssertNil(WeightEntryDraft.adjustedKilograms(.nan, by: 0.1))
        XCTAssertNil(WeightEntryDraft.adjustedKilograms(70, by: .infinity))
        XCTAssertNil(WeightEntryDraft.adjustedKilograms(0.1, by: -0.1))
        XCTAssertNil(WeightEntryDraft.adjustedKilograms(0.5, by: -1))
    }
}
