import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class CalculatedCaloriePlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 7,
            hour: 12
        ))!
    }

    func testPublishedFemaleAndMaleRestingEquationVectors() throws {
        let female = try recommendation(input(equation: .female, goalMode: .maintain))
        let male = try recommendation(input(equation: .male, goalMode: .maintain))

        XCTAssertEqual(female.restingCalories, 1_451.5, accuracy: 0.000_001)
        XCTAssertEqual(male.restingCalories, 1_617.5, accuracy: 0.000_001)
        XCTAssertEqual(female.maintenanceCalories, 1_814.375, accuracy: 0.000_001)
        XCTAssertEqual(female.calorieGoal, 1_810)
    }

    func testEveryActivityFactorIsAppliedWithoutHiddenExerciseEnergy() throws {
        let expected: [(PlanActivityLevel, Double)] = [
            (.low, 1.25),
            (.moderate, 1.38),
            (.high, 1.52),
            (.veryHigh, 1.65)
        ]

        for (level, factor) in expected {
            let plan = try recommendation(input(
                equation: .female,
                activityLevel: level,
                goalMode: .maintain
            ))
            XCTAssertEqual(plan.activityFactor, factor, accuracy: 0.000_001)
            XCTAssertEqual(
                plan.maintenanceCalories,
                plan.restingCalories * factor,
                accuracy: 0.000_001
            )
        }
    }

    func testLoseAndGainUseTransparentRateAdjustmentAndForecast() throws {
        let lose = try recommendation(input(
            goalMode: .lose,
            currentWeight: 70,
            targetWeight: 65,
            weeklyRate: 0.25
        ))
        let gain = try recommendation(input(
            goalMode: .gain,
            currentWeight: 70,
            targetWeight: 75,
            weeklyRate: 0.25
        ))

        XCTAssertEqual(lose.dailyAdjustmentCalories, 275, accuracy: 0.000_001)
        XCTAssertEqual(lose.calorieGoal, 1_540)
        XCTAssertEqual(gain.calorieGoal, 2_090)
        XCTAssertEqual(
            lose.forecastDate,
            calendar.date(byAdding: .day, value: 140, to: calendar.startOfDay(for: now))
        )
    }

    func testDateModeDerivesRateUsingLocalCalendarDays() throws {
        let date = calendar.date(byAdding: .day, value: 84, to: now)!
        let plan = try recommendation(input(
            goalMode: .lose,
            currentWeight: 70,
            targetWeight: 65,
            paceBasis: .targetDate,
            targetDate: date
        ))

        XCTAssertEqual(plan.effectiveWeeklyRateKilograms, 5 / 12, accuracy: 0.000_001)
        XCTAssertEqual(
            plan.forecastDate,
            calendar.startOfDay(for: date)
        )
    }

    func testTooSoonDateReturnsEarliestFeasibleDateInsteadOfExtremeGoal() {
        let targetDate = calendar.date(byAdding: .day, value: 14, to: now)!
        let evaluation = CalculatedCaloriePlanCalculator.evaluate(input(
            goalMode: .lose,
            currentWeight: 70,
            targetWeight: 65,
            paceBasis: .targetDate,
            targetDate: targetDate
        ), now: now, calendar: calendar)
        let expected = calendar.date(
            byAdding: .day,
            value: 70,
            to: calendar.startOfDay(for: now)
        )!

        XCTAssertEqual(
            evaluation,
            .unsupported(.targetDateTooSoon(earliestFeasibleDate: expected))
        )
    }

    func testRateAndGoalRelationshipsAreBounded() {
        for rate in [Double.zero, -0.25, 0.3, 0.500_001, .nan] {
            XCTAssertEqual(
                CalculatedCaloriePlanCalculator.evaluate(input(
                    goalMode: .lose,
                    currentWeight: 70,
                    targetWeight: 65,
                    weeklyRate: rate
                ), now: now, calendar: calendar),
                .unsupported(.invalidRate)
            )
        }
        XCTAssertNoThrow(try recommendation(input(
            goalMode: .lose,
            currentWeight: 70,
            targetWeight: 65,
            weeklyRate: 0.5
        )))
        XCTAssertEqual(
            CalculatedCaloriePlanCalculator.evaluate(input(
                goalMode: .lose,
                currentWeight: 70,
                targetWeight: 75
            ), now: now, calendar: calendar),
            .unsupported(.invalidGoalRelationship)
        )
        XCTAssertEqual(
            CalculatedCaloriePlanCalculator.evaluate(input(
                goalMode: .maintain,
                currentWeight: 70,
                targetWeight: 69
            ), now: now, calendar: calendar),
            .unsupported(.invalidGoalRelationship)
        )
        XCTAssertEqual(
            CalculatedCaloriePlanCalculator.evaluate(input(
                goalMode: .gain,
                currentWeight: 70,
                targetWeight: 65
            ), now: now, calendar: calendar),
            .unsupported(.invalidGoalRelationship)
        )
    }

    func testAgeWeightHeightFiniteAndBMIBoundariesRejectUnsupportedInputs() {
        XCTAssertIssue(.invalidAge, input: input(age: 18))
        XCTAssertIssue(.invalidAge, input: input(age: 79))
        XCTAssertIssue(.invalidWeight, input: input(currentWeight: .infinity))
        XCTAssertIssue(.invalidWeight, input: input(currentWeight: 19))
        XCTAssertIssue(.invalidHeight, input: input(height: .nan))
        XCTAssertIssue(.invalidHeight, input: input(height: 251))
        XCTAssertIssue(
            .belowSupportedBMI,
            input: input(currentWeight: 50, targetWeight: 50, height: 170)
        )
        XCTAssertIssue(
            .belowSupportedBMI,
            input: input(
                goalMode: .lose,
                currentWeight: 60,
                targetWeight: 50,
                height: 170
            )
        )
    }

    func testExactInputAndCalorieBoundariesRemainDeterministic() throws {
        let exactMinimumBMI = try recommendation(input(
            equation: .male,
            goalMode: .maintain,
            currentWeight: 74,
            targetWeight: 74,
            age: 30,
            height: 200
        ))
        XCTAssertEqual(
            CalculatedCaloriePlanCalculator.bodyMassIndex(
                kilograms: exactMinimumBMI.input.currentWeightKilograms,
                heightCentimeters: exactMinimumBMI.input.heightCentimeters
            ),
            18.5,
            accuracy: 0.000_001
        )

        let minimumAge = try recommendation(input(age: 19))
        let maximumAge = try recommendation(input(age: 78))
        XCTAssertGreaterThanOrEqual(minimumAge.calorieGoal, 1_000)
        XCTAssertGreaterThanOrEqual(maximumAge.calorieGoal, 1_000)

        XCTAssertIssue(
            .resultBelowMinimum,
            input: input(
                equation: .male,
                activityLevel: .low,
                goalMode: .maintain,
                currentWeight: 20,
                targetWeight: 20,
                age: 19,
                height: 100
            )
        )
        XCTAssertIssue(
            .resultAboveMaximum,
            input: input(
                equation: .male,
                activityLevel: .veryHigh,
                goalMode: .maintain,
                currentWeight: 500,
                targetWeight: 500,
                age: 19,
                height: 250
            )
        )

        let minimumCalories = try recommendation(input(
            equation: .female,
            activityLevel: .low,
            goalMode: .maintain,
            currentWeight: 72.6,
            targetWeight: 72.6,
            age: 78,
            height: 100
        ))
        XCTAssertEqual(minimumCalories.maintenanceCalories, 1_000, accuracy: 0.000_001)
        XCTAssertEqual(minimumCalories.calorieGoal, 1_000)

        let maximumCalories = try recommendation(input(
            equation: .male,
            activityLevel: .low,
            goalMode: .maintain,
            currentWeight: 252.75,
            targetWeight: 252.75,
            age: 19,
            height: 250
        ))
        XCTAssertEqual(maximumCalories.maintenanceCalories, 5_000, accuracy: 0.000_001)
        XCTAssertEqual(maximumCalories.calorieGoal, 5_000)
    }

    func testHalfAwayRoundingAndPreRoundBoundsAreAppliedInCorrectOrder() throws {
        let half = try recommendation(input(
            equation: .female,
            activityLevel: .low,
            goalMode: .maintain,
            currentWeight: 70.05,
            targetWeight: 70.05,
            age: 30,
            height: 170
        ))
        XCTAssertEqual(half.maintenanceCalories, 1_815, accuracy: 0.000_001)
        XCTAssertEqual(half.calorieGoal, 1_820)

        XCTAssertIssue(
            .resultBelowMinimum,
            input: input(
                equation: .female,
                activityLevel: .low,
                goalMode: .maintain,
                currentWeight: 72.592,
                targetWeight: 72.592,
                age: 78,
                height: 100
            )
        )
        XCTAssertIssue(
            .resultAboveMaximum,
            input: input(
                equation: .male,
                activityLevel: .low,
                goalMode: .maintain,
                currentWeight: 252.758,
                targetWeight: 252.758,
                age: 19,
                height: 250
            )
        )
    }

    func testCalorieBoundsReturnNoClampedRecommendation() {
        XCTAssertIssue(
            .resultBelowMinimum,
            input: input(
                equation: .female,
                activityLevel: .low,
                goalMode: .lose,
                currentWeight: 50,
                targetWeight: 49,
                age: 78,
                height: 160,
                weeklyRate: 0.5
            )
        )
        XCTAssertIssue(
            .resultAboveMaximum,
            input: input(
                equation: .male,
                activityLevel: .veryHigh,
                goalMode: .maintain,
                currentWeight: 500,
                targetWeight: 500,
                age: 19,
                height: 250
            )
        )
    }

    func testNonfiniteDatesReturnTypedIssuesWithoutCalendarMath() {
        let invalidDate = Date(timeIntervalSinceReferenceDate: .nan)
        XCTAssertIssue(
            .targetDateNotFuture,
            input: input(
                goalMode: .lose,
                currentWeight: 70,
                targetWeight: 69,
                paceBasis: .targetDate,
                targetDate: invalidDate
            )
        )
        XCTAssertEqual(
            CalculatedCaloriePlanCalculator.evaluate(
                input(),
                now: invalidDate,
                calendar: calendar
            ),
            .unsupported(.invalidCalculation)
        )
    }

    func testPastDateNeverProducesRecommendation() {
        XCTAssertIssue(
            .targetDateNotFuture,
            input: input(
                goalMode: .lose,
                currentWeight: 70,
                targetWeight: 69,
                paceBasis: .targetDate,
                targetDate: now
            )
        )
    }

    func testUnitConversionsRoundTripCanonicalValues() {
        let kilograms = 71.2
        let centimeters = 173.4

        XCTAssertEqual(
            PlanUnitConversion.kilograms(
                fromPounds: PlanUnitConversion.pounds(fromKilograms: kilograms)
            ),
            kilograms,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            PlanUnitConversion.centimeters(
                fromInches: PlanUnitConversion.inches(fromCentimeters: centimeters)
            ),
            centimeters,
            accuracy: 0.000_001
        )
    }

    func testEarliestFeasibleDateUsesExactLocalDayBoundary() throws {
        let earliest = try XCTUnwrap(
            CalculatedCaloriePlanCalculator.earliestFeasibleDate(
                currentWeightKilograms: 70,
                targetWeightKilograms: 65,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            earliest,
            calendar.date(
                byAdding: .day,
                value: 70,
                to: calendar.startOfDay(for: now)
            )
        )
    }

    func testDateModeStillAppliesCalorieBounds() {
        let twoWeeks = calendar.date(byAdding: .day, value: 14, to: now)!
        XCTAssertIssue(
            .resultBelowMinimum,
            input: input(
                equation: .female,
                activityLevel: .low,
                goalMode: .lose,
                currentWeight: 50,
                targetWeight: 49,
                age: 78,
                height: 160,
                paceBasis: .targetDate,
                targetDate: twoWeeks
            )
        )
        XCTAssertIssue(
            .resultAboveMaximum,
            input: input(
                equation: .male,
                activityLevel: .veryHigh,
                goalMode: .gain,
                currentWeight: 400,
                targetWeight: 401,
                age: 19,
                height: 250,
                paceBasis: .targetDate,
                targetDate: twoWeeks
            )
        )
    }

    func testTargetDateWorksWithNonGregorianLocalCalendar() throws {
        var islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        islamicCalendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let localNow = Date(timeIntervalSince1970: 1_800_000_000)
        let targetDate = try XCTUnwrap(
            islamicCalendar.date(byAdding: .day, value: 84, to: localNow)
        )
        let plan = try recommendation(
            input(
                goalMode: .lose,
                currentWeight: 70,
                targetWeight: 65,
                paceBasis: .targetDate,
                targetDate: targetDate
            ),
            now: localNow,
            calendar: islamicCalendar
        )

        XCTAssertEqual(plan.effectiveWeeklyRateKilograms, 5 / 12, accuracy: 0.000_001)
        XCTAssertEqual(
            islamicCalendar.dateComponents(
                [.day],
                from: islamicCalendar.startOfDay(for: localNow),
                to: try XCTUnwrap(plan.forecastDate)
            ).day,
            84
        )
    }

    func testForecastUsesCalendarDaysAcrossDST() throws {
        let plan = try recommendation(input(
            goalMode: .lose,
            currentWeight: 70.5,
            targetWeight: 70,
            weeklyRate: 0.5
        ))
        let forecast = try XCTUnwrap(plan.forecastDate)

        XCTAssertEqual(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: forecast
            ).day,
            7
        )
        XCTAssertEqual(calendar.component(.hour, from: forecast), 0)
    }

    private func input(
        equation: CalorieEquation = .female,
        activityLevel: PlanActivityLevel = .low,
        goalMode: PlanGoalMode = .maintain,
        currentWeight: Double = 70,
        targetWeight: Double = 70,
        age: Int = 30,
        height: Double = 170,
        paceBasis: PlanPaceBasis = .weeklyRate,
        weeklyRate: Double = 0.25,
        targetDate: Date? = nil
    ) -> CaloriePlanInput {
        CaloriePlanInput(
            goalMode: goalMode,
            currentWeightKilograms: currentWeight,
            targetWeightKilograms: targetWeight,
            age: age,
            heightCentimeters: height,
            equation: equation,
            activityLevel: activityLevel,
            paceBasis: paceBasis,
            weeklyRateKilograms: weeklyRate,
            targetDate: targetDate
        )
    }

    private func recommendation(
        _ input: CaloriePlanInput,
        now: Date? = nil,
        calendar: Calendar? = nil
    ) throws -> CalculatedCaloriePlan {
        let evaluation = CalculatedCaloriePlanCalculator.evaluate(
            input,
            now: now ?? self.now,
            calendar: calendar ?? self.calendar
        )
        guard case .recommendation(let plan) = evaluation else {
            XCTFail("Expected recommendation, got \(evaluation)")
            throw NSError(domain: "CalculatedCaloriePlanTests", code: 1)
        }
        return plan
    }

    private func XCTAssertIssue(
        _ expected: CaloriePlanIssue,
        input: CaloriePlanInput,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            CalculatedCaloriePlanCalculator.evaluate(
                input,
                now: now,
                calendar: calendar
            ),
            .unsupported(expected),
            file: file,
            line: line
        )
    }
}
