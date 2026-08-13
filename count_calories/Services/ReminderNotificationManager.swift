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

enum ReminderSchedulingResult: Equatable {
    case scheduled(Int)
    case disabled
    case authorizationUnavailable
    case superseded
    case failed
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
    private var schedulingTask: Task<ReminderSchedulingResult, Never>?

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

    @discardableResult
    func reschedule(
        meals: [MealReminderRecord],
        water: [WaterReminderRecord],
        weights: [WeightReminderRecord] = [],
        preferences: ReminderPreferences,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> ReminderSchedulingResult {
        _ = preferences // Callers pass current intent; durable stored intent wins after coalescing.
        schedulingGeneration += 1
        let generation = schedulingGeneration
        let predecessor = schedulingTask
        let operation = Task { @MainActor [weak self] in
            _ = await predecessor?.value
            guard let self else { return ReminderSchedulingResult.failed }
            guard generation == self.schedulingGeneration else { return .superseded }
            return await self.performReschedule(
                meals: meals,
                water: water,
                weights: weights,
                now: now,
                calendar: calendar,
                generation: generation
            )
        }
        schedulingTask = operation
        let result = await operation.value
        if generation == schedulingGeneration {
            schedulingTask = nil
        }
        return result
    }

    private func performReschedule(
        meals: [MealReminderRecord],
        water: [WaterReminderRecord],
        weights: [WeightReminderRecord],
        now: Date,
        calendar: Calendar,
        generation: Int
    ) async -> ReminderSchedulingResult {
        try? await Task.sleep(for: .milliseconds(100))
        guard generation == schedulingGeneration else { return .superseded }
        // UserDefaults owns reminder intent. Reload only after debounce/serialization so
        // stale callers cannot overwrite preferences already saved by Settings.
        let preferences = ReminderPreferences.stored()

        let pendingRequests = await center.pendingNotificationRequests()
        guard generation == schedulingGeneration else { return .superseded }
        let appPendingRequests = pendingRequests.filter {
            $0.identifier.hasPrefix(ReminderSchedulePlanner.identifierPrefix)
        }

        let deliveredNotifications = await center.deliveredNotifications()
        guard generation == schedulingGeneration else { return .superseded }
        let deliveredIdentifiers = deliveredNotifications
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(ReminderSchedulePlanner.identifierPrefix) }

        guard preferences.hasEnabledReminder else {
            center.removePendingNotificationRequests(withIdentifiers: appPendingRequests.map(\.identifier))
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            reminderLogger.notice("Reminder notifications disabled; pending reminders cleared")
            return .disabled
        }

        let settings = await center.notificationSettings()
        guard generation == schedulingGeneration else { return .superseded }
        guard authorizationState(for: settings.authorizationStatus) == .authorized else {
            center.removePendingNotificationRequests(withIdentifiers: appPendingRequests.map(\.identifier))
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            reminderLogger.notice("Reminder authorization unavailable; pending reminders cleared")
            return .authorizationUnavailable
        }

        let requests = ReminderSchedulePlanner.plans(
            now: now,
            calendar: calendar,
            preferences: preferences,
            meals: meals,
            water: water,
            weights: weights
        ).map { request(for: $0, calendar: calendar) }

        let replaced = await Self.replacePendingRequests(
            existingRequests: appPendingRequests,
            desiredRequests: requests,
            add: { [center] request in try await center.add(request) },
            remove: { [center] identifiers in
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        )
        guard generation == schedulingGeneration else { return .superseded }
        guard replaced else {
            reminderLogger.error("Failed to replace reminder notification schedule; previous requests retained where possible")
            return .failed
        }

        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
        reminderLogger.notice("Scheduled \(requests.count, privacy: .public) reminder notifications")
        return .scheduled(requests.count)
    }

    static func replacePendingRequests(
        existingRequests: [UNNotificationRequest],
        desiredRequests: [UNNotificationRequest],
        add: (UNNotificationRequest) async throws -> Void,
        remove: ([String]) -> Void
    ) async -> Bool {
        let existingIDs = Set(existingRequests.map(\.identifier))
        let desiredIDs = Set(desiredRequests.map(\.identifier))
        let obsoleteIDs = existingIDs.subtracting(desiredIDs).sorted()
        var addedIDs: [String] = []

        // Free obsolete app-owned slots first so replacing a full 64-request schedule can succeed.
        // Full request snapshots above make this removal reversible if any addition fails.
        if !obsoleteIDs.isEmpty {
            remove(obsoleteIDs)
        }

        do {
            for request in desiredRequests {
                try await add(request)
                addedIDs.append(request.identifier)
            }
        } catch {
            let introducedIDs = addedIDs.filter { !existingIDs.contains($0) }
            if !introducedIDs.isEmpty {
                remove(introducedIDs)
            }
            for request in existingRequests {
                try? await add(request)
            }
            return false
        }
        return true
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
