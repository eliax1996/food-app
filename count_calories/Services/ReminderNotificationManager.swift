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

enum ReminderAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
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
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                reminderLogger.notice("Notification authorization requested; granted=\(granted, privacy: .public)")
                return granted
            } catch {
                reminderLogger.error(
                    "Failed to request notification authorization: \(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
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
