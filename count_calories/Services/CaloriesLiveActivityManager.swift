import ActivityKit
import Foundation

@MainActor
enum CaloriesLiveActivityManager {
    static func update(
        calories: Int,
        waterGlasses: Int,
        calorieGoal: Int,
        waterGoal: Int
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = CaloriesActivityAttributes.ContentState(
            calories: max(0, calories),
            waterGlasses: max(0, waterGlasses)
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.date(byAdding: .hour, value: 8, to: .now)
        )

        if let activity = Activity<CaloriesActivityAttributes>.activities.first {
            await activity.update(content)
            return
        }

        let attributes = CaloriesActivityAttributes(
            calorieGoal: calorieGoal,
            waterGoal: waterGoal
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }
}
