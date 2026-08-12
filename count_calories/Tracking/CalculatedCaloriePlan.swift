import Foundation

nonisolated enum PlanGoalSource: String, Codable, CaseIterable, Sendable {
    case manual
    case calculated
    case adapted
    case unknown
}

nonisolated enum PlanGoalMode: String, Codable, CaseIterable, Sendable {
    case lose
    case maintain
    case gain

    var title: String {
        switch self {
        case .lose: "Lose weight"
        case .maintain: "Maintain weight"
        case .gain: "Gain weight"
        }
    }
}

nonisolated enum CalorieEquation: String, Codable, CaseIterable, Sendable {
    case female
    case male

    var constant: Double {
        switch self {
        case .female: -161
        case .male: 5
        }
    }

    var title: String {
        switch self {
        case .female: "Female equation (−161)"
        case .male: "Male equation (+5)"
        }
    }
}

nonisolated enum PlanActivityLevel: String, Codable, CaseIterable, Sendable {
    case low
    case moderate
    case high
    case veryHigh

    var factor: Double {
        switch self {
        case .low: 1.25
        case .moderate: 1.38
        case .high: 1.52
        case .veryHigh: 1.65
        }
    }

    var title: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        case .veryHigh: "Very high"
        }
    }

    var detail: String {
        switch self {
        case .low: "Mostly sitting, such as desk work"
        case .moderate: "Much of the day standing, such as teaching or retail"
        case .high: "Much of the day walking, such as delivery or floor work"
        case .veryHigh: "Sustained manual labor"
        }
    }
}

nonisolated enum PlanPaceBasis: String, Codable, CaseIterable, Sendable {
    case weeklyRate
    case targetDate
}

nonisolated enum PlanMeasurementSystem: String, Codable, CaseIterable, Sendable {
    case metric
    case us

    var title: String {
        switch self {
        case .metric: "Metric"
        case .us: "US"
        }
    }
}

nonisolated struct CaloriePlanInput: Equatable, Codable, Sendable {
    var goalMode: PlanGoalMode
    var currentWeightKilograms: Double
    var targetWeightKilograms: Double
    var age: Int
    var heightCentimeters: Double
    var equation: CalorieEquation
    var activityLevel: PlanActivityLevel
    var paceBasis: PlanPaceBasis
    var weeklyRateKilograms: Double
    var targetDate: Date?
}

nonisolated struct CalculatedCaloriePlan: Equatable, Codable, Sendable {
    let input: CaloriePlanInput
    let restingCalories: Double
    let activityFactor: Double
    let maintenanceCalories: Double
    let dailyAdjustmentCalories: Double
    let effectiveWeeklyRateKilograms: Double
    let calorieGoal: Int
    let forecastDate: Date?
}

nonisolated enum CaloriePlanIssue: Error, Equatable, Sendable {
    case invalidAge
    case invalidWeight
    case invalidHeight
    case invalidGoalRelationship
    case belowSupportedBMI
    case invalidRate
    case targetDateNotFuture
    case targetDateTooSoon(earliestFeasibleDate: Date)
    case resultBelowMinimum
    case resultAboveMaximum
    case invalidCalculation
}

nonisolated enum CaloriePlanEvaluation: Equatable, Sendable {
    case recommendation(CalculatedCaloriePlan)
    case unsupported(CaloriePlanIssue)
}

