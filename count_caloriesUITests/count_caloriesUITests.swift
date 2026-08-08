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
        let addMealButton = app.buttons["add-meal"]
        let mealEditor = app.descendants(matching: .any)
            .matching(identifier: "meal-editor")
            .firstMatch
        let saveMealButton = app.buttons["save-meal"]
        let calorieTotal = app.staticTexts["daily-calorie-total"]
        XCTContext.runActivity(named: "Launch app") { _ in
            app.launchArguments = ["-ui-testing"]
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertExists(addMealButton, identifier: "add-meal", phase: "Launch")
            assertExists(calorieTotal, identifier: "daily-calorie-total", phase: "Launch")
            assertDailyTotal(calorieTotal, eaten: 0, phase: "Launch")
        }

        XCTContext.runActivity(named: "Open meal editor") { _ in
            XCTAssertTrue(
                addMealButton.isEnabled,
                "Open: add-meal control is disabled; \(diagnostic(for: addMealButton))"
            )
            addMealButton.tap()
            assertExists(mealEditor, identifier: "meal-editor", phase: "Open")
            assertExists(saveMealButton, identifier: "save-meal", phase: "Open")

            let saveEnabled = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "enabled == true"),
                object: saveMealButton
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [saveEnabled], timeout: uiTimeout),
                .completed,
                "Open: save-meal did not become enabled; \(diagnostic(for: saveMealButton))"
            )
        }

        XCTContext.runActivity(named: "Verify saved total") { _ in
            saveMealButton.tap()
            assertDailyTotal(calorieTotal, eaten: 15, phase: "Total")
        }
    }

    @MainActor
    func testSearchingFoodAndCancellingDoesNotLogMeal() throws {
        let app = XCUIApplication()
        let addMealButton = app.buttons["add-meal"]
        let mealEditor = app.descendants(matching: .any)
            .matching(identifier: "meal-editor")
            .firstMatch
        let chooseFoodButton = app.buttons["choose-food"]
        let searchField = app.searchFields.firstMatch
        let bananaResult = app.buttons["food-result-Banana"]
        let selectedFoodName = app.staticTexts["selected-food-name"]
        let calculatedTotal = app.descendants(matching: .any)
            .matching(identifier: "calculated-total")
            .firstMatch
        let cancelButton = app.buttons["cancel-meal"]
        let bananaMeal = app.descendants(matching: .any)
            .matching(identifier: "meal-entry-Banana")
            .firstMatch
        let calorieTotal = app.staticTexts["daily-calorie-total"]

        XCTContext.runActivity(named: "Launch app") { _ in
            app.launchArguments = ["-ui-testing"]
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertExists(addMealButton, identifier: "add-meal", phase: "Launch")
            assertExists(calorieTotal, identifier: "daily-calorie-total", phase: "Launch")
            assertDailyTotal(calorieTotal, eaten: 0, phase: "Launch")
        }

        XCTContext.runActivity(named: "Open meal editor") { _ in
            addMealButton.tap()
            assertExists(mealEditor, identifier: "meal-editor", phase: "Open")
            assertExists(chooseFoodButton, identifier: "choose-food", phase: "Open")
            chooseFoodButton.tap()
            assertExists(searchField, identifier: "food search field", phase: "Open")
        }

        XCTContext.runActivity(named: "Search for Banana") { _ in
            searchField.tap()
            searchField.typeText("Banana")
            XCTAssertEqual(
                searchField.value as? String,
                "Banana",
                "Search: query did not become Banana; \(diagnostic(for: searchField))"
            )
            assertExists(bananaResult, identifier: "food-result-Banana", phase: "Search")
        }

        XCTContext.runActivity(named: "Select Banana") { _ in
            bananaResult.tap()
            let selectedBanana = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Banana"),
                object: selectedFoodName
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [selectedBanana], timeout: uiTimeout),
                .completed,
                "Select: selected food did not become Banana; \(diagnostic(for: selectedFoodName))"
            )
        }

        XCTContext.runActivity(named: "Verify draft total") { _ in
            assertExists(calculatedTotal, identifier: "calculated-total", phase: "Total")
            assertExactValue(
                calculatedTotal,
                expected: "89 calories",
                phase: "Total"
            )
        }

        XCTContext.runActivity(named: "Cancel meal") { _ in
            assertExists(cancelButton, identifier: "cancel-meal", phase: "Cancel")
            XCTAssertTrue(
                cancelButton.isEnabled,
                "Cancel: cancel-meal control is disabled; \(diagnostic(for: cancelButton))"
            )
            cancelButton.tap()

            let editorDismissed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: mealEditor
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [editorDismissed], timeout: uiTimeout),
                .completed,
                "Cancel: meal editor did not dismiss; \(diagnostic(for: mealEditor))"
            )
        }

        XCTContext.runActivity(named: "Verify final state") { _ in
            XCTAssertFalse(
                bananaMeal.exists,
                "Final-state: Banana meal row exists after cancellation; \(diagnostic(for: bananaMeal))"
            )
            assertExists(calorieTotal, identifier: "daily-calorie-total", phase: "Final-state")
            assertDailyTotal(calorieTotal, eaten: 0, phase: "Final-state")
        }
    }

    private let uiTimeout: TimeInterval = 5

    private func assertExists(
        _ element: XCUIElement,
        identifier: String,
        phase: String
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: uiTimeout),
            "\(phase): expected \(identifier) to exist; \(diagnostic(for: element))"
        )
    }

    private func assertExactValue(
        _ element: XCUIElement,
        expected: String,
        phase: String
    ) {
        let expectedValue = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectedValue], timeout: uiTimeout),
            .completed,
            "\(phase): expected value '\(expected)'; \(diagnostic(for: element))"
        )
    }

    private func assertDailyTotal(
        _ element: XCUIElement,
        eaten: Int,
        phase: String
    ) {
        let expected = "\(eaten.formatted()) eaten, \((1700 - eaten).formatted()) kcal remaining, daily goal \(1700.formatted())"
        assertExactValue(element, expected: expected, phase: phase)
    }

    private func diagnostic(for element: XCUIElement) -> String {
        let value = element.value.map { String(describing: $0) } ?? "<nil>"
        return "exists=\(element.exists), enabled=\(element.isEnabled), label='\(element.label)', value='\(value)'"
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
            "dinner-reminder-toggle"
        ] {
            XCTAssertTrue(
                app.switches[identifier].waitForExistence(timeout: 5),
                "Missing reminder control: \(identifier)"
            )
        }

        let waterReminderToggle = app.switches["water-reminder-toggle"]
        if !waterReminderToggle.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            waterReminderToggle.waitForExistence(timeout: 5),
            "Missing reminder control: water-reminder-toggle"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
