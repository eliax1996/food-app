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
    func testAmountAdjustmentsKeepServingCountAndAvoidKeyboard() throws {
        let app = XCUIApplication()
        let addMealButton = app.buttons["add-meal"]
        let mealEditor = app.descendants(matching: .any)
            .matching(identifier: "meal-editor")
            .firstMatch
        let selectedFoodName = app.staticTexts["selected-food-name"]
        let amountField = app.textFields["meal-amount"]
        let servingField = app.textFields["meal-quantity"]
        let calculatedTotal = app.descendants(matching: .any)
            .matching(identifier: "calculated-total")
            .firstMatch
        let adjustmentControls = [
            ("amount-decrease-10", app.buttons["amount-decrease-10"]),
            ("amount-decrease-1", app.buttons["amount-decrease-1"]),
            ("amount-increase-1", app.buttons["amount-increase-1"]),
            ("amount-increase-10", app.buttons["amount-increase-10"])
        ]
        var initialServingValue = ""

        XCTContext.runActivity(named: "Launch default Almond Milk editor") { _ in
            app.launchArguments = ["-ui-testing"]
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertExists(addMealButton, identifier: "add-meal", phase: "Launch")
            assertKeyboardDismissed(app, phase: "Launch")
        }

        XCTContext.runActivity(named: "Open editor and inspect adjustment targets") { _ in
            addMealButton.tap()
            assertExists(mealEditor, identifier: "meal-editor", phase: "Open")
            assertExactValue(selectedFoodName, expected: "Almond Milk", phase: "Open")
            assertExactValue(amountField, expected: "100 grams", phase: "Open")
            assertExactValue(calculatedTotal, expected: "15 calories", phase: "Open")
            assertExists(servingField, identifier: "meal-quantity", phase: "Open")
            initialServingValue = String(describing: servingField.value ?? "")
            XCTAssertFalse(
                initialServingValue.isEmpty,
                "Open: serving count has no accessibility value; \(diagnostic(for: servingField))"
            )

            for (identifier, button) in adjustmentControls {
                assertButtonTarget(button, identifier: identifier, phase: "Open")
            }
            assertKeyboardDismissed(app, phase: "Open")
        }

        XCTContext.runActivity(named: "Decrease amount by ten") { _ in
            adjustmentControls[0].1.tap()
            assertExactValue(amountField, expected: "90 grams", phase: "−10")
            assertExactValue(calculatedTotal, expected: "14 calories", phase: "−10")
            assertExactValue(servingField, expected: initialServingValue, phase: "−10")
            assertKeyboardDismissed(app, phase: "−10")
        }

        XCTContext.runActivity(named: "Restore amount by ten") { _ in
            adjustmentControls[3].1.tap()
            assertExactValue(amountField, expected: "100 grams", phase: "+10")
            assertExactValue(calculatedTotal, expected: "15 calories", phase: "+10")
            assertExactValue(servingField, expected: initialServingValue, phase: "+10")
            assertKeyboardDismissed(app, phase: "+10")
        }

        XCTContext.runActivity(named: "Increase amount by one") { _ in
            adjustmentControls[2].1.tap()
            assertExactValue(amountField, expected: "101 grams", phase: "+1")
            assertExactValue(servingField, expected: initialServingValue, phase: "+1")
            assertKeyboardDismissed(app, phase: "+1")
        }

        XCTContext.runActivity(named: "Restore amount by one") { _ in
            adjustmentControls[1].1.tap()
            assertExactValue(amountField, expected: "100 grams", phase: "−1")
            assertExactValue(calculatedTotal, expected: "15 calories", phase: "−1")
            assertExactValue(servingField, expected: initialServingValue, phase: "−1")
            assertKeyboardDismissed(app, phase: "−1")
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
            assertKeyboardDismissed(app, phase: "Select")
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

    @MainActor
    func testRemoteFoodSearchFixturePersistsSelectedFood() throws {
        let app = XCUIApplication()
        let addMealButton = app.buttons["add-meal"]
        let chooseFoodButton = app.buttons["choose-food"]
        let searchField = app.searchFields.firstMatch
        let remoteResult = app.buttons["remote-food-result-1234567890123"]
        let selectedFoodName = app.staticTexts["selected-food-name"]
        let calculatedTotal = app.descendants(matching: .any)
            .matching(identifier: "calculated-total")
            .firstMatch
        let saveMealButton = app.buttons["save-meal"]
        let calorieTotal = app.staticTexts["daily-calorie-total"]
        let persistedFood = app.buttons["food-result-Remote Oat Drink"]

        XCTContext.runActivity(named: "Launch deterministic remote search") { _ in
            app.launchArguments = ["-ui-testing"]
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertExists(addMealButton, identifier: "add-meal", phase: "Launch")
        }

        XCTContext.runActivity(named: "Find fixture food") { _ in
            addMealButton.tap()
            assertExists(chooseFoodButton, identifier: "choose-food", phase: "Open")
            chooseFoodButton.tap()
            assertExists(searchField, identifier: "food search field", phase: "Search")
            searchField.tap()
            searchField.typeText("zzremote")
            XCTAssertEqual(
                searchField.value as? String,
                "zzremote",
                "Search: query did not become zzremote; \(diagnostic(for: searchField))"
            )
            assertExists(
                remoteResult,
                identifier: "remote-food-result-1234567890123",
                phase: "Fixture search"
            )
        }

        XCTContext.runActivity(named: "Select persisted remote food") { _ in
            remoteResult.tap()
            let selectedRemoteFood = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Remote Oat Drink"),
                object: selectedFoodName
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [selectedRemoteFood], timeout: uiTimeout),
                .completed,
                "Select: selected food did not become Remote Oat Drink; \(diagnostic(for: selectedFoodName))"
            )
            assertKeyboardDismissed(app, phase: "Select")
            assertExactValue(calculatedTotal, expected: "100 calories", phase: "Select")
        }

        XCTContext.runActivity(named: "Save remote meal") { _ in
            assertExists(saveMealButton, identifier: "save-meal", phase: "Save")
            saveMealButton.tap()
            assertDailyTotal(calorieTotal, eaten: 100, phase: "Save")
        }

        XCTContext.runActivity(named: "Verify persisted food catalog entry") { _ in
            addMealButton.tap()
            assertExists(chooseFoodButton, identifier: "choose-food", phase: "Persistence")
            chooseFoodButton.tap()
            assertExists(searchField, identifier: "food search field", phase: "Persistence")
            searchField.tap()
            searchField.typeText("Remote Oat Drink")
            assertExists(
                persistedFood,
                identifier: "food-result-Remote Oat Drink",
                phase: "Persistence"
            )
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

    private func assertButtonTarget(
        _ element: XCUIElement,
        identifier: String,
        phase: String
    ) {
        assertExists(element, identifier: identifier, phase: phase)
        let targetSized = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let button = object as? XCUIElement else { return false }
                return button.exists && button.frame.height >= 44
            },
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [targetSized], timeout: uiTimeout),
            .completed,
            "\(phase): \(identifier) target height < 44; \(diagnostic(for: element)), frame=\(element.frame)"
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

    private func assertKeyboardDismissed(_ app: XCUIApplication, phase: String) {
        let keyboard = app.keyboards.firstMatch
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: keyboard
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [dismissed], timeout: uiTimeout),
            .completed,
            "\(phase): search keyboard remained visible; \(diagnostic(for: keyboard))"
        )
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
