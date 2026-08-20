import Foundation

nonisolated enum CaloriePlanSetupStep: String, Codable, CaseIterable, Sendable {
    case welcome
    case goal
    case body
    case equation
    case activity
    case pace
    case review
}

nonisolated enum CaloriePlanSetupStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case skipped
    case completed
    case legacyManual
}

nonisolated struct CaloriePlanSetupDraft: Codable, Equatable, Sendable {
    var step: CaloriePlanSetupStep = .welcome
    var measurementSystem: PlanMeasurementSystem = .metric
    var goalMode: PlanGoalMode?
    var currentWeightKilograms: Double = 70
    var targetWeightKilograms: Double = 68
    var age: Int = 30
    var heightCentimeters: Double = 0
    var equation: CalorieEquation?
    var activityLevel: PlanActivityLevel?
    var paceBasis: PlanPaceBasis = .weeklyRate
    var weeklyRateKilograms: Double = 0.25
    var targetDate: Date = Calendar.current.date(
        byAdding: .day,
        value: 90,
        to: .now
    ) ?? .now
    var eligibilityConfirmed = false

    func input() -> CaloriePlanInput? {
        guard let goalMode, let equation, let activityLevel else { return nil }
        return CaloriePlanInput(
            goalMode: goalMode,
            currentWeightKilograms: currentWeightKilograms,
            targetWeightKilograms: goalMode == .maintain
                ? currentWeightKilograms
                : targetWeightKilograms,
            age: age,
            heightCentimeters: heightCentimeters,
            equation: equation,
            activityLevel: activityLevel,
            paceBasis: paceBasis,
            weeklyRateKilograms: weeklyRateKilograms,
            targetDate: paceBasis == .targetDate ? targetDate : nil
        )
    }
}

nonisolated struct CaloriePlanSetupRecord: Codable, Equatable, Sendable {
    var status: CaloriePlanSetupStatus
    var draft: CaloriePlanSetupDraft
    var acceptedPlanDateAtStart: Date? = nil
}

nonisolated enum CaloriePlanSetupDefaults {
    static var current: UserDefaults {
#if DEBUG || RELEASE_VALIDATION
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            return UserDefaults(suiteName: "ch.elia.count-calories.ui-testing.plan-setup") ?? .standard
        }
        if ProcessInfo.processInfo.arguments.contains("-design-review") {
            return UserDefaults(suiteName: "ch.elia.count-calories.design-review.plan-setup") ?? .standard
        }
#endif
        return .standard
    }
}

nonisolated enum CaloriePlanSetupStore {
    static let storageKey = "calorie-plan.setup.v1"

    static func load(
        profileExists: Bool,
        defaults: UserDefaults = CaloriePlanSetupDefaults.current
    ) -> CaloriePlanSetupRecord {
        if let data = defaults.data(forKey: storageKey),
           let record = try? JSONDecoder().decode(CaloriePlanSetupRecord.self, from: data) {
            return record
        }

        let record = CaloriePlanSetupRecord(
            status: profileExists ? .legacyManual : .notStarted,
            draft: CaloriePlanSetupDraft()
        )
        save(record, defaults: defaults)
        return record
    }

    @discardableResult
    static func save(
        _ record: CaloriePlanSetupRecord,
        defaults: UserDefaults = CaloriePlanSetupDefaults.current
    ) -> Bool {
        do {
            let data = try JSONEncoder().encode(record)
            defaults.set(data, forKey: storageKey)
            return true
        } catch {
            return false
        }
    }

    static func reset(defaults: UserDefaults = CaloriePlanSetupDefaults.current) {
        defaults.removeObject(forKey: storageKey)
    }

    static func reconciledAfterAcceptedCalculation(
        _ record: CaloriePlanSetupRecord,
        acceptedPlanDate: Date?
    ) -> CaloriePlanSetupRecord {
        guard
            let acceptedPlanDate,
            acceptedPlanDate != record.acceptedPlanDateAtStart,
            record.status != .completed
        else {
            return record
        }
        var reconciled = record
        reconciled.status = .completed
        return reconciled
    }

    static func shouldPresentAutomatically(
        record: CaloriePlanSetupRecord
    ) -> Bool {
        record.status == .notStarted
    }
}
