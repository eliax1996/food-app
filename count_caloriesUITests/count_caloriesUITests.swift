//
//  count_caloriesUITests.swift
//  count_caloriesUITests
//
//  Created by Elia on 01/08/2026.
//

import XCTest

final class CountCaloriesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddingDefaultMealUpdatesToday() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let addMealButton = app.buttons["add-meal"]
        XCTAssertTrue(addMealButton.waitForExistence(timeout: 5), "Add meal button did not appear.")
        addMealButton.tap()

        let saveMealButton = app.buttons["save-meal"]
        XCTAssertTrue(saveMealButton.waitForExistence(timeout: 5), "Save meal button did not appear.")
        let saveEnabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: saveMealButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [saveEnabled], timeout: 5),
            .completed,
            "Save meal button never became enabled."
        )
        saveMealButton.tap()

        let calorieTotal = app.staticTexts["daily-calorie-total"]
        XCTAssertTrue(calorieTotal.waitForExistence(timeout: 5), "Today's calorie total did not appear.")

        let updatedTotal = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS '15'"),
            object: calorieTotal
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [updatedTotal], timeout: 5),
            .completed,
            "Today's calorie total did not update after saving the meal."
        )
    }

    @MainActor
    func testReminderSettingsAreAvailableIndependently() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.tabBars.buttons["Config"].tap()

        for identifier in [
            "breakfast-reminder-toggle",
            "lunch-reminder-toggle",
            "snack-reminder-toggle",
            "dinner-reminder-toggle",
            "water-reminder-toggle"
        ] {
            XCTAssertTrue(
                app.switches[identifier].waitForExistence(timeout: 5),
                "Missing reminder control: \(identifier)"
            )
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
