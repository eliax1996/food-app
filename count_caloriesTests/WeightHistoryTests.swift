import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class WeightHistoryTests: XCTestCase {
    func testFinitePositiveWeightIsValid() {
        XCTAssertTrue(WeightHistory.isValidWeight(70.5))
        XCTAssertEqual(try WeightHistory.validatedWeight(70.5), 70.5)
    }

    func testZeroWeightIsRejected() {
        XCTAssertFalse(WeightHistory.isValidWeight(0))
        XCTAssertThrowsError(try WeightHistory.validatedWeight(0)) { error in
            XCTAssertEqual(error as? WeightHistoryError, .invalidWeight)
        }
    }

    func testNegativeAndNonFiniteWeightsAreRejected() {
        for weight in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertFalse(WeightHistory.isValidWeight(weight))
            XCTAssertThrowsError(try WeightHistory.validatedWeight(weight))
        }
    }

    func testCombinedTimestampUsesSelectedLocalDateAndTime() throws {
        let timestamp = try WeightHistory.combinedTimestamp(
            date: date(year: 2026, month: 5, day: 8, hour: 2, minute: 0),
            time: date(year: 2026, month: 1, day: 1, hour: 17, minute: 45, second: 12),
            calendar: utc,
            now: date(year: 2026, month: 5, day: 9)
        )

        XCTAssertEqual(timestamp, date(year: 2026, month: 5, day: 8, hour: 17, minute: 45, second: 12))
    }

    func testCombinedTimestampUsesCalendarLocalComponents() throws {
        let honolulu = calendar(timeZoneID: "Pacific/Honolulu")
        let timestamp = try WeightHistory.combinedTimestamp(
            date: date(year: 2026, month: 7, day: 4, hour: 9, calendar: honolulu),
            time: date(year: 2026, month: 1, day: 1, hour: 21, minute: 30, calendar: honolulu),
            calendar: honolulu,
            now: date(year: 2026, month: 7, day: 5, calendar: honolulu)
        )

        XCTAssertEqual(timestamp, date(year: 2026, month: 7, day: 4, hour: 21, minute: 30, calendar: honolulu))
    }

    func testNonexistentDaylightSavingTimeIsRejected() {
        let newYork = calendar(timeZoneID: "America/New_York")

        XCTAssertThrowsError(try WeightHistory.combinedTimestamp(
            date: date(year: 2026, month: 3, day: 8, hour: 12, calendar: newYork),
            time: date(year: 2026, month: 1, day: 1, hour: 2, minute: 30, calendar: newYork),
            calendar: newYork,
            now: date(year: 2026, month: 3, day: 9, calendar: newYork)
        )) { error in
            XCTAssertEqual(error as? WeightHistoryError, .invalidTimestamp)
        }
    }

    func testFutureCombinedTimestampIsRejected() {
        XCTAssertThrowsError(try WeightHistory.combinedTimestamp(
            date: date(year: 2026, month: 5, day: 9),
            time: date(year: 2026, month: 1, day: 1, hour: 0, minute: 1),
            calendar: utc,
            now: date(year: 2026, month: 5, day: 9)
        )) { error in
            XCTAssertEqual(error as? WeightHistoryError, .futureTimestamp)
        }
    }

    func testEqualToNowTimestampIsAccepted() throws {
        let now = date(year: 2026, month: 5, day: 9, hour: 10, minute: 15)
        let timestamp = try WeightHistory.combinedTimestamp(
            date: now,
            time: now,
            calendar: utc,
            now: now
        )

        XCTAssertEqual(timestamp, now)
    }

    func testSectionsAreNewestLocalDayFirst() {
        let sections = WeightHistory.localDaySections(
            for: [point(day: 2, hour: 8, kilograms: 70), point(day: 4, hour: 8, kilograms: 69), point(day: 3, hour: 8, kilograms: 71)],
            calendar: utc
        )

        XCTAssertEqual(sections.map(\.date), [date(year: 2026, month: 5, day: 4), date(year: 2026, month: 5, day: 3), date(year: 2026, month: 5, day: 2)])
    }

    func testRowsAreNewestFirstWithinLocalDay() {
        let sections = WeightHistory.localDaySections(
            for: [point(day: 4, hour: 8, kilograms: 70), point(day: 4, hour: 20, kilograms: 69), point(day: 4, hour: 12, kilograms: 71)],
            calendar: utc
        )

        XCTAssertEqual(sections.first?.entries.map(\.kilograms), [69, 71, 70])
    }

    func testMultipleSameDayAndDuplicateValuesArePreserved() {
        let sections = WeightHistory.localDaySections(
            for: [point(day: 4, hour: 8, kilograms: 70), point(day: 4, hour: 12, kilograms: 70), point(day: 4, hour: 20, kilograms: 70)],
            calendar: utc
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].entries.map(\.kilograms), [70, 70, 70])
        XCTAssertEqual(sections[0].entries.count, 3)
    }

    func testSectionGroupingUsesProvidedTimeZone() {
        let losAngeles = calendar(timeZoneID: "America/Los_Angeles")
        let entries = [
            WeightProgressPoint(date: date(year: 2026, month: 5, day: 4, hour: 6, calendar: utc), kilograms: 70),
            WeightProgressPoint(date: date(year: 2026, month: 5, day: 4, hour: 8, calendar: utc), kilograms: 71)
        ]

        let sections = WeightHistory.localDaySections(for: entries, calendar: losAngeles)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.map(\.date), [date(year: 2026, month: 5, day: 4, calendar: losAngeles), date(year: 2026, month: 5, day: 3, calendar: losAngeles)])
    }

    func testLatestValidMeasurementUsesNewestDateNotInputOrder() {
        let latest = WeightHistory.latestValidMeasurement(
            from: [point(day: 4, hour: 8, kilograms: 70), point(day: 2, hour: 8, kilograms: 72), point(day: 3, hour: 8, kilograms: 71)],
            now: date(year: 2026, month: 5, day: 5)
        )

        XCTAssertEqual(latest, point(day: 4, hour: 8, kilograms: 70))
    }

    func testLatestValidMeasurementIgnoresInvalidAndFutureRecords() {
        let latest = WeightHistory.latestValidMeasurement(
            from: [
                point(day: 3, hour: 8, kilograms: 70),
                point(day: 4, hour: 8, kilograms: .nan),
                point(day: 5, hour: 8, kilograms: 69),
                point(day: 6, hour: 8, kilograms: 68)
            ],
            now: date(year: 2026, month: 5, day: 5, hour: 12)
        )

        XCTAssertEqual(latest, point(day: 5, hour: 8, kilograms: 69))
    }

    func testHostlessDuplicateTimestampUsesCompatibilityInputOrder() {
        let timestamp = date(year: 2026, month: 5, day: 4, hour: 8)
        let latest = WeightHistory.latestValidMeasurement(
            from: [WeightProgressPoint(date: timestamp, kilograms: 70), WeightProgressPoint(date: timestamp, kilograms: 71)],
            now: date(year: 2026, month: 5, day: 5)
        )

        XCTAssertEqual(latest?.kilograms, 71)
    }

    func testStableOrderingControlsSameTimestampRowsAndLatestMeasurement() {
        let timestamp = date(year: 2026, month: 5, day: 4, hour: 8)
        let older = WeightProgressPoint(
            date: timestamp,
            kilograms: 70,
            stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sequence: 4
        )
        let newer = WeightProgressPoint(
            date: timestamp,
            kilograms: 72,
            stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            sequence: 5
        )

        let sections = WeightHistory.localDaySections(for: [newer, older], calendar: utc)
        let latest = WeightHistory.latestValidMeasurement(
            from: [newer, older],
            now: date(year: 2026, month: 5, day: 5)
        )

        XCTAssertEqual(sections.first?.entries.map(\.kilograms), [72, 70])
        XCTAssertEqual(latest?.kilograms, 72)
    }

    func testEditingSecondFallBackOccurrenceWithoutVisibleChangesPreservesInstant() throws {
        let newYork = calendar(timeZoneID: "America/New_York")
        let day = date(year: 2026, month: 11, day: 1, hour: 0, calendar: newYork)
        let first = newYork.nextDate(
            after: day.addingTimeInterval(-1),
            matching: DateComponents(hour: 1, minute: 30),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )!
        let second = newYork.nextDate(
            after: first,
            matching: DateComponents(hour: 1, minute: 30),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .last,
            direction: .forward
        )!

        let preserved = try WeightHistory.combinedTimestamp(
            date: second,
            time: second,
            originalTimestamp: second,
            calendar: newYork,
            now: date(year: 2026, month: 11, day: 2, calendar: newYork)
        )
        let newEntry = try WeightHistory.combinedTimestamp(
            date: second,
            time: second,
            calendar: newYork,
            now: date(year: 2026, month: 11, day: 2, calendar: newYork)
        )

        XCTAssertEqual(preserved, second)
        XCTAssertEqual(newEntry, first)
    }

    private var utc: Calendar {
        calendar(timeZoneID: "GMT")
    }

    private func calendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        return calendar
    }

    private func point(day: Int, hour: Int, kilograms: Double) -> WeightProgressPoint {
        WeightProgressPoint(date: date(year: 2026, month: 5, day: day, hour: hour), kilograms: kilograms)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        calendar: Calendar? = nil
    ) -> Date {
        let calendar = calendar ?? utc
        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ).date!
    }
}
