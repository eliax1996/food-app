import Foundation

struct ReminderTime: Equatable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        precondition((0..<24).contains(hour))
        precondition((0..<60).contains(minute))
        self.hour = hour
        self.minute = minute
    }

    init?(minutesAfterMidnight: Int) {
        guard (0..<(24 * 60)).contains(minutesAfterMidnight) else { return nil }
        self.init(
            hour: minutesAfterMidnight / 60,
            minute: minutesAfterMidnight % 60
        )
    }

    var minutesAfterMidnight: Int {
        hour * 60 + minute
    }
}

enum WeightReminderFrequency: String, CaseIterable, Equatable, Sendable {
    case daily
    case weekly
}

enum ReminderPreferenceKey {
    static let breakfast = "reminders.breakfast.enabled"
    static let lunch = "reminders.lunch.enabled"
    static let snack = "reminders.snack.enabled"
    static let dinner = "reminders.dinner.enabled"
    static let water = "reminders.water.enabled"
    static let weight = "reminders.weight.enabled"

    static let breakfastTime = "reminders.breakfast.time-minutes"
    static let lunchTime = "reminders.lunch.time-minutes"
    static let snackTime = "reminders.snack.time-minutes"
    static let dinnerTime = "reminders.dinner.time-minutes"
    static let weightTime = "reminders.weight.time-minutes"
    static let weightFrequency = "reminders.weight.frequency"
}

nonisolated enum ReminderPreferenceDefaults {
    static var current: UserDefaults {
#if DEBUG || RELEASE_VALIDATION
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            return UserDefaults(suiteName: "ch.elia.count-calories.ui-testing.reminders") ?? .standard
        }
        if ProcessInfo.processInfo.arguments.contains("-design-review") {
            return UserDefaults(suiteName: "ch.elia.count-calories.design-review.reminders") ?? .standard
        }
#endif
        return .standard
    }
}

struct ReminderPreferences: Equatable, Sendable {
    var breakfastEnabled = false
    var lunchEnabled = false
    var snackEnabled = false
    var dinnerEnabled = false
    var waterEnabled = false
    var weightEnabled = false

    var breakfastTime = ReminderTime(hour: 9, minute: 0)
    var lunchTime = ReminderTime(hour: 13, minute: 0)
    var snackTime = ReminderTime(hour: 16, minute: 0)
    var dinnerTime = ReminderTime(hour: 20, minute: 0)
    var weightTime = ReminderTime(hour: 9, minute: 0)
    var weightFrequency = WeightReminderFrequency.weekly

    static func stored(in defaults: UserDefaults = ReminderPreferenceDefaults.current) -> ReminderPreferences {
        ReminderPreferences(
            breakfastEnabled: defaults.bool(forKey: ReminderPreferenceKey.breakfast),
            lunchEnabled: defaults.bool(forKey: ReminderPreferenceKey.lunch),
            snackEnabled: defaults.bool(forKey: ReminderPreferenceKey.snack),
            dinnerEnabled: defaults.bool(forKey: ReminderPreferenceKey.dinner),
            waterEnabled: defaults.bool(forKey: ReminderPreferenceKey.water),
            weightEnabled: defaults.bool(forKey: ReminderPreferenceKey.weight),
            breakfastTime: storedTime(
                forKey: ReminderPreferenceKey.breakfastTime,
                fallback: ReminderTime(hour: 9, minute: 0),
                defaults: defaults
            ),
            lunchTime: storedTime(
                forKey: ReminderPreferenceKey.lunchTime,
                fallback: ReminderTime(hour: 13, minute: 0),
                defaults: defaults
            ),
            snackTime: storedTime(
                forKey: ReminderPreferenceKey.snackTime,
                fallback: ReminderTime(hour: 16, minute: 0),
                defaults: defaults
            ),
            dinnerTime: storedTime(
                forKey: ReminderPreferenceKey.dinnerTime,
                fallback: ReminderTime(hour: 20, minute: 0),
                defaults: defaults
            ),
            weightTime: storedTime(
                forKey: ReminderPreferenceKey.weightTime,
                fallback: ReminderTime(hour: 9, minute: 0),
                defaults: defaults
            ),
            weightFrequency: defaults.string(forKey: ReminderPreferenceKey.weightFrequency)
                .flatMap(WeightReminderFrequency.init(rawValue:))
                ?? .weekly
        )
    }

