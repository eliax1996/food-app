import Foundation
import UserNotifications
import os
#if canImport(UIKit)
import UIKit
#endif

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

nonisolated enum ReminderRequestReplacementResult: Equatable, Sendable {
    case succeeded
    case failed(rollbackSucceeded: Bool)
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
#if DEBUG || RELEASE_VALIDATION
        if let debugAuthorizationState { return debugAuthorizationState }
#endif
        let settings = await center.notificationSettings()
        return authorizationState(for: settings.authorizationStatus)
    }

    func requestAuthorizationIfNeeded(parentOperationID: UUID? = nil) async throws -> Bool {
        let operation = AppLogger.begin(
            "reminders.authorization_request",
            category: .reminders,
            source: "settings",
            parentID: parentOperationID
        )
#if DEBUG || RELEASE_VALIDATION
        if let debugAuthorizationState {
            AppLogger.noop(
                operation,
                reason: debugAuthorizationState == .authorized ? "fixture_authorized" : "fixture_denied"
            )
            return debugAuthorizationState == .authorized
        }
#endif
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                if granted {
                    AppLogger.succeed(operation)
                } else {
                    AppLogger.noop(operation, reason: "denied")
                }
                return granted
            } catch {
                AppLogger.fail(operation, error: error)
                throw error
            }
        case .authorized, .provisional, .ephemeral:
            AppLogger.noop(operation, reason: "already_authorized")
            return true
        case .denied:
            AppLogger.noop(operation, reason: "denied")
            return false
        @unknown default:
            AppLogger.noop(operation, reason: "unknown_authorization")
            return false
        }
    }

    @discardableResult
    func enqueueReschedule(
        meals: [MealReminderRecord],
        water: [WaterReminderRecord],
        weights: [WeightReminderRecord] = [],
        preferences: ReminderPreferences,
        now: Date = .now,
        calendar: Calendar = .current,
        parentOperationID: UUID? = nil
    ) -> Task<ReminderSchedulingResult, Never> {
        _ = preferences // Callers pass current intent; durable stored intent wins after coalescing.
        schedulingGeneration += 1
        let generation = schedulingGeneration
        let predecessor = schedulingTask
        let logOperation = AppLogger.begin(
            "reminders.reschedule",
            category: .reminders,
            source: "app",
            parentID: parentOperationID
        )
        let operation = Task { @MainActor [weak self] in
            _ = await predecessor?.value
            guard let self else {
                AppLogger.partial(logOperation, failedComponent: "manager_lifetime")
                return ReminderSchedulingResult.failed
            }
            guard generation == self.schedulingGeneration else {
                AppLogger.cancel(logOperation, reason: "superseded")
                return .superseded
            }
            let result = await self.performReschedule(
                meals: meals,
                water: water,
                weights: weights,
                now: now,
                calendar: calendar,
                generation: generation,
                logOperation: logOperation
            )
            if generation == self.schedulingGeneration {
                self.schedulingTask = nil
            }
            return result
        }
        schedulingTask = operation
        return operation
    }

    @discardableResult
    func reschedule(
        meals: [MealReminderRecord],
        water: [WaterReminderRecord],
        weights: [WeightReminderRecord] = [],
        preferences: ReminderPreferences,
        now: Date = .now,
        calendar: Calendar = .current,
        parentOperationID: UUID? = nil
    ) async -> ReminderSchedulingResult {
        await enqueueReschedule(
            meals: meals,
            water: water,
            weights: weights,
            preferences: preferences,
            now: now,
            calendar: calendar,
            parentOperationID: parentOperationID
        ).value
    }

    private func performReschedule(
        meals: [MealReminderRecord],
        water: [WaterReminderRecord],
        weights: [WeightReminderRecord],
        now: Date,
        calendar: Calendar,
        generation: Int,
        logOperation: AppLogOperation
    ) async -> ReminderSchedulingResult {
        try? await Task.sleep(for: .milliseconds(100))
        guard generation == schedulingGeneration else {
            AppLogger.cancel(logOperation, reason: "superseded")
            return .superseded
        }
#if DEBUG || RELEASE_VALIDATION
        if let debugAuthorizationState {
            let preferences = ReminderPreferences.stored()
            guard preferences.hasEnabledReminder else {
                AppLogger.noop(logOperation, reason: "disabled")
                return .disabled
            }
            guard debugAuthorizationState == .authorized else {
                AppLogger.noop(logOperation, reason: "authorization_unavailable")
                return .authorizationUnavailable
            }
            let count = ReminderSchedulePlanner.plans(
                now: now,
                calendar: calendar,
                preferences: preferences,
                meals: meals,
                water: water,
                weights: weights
            ).count
            AppLogger.succeed(logOperation, count: count)
            return .scheduled(count)
        }
#endif
        // UserDefaults owns reminder intent. Reload only after debounce/serialization so
        // stale callers cannot overwrite preferences already saved by Settings.
        let preferences = ReminderPreferences.stored()

        let pendingRequests = await center.pendingNotificationRequests()
        guard generation == schedulingGeneration else {
            AppLogger.cancel(logOperation, reason: "superseded")
            return .superseded
        }
        let appPendingRequests = pendingRequests.filter {
            $0.identifier.hasPrefix(ReminderSchedulePlanner.identifierPrefix)
        }

        let deliveredNotifications = await center.deliveredNotifications()
        guard generation == schedulingGeneration else {
            AppLogger.cancel(logOperation, reason: "superseded")
            return .superseded
        }
        let deliveredIdentifiers = deliveredNotifications
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(ReminderSchedulePlanner.identifierPrefix) }

        guard preferences.hasEnabledReminder else {
            center.removePendingNotificationRequests(withIdentifiers: appPendingRequests.map(\.identifier))
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            AppLogger.noop(logOperation, reason: "disabled")
            return .disabled
        }

        let settings = await center.notificationSettings()
        guard generation == schedulingGeneration else {
            AppLogger.cancel(logOperation, reason: "superseded")
            return .superseded
        }
        guard authorizationState(for: settings.authorizationStatus) == .authorized else {
            center.removePendingNotificationRequests(withIdentifiers: appPendingRequests.map(\.identifier))
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            AppLogger.noop(logOperation, reason: "authorization_unavailable")
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

        let replacement = await Self.replacePendingRequestsDetailed(
            existingRequests: appPendingRequests,
            desiredRequests: requests,
            add: { [center] request in try await center.add(request) },
            remove: { [center] identifiers in
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        )
        guard generation == schedulingGeneration else {
            AppLogger.cancel(logOperation, reason: "superseded")
            return .superseded
        }
        guard case .succeeded = replacement else {
            let failedComponent = replacement == .failed(rollbackSucceeded: true)
                ? "pending_request_replacement"
                : "pending_request_replacement_and_rollback"
            AppLogger.partial(logOperation, failedComponent: failedComponent)
            return .failed
        }

        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
        AppLogger.succeed(logOperation, count: requests.count)
        return .scheduled(requests.count)
    }

    static func replacePendingRequests(
        existingRequests: [UNNotificationRequest],
        desiredRequests: [UNNotificationRequest],
        add: (UNNotificationRequest) async throws -> Void,
        remove: ([String]) -> Void
    ) async -> Bool {
        await replacePendingRequestsDetailed(
            existingRequests: existingRequests,
            desiredRequests: desiredRequests,
            add: add,
            remove: remove
        ) == .succeeded
    }

    static func replacePendingRequestsDetailed(
        existingRequests: [UNNotificationRequest],
        desiredRequests: [UNNotificationRequest],
        add: (UNNotificationRequest) async throws -> Void,
        remove: ([String]) -> Void
    ) async -> ReminderRequestReplacementResult {
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
            var rollbackSucceeded = true
            for request in existingRequests {
                do {
                    try await add(request)
                } catch {
                    rollbackSucceeded = false
                }
            }
            return .failed(rollbackSucceeded: rollbackSucceeded)
        }
        return .succeeded
    }

#if DEBUG || RELEASE_VALIDATION
    private var debugAuthorizationState: ReminderAuthorizationState? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-reminders-denied") { return .denied }
        if arguments.contains("-ui-testing-reminders-authorized") { return .authorized }
        return nil
    }
#endif

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
