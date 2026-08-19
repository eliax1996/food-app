import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class CalorieDiaryTests: XCTestCase {
    func testDiaryGroupsLocalDaysMealsAndPreservesStableRows() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 2 * 3_600))
        let newest = try date(2026, 8, 13, 23, 30, calendar: calendar)
        let sameNewestDayUTCBoundary = try date(2026, 8, 13, 0, 15, calendar: calendar)
        let older = try date(2026, 8, 11, 12, 0, calendar: calendar)
        let records = [
            record(1, date: newest, meal: "Dinner", calories: 500, name: "Dinner"),
            record(2, date: sameNewestDayUTCBoundary, meal: "Breakfast", calories: 300, name: "Breakfast"),
            record(3, date: older, meal: "Lunch", calories: 400, name: "Lunch"),
            record(4, date: older, meal: "Future Meal", calories: 100, name: "Legacy")
        ]

        let days = CalorieDiary.days(from: records, calendar: calendar)

        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].date, calendar.startOfDay(for: newest))
        XCTAssertEqual(days[0].calorieTotal.calories, 800)
        XCTAssertEqual(days[0].mealGroups.map(\.mealType), ["Breakfast", "Dinner"])
        XCTAssertEqual(days[1].mealGroups.map(\.mealType), ["Lunch", "Unknown meal"])
        XCTAssertEqual(days[1].mealGroups.last?.records.first?.foodName, "Legacy")
        XCTAssertEqual(days.flatMap(\.mealGroups).flatMap(\.records).count, records.count)
    }

    func testDiaryMarksInvalidLegacyCaloriesIncompleteWithoutDroppingRow() throws {
        let calendar = utcCalendar()
        let day = try date(2026, 8, 13, 12, 0, calendar: calendar)
        let days = CalorieDiary.days(from: [
            record(1, date: day, meal: "Lunch", calories: 500, name: "Valid"),
            record(2, date: day, meal: "Lunch", calories: Int.max, name: "Invalid")
        ], calendar: calendar)

        let diaryDay = try XCTUnwrap(days.first)
        XCTAssertEqual(diaryDay.entryCount, 2)
        XCTAssertEqual(diaryDay.calorieTotal.calories, 500)
        XCTAssertFalse(diaryDay.calorieTotal.isComplete)
        XCTAssertEqual(diaryDay.mealGroups.first?.records.map(\.foodName), ["Valid", "Invalid"])
    }

    func testDiaryRejectsNonfiniteDatesAndOrdersTimestampTiesByIdentity() throws {
        let calendar = utcCalendar()
        let date = try date(2026, 8, 13, 12, 0, calendar: calendar)
        let days = CalorieDiary.days(from: [
            record(2, date: date, meal: "Lunch", calories: 20, name: "Second"),
            record(1, date: date, meal: "Lunch", calories: 10, name: "First"),
            record(3, date: Date(timeIntervalSinceReferenceDate: .infinity), meal: "Lunch", calories: 30, name: "Invalid date")
        ], calendar: calendar)

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].mealGroups[0].records.map(\.foodName), ["First", "Second"])
    }

    func testAdjacentDaysTraverseRecordedDaysOnly() throws {
        let calendar = utcCalendar()
        let dates = try [1, 3, 7].map { try date(2026, 8, $0, 12, 0, calendar: calendar) }
        let days = CalorieDiary.days(from: dates.enumerated().map {
            record(UInt8($0.offset + 1), date: $0.element, meal: "Lunch", calories: 100, name: "Day")
        }, calendar: calendar)
        let middle = calendar.startOfDay(for: dates[1])

        let adjacent = CalorieDiary.adjacentDays(to: middle, in: days)

        XCTAssertEqual(adjacent.previous?.date, calendar.startOfDay(for: dates[0]))
        XCTAssertEqual(adjacent.next?.date, calendar.startOfDay(for: dates[2]))
        let oldest = CalorieDiary.adjacentDays(to: calendar.startOfDay(for: dates[0]), in: days)
        XCTAssertNil(oldest.previous)
        XCTAssertEqual(oldest.next?.date, middle)
    }

    func testHistoricalMutationScalesImmutableCaloriesAndRejectsInvalidInputs() throws {
        let scaled = try XCTUnwrap(HistoricalFoodMutation.scaledSnapshot(
            originalCalories: 150,
            originalAmount: 100,
            originalPortions: 1,
            newAmount: 125,
            newPortions: 2
        ))
        XCTAssertEqual(scaled.multiplier, 2.5, accuracy: 0.000_001)
        XCTAssertEqual(scaled.calories, 375)

        XCTAssertNil(HistoricalFoodMutation.scaledSnapshot(
            originalCalories: 150,
            originalAmount: 0,
            originalPortions: 1,
            newAmount: 100,
            newPortions: 1
        ))
        XCTAssertNil(HistoricalFoodMutation.scaledSnapshot(
            originalCalories: 5_000,
            originalAmount: 1,
            originalPortions: 1,
            newAmount: 2,
            newPortions: 1
        ))
        XCTAssertNil(HistoricalFoodMutation.scaledSnapshot(
            originalCalories: 0,
            originalAmount: 1,
            originalPortions: 1,
            newAmount: 1,
            newPortions: Double.greatestFiniteMagnitude
        ))
        XCTAssertFalse(HistoricalFoodMutation.isValidTimestamp(
            Date(timeIntervalSinceReferenceDate: .infinity),
            now: Date(timeIntervalSinceReferenceDate: 100)
        ))
        XCTAssertFalse(HistoricalFoodMutation.isValidTimestamp(
            Date(timeIntervalSinceReferenceDate: 101),
            now: Date(timeIntervalSinceReferenceDate: 100)
        ))
    }

    func testDiaryMutationEligibilityRequiresKnownProvenanceAndSupportedStoredUnit() throws {
        let date = try XCTUnwrap(utcCalendar().date(from: DateComponents(year: 2026, month: 8, day: 13)))
        let known = CalorieDiaryRecord(
            id: UUID(),
            date: date,
            mealType: "Snack",
            foodName: "Known",
            calories: 100,
            loggedAmount: 250,
            portionCount: 1,
            unitRawValue: "ml",
            modifiedAt: date,
            loggedSnapshotKindRawValue: "item"
        )
        let legacy = CalorieDiaryRecord(
            id: UUID(),
            date: date,
            mealType: "Snack",
            foodName: "Legacy aggregate",
            calories: 100,
            loggedAmount: 250,
            portionCount: 1,
            unitRawValue: "ml"
        )
        let unknownUnit = CalorieDiaryRecord(
            id: UUID(),
            date: date,
            mealType: "Snack",
            foodName: "Unknown unit",
            calories: 100,
            loggedAmount: 250,
            portionCount: 1,
            unitRawValue: "oz",
            modifiedAt: date,
            loggedSnapshotKindRawValue: "item"
        )

        XCTAssertTrue(known.canEditOrCopy)
        XCTAssertFalse(legacy.canEditOrCopy)
        XCTAssertFalse(unknownUnit.canEditOrCopy)
        XCTAssertEqual(unknownUnit.unitRawValue, "g", "Display compatibility still normalizes unknown units.")
    }

    func testDiaryPreservesPairedVolumeAmountAndNormalizesUnknownUnit() throws {
        let date = try XCTUnwrap(utcCalendar().date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 13
        )))
        let volume = CalorieDiaryRecord(
            id: UUID(),
            date: date,
            mealType: "Snack",
            foodName: "Oat drink",
            calories: 100,
            loggedAmount: 250,
            portionCount: 1,
            unitRawValue: "ml"
        )
        let unknown = CalorieDiaryRecord(
            id: UUID(),
            date: date,
            mealType: "Snack",
            foodName: "Legacy",
            calories: 10,
            loggedAmount: 28.35,
            portionCount: 1,
            unitRawValue: "oz"
        )

        XCTAssertEqual(volume.loggedAmount, 250)
        XCTAssertEqual(volume.unitRawValue, "ml")
        XCTAssertEqual(unknown.loggedAmount, 28.35)
        XCTAssertEqual(unknown.unitRawValue, "g")
    }

    private func record(
        _ value: UInt8,
        date: Date,
        meal: String?,
        calories: Int,
        name: String
    ) -> CalorieDiaryRecord {
        CalorieDiaryRecord(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value)),
            date: date,
            mealType: meal,
            foodName: name,
            calories: calories,
            loggedAmount: 100,
            portionCount: 1,
            unitRawValue: "g"
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
