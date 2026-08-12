import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class AdaptiveCaloriePlanTests: XCTestCase {
    func testProposalUsesFortyTwoLocalDaysEndingYesterdayAcrossDSTAndLeapDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = date(2024, 4, 10, calendar: calendar)
        let input = baseInput(currentGoal: 1_900, calendar: calendar, now: now)
        XCTAssertTrue(input.foodDays.contains { calendar.component(.month, from: $0.date) == 2 && calendar.component(.day, from: $0.date) == 29 })
        let result = evaluate(input, now: now, calendar: calendar)

        let proposal = try proposal(result)
        XCTAssertEqual(proposal.proposedDailyGoal, 2_000)
        XCTAssertEqual(proposal.evidence.estimates.map(\.nominalDays), [28, 35, 42])
        XCTAssertEqual(
            calendar.dateComponents([.day], from: proposal.evidence.estimates[0].trendStart, to: proposal.evidence.estimates[0].trendEnd).day,
            27
        )
        XCTAssertEqual(calendar.component(.hour, from: proposal.evidence.estimates[0].trendStart), 0)
    }

    func testNonGregorianCalendarUsesLocalCalendarWindows() throws {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Riyadh"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let result = evaluate(baseInput(currentGoal: 1_900, calendar: calendar, now: now), now: now, calendar: calendar)

        let proposal = try proposal(result)
        XCTAssertEqual(
            calendar.dateComponents([.day], from: proposal.evidence.estimates[2].trendStart, to: proposal.evidence.estimates[2].trendEnd).day,
            41
        )
    }

    func testMissingAndStaleFoodCollectWhileExplicitZeroRemainsComplete() throws {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        var missing = baseInput(currentGoal: 1_900, calendar: calendar, now: now)
        missing = AdaptiveCaloriePlanInput(
            source: missing.source,
            currentSupportedScope: missing.currentSupportedScope,
            currentDailyGoal: missing.currentDailyGoal,
            calculatedPlan: missing.calculatedPlan,
            foodDays: Array(missing.foodDays.dropLast()),
            weights: missing.weights
        )
        XCTAssertCollecting(evaluate(missing, now: now, calendar: calendar), contains: .completeFoodDays)

        var staleFood = baseInput(currentGoal: 1_900, calendar: calendar, now: now).foodDays
        staleFood[10] = AdaptiveCalorieFoodDay(date: staleFood[10].date, calories: 2_000, isStale: true)
        let stale = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(), foodDays: staleFood,
            weights: weights(calendar: calendar, now: now)
        )
        XCTAssertCollecting(evaluate(stale, now: now, calendar: calendar), contains: .completeFoodDays)

        let zero = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true,
            currentDailyGoal: 1_900,
            calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now, calories: 0),
            weights: weights(calendar: calendar, now: now)
        )
        guard case .checkData(let data) = evaluate(zero, now: now, calendar: calendar) else {
            return XCTFail("Explicit zero food days must not be treated as missing")
        }
        XCTAssertEqual(data.reason, .unsupportedMaintenance)
        XCTAssertEqual(data.estimates?.completeFoodDays, 42)
    }

    func testCalculatedAndAdaptedRequireCurrentSupportedScopeConfirmation() {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let evidence = baseInput(currentGoal: 1_900, calendar: calendar, now: now)
        let omitted = AdaptiveCaloriePlanInput(
            source: .calculated, currentDailyGoal: evidence.currentDailyGoal,
            calculatedPlan: evidence.calculatedPlan, foodDays: evidence.foodDays, weights: evidence.weights
        )
        let falseConfirmation = AdaptiveCaloriePlanInput(
            source: .adapted, currentSupportedScope: false, currentDailyGoal: evidence.currentDailyGoal,
            calculatedPlan: evidence.calculatedPlan, foodDays: evidence.foodDays, weights: evidence.weights
        )

        XCTAssertEqual(evaluate(omitted, now: now, calendar: calendar), .paused(.unsupportedScope))
        XCTAssertEqual(evaluate(falseConfirmation, now: now, calendar: calendar), .paused(.unsupportedScope))
    }

    func testCollectionEnforcesWeightCountsBoundariesBlocksAndGaps() {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let sparse = [0, 11, 21, 31, 41].map { offset in
            AdaptiveCalorieWeight(date: evidenceDay(offset, calendar: calendar, now: now), kilograms: 70)
        }
        let input = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now), weights: sparse
        )
        XCTAssertCollecting(evaluate(input, now: now, calendar: calendar), contains: .eightWeighInDays)
        XCTAssertCollecting(evaluate(input, now: now, calendar: calendar), contains: .sixRecentWeighInDays)
        XCTAssertCollecting(evaluate(input, now: now, calendar: calendar), contains: .maximumWeightGap)
        XCTAssertCollecting(evaluate(input, now: now, calendar: calendar), contains: .weighInInSevenDayBlock(2))

        let noFinal = weights(calendar: calendar, now: now).filter {
            $0.date < evidenceDay(39, calendar: calendar, now: now)
        }
        let noFinalInput = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now), weights: noFinal
        )
        XCTAssertCollecting(evaluate(noFinalInput, now: now, calendar: calendar), contains: .commonFinalBoundary)
    }

    func testSameDayMedianDoesNotAddWeightInfluence() throws {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        var readings = weights(calendar: calendar, now: now)
        let middle = evidenceDay(20, calendar: calendar, now: now)
        readings.removeAll { $0.date == middle }
        readings += [
            AdaptiveCalorieWeight(date: middle, kilograms: 68),
            AdaptiveCalorieWeight(date: middle, kilograms: 72)
        ]
        let input = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now), weights: readings
        )
        let proposal = try proposal(evaluate(input, now: now, calendar: calendar))
        XCTAssertEqual(proposal.evidence.estimate28Days?.kilogramsPerDay ?? .nan, 0, accuracy: 0.000_000_001)
        XCTAssertEqual(proposal.evidence.estimate28Days?.observedMaintenanceCalories ?? .nan, 2_000, accuracy: 0.000_001)
    }

    func testInterpolationRetainsInteriorKnotsBeforeSmoothingAndOLS() throws {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let knots: [(Int, Double)] = [(0, 70), (7, 69.7), (14, 69.8), (17, 69.2), (21, 69.4), (28, 68.7), (35, 68.9), (41, 68.2)]
        let input = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 2_000, calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now),
            weights: knots.map { AdaptiveCalorieWeight(date: evidenceDay($0.0, calendar: calendar, now: now), kilograms: $0.1) }
        )
        let result = evaluate(input, now: now, calendar: calendar)
        guard case .proposal(let proposal) = result else {
            return XCTFail("Interior-knot vector should yield a proposal: \(result)")
        }
        let estimates = proposal.evidence.estimates
        XCTAssertEqual(estimates[0].kilogramsPerDay, -0.037837111129037086, accuracy: 0.000_000_000_001)
        XCTAssertEqual(estimates[1].kilogramsPerDay, -0.04327938071780438, accuracy: 0.000_000_000_001)
        XCTAssertEqual(estimates[2].kilogramsPerDay, -0.03983146411717822, accuracy: 0.000_000_000_001)
    }

    func testCoincidentFoodIntervalAndMaintenanceFormula() throws {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        var food = foodDays(calendar: calendar, now: now)
        food[0] = AdaptiveCalorieFoodDay(date: food[0].date, calories: 9_000)
        let input = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(), foodDays: food,
            weights: weights(calendar: calendar, now: now)
        )
        guard case .checkData(let check) = evaluate(input, now: now, calendar: calendar),
              let evidence = check.estimates else { return XCTFail("Expected unsupported interval estimate") }
        XCTAssertEqual(check.reason, .estimatesDisagree)
        XCTAssertEqual(evidence.estimates[0].meanLoggedCalories, 2_000, accuracy: 0.000_001)
        XCTAssertGreaterThan(evidence.estimates[2].meanLoggedCalories, 2_000)
    }

    func testLoseMaintainAndGainUseStoredUnroundedPaceAdjustment() throws {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let cases: [(PlanGoalMode, Double, Double)] = [(.lose, 2_275, 2_000), (.maintain, 2_000, 2_000), (.gain, 1_725, 2_000)]
        for (mode, foodCalories, expectedCandidate) in cases {
            let calculated = plan(mode: mode)
            let input = AdaptiveCaloriePlanInput(
                source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: calculated,
                foodDays: foodDays(calendar: calendar, now: now, calories: foodCalories),
                weights: weights(calendar: calendar, now: now)
            )
            let output = try proposal(evaluate(input, now: now, calendar: calendar))
            XCTAssertEqual(output.candidateCalories, expectedCandidate, accuracy: 0.000_001)
            XCTAssertEqual(output.stepCalories, 100)
        }
    }

    func testManualUnknownScopeAndReachedTargetPause() {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let base = baseInput(currentGoal: 1_900, calendar: calendar, now: now)
        XCTAssertEqual(evaluate(AdaptiveCaloriePlanInput(source: .manual, currentDailyGoal: 1_900, calculatedPlan: plan(), foodDays: [], weights: []), now: now, calendar: calendar), .paused(.manualSource))
        XCTAssertEqual(evaluate(AdaptiveCaloriePlanInput(source: .unknown, currentDailyGoal: 1_900, calculatedPlan: plan(), foodDays: [], weights: []), now: now, calendar: calendar), .paused(.unknownSource))
        XCTAssertEqual(evaluate(AdaptiveCaloriePlanInput(source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: nil, foodDays: base.foodDays, weights: base.weights), now: now, calendar: calendar), .paused(.missingCalculatedBasis))
        XCTAssertNoThrow(try proposal(evaluate(AdaptiveCaloriePlanInput(source: .adapted, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(), foodDays: base.foodDays, weights: base.weights), now: now, calendar: calendar)))
        XCTAssertEqual(evaluate(AdaptiveCaloriePlanInput(source: .calculated, currentSupportedScope: true, currentDailyGoal: 999, calculatedPlan: plan(), foodDays: base.foodDays, weights: base.weights), now: now, calendar: calendar), .paused(.unsupportedScope))

        let unsupportedBMI = CalculatedCaloriePlan(
            input: CaloriePlanInput(goalMode: .maintain, currentWeightKilograms: 70, targetWeightKilograms: 70, age: 30, heightCentimeters: 250, equation: .female, activityLevel: .low, paceBasis: .weeklyRate, weeklyRateKilograms: 0.25, targetDate: nil),
            restingCalories: 1_000, activityFactor: 1, maintenanceCalories: 1_000, dailyAdjustmentCalories: 0,
            effectiveWeeklyRateKilograms: 0, calorieGoal: 1_000, forecastDate: nil
        )
        XCTAssertEqual(evaluate(AdaptiveCaloriePlanInput(source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: unsupportedBMI, foodDays: base.foodDays, weights: base.weights), now: now, calendar: calendar), .paused(.unsupportedScope))

        let reached = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(mode: .lose),
            foodDays: base.foodDays,
            weights: base.weights + [AdaptiveCalorieWeight(date: now, kilograms: 65)]
        )
        XCTAssertEqual(evaluate(reached, now: now, calendar: calendar), .paused(.targetReached))
    }

    func testCorruptStoredPlansPauseBeforeCandidateMath() {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let evidence = baseInput(currentGoal: 1_900, calendar: calendar, now: now)
        let valid = plan(mode: .lose)
        var invalidRelationship = valid.input
        invalidRelationship.targetWeightKilograms = 75
        var invalidRate = valid.input
        invalidRate.weeklyRateKilograms = 0.3
        let corruptPlans = [
            alteredPlan(valid, dailyAdjustmentCalories: .infinity),
            alteredPlan(valid, dailyAdjustmentCalories: -1),
            alteredPlan(valid, input: invalidRelationship),
            alteredPlan(valid, input: invalidRate),
            alteredPlan(plan(), dailyAdjustmentCalories: 1)
        ]

        for corrupt in corruptPlans {
            let input = AdaptiveCaloriePlanInput(
                source: .calculated, currentSupportedScope: true, currentDailyGoal: evidence.currentDailyGoal,
                calculatedPlan: corrupt, foodDays: evidence.foodDays, weights: evidence.weights
            )
            XCTAssertEqual(evaluate(input, now: now, calendar: calendar), .paused(.unsupportedScope))
        }
    }

    func testDeadbandDiscrepancyRoundingAndCumulativeCap() throws {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        XCTAssertUpToDate(baseInput(currentGoal: 1_925, calendar: calendar, now: now))

        let huge = baseInput(currentGoal: 1_500, calendar: calendar, now: now)
        guard case .checkData(let check) = evaluate(huge, now: now, calendar: calendar) else {
            return XCTFail("Expected large discrepancy hold")
        }
        XCTAssertEqual(check.reason, .discrepancyTooLarge)

        let rounded = baseInput(currentGoal: 1_924, calendar: calendar, now: now)
        let output = try proposal(evaluate(rounded, now: now, calendar: calendar))
        XCTAssertEqual(output.rawDifferenceCalories, 76, accuracy: 0.000_001)
        XCTAssertEqual(output.stepCalories, 80)

        let unsupportedCandidate = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_000, calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now, calories: 900), weights: weights(calendar: calendar, now: now)
        )
        XCTAssertCheckData(evaluate(unsupportedCandidate, now: now, calendar: calendar), .unsupportedCandidate)

        let capped = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now), weights: weights(calendar: calendar, now: now),
            acceptedSteps: [AdaptiveCalorieAcceptedStep(effectiveDate: evidenceDay(40, calendar: calendar, now: now), calories: 110)]
        )
        XCTAssertEqual(evaluate(capped, now: now, calendar: calendar), .paused(.cumulativeStepCap))
    }

    func testTrailingStepCapIncludesTodayAndExcludesTwentyEightDaysAgo() throws {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let base = baseInput(currentGoal: 1_900, calendar: calendar, now: now)
        let today = calendar.startOfDay(for: now)
        let twentyEightDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -28, to: today))
        let todayStep = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: base.currentDailyGoal,
            calculatedPlan: base.calculatedPlan, foodDays: base.foodDays, weights: base.weights,
            acceptedSteps: [AdaptiveCalorieAcceptedStep(effectiveDate: today, calories: 110)]
        )
        let expiredStep = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: base.currentDailyGoal,
            calculatedPlan: base.calculatedPlan, foodDays: base.foodDays, weights: base.weights,
            acceptedSteps: [AdaptiveCalorieAcceptedStep(effectiveDate: twentyEightDaysAgo, calories: 110)]
        )

        XCTAssertEqual(evaluate(todayStep, now: now, calendar: calendar), .paused(.cumulativeStepCap))
        XCTAssertNoThrow(try proposal(evaluate(expiredStep, now: now, calendar: calendar)))
    }

    func testNonfiniteDatesAndValuesFailClosedBeforeCalendarMath() {
        let calendar = utc
        let now = date(2026, 8, 1, calendar: calendar)
        let invalidDate = Date(timeIntervalSinceReferenceDate: .nan)
        let invalidDateInput = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(),
            foodDays: [AdaptiveCalorieFoodDay(date: invalidDate, calories: 2_000)], weights: []
        )
        XCTAssertCheckData(evaluate(invalidDateInput, now: now, calendar: calendar), .invalidDate)
        XCTAssertCheckData(evaluate(baseInput(currentGoal: 1_900, calendar: calendar, now: now), now: invalidDate, calendar: calendar), .invalidDate)

        var invalidCalories = baseInput(currentGoal: 1_900, calendar: calendar, now: now).foodDays
        invalidCalories[0] = AdaptiveCalorieFoodDay(date: invalidCalories[0].date, calories: .infinity)
        let badFood = AdaptiveCaloriePlanInput(source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(), foodDays: invalidCalories, weights: weights(calendar: calendar, now: now))
        XCTAssertCheckData(evaluate(badFood, now: now, calendar: calendar), .invalidFoodCalories)

        let baseline = baseInput(currentGoal: 1_900, calendar: calendar, now: now)
        let noisyWeights = baseline.weights + [
            AdaptiveCalorieWeight(date: calendar.date(byAdding: .day, value: 1, to: now)!, kilograms: 69),
            AdaptiveCalorieWeight(date: evidenceDay(20, calendar: calendar, now: now), kilograms: .infinity)
        ]
        let ignoredWeightNoise = AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: 1_900, calculatedPlan: plan(),
            foodDays: baseline.foodDays, weights: noisyWeights
        )
        XCTAssertNoThrow(try proposal(evaluate(ignoredWeightNoise, now: now, calendar: calendar)))
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func evaluate(_ input: AdaptiveCaloriePlanInput, now: Date, calendar: Calendar) -> AdaptiveCaloriePlanEvaluation {
        AdaptiveCaloriePlanEvaluator.evaluate(input, now: now, calendar: calendar)
    }

    private func baseInput(currentGoal: Int, calendar: Calendar, now: Date) -> AdaptiveCaloriePlanInput {
        AdaptiveCaloriePlanInput(
            source: .calculated, currentSupportedScope: true, currentDailyGoal: currentGoal, calculatedPlan: plan(),
            foodDays: foodDays(calendar: calendar, now: now), weights: weights(calendar: calendar, now: now)
        )
    }

    private func foodDays(calendar: Calendar, now: Date, calories: Double = 2_000) -> [AdaptiveCalorieFoodDay] {
        (0..<42).map { AdaptiveCalorieFoodDay(date: evidenceDay($0, calendar: calendar, now: now), calories: calories) }
    }

    private func weights(calendar: Calendar, now: Date) -> [AdaptiveCalorieWeight] {
        (0..<42).map { AdaptiveCalorieWeight(date: evidenceDay($0, calendar: calendar, now: now), kilograms: 70) }
    }

    private func evidenceDay(_ offset: Int, calendar: Calendar, now: Date) -> Date {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .day, value: -41 + offset, to: yesterday)!
    }

    private func plan(mode: PlanGoalMode = .maintain) -> CalculatedCaloriePlan {
        let target: Double
        switch mode {
        case .lose: target = 65
        case .maintain: target = 70
        case .gain: target = 75
        }
        let input = CaloriePlanInput(
            goalMode: mode, currentWeightKilograms: 70, targetWeightKilograms: target,
            age: 30, heightCentimeters: 170, equation: .female, activityLevel: .low,
            paceBasis: .weeklyRate, weeklyRateKilograms: 0.25, targetDate: nil
        )
        guard case .recommendation(let plan) = CalculatedCaloriePlanCalculator.evaluate(input, now: Date(timeIntervalSince1970: 0), calendar: utc) else {
            fatalError("Valid calculated plan fixture failed")
        }
        return plan
    }

    private func alteredPlan(
        _ plan: CalculatedCaloriePlan,
        input: CaloriePlanInput? = nil,
        dailyAdjustmentCalories: Double? = nil
    ) -> CalculatedCaloriePlan {
        CalculatedCaloriePlan(
            input: input ?? plan.input,
            restingCalories: plan.restingCalories,
            activityFactor: plan.activityFactor,
            maintenanceCalories: plan.maintenanceCalories,
            dailyAdjustmentCalories: dailyAdjustmentCalories ?? plan.dailyAdjustmentCalories,
            effectiveWeeklyRateKilograms: plan.effectiveWeeklyRateKilograms,
            calorieGoal: plan.calorieGoal,
            forecastDate: plan.forecastDate
        )
    }

    private func proposal(_ result: AdaptiveCaloriePlanEvaluation) throws -> AdaptiveCalorieProposal {
        guard case .proposal(let proposal) = result else {
            XCTFail("Expected proposal, got \(result)")
            throw NSError(domain: "AdaptiveCaloriePlanTests", code: 1)
        }
        return proposal
    }

    private func XCTAssertCollecting(
        _ result: AdaptiveCaloriePlanEvaluation,
        contains requirement: AdaptiveCalorieCollectionRequirement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .collecting(let collecting) = result else {
            return XCTFail("Expected collecting, got \(result)", file: file, line: line)
        }
        XCTAssertTrue(collecting.missing.contains(requirement), file: file, line: line)
    }

    private func XCTAssertCheckData(
        _ result: AdaptiveCaloriePlanEvaluation,
        _ reason: AdaptiveCalorieCheckDataReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .checkData(let data) = result else {
            return XCTFail("Expected check data, got \(result)", file: file, line: line)
        }
        XCTAssertEqual(data.reason, reason, file: file, line: line)
    }

    private func XCTAssertUpToDate(_ input: AdaptiveCaloriePlanInput, file: StaticString = #filePath, line: UInt = #line) {
        guard case .upToDate = evaluate(input, now: date(2026, 8, 1, calendar: utc), calendar: utc) else {
            return XCTFail("Expected up to date", file: file, line: line)
        }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day, hour: 12).date!
    }
}