nonisolated enum CalculatedCaloriePlanCalculator {
    static let supportedAgeRange = 19...78
    static let supportedWeightRange = 20.0...500.0
    static let supportedHeightRange = 100.0...250.0
    static let minimumBMI = 18.5
    static let maximumWeeklyRateKilograms = 0.5
    static let minimumCalorieGoal = 1_000.0
    static let maximumCalorieGoal = 5_000.0
    static let kilocaloriesPerKilogram = 7_700.0

    static func evaluate(
        _ input: CaloriePlanInput,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CaloriePlanEvaluation {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            return .unsupported(.invalidCalculation)
        }
        guard supportedAgeRange.contains(input.age) else {
            return .unsupported(.invalidAge)
        }
        guard
            input.currentWeightKilograms.isFinite,
            input.targetWeightKilograms.isFinite,
            supportedWeightRange.contains(input.currentWeightKilograms),
            supportedWeightRange.contains(input.targetWeightKilograms)
        else {
            return .unsupported(.invalidWeight)
        }
        guard
            input.heightCentimeters.isFinite,
            supportedHeightRange.contains(input.heightCentimeters)
        else {
            return .unsupported(.invalidHeight)
        }
        guard goalRelationshipIsValid(input) else {
            return .unsupported(.invalidGoalRelationship)
        }
        guard
            bodyMassIndex(
                kilograms: input.currentWeightKilograms,
                heightCentimeters: input.heightCentimeters
            ) >= minimumBMI,
            bodyMassIndex(
                kilograms: input.targetWeightKilograms,
                heightCentimeters: input.heightCentimeters
            ) >= minimumBMI
        else {
            return .unsupported(.belowSupportedBMI)
        }

        let pace: PaceResult
        switch paceResult(for: input, now: now, calendar: calendar) {
        case .success(let result):
            pace = result
        case .failure(let issue):
            return .unsupported(issue)
        }

        let resting = 10 * input.currentWeightKilograms
            + 6.25 * input.heightCentimeters
            - 5 * Double(input.age)
            + input.equation.constant
        let maintenance = resting * input.activityLevel.factor
        let adjustment = pace.weeklyRateKilograms * kilocaloriesPerKilogram / 7
        let rawGoal: Double
        switch input.goalMode {
        case .lose:
            rawGoal = maintenance - adjustment
        case .maintain:
            rawGoal = maintenance
        case .gain:
            rawGoal = maintenance + adjustment
        }

        guard resting.isFinite, resting > 0,
              maintenance.isFinite, maintenance > 0,
              adjustment.isFinite, adjustment >= 0,
              rawGoal.isFinite else {
            return .unsupported(.invalidCalculation)
        }
        guard rawGoal >= minimumCalorieGoal else {
            return .unsupported(.resultBelowMinimum)
        }
        guard rawGoal <= maximumCalorieGoal else {
            return .unsupported(.resultAboveMaximum)
        }

        let roundedGoal = (rawGoal / 10).rounded(.toNearestOrAwayFromZero) * 10
        guard roundedGoal.isFinite,
              roundedGoal >= minimumCalorieGoal,
              roundedGoal <= maximumCalorieGoal,
              roundedGoal <= Double(Int.max) else {
            return .unsupported(.invalidCalculation)
        }

        return .recommendation(CalculatedCaloriePlan(
            input: input,
            restingCalories: resting,
            activityFactor: input.activityLevel.factor,
            maintenanceCalories: maintenance,
            dailyAdjustmentCalories: adjustment,
            effectiveWeeklyRateKilograms: pace.weeklyRateKilograms,
            calorieGoal: Int(roundedGoal),
            forecastDate: pace.forecastDate
        ))
    }

    static func earliestFeasibleDate(
        currentWeightKilograms: Double,
        targetWeightKilograms: Double,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let difference = abs(targetWeightKilograms - currentWeightKilograms)
        guard
            difference.isFinite,
            difference > 0,
            now.timeIntervalSinceReferenceDate.isFinite
        else { return nil }
        let days = Int(ceil(difference / maximumWeeklyRateKilograms * 7))
        return calendar.date(
            byAdding: .day,
            value: days,
            to: calendar.startOfDay(for: now)
        )
    }

    static func bodyMassIndex(
        kilograms: Double,
        heightCentimeters: Double
    ) -> Double {
        let meters = heightCentimeters / 100
        guard kilograms.isFinite, meters.isFinite, meters > 0 else {
            return .nan
        }
        return kilograms / (meters * meters)
    }

    private struct PaceResult {
        let weeklyRateKilograms: Double
        let forecastDate: Date?
    }

    private static func paceResult(
        for input: CaloriePlanInput,
        now: Date,
        calendar: Calendar
    ) -> Result<PaceResult, CaloriePlanIssue> {
        guard input.goalMode != .maintain else {
            return .success(PaceResult(weeklyRateKilograms: 0, forecastDate: nil))
        }

        let difference = abs(input.targetWeightKilograms - input.currentWeightKilograms)
        guard difference.isFinite, difference > 0 else {
            return .failure(.invalidGoalRelationship)
        }

        switch input.paceBasis {
        case .weeklyRate:
            let rate = input.weeklyRateKilograms
            guard
                rate.isFinite,
                abs(rate - 0.25) < 0.000_001
                    || abs(rate - 0.50) < 0.000_001
            else {
                return .failure(.invalidRate)
            }
            let days = Int(ceil(difference / rate * 7))
            guard let forecast = calendar.date(
                byAdding: .day,
                value: days,
                to: calendar.startOfDay(for: now)
            ) else {
                return .failure(.invalidCalculation)
            }
            return .success(PaceResult(
                weeklyRateKilograms: rate,
                forecastDate: forecast
            ))

        case .targetDate:
            guard
                let targetDate = input.targetDate,
                targetDate.timeIntervalSinceReferenceDate.isFinite
            else {
                return .failure(.targetDateNotFuture)
            }
            let start = calendar.startOfDay(for: now)
            let end = calendar.startOfDay(for: targetDate)
            guard let days = calendar.dateComponents([.day], from: start, to: end).day,
                  days > 0 else {
                return .failure(.targetDateNotFuture)
            }
            let rate = difference / (Double(days) / 7)
            guard rate.isFinite, rate > 0 else {
                return .failure(.invalidCalculation)
            }
            guard rate <= maximumWeeklyRateKilograms else {
                guard let earliest = earliestFeasibleDate(
                    currentWeightKilograms: input.currentWeightKilograms,
                    targetWeightKilograms: input.targetWeightKilograms,
                    now: now,
                    calendar: calendar
                ) else {
                    return .failure(.invalidCalculation)
                }
                return .failure(.targetDateTooSoon(earliestFeasibleDate: earliest))
            }
            return .success(PaceResult(
                weeklyRateKilograms: rate,
                forecastDate: end
            ))
        }
    }

    private static func goalRelationshipIsValid(_ input: CaloriePlanInput) -> Bool {
        switch input.goalMode {
        case .lose:
            input.targetWeightKilograms < input.currentWeightKilograms
        case .maintain:
            abs(input.targetWeightKilograms - input.currentWeightKilograms) < 0.000_001
        case .gain:
            input.targetWeightKilograms > input.currentWeightKilograms
        }
    }
}

nonisolated enum PlanUnitConversion {
    static let poundsPerKilogram = 2.204_622_621_8
    static let centimetersPerInch = 2.54

    static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms * poundsPerKilogram
    }

    static func kilograms(fromPounds pounds: Double) -> Double {
        pounds / poundsPerKilogram
    }

    static func inches(fromCentimeters centimeters: Double) -> Double {
        centimeters / centimetersPerInch
    }

    static func centimeters(fromInches inches: Double) -> Double {
        inches * centimetersPerInch
    }
}