    func store(in defaults: UserDefaults = ReminderPreferenceDefaults.current) {
        defaults.set(breakfastEnabled, forKey: ReminderPreferenceKey.breakfast)
        defaults.set(lunchEnabled, forKey: ReminderPreferenceKey.lunch)
        defaults.set(snackEnabled, forKey: ReminderPreferenceKey.snack)
        defaults.set(dinnerEnabled, forKey: ReminderPreferenceKey.dinner)
        defaults.set(waterEnabled, forKey: ReminderPreferenceKey.water)
        defaults.set(weightEnabled, forKey: ReminderPreferenceKey.weight)
        defaults.set(breakfastTime.minutesAfterMidnight, forKey: ReminderPreferenceKey.breakfastTime)
        defaults.set(lunchTime.minutesAfterMidnight, forKey: ReminderPreferenceKey.lunchTime)
        defaults.set(snackTime.minutesAfterMidnight, forKey: ReminderPreferenceKey.snackTime)
        defaults.set(dinnerTime.minutesAfterMidnight, forKey: ReminderPreferenceKey.dinnerTime)
        defaults.set(weightTime.minutesAfterMidnight, forKey: ReminderPreferenceKey.weightTime)
        defaults.set(weightFrequency.rawValue, forKey: ReminderPreferenceKey.weightFrequency)
    }

    var hasEnabledReminder: Bool {
        breakfastEnabled
            || lunchEnabled
            || snackEnabled
            || dinnerEnabled
            || waterEnabled
            || weightEnabled
    }

    var enabledCount: Int {
        [
            breakfastEnabled,
            lunchEnabled,
            snackEnabled,
            dinnerEnabled,
            waterEnabled,
            weightEnabled
        ]
        .filter { $0 }
        .count
    }

    func isEnabled(_ meal: ReminderMeal) -> Bool {
        switch meal {
        case .breakfast: breakfastEnabled
        case .lunch: lunchEnabled
        case .snack: snackEnabled
        case .dinner: dinnerEnabled
        }
    }

    func time(for meal: ReminderMeal) -> ReminderTime {
        switch meal {
        case .breakfast: breakfastTime
        case .lunch: lunchTime
        case .snack: snackTime
        case .dinner: dinnerTime
        }
    }

    private static func storedTime(
        forKey key: String,
        fallback: ReminderTime,
        defaults: UserDefaults
    ) -> ReminderTime {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return ReminderTime(minutesAfterMidnight: defaults.integer(forKey: key)) ?? fallback
    }
}

enum ReminderMeal: String, CaseIterable, Sendable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case snack = "Snack"
    case dinner = "Dinner"

    var identifierComponent: String {
        rawValue.lowercased()
    }
}

struct MealReminderRecord: Equatable, Sendable {
    let mealType: String?
    let date: Date
}

struct WaterReminderRecord: Equatable, Sendable {
    let date: Date
    let glasses: Int
    let lastRecordedAt: Date?
}

struct WeightReminderRecord: Equatable, Sendable {
    let date: Date
}

enum ReminderNotificationKind: Equatable, Sendable {
    case meal(ReminderMeal)
    case water
    case weight

    var title: String {
        switch self {
        case .meal(let meal): "Log \(meal.rawValue.lowercased())"
        case .water: "Time for water"
        case .weight: "Weight check-in"
        }
    }

    var body: String {
        switch self {
        case .meal(let meal):
            "\(meal.rawValue) isn’t logged yet. Add it when you’re ready."
        case .water:
            "No glass logged recently. Add water when you’re ready."
        case .weight:
            "A consistent check-in can make your weight trend easier to understand."
        }
    }

    var threadIdentifier: String {
        switch self {
        case .meal: "food-reminders"
        case .water: "water-reminders"
        case .weight: "weight-reminders"
        }
    }
}

struct ReminderNotificationPlan: Equatable, Sendable {
    let identifier: String
    let kind: ReminderNotificationKind
    let fireDate: Date
}

enum ReminderSchedulePlanner {
    static let identifierPrefix = "count-calories.reminder."
    static let schedulingDayCount = 5
    static let pendingNotificationLimit = 64
    static let waterGoal = 8
    static let waterReminderIntervalHours = 2
    static let waterReminderStartHour = 8
    static let waterReminderEndHour = 22

    static func plans(
        now: Date,
        calendar: Calendar,
        preferences: ReminderPreferences,
        meals: [MealReminderRecord],
        water: [WaterReminderRecord],
        weights: [WeightReminderRecord] = []
    ) -> [ReminderNotificationPlan] {
        guard preferences.hasEnabledReminder else { return [] }

        let today = calendar.startOfDay(for: now)
        var plans: [ReminderNotificationPlan] = []

        for dayOffset in 0..<schedulingDayCount {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            let recordedMeals = Set(
                meals
                    .filter { calendar.isDate($0.date, inSameDayAs: day) }
                    .compactMap { record in
                        ReminderMeal(rawValue: record.mealType ?? ReminderMeal.snack.rawValue)
                    }
            )

            for meal in ReminderMeal.allCases
            where preferences.isEnabled(meal) && !recordedMeals.contains(meal) {
                guard
                    let fireDate = fireDate(
                        on: day,
                        at: preferences.time(for: meal),
                        calendar: calendar
                    ),
                    fireDate > now
                else {
                    continue
                }

                plans.append(
                    ReminderNotificationPlan(
                        identifier: identifier(for: .meal(meal), date: fireDate, calendar: calendar),
                        kind: .meal(meal),
                        fireDate: fireDate
                    )
                )
            }

            guard preferences.waterEnabled else { continue }
            let waterRecord = water.first { calendar.isDate($0.date, inSameDayAs: day) }
            guard (waterRecord?.glasses ?? 0) < waterGoal else { continue }

            plans.append(contentsOf: waterPlans(
                on: day,
                now: now,
                calendar: calendar,
                record: waterRecord
            ))
        }

        if preferences.weightEnabled {
            plans.append(contentsOf: weightPlans(
                now: now,
                calendar: calendar,
                preferences: preferences,
                weights: weights
            ))
        }

        let sortedPlans = plans.sorted {
            if $0.fireDate == $1.fireDate {
                return $0.identifier < $1.identifier
            }
            return $0.fireDate < $1.fireDate
        }
        return Array(sortedPlans.prefix(pendingNotificationLimit))
    }

