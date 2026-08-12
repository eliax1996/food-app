import Foundation

/// Hostless evidence used to decide whether an existing calculated goal merits review.
nonisolated struct AdaptiveCalorieFoodDay: Equatable, Sendable {
    let date: Date
    let calories: Double
    let isComplete: Bool
    let isStale: Bool

    init(date: Date, calories: Double, isComplete: Bool = true, isStale: Bool = false) {
        self.date = date
        self.calories = calories
        self.isComplete = isComplete
        self.isStale = isStale
    }
}

nonisolated struct AdaptiveCalorieWeight: Equatable, Sendable {
    let date: Date
    let kilograms: Double

    init(date: Date, kilograms: Double) {
        self.date = date
        self.kilograms = kilograms
    }
}

nonisolated struct AdaptiveCalorieAcceptedStep: Equatable, Sendable {
    let effectiveDate: Date
    let calories: Int

    init(effectiveDate: Date, calories: Int) {
        self.effectiveDate = effectiveDate
        self.calories = calories
    }
}

nonisolated struct AdaptiveCaloriePlanInput: Equatable, Sendable {
    let source: PlanGoalSource
    /// Current caller-confirmed support status. Omission must never enable adaptation.
    let currentSupportedScope: Bool
    let currentDailyGoal: Int
    /// Accepted Slice C plan. Its unrounded daily adjustment is deliberately retained.
    let calculatedPlan: CalculatedCaloriePlan?
    let foodDays: [AdaptiveCalorieFoodDay]
    let weights: [AdaptiveCalorieWeight]
    let acceptedSteps: [AdaptiveCalorieAcceptedStep]

    init(
        source: PlanGoalSource,
        currentSupportedScope: Bool = false,
        currentDailyGoal: Int,
        calculatedPlan: CalculatedCaloriePlan?,
        foodDays: [AdaptiveCalorieFoodDay],
        weights: [AdaptiveCalorieWeight],
        acceptedSteps: [AdaptiveCalorieAcceptedStep] = []
    ) {
        self.source = source
        self.currentSupportedScope = currentSupportedScope
        self.currentDailyGoal = currentDailyGoal
        self.calculatedPlan = calculatedPlan
        self.foodDays = foodDays
        self.weights = weights
        self.acceptedSteps = acceptedSteps
    }
}

nonisolated enum AdaptiveCalorieCollectionRequirement: Equatable, Sendable {
    case completeFoodDays
    case eightWeighInDays
    case sixRecentWeighInDays
    case weighInInSevenDayBlock(Int)
    case firstBoundary(windowDays: Int)
    case commonFinalBoundary
    case maximumWeightGap
}

nonisolated struct AdaptiveCalorieCollecting: Equatable, Sendable {
    let completeFoodDays: Int
    let weighInDays: Int
    let newest28WeighInDays: Int
    let missing: [AdaptiveCalorieCollectionRequirement]
}

nonisolated enum AdaptiveCalorieCheckDataReason: Equatable, Sendable {
    case invalidDate
    case invalidFoodCalories
    case duplicateFoodDay
    case invalidTrend
    case unsupportedMaintenance
    case estimatesDisagree
    case unsupportedCandidate
    case discrepancyTooLarge
}

nonisolated struct AdaptiveCalorieCheckData: Equatable, Sendable {
    let reason: AdaptiveCalorieCheckDataReason
    let estimates: AdaptiveCalorieEvidence?
}

nonisolated enum AdaptiveCaloriePauseReason: Equatable, Sendable {
    case manualSource
    case unknownSource
    case missingCalculatedBasis
    case unsupportedScope
    case targetReached
    case cumulativeStepCap
}

nonisolated enum AdaptiveCalorieWeightDirection: Equatable, Sendable {
    case losing
    case stable
    case gaining
}

nonisolated struct AdaptiveCalorieWindowEstimate: Equatable, Sendable {
    let nominalDays: Int
    let trendStart: Date
    let trendEnd: Date
    let meanLoggedCalories: Double
    let kilogramsPerDay: Double
    let observedMaintenanceCalories: Double

    var kilogramsPerWeek: Double { kilogramsPerDay * 7 }
}

nonisolated struct AdaptiveCalorieEvidence: Equatable, Sendable {
    let estimates: [AdaptiveCalorieWindowEstimate]
    let completeFoodDays: Int
    let weighInDays: Int

    var estimate28Days: AdaptiveCalorieWindowEstimate? {
        estimates.first { $0.nominalDays == 28 }
    }
}

