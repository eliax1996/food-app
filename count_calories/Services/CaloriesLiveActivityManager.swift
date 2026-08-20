import ActivityKit
import Foundation
import os

@MainActor
enum CaloriesLiveActivityManager {
    nonisolated enum SynchronizationResult: Equatable, Sendable {
        case success
        case superseded
    }

    private static var synchronizationGeneration = 0
    private static var synchronizationTask: Task<SynchronizationResult, Never>?

    enum StartResult: Equatable {
        case started
        case alreadyActive
        case unavailable
        case failed
    }

    static var isActive: Bool {
        !Activity<CaloriesActivityAttributes>.activities.isEmpty
    }

    static func start(
        calories: Int,
        waterGlasses: Int,
        calorieGoal: Int,
        waterGoal: Int
    ) -> StartResult {
        let operation = AppLogger.begin(
            "live_activity.start",
            category: .integrations,
            source: "today"
        )
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.noop(operation, reason: "authorization_unavailable")
            return .unavailable
        }
        guard !isActive else {
            AppLogger.noop(operation, reason: "already_active")
            return .alreadyActive
        }

        let state = contentState(
            calories: calories,
            waterGlasses: waterGlasses,
            calorieGoal: calorieGoal,
            waterGoal: waterGoal
        )
        let content = activityContent(state: state)
        let attributes = CaloriesActivityAttributes(
            calorieGoal: max(1, calorieGoal),
            waterGoal: max(1, waterGoal)
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            AppLogger.succeed(operation, count: 1)
            return .started
        } catch {
            AppLogger.fail(operation, error: error)
            return .failed
        }
    }

    @discardableResult
    static func synchronize(
        calories: Int,
        caloriesAreComplete: Bool,
        waterGlasses: Int,
        calorieGoal: Int,
        waterGoal: Int,
        parentOperationID: UUID? = nil
    ) -> Task<SynchronizationResult, Never> {
        synchronizationGeneration += 1
        let generation = synchronizationGeneration
        let predecessor = synchronizationTask
        let logOperation = AppLogger.begin(
            "live_activity.synchronize",
            category: .integrations,
            source: "today",
            parentID: parentOperationID
        )
        let operation = Task<SynchronizationResult, Never> { @MainActor in
            _ = await predecessor?.value
            guard generation == synchronizationGeneration else {
                AppLogger.cancel(logOperation, reason: "superseded")
                return .superseded
            }
            if caloriesAreComplete {
                await updateIfActive(
                    calories: calories,
                    waterGlasses: waterGlasses,
                    calorieGoal: calorieGoal,
                    waterGoal: waterGoal
                )
            } else {
                await stop(
                    source: "incomplete_calories",
                    parentOperationID: logOperation.id
                )
            }
            AppLogger.succeed(
                logOperation,
                count: Activity<CaloriesActivityAttributes>.activities.count
            )
            if generation == synchronizationGeneration {
                synchronizationTask = nil
            }
            return .success
        }
        synchronizationTask = operation
        return operation
    }

    static func updateIfActive(
        calories: Int,
        waterGlasses: Int,
        calorieGoal: Int,
        waterGoal: Int
    ) async {
        let activities = Activity<CaloriesActivityAttributes>.activities
        guard !activities.isEmpty else { return }

        let content = activityContent(
            state: contentState(
                calories: calories,
                waterGlasses: waterGlasses,
                calorieGoal: calorieGoal,
                waterGoal: waterGoal
            )
        )
        for activity in activities {
            await activity.update(content)
        }
    }

    static func stop(
        source: String = "today",
        parentOperationID: UUID? = nil
    ) async {
        let operation = AppLogger.begin(
            "live_activity.stop",
            category: .integrations,
            source: source,
            parentID: parentOperationID
        )
        let activities = Activity<CaloriesActivityAttributes>.activities
        guard !activities.isEmpty else {
            AppLogger.noop(operation, reason: "not_active")
            return
        }
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        AppLogger.succeed(operation, count: activities.count)
    }

    private static func contentState(
        calories: Int,
        waterGlasses: Int,
        calorieGoal: Int,
        waterGoal: Int
    ) -> CaloriesActivityAttributes.ContentState {
        CaloriesActivityAttributes.ContentState(
            calories: max(0, calories),
            waterGlasses: min(max(0, waterGlasses), 30),
            calorieGoal: max(1, calorieGoal),
            waterGoal: max(1, waterGoal)
        )
    }

    private static func activityContent(
        state: CaloriesActivityAttributes.ContentState
    ) -> ActivityContent<CaloriesActivityAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: Calendar.current.date(byAdding: .hour, value: 8, to: .now)
        )
    }
}
