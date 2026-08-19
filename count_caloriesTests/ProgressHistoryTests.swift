import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class ProgressHistoryTests: XCTestCase {
    func testEmptyProgressHasNoSummariesOrWeightValues() {
        let calories = ProgressHistory.calorieProgress(summaries: [], goalRevisions: [])
        let weights = ProgressHistory.weightProgress(entries: [], targetWeight: 68)

        XCTAssertEqual(calories, CalorieProgress(summaries: [], averageCalories: nil, goalDifference: nil))
        XCTAssertEqual(weights.points, [])
        XCTAssertNil(weights.current)
        XCTAssertNil(weights.periodChange)
        XCTAssertNil(weights.targetDistance)
        XCTAssertNil(weights.domain)
    }

    func testCalorieAverageIsAboveGoal() {
        let progress = ProgressHistory.calorieProgress(
            summaries: [summary(day: 1, calories: 200), summary(day: 2, calories: 300)],
            goalRevisions: [revision(day: 1, sequence: 1, calories: 200)],
            calendar: calendar
        )

        XCTAssertEqual(progress.averageCalories, 250)
        XCTAssertEqual(progress.goalDifference, 50)
    }

    func testCalorieAverageIsBelowGoal() {
        let progress = ProgressHistory.calorieProgress(
            summaries: [summary(day: 1, calories: 100), summary(day: 2, calories: 200)],
            goalRevisions: [revision(day: 1, sequence: 1, calories: 200)],
            calendar: calendar
        )

        XCTAssertEqual(progress.averageCalories, 150)
        XCTAssertEqual(progress.goalDifference, -50)
    }

    func testCalorieAverageCanEqualGoal() {
        let progress = ProgressHistory.calorieProgress(
            summaries: [summary(day: 1, calories: 150), summary(day: 2, calories: 250)],
            goalRevisions: [revision(day: 1, sequence: 1, calories: 200)],
            calendar: calendar
        )

        XCTAssertEqual(progress.averageCalories, 200)
        XCTAssertEqual(progress.goalDifference, 0)
    }

    func testHistoricalGoalContextUsesHighestEffectiveSequenceWithoutFabricatingEarlierDays() {
        let progress = ProgressHistory.calorieProgress(
            summaries: [
                summary(day: 1, calories: 1_700),
                summary(day: 2, calories: 1_800),
                summary(day: 3, calories: 1_900),
                summary(day: 4, calories: 2_100)
            ],
            goalRevisions: [
                revision(day: 2, sequence: 1, calories: 1_800),
                revision(day: 3, sequence: 2, calories: 2_000),
                revision(day: 3, sequence: 3, calories: 1_900),
                revision(day: 5, sequence: 4, calories: 5_000)
            ],
            calendar: calendar
        )

        XCTAssertEqual(progress.goalContexts.map(\.calories), [nil, 1_800, 1_900, 1_900])
        XCTAssertEqual(progress.comparableGoalDays, 3)
        XCTAssertEqual(progress.missingGoalDays, 1)
        XCTAssertEqual(progress.goalDifference ?? .nan, 200.0 / 3.0, accuracy: 0.000_001)
    }

    func testHistoricalGoalResolverRejectsInvalidHistoryAndUsesLatestSequence() {
        let selectedDay = date(day: 3)
        let goal = ProgressHistory.calorieGoal(
            for: selectedDay,
            revisions: [
                revision(day: 1, sequence: 1, calories: 1_700),
                revision(day: 3, sequence: 2, calories: 1_800),
                revision(day: 3, sequence: 3, calories: 1_900),
                CalorieGoalRevisionPoint(
                    effectiveDate: Date(timeIntervalSinceReferenceDate: .infinity),
                    sequence: 99,
                    calories: 5_000
                ),
                revision(day: 2, sequence: 100, calories: 0)
            ],
            calendar: calendar
        )

        XCTAssertEqual(goal, 1_900)
        XCTAssertNil(ProgressHistory.calorieGoal(
            for: date(day: 0),
            revisions: [revision(day: 1, sequence: 1, calories: 1_700)],
            calendar: calendar
        ))
        XCTAssertNil(ProgressHistory.calorieGoal(
            for: Date(timeIntervalSinceReferenceDate: .nan),
            revisions: [revision(day: 1, sequence: 1, calories: 1_700)],
            calendar: calendar
        ))
    }

    func testCaloriesAreSortedAndLimitedToMostRecentSevenDays() {
        let progress = ProgressHistory.calorieProgress(
            summaries: (1...9).reversed().map { summary(day: $0, calories: $0 * 100) },
            goalRevisions: [],
            calendar: calendar
        )

        XCTAssertEqual(progress.summaries.map(\.date), (3...9).map { date(day: $0) })
        XCTAssertEqual(progress.summaries.map(\.calories), (3...9).map { $0 * 100 })
    }

    func testNegativeCalorieSummariesAreIgnored() {
        let progress = ProgressHistory.calorieProgress(
            summaries: [
                summary(day: 1, calories: -100),
                summary(day: 2, calories: 200),
                summary(day: 3, calories: 300)
            ],
            goalRevisions: [revision(day: 1, sequence: 1, calories: 200)],
            calendar: calendar
        )

        XCTAssertEqual(progress.summaries.map(\.calories), [200, 300])
        XCTAssertEqual(progress.averageCalories, 250)
        XCTAssertEqual(progress.goalDifference, 50)
    }

    func testInvalidCalorieLimitProducesEmptyProgress() {
        let progress = ProgressHistory.calorieProgress(
            summaries: [summary(day: 1, calories: 200)],
            goalRevisions: [revision(day: 1, sequence: 1, calories: 200)],
            calendar: calendar,
            limit: 0
        )

        XCTAssertEqual(progress, CalorieProgress(summaries: [], averageCalories: nil, goalDifference: nil))
    }

    func testCalorieAverageUsesDoubleBeforeSumming() {
        let progress = ProgressHistory.calorieProgress(
            summaries: [
                summary(day: 1, calories: Int.max),
                summary(day: 2, calories: Int.max)
            ],
            goalRevisions: [],
            calendar: calendar
        )

        XCTAssertEqual(progress.averageCalories, Double(Int.max))
    }

    func testWeightProgressSortsAndKeepsMostRecentFourteen() {
        let entries = (1...16).reversed().map { day in
            WeightProgressPoint(date: date(day: day), kilograms: Double(day))
        }

        let progress = ProgressHistory.weightProgress(entries: entries, targetWeight: 20)

        XCTAssertEqual(progress.points.map(\.kilograms), (3...16).map(Double.init))
        XCTAssertEqual(progress.current, 16)
        XCTAssertEqual(progress.periodChange, 13)
    }

    func testWeightProgressRetainsDuplicateTimestampsWithoutWeightTieBreakers() {
        let duplicateDate = date(day: 1)
        let progress = ProgressHistory.weightProgress(
            entries: [
                WeightProgressPoint(date: duplicateDate, kilograms: 72),
                WeightProgressPoint(date: duplicateDate, kilograms: 70),
                point(day: 2, kilograms: 71)
            ],
            targetWeight: nil
        )

        XCTAssertEqual(progress.points.map(\.date), [duplicateDate, duplicateDate, date(day: 2)])
        XCTAssertEqual(progress.points.map(\.kilograms), [72, 70, 71])
    }

    func testWeightProgressUsesStableSequenceForSameTimestampCurrent() {
        let timestamp = date(day: 4)
        let progress = ProgressHistory.weightProgress(
            entries: [
                WeightProgressPoint(
                    date: timestamp,
                    kilograms: 72,
                    stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    sequence: 2
                ),
                WeightProgressPoint(
                    date: timestamp,
                    kilograms: 70,
                    stableID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    sequence: 1
                )
            ],
            targetWeight: nil
        )

        XCTAssertEqual(progress.points.map(\.kilograms), [70, 72])
        XCTAssertEqual(progress.current, 72)
    }

    func testRisingWeightHasPositiveChange() {
        let progress = ProgressHistory.weightProgress(
            entries: [point(day: 1, kilograms: 70), point(day: 2, kilograms: 71.2)],
            targetWeight: 68
        )

        XCTAssertEqual(progress.periodChange ?? .nan, 1.2, accuracy: 0.0001)
    }

    func testFallingWeightHasNegativeChange() {
        let progress = ProgressHistory.weightProgress(
            entries: [point(day: 1, kilograms: 71.2), point(day: 2, kilograms: 70)],
            targetWeight: 68
        )

        XCTAssertEqual(progress.periodChange ?? .nan, -1.2, accuracy: 0.0001)
    }

    func testSingleWeightHasCurrentWithoutPeriodChange() {
        let progress = ProgressHistory.weightProgress(
            entries: [point(day: 1, kilograms: 70)],
            targetWeight: 68
        )

        XCTAssertEqual(progress.current, 70)
        XCTAssertNil(progress.periodChange)
    }

    func testWeightProgressIgnoresFutureRowsWhenNowIsProvided() {
        let now = date(day: 10)
        let progress = ProgressHistory.weightProgress(
            entries: [
                point(day: 9, kilograms: 70),
                point(day: 11, kilograms: 68),
                point(day: 12, kilograms: .infinity)
            ],
            targetWeight: 68,
            now: now
        )

        XCTAssertEqual(progress.points.map(\.kilograms), [70])
        XCTAssertEqual(progress.current, 70)
        XCTAssertNil(progress.periodChange)
        XCTAssertEqual(progress.targetDistance, -2)
    }

    func testInvalidWeightsAndTargetAreIgnored() {
        let progress = ProgressHistory.weightProgress(
            entries: [
                point(day: 1, kilograms: .nan),
                point(day: 2, kilograms: .infinity),
                point(day: 3, kilograms: -2),
                point(day: 4, kilograms: 70)
            ],
            targetWeight: .infinity
        )

        XCTAssertEqual(progress.points.map(\.kilograms), [70])
        XCTAssertEqual(progress.current, 70)
        XCTAssertNil(progress.targetDistance)
        XCTAssertEqual(progress.domain, 69.5...70.5)
    }

    func testTargetDistanceUsesTargetMinusCurrentWeight() {
        let progress = ProgressHistory.weightProgress(
            entries: [point(day: 1, kilograms: 70)],
            targetWeight: 68
        )

        XCTAssertEqual(progress.targetDistance, -2)
    }

    func testAdaptiveWeightDomainIncludesValuesWithoutForcingZero() {
        let domain = ProgressHistory.adaptiveWeightDomain(values: [69.8, 70.2, 70])

        XCTAssertEqual(domain, 69.3...70.7)
        XCTAssertGreaterThan(domain!.lowerBound, 0)
    }

    private func summary(day: Int, calories: Int) -> DailyCalorieSummary {
        DailyCalorieSummary(date: date(day: day), calories: calories)
    }

    private func revision(day: Int, sequence: Int64, calories: Int) -> CalorieGoalRevisionPoint {
        CalorieGoalRevisionPoint(effectiveDate: date(day: day), sequence: sequence, calories: calories)
    }

    private func point(day: Int, kilograms: Double) -> WeightProgressPoint {
        WeightProgressPoint(date: date(day: day), kilograms: kilograms)
    }

    private func date(day: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: day
        ).date!
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
