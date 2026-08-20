#if !SWIFT_PACKAGE
import XCTest
@testable import count_calories

@MainActor
final class TodayExternalSurfaceCoordinatorTests: XCTestCase {
    func testSnapshotUsesPersistedTodayTruthAndKeepsAllReminderEvidence() {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_777_824_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let todayWater = WaterDay(date: now, glasses: 5)
        let oldWater = WaterDay(date: yesterday, glasses: 7)
        let entries = [
            PlateEntry(
                foodName: "Today valid",
                calories: 300,
                weightGrams: 100,
                quantity: 1,
                mealType: MealType.breakfast.rawValue,
                date: now
            ),
            PlateEntry(
                foodName: "Today invalid",
                calories: FoodCaloriePolicy.maximumCaloriesPerFood + 1,
                weightGrams: 100,
                quantity: 1,
                mealType: MealType.lunch.rawValue,
                date: now
            ),
            PlateEntry(
                foodName: "Yesterday",
                calories: 200,
                weightGrams: 100,
                quantity: 1,
                mealType: MealType.dinner.rawValue,
                date: yesterday
            )
        ]
        let weights = [WeightEntry(date: yesterday, kilograms: 70)]

        let snapshot = TodayExternalSurfaceCoordinator.snapshot(
            entries: entries,
            waterDays: [oldWater, todayWater],
            weights: weights,
            profiles: [UserProfile(dailyCalorieGoal: 1_850)],
            calendar: calendar,
            now: now,
            waterGoal: 9
        )

        XCTAssertEqual(snapshot.calories, 300)
        XCTAssertFalse(snapshot.caloriesAreComplete)
        XCTAssertEqual(snapshot.waterGlasses, 5)
        XCTAssertEqual(snapshot.lastWaterRecordedAt, todayWater.lastRecordedAt)
        XCTAssertEqual(snapshot.calorieGoal, 1_850)
        XCTAssertEqual(snapshot.waterGoal, 9)
        XCTAssertEqual(snapshot.mealReminderRecords.count, 3)
        XCTAssertEqual(snapshot.waterReminderRecords.count, 2)
        XCTAssertEqual(snapshot.weightReminderRecords.count, 1)
    }

    func testCompositeOutcomeWaitsForEveryChildTerminalAndReportsPartialFailures() {
        XCTAssertEqual(
            TodayExternalSurfaceOutcome.resolve(
                widgetSaved: true,
                reminderResult: .scheduled(4),
                liveActivityResult: .success
            ),
            .success
        )
        XCTAssertEqual(
            TodayExternalSurfaceOutcome.resolve(
                widgetSaved: false,
                reminderResult: .scheduled(4),
                liveActivityResult: .success
            ),
            .partial("widget")
        )
        XCTAssertEqual(
            TodayExternalSurfaceOutcome.resolve(
                widgetSaved: true,
                reminderResult: .failed,
                liveActivityResult: .success
            ),
            .partial("reminders")
        )
        XCTAssertEqual(
            TodayExternalSurfaceOutcome.resolve(
                widgetSaved: false,
                reminderResult: .failed,
                liveActivityResult: .success
            ),
            .partial("widget_and_reminders")
        )
        XCTAssertEqual(
            TodayExternalSurfaceOutcome.resolve(
                widgetSaved: true,
                reminderResult: .superseded,
                liveActivityResult: .success
            ),
            .cancelled
        )
        XCTAssertEqual(
            TodayExternalSurfaceOutcome.resolve(
                widgetSaved: true,
                reminderResult: .scheduled(4),
                liveActivityResult: .superseded
            ),
            .cancelled
        )
    }

    func testSnapshotUsesSafeEmptyDefaults() {
        let snapshot = TodayExternalSurfaceCoordinator.snapshot(
            entries: [],
            waterDays: [],
            weights: [],
            profiles: [],
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(snapshot.calories, 0)
        XCTAssertTrue(snapshot.caloriesAreComplete)
        XCTAssertEqual(snapshot.waterGlasses, 0)
        XCTAssertNil(snapshot.lastWaterRecordedAt)
        XCTAssertEqual(snapshot.calorieGoal, 1_700)
        XCTAssertEqual(snapshot.waterGoal, 8)
    }
}
#endif