    private static func weightPlans(
        now: Date,
        calendar: Calendar,
        preferences: ReminderPreferences,
        weights: [WeightReminderRecord]
    ) -> [ReminderNotificationPlan] {
        switch preferences.weightFrequency {
        case .daily:
            let today = calendar.startOfDay(for: now)
            return (0..<schedulingDayCount).compactMap { dayOffset in
                guard
                    let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                    !weights.contains(where: { calendar.isDate($0.date, inSameDayAs: day) }),
                    let date = fireDate(on: day, at: preferences.weightTime, calendar: calendar),
                    date > now
                else {
                    return nil
                }
                return ReminderNotificationPlan(
                    identifier: identifier(for: .weight, date: date, calendar: calendar),
                    kind: .weight,
                    fireDate: date
                )
            }

        case .weekly:
            let today = calendar.startOfDay(for: now)
            let latestPastWeight = weights
                .map(\.date)
                .filter { $0 <= now }
                .max()
            let dueDay: Date
            if let latestPastWeight,
               let date = calendar.date(
                byAdding: .day,
                value: 7,
                to: calendar.startOfDay(for: latestPastWeight)
               ) {
                dueDay = date
            } else {
                dueDay = today
            }

            var candidate = fireDate(
                on: max(dueDay, today),
                at: preferences.weightTime,
                calendar: calendar
            )
            if candidate == nil || candidate! <= now {
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
                    return []
                }
                candidate = fireDate(
                    on: tomorrow,
                    at: preferences.weightTime,
                    calendar: calendar
                )
            }
            guard let candidate, candidate > now else { return [] }

            return [ReminderNotificationPlan(
                identifier: identifier(for: .weight, date: candidate, calendar: calendar),
                kind: .weight,
                fireDate: candidate
            )]
        }
    }

    private static func waterPlans(
        on day: Date,
        now: Date,
        calendar: Calendar,
        record: WaterReminderRecord?
    ) -> [ReminderNotificationPlan] {
        guard
            let reminderWindowStart = fireDate(
                on: day,
                at: ReminderTime(hour: waterReminderStartHour, minute: 0),
                calendar: calendar
            ),
            let reminderWindowEnd = fireDate(
                on: day,
                at: ReminderTime(hour: waterReminderEndHour, minute: 0),
                calendar: calendar
            )
        else {
            return []
        }

        let lastRecordedAt = record?.lastRecordedAt.flatMap { recordedAt in
            calendar.isDate(recordedAt, inSameDayAs: day) ? recordedAt : nil
        }
        let baseline = max(lastRecordedAt ?? reminderWindowStart, reminderWindowStart)
        guard var fireDate = calendar.date(
            byAdding: .hour,
            value: waterReminderIntervalHours,
            to: baseline
        ) else {
            return []
        }

        if calendar.isDate(day, inSameDayAs: now), fireDate <= now {
            fireDate = now.addingTimeInterval(60)
        }

        var plans: [ReminderNotificationPlan] = []
        while fireDate <= reminderWindowEnd {
            plans.append(
                ReminderNotificationPlan(
                    identifier: identifier(for: .water, date: fireDate, calendar: calendar),
                    kind: .water,
                    fireDate: fireDate
                )
            )

            guard let nextDate = calendar.date(
                byAdding: .hour,
                value: waterReminderIntervalHours,
                to: fireDate
            ) else {
                break
            }
            fireDate = nextDate
        }
        return plans
    }

    private static func fireDate(
        on day: Date,
        at time: ReminderTime,
        calendar: Calendar
    ) -> Date? {
        calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: day
        )
    }

    private static func identifier(
        for kind: ReminderNotificationKind,
        date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let kindComponent: String
        switch kind {
        case .meal(let meal): kindComponent = "meal.\(meal.identifierComponent)"
        case .water: kindComponent = "water"
        case .weight: kindComponent = "weight"
        }

        return "\(identifierPrefix)\(kindComponent).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(components.hour ?? 0)-\(components.minute ?? 0)-\(components.second ?? 0)"
    }
}