nonisolated struct AdaptiveCalorieProposal: Equatable, Sendable {
    let evidence: AdaptiveCalorieEvidence
    let candidateCalories: Double
    let rawDifferenceCalories: Double
    let stepCalories: Int
    let proposedDailyGoal: Int
}

nonisolated enum AdaptiveCaloriePlanEvaluation: Equatable, Sendable {
    case collecting(AdaptiveCalorieCollecting)
    case checkData(AdaptiveCalorieCheckData)
    case upToDate(AdaptiveCalorieEvidence)
    case proposal(AdaptiveCalorieProposal)
    case paused(AdaptiveCaloriePauseReason)
}

nonisolated enum AdaptiveCaloriePlanEvaluator {
    static let evidenceWindowDays = 42
    static let nominalWindows = [28, 35, 42]
    static let foodDayRequirement = 42
    static let minimumWeighInDays = 8
    static let minimumNewest28WeighInDays = 6
    static let minimumMaintenanceCalories = 800.0
    static let maximumMaintenanceCalories = 6_000.0
    static let maintenanceAgreementCalories = 100.0
    static let stableKilogramsPerWeek = 0.05
    static let deadbandCalories = 75.0
    static let maximumDiscrepancyCalories = 400.0
    static let maximumProposalStepCalories = 100.0
    static let proposalRoundingCalories = 10.0
    static let trailingStepCapCalories = 200

    static func evaluate(
        _ input: AdaptiveCaloriePlanInput,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AdaptiveCaloriePlanEvaluation {
        if (input.source == .calculated || input.source == .adapted), !input.currentSupportedScope {
            return .paused(.unsupportedScope)
        }
        guard allDatesAreFinite(input, now: now) else {
            return .checkData(AdaptiveCalorieCheckData(reason: .invalidDate, estimates: nil))
        }
        guard now.timeIntervalSinceReferenceDate.isFinite,
              let today = localDay(for: now, calendar: calendar),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let windowStart = calendar.date(byAdding: .day, value: -(evidenceWindowDays - 1), to: yesterday),
              let days = localDays(from: windowStart, count: evidenceWindowDays, calendar: calendar)
        else {
            return .checkData(AdaptiveCalorieCheckData(reason: .invalidDate, estimates: nil))
        }

        switch input.source {
        case .manual:
            return .paused(.manualSource)
        case .unknown:
            return .paused(.unknownSource)
        case .calculated, .adapted:
            break
        }
        guard let plan = input.calculatedPlan else {
            return .paused(.missingCalculatedBasis)
        }
        guard storedPlanIsValid(plan) else {
            return .paused(.unsupportedScope)
        }
        guard input.currentDailyGoal >= Int(CalculatedCaloriePlanCalculator.minimumCalorieGoal),
              input.currentDailyGoal <= Int(CalculatedCaloriePlanCalculator.maximumCalorieGoal) else {
            return .paused(.unsupportedScope)
        }
        guard foodCaloriesAreValid(input.foodDays) else {
            return .checkData(AdaptiveCalorieCheckData(reason: .invalidFoodCalories, estimates: nil))
        }

        let foodByDay = Dictionary(grouping: input.foodDays) { localDay(for: $0.date, calendar: calendar)! }
        guard foodByDay.values.allSatisfy({ $0.count == 1 }) else {
            return .checkData(AdaptiveCalorieCheckData(reason: .duplicateFoodDay, estimates: nil))
        }
        let completeFoodDays = days.reduce(into: 0) { count, day in
            if let food = foodByDay[day]?.first, food.isComplete, !food.isStale { count += 1 }
        }

        let medianWeights = medianWeightsByDay(input.weights, through: yesterday, calendar: calendar)
        let windowWeightDays = days.filter { medianWeights[$0] != nil }
        let newest28 = Array(days.suffix(28))
        let newest28WeightDays = newest28.filter { medianWeights[$0] != nil }
        let collection = collectionStatus(
            days: days,
            completeFoodDays: completeFoodDays,
            weightDays: windowWeightDays,
            newest28WeightDays: newest28WeightDays,
            calendar: calendar
        )
        guard collection.missing.isEmpty else { return .collecting(collection) }

        guard scopeIsSupported(plan: plan, latestWeight: latestValidWeight(input.weights, through: now)) else {
            return .paused(.unsupportedScope)
        }
        if targetIsReached(plan: plan, latestWeight: latestValidWeight(input.weights, through: now)) {
            return .paused(.targetReached)
        }

        let estimatesResult = estimates(
            days: days,
            foodByDay: foodByDay,
            weights: medianWeights,
            calendar: calendar
        )
        guard let estimates = estimatesResult else {
            return .checkData(AdaptiveCalorieCheckData(reason: .invalidTrend, estimates: nil))
        }
        let evidence = AdaptiveCalorieEvidence(
            estimates: estimates,
            completeFoodDays: completeFoodDays,
            weighInDays: windowWeightDays.count
        )
        guard estimates.allSatisfy({ maintenanceIsSupported($0.observedMaintenanceCalories) }) else {
            return .checkData(AdaptiveCalorieCheckData(reason: .unsupportedMaintenance, estimates: evidence))
        }
        guard estimatesAgree(estimates) else {
            return .checkData(AdaptiveCalorieCheckData(reason: .estimatesDisagree, estimates: evidence))
        }
        guard let estimate28 = evidence.estimate28Days else {
            return .checkData(AdaptiveCalorieCheckData(reason: .invalidTrend, estimates: evidence))
        }

        let candidate = candidateCalories(plan: plan, maintenance: estimate28.observedMaintenanceCalories)
        let difference = candidate - Double(input.currentDailyGoal)
        guard candidate.isFinite, difference.isFinite,
              candidate >= CalculatedCaloriePlanCalculator.minimumCalorieGoal,
              candidate <= CalculatedCaloriePlanCalculator.maximumCalorieGoal else {
            return .checkData(AdaptiveCalorieCheckData(reason: .unsupportedCandidate, estimates: evidence))
        }
        if abs(difference) <= deadbandCalories { return .upToDate(evidence) }
        if abs(difference) > maximumDiscrepancyCalories {
            return .checkData(AdaptiveCalorieCheckData(reason: .discrepancyTooLarge, estimates: evidence))
        }

        let limited = max(-maximumProposalStepCalories, min(maximumProposalStepCalories, difference))
        let rounded = (limited / proposalRoundingCalories).rounded(.toNearestOrAwayFromZero) * proposalRoundingCalories
        guard rounded.isFinite, rounded != 0,
              rounded >= Double(Int.min), rounded <= Double(Int.max) else {
            return .checkData(AdaptiveCalorieCheckData(reason: .unsupportedCandidate, estimates: evidence))
        }
        let step = Int(rounded)
        let proposedGoal = input.currentDailyGoal + step
        guard proposedGoal >= Int(CalculatedCaloriePlanCalculator.minimumCalorieGoal),
              proposedGoal <= Int(CalculatedCaloriePlanCalculator.maximumCalorieGoal) else {
            return .checkData(AdaptiveCalorieCheckData(reason: .unsupportedCandidate, estimates: evidence))
        }
        guard let capStart = calendar.date(byAdding: .day, value: -27, to: today),
              let priorSteps = acceptedStepMagnitude(
                input.acceptedSteps,
                from: capStart,
                through: today,
                calendar: calendar
              ) else {
            return .paused(.cumulativeStepCap)
        }
        guard priorSteps <= trailingStepCapCalories - abs(step) else {
            return .paused(.cumulativeStepCap)
        }
        return .proposal(AdaptiveCalorieProposal(
            evidence: evidence,
            candidateCalories: candidate,
            rawDifferenceCalories: difference,
            stepCalories: step,
            proposedDailyGoal: proposedGoal
        ))
    }

    private static func allDatesAreFinite(_ input: AdaptiveCaloriePlanInput, now: Date) -> Bool {
        now.timeIntervalSinceReferenceDate.isFinite
            && input.foodDays.allSatisfy { $0.date.timeIntervalSinceReferenceDate.isFinite }
            && input.weights.allSatisfy { $0.date.timeIntervalSinceReferenceDate.isFinite }
            && input.acceptedSteps.allSatisfy { $0.effectiveDate.timeIntervalSinceReferenceDate.isFinite }
    }

    private static func localDay(for date: Date, calendar: Calendar) -> Date? {
        guard date.timeIntervalSinceReferenceDate.isFinite else { return nil }
        return calendar.startOfDay(for: date)
    }

    private static func localDays(from first: Date, count: Int, calendar: Calendar) -> [Date]? {
        guard count > 0 else { return [] }
        var result: [Date] = []
        result.reserveCapacity(count)
        for offset in 0..<count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            result.append(day)
        }
        return result
    }

    private static func foodCaloriesAreValid(_ foodDays: [AdaptiveCalorieFoodDay]) -> Bool {
        foodDays.allSatisfy { $0.calories.isFinite && $0.calories >= 0 }
    }

    private static func medianWeightsByDay(
        _ weights: [AdaptiveCalorieWeight],
        through lastDay: Date,
        calendar: Calendar
    ) -> [Date: Double] {
        let valid = weights.compactMap { weight -> (Date, Double)? in
            guard weight.kilograms.isFinite,
                  (20...500).contains(weight.kilograms),
                  let day = localDay(for: weight.date, calendar: calendar),
                  day <= lastDay else { return nil }
            return (day, weight.kilograms)
        }
        return Dictionary(grouping: valid, by: \.0).reduce(into: [:]) { result, pair in
            let values = pair.value.map(\.1).sorted()
            let middle = values.count / 2
            let median = values.count.isMultiple(of: 2)
                ? (values[middle - 1] + values[middle]) / 2
                : values[middle]
            result[pair.key] = median
        }
    }

    private static func latestValidWeight(
        _ weights: [AdaptiveCalorieWeight],
        through now: Date
    ) -> Double? {
        weights
            .filter {
                $0.date <= now && $0.kilograms.isFinite && (20...500).contains($0.kilograms)
            }
            .max { $0.date < $1.date }?
            .kilograms
    }

    private static func acceptedStepMagnitude(
        _ steps: [AdaptiveCalorieAcceptedStep],
        from firstDay: Date,
        through lastDay: Date,
        calendar: Calendar
    ) -> Int? {
        var total = 0
        for step in steps {
            guard let day = localDay(for: step.effectiveDate, calendar: calendar),
                  day >= firstDay, day <= lastDay else { continue }
            guard step.calories != Int.min else { return nil }
            let magnitude = abs(step.calories)
            let (next, overflow) = total.addingReportingOverflow(magnitude)
            guard !overflow else { return nil }
            total = next
        }
        return total
    }

    private static func collectionStatus(
        days: [Date],
        completeFoodDays: Int,
        weightDays: [Date],
        newest28WeightDays: [Date],
        calendar: Calendar
    ) -> AdaptiveCalorieCollecting {
        var missing: [AdaptiveCalorieCollectionRequirement] = []
        if completeFoodDays != foodDayRequirement { missing.append(.completeFoodDays) }
        if weightDays.count < minimumWeighInDays { missing.append(.eightWeighInDays) }
        if newest28WeightDays.count < minimumNewest28WeighInDays { missing.append(.sixRecentWeighInDays) }
        for block in 0..<6 where !weightDays.contains(where: { $0 >= days[block * 7] && $0 <= days[block * 7 + 6] }) {
            missing.append(.weighInInSevenDayBlock(block))
        }
        var finalDays: [Date] = []
        for window in nominalWindows {
            let nominal = Array(days.suffix(window))
            if !weightDays.contains(where: { $0 >= nominal[0] && $0 <= nominal[2] }) {
                missing.append(.firstBoundary(windowDays: window))
            }
            if let last = weightDays.last(where: { $0 >= nominal[nominal.count - 3] && $0 <= nominal.last! }) {
                finalDays.append(last)
            } else {
                finalDays = []
                break
            }
        }
        if finalDays.count != nominalWindows.count || Set(finalDays).count != 1 {
            missing.append(.commonFinalBoundary)
        }
        if zip(weightDays, weightDays.dropFirst()).contains(where: { pair in
            guard let gap = calendar.dateComponents([.day], from: pair.0, to: pair.1).day else { return true }
            return gap > 10
        }) {
            missing.append(.maximumWeightGap)
        }
        return AdaptiveCalorieCollecting(
            completeFoodDays: completeFoodDays,
            weighInDays: weightDays.count,
            newest28WeighInDays: newest28WeightDays.count,
            missing: missing
        )
    }

    private static func storedPlanIsValid(_ plan: CalculatedCaloriePlan) -> Bool {
        let input = plan.input
        guard CalculatedCaloriePlanCalculator.supportedAgeRange.contains(input.age),
              input.currentWeightKilograms.isFinite,
              input.targetWeightKilograms.isFinite,
              CalculatedCaloriePlanCalculator.supportedWeightRange.contains(input.currentWeightKilograms),
              CalculatedCaloriePlanCalculator.supportedWeightRange.contains(input.targetWeightKilograms),
              input.heightCentimeters.isFinite,
              CalculatedCaloriePlanCalculator.supportedHeightRange.contains(input.heightCentimeters),
              input.weeklyRateKilograms.isFinite,
              plan.effectiveWeeklyRateKilograms.isFinite,
              plan.dailyAdjustmentCalories.isFinite,
              plan.dailyAdjustmentCalories >= 0,
              plan.calorieGoal >= Int(CalculatedCaloriePlanCalculator.minimumCalorieGoal),
              plan.calorieGoal <= Int(CalculatedCaloriePlanCalculator.maximumCalorieGoal),
              input.targetDate?.timeIntervalSinceReferenceDate.isFinite ?? true
        else { return false }

        let relationshipIsValid: Bool
        switch input.goalMode {
        case .lose:
            relationshipIsValid = input.targetWeightKilograms < input.currentWeightKilograms
        case .maintain:
            relationshipIsValid = abs(input.targetWeightKilograms - input.currentWeightKilograms) < 0.000_001
            guard relationshipIsValid,
                  plan.effectiveWeeklyRateKilograms == 0,
                  plan.dailyAdjustmentCalories == 0 else { return false }
            return true
        case .gain:
            relationshipIsValid = input.targetWeightKilograms > input.currentWeightKilograms
        }
        guard relationshipIsValid,
              plan.effectiveWeeklyRateKilograms > 0,
              plan.effectiveWeeklyRateKilograms <= CalculatedCaloriePlanCalculator.maximumWeeklyRateKilograms
        else { return false }

        switch input.paceBasis {
        case .weeklyRate:
            guard abs(input.weeklyRateKilograms - 0.25) < 0.000_001
                    || abs(input.weeklyRateKilograms - 0.50) < 0.000_001,
                  abs(plan.effectiveWeeklyRateKilograms - input.weeklyRateKilograms) < 0.000_001
            else { return false }
        case .targetDate:
            guard input.targetDate != nil else { return false }
        }
        let expectedAdjustment = plan.effectiveWeeklyRateKilograms
            * CalculatedCaloriePlanCalculator.kilocaloriesPerKilogram / 7
        return expectedAdjustment.isFinite
            && abs(plan.dailyAdjustmentCalories - expectedAdjustment) < 0.000_001
    }

    private static func scopeIsSupported(plan: CalculatedCaloriePlan, latestWeight: Double?) -> Bool {
        let input = plan.input
        guard CalculatedCaloriePlanCalculator.supportedAgeRange.contains(input.age),
              input.heightCentimeters.isFinite,
              CalculatedCaloriePlanCalculator.supportedHeightRange.contains(input.heightCentimeters),
              input.targetWeightKilograms.isFinite,
              CalculatedCaloriePlanCalculator.supportedWeightRange.contains(input.targetWeightKilograms),
              let latestWeight,
              latestWeight.isFinite,
              CalculatedCaloriePlanCalculator.supportedWeightRange.contains(latestWeight) else {
            return false
        }
        return CalculatedCaloriePlanCalculator.bodyMassIndex(
            kilograms: latestWeight,
            heightCentimeters: input.heightCentimeters
        ) >= CalculatedCaloriePlanCalculator.minimumBMI
            && CalculatedCaloriePlanCalculator.bodyMassIndex(
                kilograms: input.targetWeightKilograms,
                heightCentimeters: input.heightCentimeters
            ) >= CalculatedCaloriePlanCalculator.minimumBMI
    }

    private static func targetIsReached(plan: CalculatedCaloriePlan, latestWeight: Double?) -> Bool {
        guard let latestWeight else { return false }
        return switch plan.input.goalMode {
        case .lose: latestWeight <= plan.input.targetWeightKilograms
        case .gain: latestWeight >= plan.input.targetWeightKilograms
        case .maintain: false
        }
    }

    private static func estimates(
        days: [Date],
        foodByDay: [Date: [AdaptiveCalorieFoodDay]],
        weights: [Date: Double],
        calendar: Calendar
    ) -> [AdaptiveCalorieWindowEstimate]? {
        var result: [AdaptiveCalorieWindowEstimate] = []
        for nominalDays in nominalWindows {
            let nominal = Array(days.suffix(nominalDays))
            guard let first = nominal.first(where: { weights[$0] != nil && $0 <= nominal[2] }),
                  let last = nominal.last(where: { weights[$0] != nil && $0 >= nominal[nominal.count - 3] }),
                  first <= last,
                  let firstIndex = nominal.firstIndex(of: first),
                  let lastIndex = nominal.firstIndex(of: last)
            else { return nil }
            let interval = Array(nominal[firstIndex...lastIndex])
            let knots = interval.compactMap { day -> (Int, Double)? in
                guard let value = weights[day] else { return nil }
                return (interval.firstIndex(of: day)!, value)
            }
            guard let interpolated = interpolate(knots: knots, count: interval.count),
                  let slope = smoothedSlope(interpolated),
                  let meanCalories = meanCalories(interval, foodByDay: foodByDay),
                  slope.isFinite, meanCalories.isFinite
            else { return nil }
            let maintenance = meanCalories - slope * CalculatedCaloriePlanCalculator.kilocaloriesPerKilogram
            guard maintenance.isFinite else { return nil }
            result.append(AdaptiveCalorieWindowEstimate(
                nominalDays: nominalDays,
                trendStart: first,
                trendEnd: last,
                meanLoggedCalories: meanCalories,
                kilogramsPerDay: slope,
                observedMaintenanceCalories: maintenance
            ))
        }
        return result
    }

    private static func interpolate(knots: [(Int, Double)], count: Int) -> [Double]? {
        guard knots.count >= 2, count >= 7 else { return nil }
        var values = Array(repeating: Double.nan, count: count)
        for (left, right) in zip(knots, knots.dropFirst()) {
            let span = right.0 - left.0
            guard span > 0 else { return nil }
            for index in left.0...right.0 {
                let fraction = Double(index - left.0) / Double(span)
                let value = left.1 + (right.1 - left.1) * fraction
                guard value.isFinite else { return nil }
                values[index] = value
            }
        }
        return values.allSatisfy(\.isFinite) ? values : nil
    }

    private static func smoothedSlope(_ values: [Double]) -> Double? {
        guard values.count >= 7 else { return nil }
        let smooth = (3..<(values.count - 3)).map { center in
            values[(center - 3)...(center + 3)].reduce(0, +) / 7
        }
        let meanX = Double(smooth.count - 1) / 2
        let meanY = smooth.reduce(0, +) / Double(smooth.count)
        var covariance = 0.0
        var variance = 0.0
        for (index, value) in smooth.enumerated() {
            let dx = Double(index) - meanX
            covariance += dx * (value - meanY)
            variance += dx * dx
        }
        guard covariance.isFinite, variance.isFinite, variance > 0 else { return nil }
        let slope = covariance / variance
        return slope.isFinite ? slope : nil
    }

    private static func meanCalories(
        _ days: [Date],
        foodByDay: [Date: [AdaptiveCalorieFoodDay]]
    ) -> Double? {
        var total = 0.0
        for day in days {
            guard let food = foodByDay[day]?.first,
                  food.isComplete, !food.isStale,
                  food.calories.isFinite, food.calories >= 0 else { return nil }
            total += food.calories
            guard total.isFinite else { return nil }
        }
        let mean = total / Double(days.count)
        return mean.isFinite ? mean : nil
    }

    private static func maintenanceIsSupported(_ calories: Double) -> Bool {
        calories.isFinite && calories >= minimumMaintenanceCalories && calories <= maximumMaintenanceCalories
    }

    private static func estimatesAgree(_ estimates: [AdaptiveCalorieWindowEstimate]) -> Bool {
        guard estimates.count == nominalWindows.count,
              let low = estimates.map(\.observedMaintenanceCalories).min(),
              let high = estimates.map(\.observedMaintenanceCalories).max(),
              high - low <= maintenanceAgreementCalories else { return false }
        let directions = estimates.map { estimate -> AdaptiveCalorieWeightDirection in
            let weekly = estimate.kilogramsPerWeek
            if abs(weekly) < stableKilogramsPerWeek { return .stable }
            return weekly < 0 ? .losing : .gaining
        }
        return Set(directions).count == 1
    }

    private static func candidateCalories(plan: CalculatedCaloriePlan, maintenance: Double) -> Double {
        switch plan.input.goalMode {
        case .lose: maintenance - plan.dailyAdjustmentCalories
        case .maintain: maintenance
        case .gain: maintenance + plan.dailyAdjustmentCalories
        }
    }
}
