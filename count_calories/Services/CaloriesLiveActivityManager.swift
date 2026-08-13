import ActivityKit
import Foundation
import os

@MainActor
enum CaloriesLiveActivityManager {
    private static var synchronizationGeneration = 0
    private static var synchronizationTask: Task<Void, Never>?

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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return .unavailable }
        guard !isActive else { return .alreadyActive }

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
            return .started
        } catch {
            Logger(subsystem: "ch.elia.count-calories", category: "LiveActivity")
                .error("Could not start Live Activity: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    static func refreshCalorieGoalIfActive(_ calorieGoal: Int) async {
        let activities = Activity<CaloriesActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        for activity in activities {
            var state = activity.content.state
            state.calorieGoal = max(1, calorieGoal)
            await activity.update(activityContent(state: state))
        }
    }

    @discardableResult
    static func synchronize(
        calories: Int,
        caloriesAreComplete: Bool,
        waterGlasses: Int,
        calorieGoal: Int,
        waterGoal: Int
    ) -> Task<Void, Never> {
        synchronizationGeneration += 1
        let generation = synchronizationGeneration
        let predecessor = synchronizationTask
        let operation = Task { @MainActor in
            _ = await predecessor?.value
            guard generation == synchronizationGeneration else { return }
            if caloriesAreComplete {
                await updateIfActive(
                    calories: calories,
                    waterGlasses: waterGlasses,
                    calorieGoal: calorieGoal,
                    waterGoal: waterGoal
                )
            } else {
                await stop()
            }
            if generation == synchronizationGeneration {
                synchronizationTask = nil
            }
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

    static func stop() async {
        let activities = Activity<CaloriesActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
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
