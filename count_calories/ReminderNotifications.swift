import Foundation
import UserNotifications
import os
#if canImport(UIKit)
import UIKit
#endif

private let reminderLogger = Logger(
    subsystem: "ch.elia.count-calories",
    category: "notifications"
)

enum ReminderPreferenceKey {
    static let breakfast = "reminders.breakfast.enabled"
    static let lunch = "reminders.lunch.enabled"
    static let snack = "reminders.snack.enabled"
    static let dinner = "reminders.dinner.enabled"
    static let water = "reminders.water.enabled"
}

struct ReminderPreferences: Equatable, Sendable {
    var breakfastEnabled = false
    var lunchEnabled = false
    var snackEnabled = false
    var dinnerEnabled = false
    var waterEnabled = false

    static func stored(in defaults: UserDefaults = .standard) -> ReminderPreferences {
        ReminderPreferences(
            breakfastEnabled: defaults.bool(forKey: ReminderPreferenceKey.breakfast),
            lunchEnabled: defaults.bool(forKey: ReminderPreferenceKey.lunch),
            snackEnabled: defaults.bool(forKey: ReminderPreferenceKey.snack),
            dinnerEnabled: defaults.bool(forKey: ReminderPreferenceKey.dinner),
            waterEnabled: defaults.bool(forKey: ReminderPreferenceKey.water)
        )
    }

    var hasEnabledReminder: Bool {
        breakfastEnabled || lunchEnabled || snackEnabled || dinnerEnabled || waterEnabled
    }

    func isEnabled(_ meal: ReminderMeal) -> Bool {
        switch meal {
        case .breakfast:
            breakfastEnabled
        case .lunch:
            lunchEnabled
        case .snack:
            snackEnabled
        case .dinner:
            dinnerEnabled
        }
    }
}

enum ReminderMeal: String, CaseIterable, Sendable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case snack = "Snack"
    case dinner = "Dinner"

    var reminderHour: Int {
        switch self {
        case .breakfast: 9
        case .lunch: 13
        case .snack: 16
        case .dinner: 20
        }
    }

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

enum ReminderNotificationKind: Equatable, Sendable {
    case meal(ReminderMeal)
    case water

    var title: String {
        switch self {
        case .meal(let meal):
            "Log \(meal.rawValue.lowercased())"
        case .water:
            "Time for water"
        }
    }

    var body: String {
        switch self {
        case .meal(let meal):
            "No \(meal.rawValue.lowercased()) is registered yet. Don't forget to log what you ate."
        case .water:
            "No glass was registered recently. Don't forget to log your water."
        }
    }

    var threadIdentifier: String {
        switch self {
        case .meal:
            "food-reminders"
        case .water:
            "water-reminders"
        }
    }
}

struct ReminderNotificationPlan: Equatable, Sendable {
    let identifier: String
    let kind: ReminderNotificationKind
    let fireDate: Date
}

enum ReminderAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
}

enum ReminderSchedulePlanner {
    static let identifierPrefix = "count-calories.reminder."
    static let schedulingDayCount = 5
    static let waterGoal = 8
    static let waterReminderIntervalHours = 2
    static let waterReminderStartHour = 8
    static let waterReminderEndHour = 22

    static func plans(
        now: Date,
        calendar: Calendar,
        preferences: ReminderPreferences,
        meals: [MealReminderRecord],
        water: [WaterReminderRecord]
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

            for meal in ReminderMeal.allCases where preferences.isEnabled(meal) && !recordedMeals.contains(meal) {
                guard
                    let fireDate = calendar.date(
                        bySettingHour: meal.reminderHour,
                        minute: 0,
                        second: 0,
                        of: day
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

        return plans.sorted {
            if $0.fireDate == $1.fireDate {
                return $0.identifier < $1.identifier
            }
            return $0.fireDate < $1.fireDate
        }
    }

    private static func waterPlans(
        on day: Date,
        now: Date,
        calendar: Calendar,
        record: WaterReminderRecord?
    ) -> [ReminderNotificationPlan] {
        guard
            let reminderWindowStart = calendar.date(
                bySettingHour: waterReminderStartHour,
                minute: 0,
                second: 0,
                of: day
            ),
            let reminderWindowEnd = calendar.date(
                bySettingHour: waterReminderEndHour,
                minute: 0,
                second: 0,
                of: day
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
        case .meal(let meal):
            kindComponent = "meal.\(meal.identifierComponent)"
        case .water:
            kindComponent = "water"
        }

        return "\(identifierPrefix)\(kindComponent).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(components.hour ?? 0)-\(components.minute ?? 0)-\(components.second ?? 0)"
    }
}

@MainActor
final class ReminderNotificationManager {
    static let shared = ReminderNotificationManager()

    static var systemSettingsURL: URL? {
#if canImport(UIKit)
        URL(string: UIApplication.openNotificationSettingsURLString)
#else
        nil
#endif
    }

    private let center: UNUserNotificationCenter
    private var schedulingGeneration = 0

    private init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationState() async -> ReminderAuthorizationState {
        let settings = await center.notificationSettings()
        return authorizationState(for: settings.authorizationStatus)
    }

    func requestAuthorizationIfNeeded() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            reminderLogger.notice("Notification authorization requested; granted=\(granted, privacy: .public)")
            return granted
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func reschedule(
        meals: [MealReminderRecord],
        water: [WaterReminderRecord],
        preferences: ReminderPreferences,
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        schedulingGeneration += 1
        let generation = schedulingGeneration

        try? await Task.sleep(for: .milliseconds(100))
        guard generation == schedulingGeneration else { return }

        let pendingRequests = await center.pendingNotificationRequests()
        guard generation == schedulingGeneration else { return }
        let pendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderSchedulePlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)

        let deliveredNotifications = await center.deliveredNotifications()
        guard generation == schedulingGeneration else { return }
        let deliveredIdentifiers = deliveredNotifications
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(ReminderSchedulePlanner.identifierPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)

        guard preferences.hasEnabledReminder else {
            reminderLogger.notice("Reminder notifications disabled; pending reminders cleared")
            return
        }

        let settings = await center.notificationSettings()
        guard generation == schedulingGeneration else { return }
        guard authorizationState(for: settings.authorizationStatus) == .authorized else {
            reminderLogger.notice("Reminder scheduling skipped; notification authorization unavailable")
            return
        }

        let plans = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: meals,
            water: water
        )

        var scheduledCount = 0
        for plan in plans {
            guard generation == schedulingGeneration else { return }
            do {
                try await center.add(request(for: plan, calendar: calendar))
                scheduledCount += 1
            } catch {
                reminderLogger.error(
                    "Failed to schedule reminder id=\(plan.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        reminderLogger.notice("Scheduled \(scheduledCount, privacy: .public) reminder notifications")
    }

    private func authorizationState(for status: UNAuthorizationStatus) -> ReminderAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .authorized, .provisional, .ephemeral:
            .authorized
        case .denied:
            .denied
        @unknown default:
            .denied
        }
    }

    private func request(
        for plan: ReminderNotificationPlan,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = plan.kind.title
        content.body = plan.kind.body
        content.sound = .default
        content.threadIdentifier = plan.kind.threadIdentifier

        var dateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: plan.fireDate
        )
        dateComponents.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        return UNNotificationRequest(
            identifier: plan.identifier,
            content: content,
            trigger: trigger
        )
    }
}
