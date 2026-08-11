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
        var initialEatenCalories = 0
        XCTContext.runActivity(named: "Launch app") { _ in
            app.launchArguments = ["-ui-testing"]
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertExists(addMealButton, identifier: "add-meal", phase: "Launch")
            assertExists(calorieTotal, identifier: "daily-calorie-total", phase: "Launch")
            initialEatenCalories = dailyEatenCalories(calorieTotal, phase: "Launch")
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
            assertDailyTotal(calorieTotal, eaten: initialEatenCalories + 15, phase: "Total")
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
        let keyboardDone = app.buttons["meal-editor-keyboard-done"]
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
            assertLabel(selectedFoodName, expected: "Almond Milk", phase: "Open")
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

        XCTContext.runActivity(named: "Dismiss numeric keyboard without saving") { _ in
            amountField.tap()
            assertExists(app.keyboards.firstMatch, identifier: "numeric keyboard", phase: "Keyboard")
            assertHittable(
                keyboardDone,
                identifier: "meal-editor-keyboard-done",
                phase: "Keyboard"
            )
            keyboardDone.tap()
            assertKeyboardDismissed(app, phase: "Keyboard")
            assertExactValue(amountField, expected: "100 grams", phase: "Keyboard")
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
        let amountField = app.textFields["meal-amount"]
        let servingField = app.textFields["meal-quantity"]
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
            assertExactValue(amountField, expected: "100 grams", phase: "Total")
            assertExactValue(servingField, expected: "1", phase: "Total")
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

    @MainActor
    func testScannerPermissionDeniedRecoversToManualBarcodeEntry() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-scanner-permission-denied",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let moreLoggingOptions = app.buttons["More logging options"]
        let scanBarcode = app.buttons["Scan barcode"]
        let scannerNavigationTitle = app.navigationBars["Scan barcode"]
        let scannerState = app.descendants(matching: .any)
            .matching(identifier: "barcode-scanner-state")
            .firstMatch
        let cameraAccessTitle = app.staticTexts["Camera access is off"]
        let cameraAccessMessage = app.staticTexts[
            "Allow camera access in Settings, or enter the barcode manually."
        ]
        let openSettings = app.buttons.matching(
            NSPredicate(format: "label == %@", "Open Settings for camera access")
        ).firstMatch
        let enterManually = app.buttons.matching(
            NSPredicate(format: "label == %@", "Enter barcode manually")
        ).firstMatch
        let cancelScanner = app.buttons["barcode-scanner-cancel"]
        let foodToolsTitle = app.navigationBars["Food tools"]
        let manualBarcode = app.textFields["manual-barcode"]
        let done = app.buttons["Done"]

        XCTContext.runActivity(named: "Launch Today with camera access denied") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(
                moreLoggingOptions,
                identifier: "More logging options",
                phase: "Launch"
            )
        }

        XCTContext.runActivity(named: "Open denied scanner sheet") { _ in
            moreLoggingOptions.tap()
            assertHittable(scanBarcode, identifier: "Scan barcode", phase: "Scanner menu")
            scanBarcode.tap()
            assertExists(
                scannerNavigationTitle,
                identifier: "Scan barcode scanner sheet title",
                phase: "Scanner sheet"
            )
            assertExists(scannerState, identifier: "barcode-scanner-state", phase: "Scanner sheet")
        }

        XCTContext.runActivity(named: "Verify calm camera recovery actions") { _ in
            assertExists(cameraAccessTitle, identifier: "camera access title", phase: "Permission denied")
            assertLabel(
                cameraAccessTitle,
                expected: "Camera access is off",
                phase: "Permission denied"
            )
            assertExists(cameraAccessMessage, identifier: "camera access message", phase: "Permission denied")
            assertLabel(
                cameraAccessMessage,
                expected: "Allow camera access in Settings, or enter the barcode manually.",
                phase: "Permission denied"
            )

            for (identifier, control) in [
                ("barcode-scanner-open-settings", openSettings),
                ("barcode-scanner-enter-manually", enterManually)
            ] {
                assertHittable(control, identifier: identifier, phase: "Permission denied")
                assertButtonTarget(control, identifier: identifier, phase: "Permission denied")
            }
            // Native navigation-bar buttons report their visible glyph frame, not system hit slop.
            assertHittable(
                cancelScanner,
                identifier: "barcode-scanner-cancel",
                phase: "Permission denied"
            )
        }

        XCTContext.runActivity(named: "Recover through manual barcode entry") { _ in
            enterManually.tap()
            let scannerDismissed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: scannerNavigationTitle
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [scannerDismissed], timeout: uiTimeout),
                .completed,
                "Manual recovery: scanner did not dismiss; \(diagnostic(for: scannerNavigationTitle))"
            )
            assertExists(foodToolsTitle, identifier: "Food tools navigation title", phase: "Manual recovery")
            assertExists(manualBarcode, identifier: "manual-barcode", phase: "Manual recovery")
            assertExists(done, identifier: "Done", phase: "Manual recovery")
        }

        XCTContext.runActivity(named: "Keep manual Food tools usable") { _ in
            assertHittable(done, identifier: "Done", phase: "Manual recovery")
        }
    }

    @MainActor
    func testMealEditorScannerCancelPreservesDraft() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-scanner-permission-denied",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let addMealButton = app.buttons["add-meal"]
        let mealEditor = app.descendants(matching: .any)
            .matching(identifier: "meal-editor")
            .firstMatch
        let logFoodTitle = app.navigationBars["Log food"]
        let selectedFoodName = app.staticTexts["selected-food-name"]
        let amountField = app.textFields["meal-amount"]
        let decreaseAmount = app.buttons["amount-decrease-10"]
        let mealEditorScanBarcode = mealEditor.buttons["Scan barcode"]
        let scannerNavigationTitle = app.navigationBars["Scan barcode"]
        let scannerState = app.descendants(matching: .any)
            .matching(identifier: "barcode-scanner-state")
            .firstMatch
        let cancelScanner = app.buttons["barcode-scanner-cancel"]

        XCTContext.runActivity(named: "Launch and create distinct meal draft") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(addMealButton, identifier: "add-meal", phase: "Launch")
            addMealButton.tap()
            assertExists(mealEditor, identifier: "meal-editor", phase: "Meal draft")
            assertExists(logFoodTitle, identifier: "Log food navigation title", phase: "Meal draft")
            assertLabel(selectedFoodName, expected: "Almond Milk", phase: "Meal draft")
            assertExactValue(amountField, expected: "100 grams", phase: "Meal draft")
            assertHittable(decreaseAmount, identifier: "amount-decrease-10", phase: "Meal draft")
            decreaseAmount.tap()
            assertExactValue(amountField, expected: "90 grams", phase: "Meal draft")
        }

        XCTContext.runActivity(named: "Cancel denied scanner back to same meal draft") { _ in
            assertHittable(
                mealEditorScanBarcode,
                identifier: "MealEditor Scan barcode",
                phase: "Meal draft"
            )
            mealEditorScanBarcode.tap()
            assertExists(
                scannerNavigationTitle,
                identifier: "Scan barcode scanner sheet title",
                phase: "Meal scanner"
            )
            assertExists(scannerState, identifier: "barcode-scanner-state", phase: "Meal scanner")
            assertHittable(cancelScanner, identifier: "barcode-scanner-cancel", phase: "Meal scanner")
            cancelScanner.tap()

            assertAbsent(scannerNavigationTitle, identifier: "Scan barcode scanner sheet title", phase: "Return")
            assertExists(mealEditor, identifier: "meal-editor", phase: "Return")
            assertExists(logFoodTitle, identifier: "Log food navigation title", phase: "Return")
            assertLabel(selectedFoodName, expected: "Almond Milk", phase: "Return")
            assertExactValue(amountField, expected: "90 grams", phase: "Return")
        }
    }

    @MainActor
    func testFoodToolsBarcodeOfflineRecoveryThenSuccess() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-test-session", UUID().uuidString
        ]
        let moreLoggingOptions = app.buttons["More logging options"]
        let enterBarcodeOrCreateFood = app.buttons["Enter barcode or create food"]
        let foodToolsTitle = app.navigationBars["Food tools"]
        let manualBarcode = app.textFields["manual-barcode"]
        let lookup = app.buttons["barcode-lookup-button"]
        let failureTitle = app.staticTexts["barcode-lookup-failure-title"]
        let customFoodTitle = app.staticTexts["Custom food"]
        let customFoodName = app.textFields["custom-food-name"]
        let mealEditor = app.descendants(matching: .any)
            .matching(identifier: "meal-editor")
            .firstMatch
        let logFoodTitle = app.navigationBars["Log food"]
        let selectedFoodName = app.staticTexts["selected-food-name"]
        let amountField = app.textFields["meal-amount"]
        let calculatedTotal = app.descendants(matching: .any)
            .matching(identifier: "calculated-total")
            .firstMatch

        XCTContext.runActivity(named: "Launch Food tools from Today toolbar") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(moreLoggingOptions, identifier: "More logging options", phase: "Launch")
            moreLoggingOptions.tap()
            assertHittable(enterBarcodeOrCreateFood, identifier: "Enter barcode or create food", phase: "Toolbar menu")
            enterBarcodeOrCreateFood.tap()
            assertExists(foodToolsTitle, identifier: "Food tools navigation title", phase: "Food tools")
            assertExists(manualBarcode, identifier: "manual-barcode", phase: "Food tools")
        }

        XCTContext.runActivity(named: "Show inline product-not-found recovery") { _ in
            replaceText(
                in: manualBarcode,
                with: "00000000",
                app: app,
                identifier: "manual-barcode",
                phase: "Not-found barcode"
            )
            assertHittable(lookup, identifier: "barcode-lookup-button", phase: "Not found")
            lookup.tap()
            assertLabel(failureTitle, expected: "Product not found", phase: "Not found")
            assertExists(foodToolsTitle, identifier: "Food tools navigation title", phase: "Not found")
        }

        XCTContext.runActivity(named: "Keep custom-food recovery available while offline") { _ in
            replaceText(
                in: manualBarcode,
                with: "99999999",
                app: app,
                identifier: "manual-barcode",
                phase: "Offline barcode"
            )
            assertAbsent(failureTitle, identifier: "barcode-lookup-failure-title", phase: "Offline barcode")
            lookup.tap()
            assertLabel(failureTitle, expected: "You’re offline", phase: "Offline")
            assertExists(customFoodTitle, identifier: "Custom food section", phase: "Offline")
            assertExists(customFoodName, identifier: "custom-food-name", phase: "Offline")
            assertExactValue(manualBarcode, expected: "99999999", phase: "Offline")
            assertLabel(lookup, expected: "Try lookup again", phase: "Offline")
            assertHittable(lookup, identifier: "barcode-lookup-button", phase: "Offline")
            assertButtonTarget(lookup, identifier: "barcode-lookup-button", phase: "Offline")
            assertQueryCount(app.alerts, expected: 0, phase: "Offline")
        }

        XCTContext.runActivity(named: "Resolve fixture product into Log food") { _ in
            replaceText(
                in: manualBarcode,
                with: "12345678",
                app: app,
                identifier: "manual-barcode",
                phase: "Fixture barcode"
            )
            assertAbsent(failureTitle, identifier: "barcode-lookup-failure-title", phase: "Fixture barcode")
            lookup.tap()
            assertExists(mealEditor, identifier: "meal-editor", phase: "Fixture success")
            assertExists(logFoodTitle, identifier: "Log food navigation title", phase: "Fixture success")
            XCTAssertFalse(
                foodToolsTitle.exists,
                "Fixture success: Food tools remained after Log food appeared; \(diagnostic(for: foodToolsTitle))"
            )
            assertLabel(selectedFoodName, expected: "Fixture Granola", phase: "Fixture success")
            assertExactValue(amountField, expected: "45 grams", phase: "Fixture success")
            assertExactValue(calculatedTotal, expected: "189 calories", phase: "Fixture success")
        }
    }

    @MainActor
    func testCustomFoodNutrientEditorSavesDraftFood() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-test-session", UUID().uuidString
        ]
        let moreLoggingOptions = app.buttons["More logging options"]
        let enterBarcodeOrCreateFood = app.buttons["Enter barcode or create food"]
        let foodToolsTitle = app.navigationBars["Food tools"]
        let customFoodName = app.textFields["custom-food-name"]
        let nutrientLink = app.descendants(matching: .any)
            .matching(identifier: "custom-food-nutrients")
            .firstMatch
        let nutrientTitle = app.navigationBars["Nutrients"]
        let nutrientDone = app.buttons["nutrient-editor-done"]
        let carbohydrates = app.textFields["custom-food-carbohydrates"]
        let protein = app.textFields["custom-food-protein"]
        let fat = app.textFields["custom-food-fat"]
        let fiber = app.textFields["custom-food-fiber"]
        let saveCustomFood = app.buttons["Save custom food"]
        let keyboardDone = app.buttons["food-tools-keyboard-done"]
        let addMealButton = app.buttons["add-meal"]
        let selectedFoodName = app.staticTexts["selected-food-name"]

        XCTContext.runActivity(named: "Launch Food tools") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(moreLoggingOptions, identifier: "More logging options", phase: "Launch")
            moreLoggingOptions.tap()
            assertHittable(enterBarcodeOrCreateFood, identifier: "Enter barcode or create food", phase: "Toolbar menu")
            enterBarcodeOrCreateFood.tap()
            assertExists(foodToolsTitle, identifier: "Food tools navigation title", phase: "Food tools")
            assertHittable(nutrientLink, identifier: "custom-food-nutrients", phase: "Food tools")
        }

        XCTContext.runActivity(named: "Save complete custom-food nutrient facts") { _ in
            replaceText(
                in: customFoodName,
                with: "Fixture Bowl ",
                app: app,
                identifier: "custom-food-name",
                phase: "Custom food"
            )
            assertHittable(keyboardDone, identifier: "food-tools-keyboard-done", phase: "Custom food")
            keyboardDone.tap()
            nutrientLink.tap()
            assertExists(nutrientTitle, identifier: "Nutrients navigation title", phase: "Custom nutrients")

            for (field, value, identifier) in [
                (carbohydrates, "15", "custom-food-carbohydrates"),
                (protein, "10", "custom-food-protein"),
                (fat, "2", "custom-food-fat"),
                (fiber, "4", "custom-food-fiber")
            ] {
                replaceText(
                    in: field,
                    with: value,
                    app: app,
                    identifier: identifier,
                    phase: "Custom nutrients"
                )
            }
            assertHittable(nutrientDone, identifier: "nutrient-editor-done", phase: "Custom nutrients")
            nutrientDone.tap()
            assertExists(foodToolsTitle, identifier: "Food tools navigation title", phase: "Custom nutrients")
            assertHittable(saveCustomFood, identifier: "Save custom food", phase: "Custom nutrients")
            saveCustomFood.tap()
            assertAbsent(foodToolsTitle, identifier: "Food tools navigation title", phase: "Custom saved")
        }

        XCTContext.runActivity(named: "Open saved custom food in meal editor") { _ in
            assertHittable(addMealButton, identifier: "add-meal", phase: "Custom saved")
            addMealButton.tap()
            assertLabel(selectedFoodName, expected: "Fixture Bowl", phase: "Meal editor")
        }
    }

    @MainActor
    func testLoggedCustomNutrientsReachDailyBalance() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-design-review",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment = [
            "DESIGN_REVIEW_STATE": "customNutrition",
            "DESIGN_REVIEW_APPEARANCE": "light",
            "DESIGN_REVIEW_DYNAMIC_TYPE": "normal"
        ]
        let nutritionLink = app.descendants(matching: .any)
            .matching(identifier: "nutrition-balance-link")
            .firstMatch
        let nutritionDetail = app.descendants(matching: .any)
            .matching(identifier: "daily-nutrition-detail")
            .firstMatch
        let carbohydrateValues = app.staticTexts.matching(identifier: "nutrition-macro-carbs")
        let proteinValues = app.staticTexts.matching(identifier: "nutrition-macro-protein")
        let fatValues = app.staticTexts.matching(identifier: "nutrition-macro-fat")
        let fiberMeasured = app.staticTexts["nutrition-fiber-measured"]
        let fatGuidance = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "nutrition-guidance", "Fat below range")
        ).firstMatch

        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: uiTimeout),
            "Nutrition fixture launch: app did not reach foreground; state=\(app.state)."
        )
        assertHittable(nutritionLink, identifier: "nutrition-balance-link", phase: "Nutrition fixture")
        nutritionLink.tap()
        assertExists(nutritionDetail, identifier: "daily-nutrition-detail", phase: "Nutrition detail")
        assertLabel(carbohydrateValues.element(boundBy: 0), expected: "Carbs, 15 g", phase: "Nutrition detail")
        assertLabel(
            carbohydrateValues.element(boundBy: 1),
            expected: "Carbs, 50% of logged energy · adult range 45%–65%",
            phase: "Nutrition detail"
        )
        assertLabel(proteinValues.element(boundBy: 0), expected: "Protein, 10 g", phase: "Nutrition detail")
        assertLabel(fatValues.element(boundBy: 0), expected: "Fat, 2 g", phase: "Nutrition detail")
        assertLabel(fiberMeasured, expected: "Measured, 4 g", phase: "Nutrition detail")
        app.swipeUp()
        assertExists(fatGuidance, identifier: "Fat below range", phase: "Nutrition detail")
    }

    @MainActor
    func testOpenFoodFactsSlowSearchEndsWithNoMatches() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let addMealButton = app.buttons["add-meal"]
        let chooseFoodButton = app.buttons["choose-food"]
        let searchField = app.searchFields.firstMatch
        let loading = app.descendants(matching: .any)
            .matching(identifier: "open-food-facts-loading")
            .firstMatch
        let noMatches = app.descendants(matching: .any)
            .matching(identifier: "open-food-facts-no-matches")
            .firstMatch
        let genericSearch = app.buttons["search-open-food-facts"]
        let savedFoodsSection = app.staticTexts["Saved foods"]
        let noSavedFoodsMatch = app.staticTexts["No saved foods match."]

        XCTContext.runActivity(named: "Launch Today and open Choose food") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(addMealButton, identifier: "add-meal", phase: "Launch")
            addMealButton.tap()
            assertHittable(chooseFoodButton, identifier: "choose-food", phase: "Open")
            chooseFoodButton.tap()
            assertExists(searchField, identifier: "food search field", phase: "Choose food")
        }

        XCTContext.runActivity(named: "Verify slow search loading then no matches") { _ in
            searchField.tap()
            searchField.typeText("zzslow")
            assertExists(loading, identifier: "open-food-facts-loading", phase: "Slow loading")
            assertExists(genericSearch, identifier: "search-open-food-facts", phase: "Slow loading")
            XCTAssertFalse(
                genericSearch.isEnabled,
                "Slow loading: search-open-food-facts is enabled while loading; \(diagnostic(for: genericSearch))"
            )
            assertExists(noMatches, identifier: "open-food-facts-no-matches", phase: "Slow terminal")
            assertAbsent(loading, identifier: "open-food-facts-loading", phase: "Slow terminal")
            assertExists(savedFoodsSection, identifier: "Saved foods section", phase: "Slow terminal")
            assertExists(noSavedFoodsMatch, identifier: "No saved foods match", phase: "Slow terminal")
        }
    }

    @MainActor
    func testOpenFoodFactsOfflineStateKeepsSavedFoodRecovery() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let addMealButton = app.buttons["add-meal"]
        let chooseFoodButton = app.buttons["choose-food"]
        let searchField = app.searchFields.firstMatch
        let failure = app.descendants(matching: .any)
            .matching(identifier: "open-food-facts-failure")
            .firstMatch
        let genericSearch = app.buttons["search-open-food-facts"]
        let retry = app.buttons["retry-open-food-facts"]
        let savedFoodsSection = app.staticTexts["Saved foods"]
        let noSavedFoodsMatch = app.staticTexts["No saved foods match."]
        let attribution = app.links["Open Food Facts attribution"]
        let offlineTitle = app.descendants(matching: .any)
            .matching(identifier: "open-food-facts-failure-title")
            .firstMatch
        let offlineBody = app.descendants(matching: .any)
            .matching(identifier: "open-food-facts-failure-message")
            .firstMatch

        XCTContext.runActivity(named: "Launch Today and open Choose food") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(addMealButton, identifier: "add-meal", phase: "Launch")
            addMealButton.tap()
            assertHittable(chooseFoodButton, identifier: "choose-food", phase: "Open")
            chooseFoodButton.tap()
            assertExists(searchField, identifier: "food search field", phase: "Choose food")
        }

        XCTContext.runActivity(named: "Verify offline recovery without duplicate search") { _ in
            searchField.tap()
            searchField.typeText("zzoffline")
            assertExists(offlineTitle, identifier: "offline failure title", phase: "Offline")
            assertExists(failure, identifier: "open-food-facts-failure", phase: "Offline")
            assertLabel(offlineTitle, expected: "No connection", phase: "Offline")
            assertLabel(
                offlineBody,
                expected: "Saved foods still work offline. Reconnect, then try again.",
                phase: "Offline"
            )
            assertHittable(retry, identifier: "retry-open-food-facts", phase: "Offline")
            assertButtonTarget(retry, identifier: "retry-open-food-facts", phase: "Offline")
            assertAbsent(genericSearch, identifier: "search-open-food-facts", phase: "Offline")
            assertExists(savedFoodsSection, identifier: "Saved foods section", phase: "Offline")
            assertExists(noSavedFoodsMatch, identifier: "No saved foods match", phase: "Offline")
            assertHittable(attribution, identifier: "Open Food Facts attribution", phase: "Offline")
        }
    }

    @MainActor
    func testWeightEditorUsesLatestReadingAdjustmentsAndKeyboardDone() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-design-review",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment = [
            "DESIGN_REVIEW_STATE": "normal",
            "DESIGN_REVIEW_APPEARANCE": "light",
            "DESIGN_REVIEW_DYNAMIC_TYPE": "normal"
        ]

        let weightTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Weight")
        ).firstMatch
        let recordWeight = app.buttons["record-weight-button"]
        let editor = app.descendants(matching: .any)
            .matching(identifier: "weight-editor")
            .firstMatch
        let value = app.textFields["weight-value"]
        let cancel = app.buttons.matching(
            NSPredicate(format: "label == %@", "Cancel")
        ).firstMatch
        let keyboardDone = app.buttons["weight-keyboard-done"]
        let adjustments = [
            ("weight-decrease-1", app.buttons["weight-decrease-1"]),
            ("weight-decrease-0.1", app.buttons["weight-decrease-0.1"]),
            ("weight-increase-0.1", app.buttons["weight-increase-0.1"]),
            ("weight-increase-1", app.buttons["weight-increase-1"])
        ]

        XCTContext.runActivity(named: "Open one-step weight editor with latest reading") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Weight editor: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(weightTab, identifier: "Weight tab", phase: "Weight editor")
            weightTab.tap()
            assertHittable(recordWeight, identifier: "record-weight-button", phase: "Weight editor")
            recordWeight.tap()
            assertExists(editor, identifier: "weight-editor", phase: "Weight editor")
            assertExactValue(value, expected: "70.2", phase: "Latest weight default")
        }

        XCTContext.runActivity(named: "Adjust weight without keyboard") { _ in
            for (identifier, control) in adjustments {
                assertButtonTarget(control, identifier: identifier, phase: "Weight adjustments")
            }

            adjustments[0].1.tap()
            assertExactValue(value, expected: "69.2", phase: "Weight −1")
            adjustments[3].1.tap()
            assertExactValue(value, expected: "70.2", phase: "Weight +1")
            adjustments[1].1.tap()
            assertExactValue(value, expected: "70.1", phase: "Weight −0.1")
            adjustments[2].1.tap()
            assertExactValue(value, expected: "70.2", phase: "Weight +0.1")
            assertKeyboardDismissed(app, phase: "Weight adjustments")
        }

        XCTContext.runActivity(named: "Dismiss numeric keyboard without saving") { _ in
            value.tap()
            assertExists(app.keyboards.firstMatch, identifier: "numeric keyboard", phase: "Weight keyboard")
            assertHittable(keyboardDone, identifier: "weight-keyboard-done", phase: "Weight keyboard")
            keyboardDone.tap()
            assertKeyboardDismissed(app, phase: "Weight keyboard")
            assertExactValue(value, expected: "70.2", phase: "Weight keyboard")
            assertHittable(cancel, identifier: "Cancel", phase: "Weight keyboard")
            cancel.tap()
            assertAbsent(editor, identifier: "weight-editor", phase: "Weight keyboard")
        }
    }

    @MainActor
    func testTrackingWeightLogLifecycleAndAnalytics() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-test-session", UUID().uuidString
        ]

        let tabs = app.tabBars.buttons
        let todayTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Today")
        ).firstMatch
        let weightTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Weight")
        ).firstMatch
        let progressTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Progress")
        ).firstMatch
        let settingsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Settings")
        ).firstMatch
        let metricPicker = app.segmentedControls["progress-metric-picker"]
        let weightSegment = metricPicker.buttons["Weight"]
        let weightLog = app.descendants(matching: .any)
            .matching(identifier: "weight-log")
            .firstMatch
        let weightLogNavigationBar = app.navigationBars["Weight Log"]
        let recordWeightActions = app.buttons.matching(
            NSPredicate(format: "label == %@", "Record Weight")
        )
        let recordWeightToolbarButton = app.buttons["record-weight-button"]
        let weightEditor = app.descendants(matching: .any)
            .matching(identifier: "weight-editor")
            .firstMatch
        let recordWeightTitle = app.navigationBars["Record Weight"]
        let editWeightTitle = app.navigationBars["Edit Weight"]
        let weightValue = app.textFields["weight-value"]
        let weightIncreasePointOne = app.buttons["weight-increase-0.1"]
        let weightIncreaseOne = app.buttons["weight-increase-1"]
        let weightDate = app.descendants(matching: .any)
            .matching(identifier: "weight-date")
            .firstMatch
        let weightTime = app.descendants(matching: .any)
            .matching(identifier: "weight-time")
            .firstMatch
        let weightSave = app.buttons["weight-save"]
        let weightRows = app.descendants(matching: .any)
            .matching(identifier: "weight-log-row")
        let deleteActions = app.buttons.matching(
            NSPredicate(format: "label == %@", "Delete")
        )
        let confirmDelete = app.descendants(matching: .any)
            .matching(identifier: "confirm-delete-weight")
            .firstMatch
        let undo = app.buttons["weight-undo"]
        let weightLogChart = app.descendants(matching: .any)
            .matching(identifier: "weight-log-chart")
            .firstMatch
        let weightLogChartPrompt = app.descendants(matching: .any)
            .matching(identifier: "weight-log-chart-prompt")
            .firstMatch
        let weightViewProgress = app.buttons["weight-view-progress"]
        let currentWeight = app.staticTexts["progress-weight-current"]
        let trendChart = app.descendants(matching: .any)
            .matching(identifier: "progress-weight-chart")
            .firstMatch

        XCTContext.runActivity(named: "Launch and verify root tabs") { _ in
            trace("tracking: launch")
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Launch: app did not reach foreground; state=\(app.state), tabs=\(diagnostic(for: tabs))"
            )
            assertQueryCount(tabs, expected: 4, phase: "Launch")
            assertTabLabels(
                tabs,
                expected: ["Today", "Weight", "Progress", "Settings"],
                phase: "Launch"
            )
            assertExists(todayTab, identifier: "Today tab", phase: "Launch")
            assertExists(weightTab, identifier: "Weight tab", phase: "Launch")
            assertExists(progressTab, identifier: "Progress tab", phase: "Launch")
            assertExists(settingsTab, identifier: "Settings tab", phase: "Launch")
            XCTAssertFalse(
                app.tabBars.buttons["Counter"].exists,
                "Launch: obsolete Counter tab exists; tabs=\(diagnostic(for: tabs))"
            )
            XCTAssertFalse(
                app.tabBars.buttons["Config"].exists,
                "Launch: obsolete Config tab exists; tabs=\(diagnostic(for: tabs))"
            )
        }

        XCTContext.runActivity(named: "Open dedicated Weight Log empty state") { _ in
            trace("tracking: weight empty")
            assertHittable(weightTab, identifier: "Weight tab", phase: "Weight Log")
            weightTab.tap()
            assertExists(weightLog, identifier: "weight-log", phase: "Weight Log")
            assertExists(
                weightLogNavigationBar,
                identifier: "Weight Log navigation title",
                phase: "Weight Log"
            )
            assertQueryCount(weightRows, expected: 0, phase: "Weight Log empty")
            assertQueryAtLeastCount(
                recordWeightActions,
                expected: 1,
                phase: "Weight Log empty"
            )
            assertHittable(
                recordWeightActions.firstMatch,
                identifier: "Record Weight action",
                phase: "Weight Log empty"
            )
        }

        XCTContext.runActivity(named: "Create first default raw measurement") { _ in
            trace("tracking: first record")
            recordWeightActions.firstMatch.tap()
            assertExists(weightEditor, identifier: "weight-editor", phase: "Record editor")
            assertExists(
                recordWeightTitle,
                identifier: "Record Weight title",
                phase: "Record editor"
            )
            assertExists(weightValue, identifier: "weight-value", phase: "Record editor")
            assertNonEmptyValue(weightValue, identifier: "weight-value", phase: "Record editor")
            assertExists(weightDate, identifier: "weight-date", phase: "Record editor")
            assertExists(weightTime, identifier: "weight-time", phase: "Record editor")
            assertExists(weightSave, identifier: "weight-save", phase: "Record editor")
            XCTAssertTrue(
                weightSave.isEnabled,
                "Record editor: weight-save is disabled; \(diagnostic(for: weightSave))"
            )
            weightSave.tap()
            assertQueryCount(weightRows, expected: 1, phase: "First save")
            assertAbsent(weightEditor, identifier: "weight-editor", phase: "First save")
            assertExists(
                weightLogChartPrompt,
                identifier: "weight-log-chart-prompt",
                phase: "First save"
            )
            assertAbsent(weightLogChart, identifier: "weight-log-chart", phase: "First save")
            assertExists(weightViewProgress, identifier: "weight-view-progress", phase: "First save")
        }

        XCTContext.runActivity(named: "Create second same-day raw measurement") { _ in
            trace("tracking: second record")
            assertExists(
                recordWeightToolbarButton,
                identifier: "record-weight-button",
                phase: "Second record"
            )
            recordWeightToolbarButton.tap()
            assertExists(weightEditor, identifier: "weight-editor", phase: "Second record")
            assertExists(
                recordWeightTitle,
                identifier: "Record Weight title",
                phase: "Second record"
            )
            assertExists(weightValue, identifier: "weight-value", phase: "Second record")
            assertExists(weightDate, identifier: "weight-date", phase: "Second record")
            assertExists(weightTime, identifier: "weight-time", phase: "Second record")
            assertExists(weightSave, identifier: "weight-save", phase: "Second record")
            weightSave.tap()
            assertQueryCount(weightRows, expected: 2, phase: "Second save")
            XCTAssertEqual(
                rowAccessibilityValues(weightRows).count,
                2,
                "Second save: expected two distinct raw row values; \(diagnostic(for: weightRows))"
            )
            assertAbsent(
                weightLogChartPrompt,
                identifier: "weight-log-chart-prompt",
                phase: "Second save"
            )
            assertExists(weightLogChart, identifier: "weight-log-chart", phase: "Second save")
        }

        XCTContext.runActivity(named: "Edit one row and preserve peer value") { _ in
            trace("tracking: edit")
            let valuesBeforeEdit = rowAccessibilityValues(weightRows)
            assertQueryCount(weightRows, expected: 2, phase: "Edit before")
            trace("tracking: edit rows ready")
            let rowToEdit = weightRows.firstMatch
            let originalEditedValue = accessibilityValue(of: rowToEdit)
            assertExists(rowToEdit, identifier: "weight-log-row to edit", phase: "Edit before")
            rowToEdit.tap()
            trace("tracking: edit row tapped")
            assertExists(weightEditor, identifier: "weight-editor", phase: "Edit editor")
            assertExists(editWeightTitle, identifier: "Edit Weight title", phase: "Edit editor")
            trace("tracking: edit sheet ready")
            assertButtonTarget(
                weightIncreasePointOne,
                identifier: "weight-increase-0.1",
                phase: "Edit editor"
            )
            assertButtonTarget(
                weightIncreaseOne,
                identifier: "weight-increase-1",
                phase: "Edit editor"
            )
            weightIncreaseOne.tap()
            weightIncreaseOne.tap()
            weightIncreasePointOne.tap()
            weightIncreasePointOne.tap()
            weightIncreasePointOne.tap()
            assertExactValue(weightValue, expected: "72.3", phase: "Edit editor")
            trace("tracking: edit value adjusted")

            assertExists(weightSave, identifier: "weight-save", phase: "Edit editor")
            weightSave.tap()
            trace("tracking: edit save tapped")
            assertQueryCount(weightRows, expected: 2, phase: "Edit save")
            assertAbsent(weightEditor, identifier: "weight-editor", phase: "Edit save")

            let valuesAfterEdit = rowAccessibilityValues(weightRows)
            assertOnlyOneAccessibilityValueChanged(
                before: valuesBeforeEdit,
                after: valuesAfterEdit,
                rows: weightRows,
                phase: "Edit save"
            )
            XCTAssertEqual(
                valuesAfterEdit.filter { $0.contains("72.3 kg") }.count,
                1,
                "Edit save: edited row value missing or duplicated; rows=\(diagnostic(for: weightRows))"
            )
            let originalEditedValueOccurrencesBefore = valuesBeforeEdit.filter {
                $0 == originalEditedValue
            }.count
            let originalEditedValueOccurrencesAfter = valuesAfterEdit.filter {
                $0 == originalEditedValue
            }.count
            XCTAssertEqual(
                originalEditedValueOccurrencesAfter,
                originalEditedValueOccurrencesBefore - 1,
                "Edit save: edited row accessibility value occurrence count did not decrease by one; before=\(valuesBeforeEdit), after=\(valuesAfterEdit), rows=\(diagnostic(for: weightRows))"
            )
        }

        XCTContext.runActivity(named: "Confirm selected delete and restore with Undo") { _ in
            trace("tracking: delete undo")
            assertQueryCount(weightRows, expected: 2, phase: "Delete confirm before swipe")
            let rowToDelete = weightRows.firstMatch
            let deletedValue = accessibilityValue(of: rowToDelete)
            assertExists(rowToDelete, identifier: "selected weight-log-row", phase: "Delete confirm before swipe")
            rowToDelete.swipeLeft()
            trace("tracking: delete undo row swiped")
            assertQueryAtLeastCount(deleteActions, expected: 1, phase: "Delete confirm swipe")
            deleteActions.firstMatch.tap()
            trace("tracking: delete undo action tapped")
            assertExists(confirmDelete, identifier: "confirm-delete-weight", phase: "Delete confirm")
            assertQueryCount(weightRows, expected: 2, phase: "Delete confirm")
            confirmDelete.tap()
            trace("tracking: delete undo confirmation tapped")
            assertQueryCount(weightRows, expected: 1, phase: "Delete committed")
            let valuesAfterDelete = rowAccessibilityValues(weightRows)
            XCTAssertFalse(
                valuesAfterDelete.contains(deletedValue),
                "Delete committed: selected row still exists; rows=\(diagnostic(for: weightRows))"
            )
            assertHittable(undo, identifier: "weight-undo", phase: "Delete committed")
            trace("tracking: undo hittable")
            undo.tap()
            trace("tracking: undo tapped")
            assertQueryCount(weightRows, expected: 2, phase: "Undo")
            XCTAssertTrue(
                rowAccessibilityValues(weightRows).contains(deletedValue),
                "Undo: deleted row value was not restored; rows=\(diagnostic(for: weightRows))"
            )
            assertAbsent(undo, identifier: "weight-undo", phase: "Undo")
            trace("tracking: undo complete")
        }

        XCTContext.runActivity(named: "View full trends in Progress") { _ in
            trace("tracking: final trends")
            assertExists(weightViewProgress, identifier: "weight-view-progress", phase: "Analytics navigation")
            for _ in 0..<5 {
                if weightViewProgress.isHittable { break }
                app.swipeDown()
            }
            assertHittable(
                weightViewProgress,
                identifier: "weight-view-progress",
                phase: "Analytics navigation"
            )
            weightViewProgress.tap()

            let progressSelected = XCTNSPredicateExpectation(
                predicate: NSPredicate { object, _ in
                    guard let tab = object as? XCUIElement else { return false }
                    return tab.exists && tab.isSelected
                },
                object: progressTab
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [progressSelected], timeout: uiTimeout),
                .completed,
                "Analytics: Progress tab was not selected; tabs=\(diagnostic(for: tabs))"
            )
            assertExists(metricPicker, identifier: "progress-metric-picker", phase: "Analytics")
            assertExists(weightSegment, identifier: "Weight metric", phase: "Analytics")
            let weightSelected = XCTNSPredicateExpectation(
                predicate: NSPredicate { object, _ in
                    guard let segment = object as? XCUIElement else { return false }
                    return segment.exists && segment.isSelected
                },
                object: weightSegment
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [weightSelected], timeout: uiTimeout),
                .completed,
                "Analytics: View full trends did not open Weight metric; \(diagnostic(for: weightSegment))"
            )
            assertExists(currentWeight, identifier: "progress-weight-current", phase: "Analytics")
            assertExists(trendChart, identifier: "progress-weight-chart", phase: "Analytics")
            XCTAssertTrue(
                currentWeight.label.contains("Current 72.3 kg"),
                "Analytics: current weight did not use latest edited raw value; \(diagnostic(for: currentWeight))"
            )
        }
    }

    private let uiTimeout: TimeInterval = 5

    private func assertQueryCount(
        _ query: XCUIElementQuery,
        expected: Int,
        phase: String
    ) {
        if query.count == expected { return }
        let countExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == %d", expected),
            object: query
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [countExpectation], timeout: uiTimeout),
            .completed,
            "\(phase): expected exactly \(expected) elements; \(diagnostic(for: query))"
        )
    }

    private func assertQueryAtLeastCount(
        _ query: XCUIElementQuery,
        expected: Int,
        phase: String
    ) {
        if query.count >= expected { return }
        let countExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count >= %d", expected),
            object: query
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [countExpectation], timeout: uiTimeout),
            .completed,
            "\(phase): expected at least \(expected) elements; \(diagnostic(for: query))"
        )
    }

    private func assertTabLabels(
        _ tabs: XCUIElementQuery,
        expected: [String],
        phase: String
    ) {
        assertQueryCount(tabs, expected: expected.count, phase: phase)
        let actual = tabs.allElementsBoundByIndex.map { $0.label }
        XCTAssertEqual(
            Set(actual),
            Set(expected),
            "\(phase): tab label set mismatch; labels=\(actual), tabs=\(diagnostic(for: tabs))"
        )
        XCTAssertEqual(
            actual,
            expected,
            "\(phase): tab label order mismatch; labels=\(actual), tabs=\(diagnostic(for: tabs))"
        )
    }

    private func assertHittable(
        _ element: XCUIElement,
        identifier: String,
        phase: String
    ) {
        if element.exists && element.isHittable { return }
        assertExists(element, identifier: identifier, phase: phase)
        let hittableExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let element = object as? XCUIElement else { return false }
                return element.exists && element.isHittable
            },
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [hittableExpectation], timeout: uiTimeout),
            .completed,
            "\(phase): \(identifier) is not hittable; \(diagnostic(for: element))"
        )
    }

    private func assertNonEmptyValue(
        _ element: XCUIElement,
        identifier: String,
        phase: String
    ) {
        assertExists(element, identifier: identifier, phase: phase)
        let value = accessibilityValue(of: element)
        XCTAssertFalse(
            value == "<nil>" || value.isEmpty,
            "\(phase): \(identifier) has no accessibility value; \(diagnostic(for: element))"
        )
    }

    private func assertAbsent(
        _ element: XCUIElement,
        identifier: String,
        phase: String
    ) {
        if !element.exists { return }
        XCTAssertTrue(
            element.waitForNonExistence(timeout: uiTimeout),
            "\(phase): expected \(identifier) to be absent; \(diagnostic(for: element))"
        )
    }

    private func replaceText(
        in field: XCUIElement,
        with replacement: String,
        app: XCUIApplication,
        identifier: String,
        phase: String
    ) {
        assertExists(field, identifier: identifier, phase: phase)
        field.tap()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(replacement)

        if accessibilityValue(of: field) != replacement {
            field.press(forDuration: 1)
            let selectAll = app.menuItems.matching(
                NSPredicate(format: "label == %@", "Select All")
            ).firstMatch
            if selectAll.waitForExistence(timeout: 1) {
                selectAll.tap()
            } else {
                field.tap()
                field.typeKey("a", modifierFlags: .command)
            }

            for index in replacement.indices {
                let prefix = String(replacement[replacement.startIndex...index])
                field.typeText(String(replacement[index]))
                let prefixEntered = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value == %@", prefix),
                    object: field
                )
                XCTAssertEqual(
                    XCTWaiter.wait(for: [prefixEntered], timeout: uiTimeout),
                    .completed,
                    "\(phase): replacement prefix '\(prefix)' did not become accessible; \(diagnostic(for: field))"
                )
            }
        }

        XCTAssertEqual(
            accessibilityValue(of: field),
            replacement,
            "\(phase): robust text replacement failed; \(diagnostic(for: field))"
        )
    }

    private func rowAccessibilityValues(_ rows: XCUIElementQuery) -> [String] {
        rows.allElementsBoundByIndex.map { accessibilityValue(of: $0) }
    }

    private func accessibilityValue(of element: XCUIElement) -> String {
        element.value.map { String(describing: $0) } ?? "<nil>"
    }

    private func assertOnlyOneAccessibilityValueChanged(
        before: [String],
        after: [String],
        rows: XCUIElementQuery,
        phase: String
    ) {
        var unmatchedAfter = after
        var unchangedCount = 0
        for value in before {
            if let index = unmatchedAfter.firstIndex(of: value) {
                unmatchedAfter.remove(at: index)
                unchangedCount += 1
            }
        }
        XCTAssertEqual(
            unchangedCount,
            before.count - 1,
            "\(phase): expected exactly one row accessibility value change; before=\(before), after=\(after), rows=\(diagnostic(for: rows))"
        )
        XCTAssertEqual(
            unmatchedAfter.count,
            1,
            "\(phase): expected one replacement row value; before=\(before), after=\(after), rows=\(diagnostic(for: rows))"
        )
    }

    private func diagnostic(for query: XCUIElementQuery) -> String {
        let elements = query.allElementsBoundByIndex
        let states = elements.enumerated().map { index, element in
            "\(index):\(diagnostic(for: element))"
        }.joined(separator: "; ")
        return "count=\(query.count), elements=[\(states)]"
    }

    private func assertExists(
        _ element: XCUIElement,
        identifier: String,
        phase: String
    ) {
        if element.exists { return }
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

    private func assertWeightLabel(_ element: XCUIElement, phase: String) {
        assertExists(element, identifier: "progress-weight-current", phase: phase)
        XCTAssertTrue(
            element.label.hasPrefix("Current 70") && element.label.hasSuffix("kg"),
            "\(phase): expected current 70 kg; \(diagnostic(for: element))"
        )
    }

    private func assertLabel(
        _ element: XCUIElement,
        expected: String,
        phase: String
    ) {
        let expectedLabel = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectedLabel], timeout: uiTimeout),
            .completed,
            "\(phase): expected label '\(expected)'; \(diagnostic(for: element))"
        )
    }

    private func assertPlanGoal(
        _ element: XCUIElement,
        calories: Int,
        phase: String
    ) {
        let expectedGoal = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let element = object as? XCUIElement else { return false }
                return element.exists
                    && element.label.hasPrefix("Daily goal, ")
                    && element.label.hasSuffix(" kcal")
                    && Int(element.label.filter(\.isNumber)) == calories
            },
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectedGoal], timeout: uiTimeout),
            .completed,
            "\(phase): expected localized daily goal \(calories) kcal; \(diagnostic(for: element))"
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

    private func dailyEatenCalories(_ element: XCUIElement, phase: String) -> Int {
        let value = element.value.map { String(describing: $0) } ?? ""
        let leadingValue = value.split(separator: " ").first ?? ""
        let digits = leadingValue.filter(\.isNumber)
        guard let calories = Int(digits) else {
            XCTFail("\(phase): could not parse eaten calories; \(diagnostic(for: element))")
            return 0
        }
        return calories
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

    private func trace(_ message: String) {
        let url = URL(fileURLWithPath: "/tmp/count-calories-ui-trace")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + "\(Date()) \(message)\n").write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
    }

    @MainActor
    func testCalculatedSetupCanBeSkippedWithoutChangingManualGoal() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-calculated-setup",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let setup = app.descendants(matching: .any)
            .matching(identifier: "calculated-plan-setup")
            .firstMatch
        let keepManual = app.buttons["keep-manual-goal"]
        let settingsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Settings")
        ).firstMatch
        let planLink = app.descendants(matching: .any)
            .matching(identifier: "settings-plan-link")
            .firstMatch
        let planSource = app.descendants(matching: .any)
            .matching(identifier: "plan-goal-source")
            .firstMatch
        let planGoal = app.descendants(matching: .any)
            .matching(identifier: "plan-current-calorie-goal")
            .firstMatch

        XCTContext.runActivity(named: "Launch optional welcome") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Calculated skip launch: app did not reach foreground; state=\(app.state)."
            )
            assertExists(app.navigationBars["Welcome"], identifier: "Welcome", phase: "Calculated skip")
            assertExists(setup, identifier: "calculated-plan-setup", phase: "Calculated skip")
            assertHittable(keepManual, identifier: "keep-manual-goal", phase: "Calculated skip")
        }

        XCTContext.runActivity(named: "Keep existing manual goal") { _ in
            keepManual.tap()
            assertAbsent(setup, identifier: "calculated-plan-setup", phase: "Calculated skip")
            assertHittable(settingsTab, identifier: "Settings tab", phase: "Calculated skip")
            settingsTab.tap()
            assertHittable(planLink, identifier: "settings-plan-link", phase: "Calculated skip")
            planLink.tap()
            assertLabel(planSource, expected: "Source, Manual", phase: "Calculated skip")
            assertPlanGoal(planGoal, calories: 1_700, phase: "Calculated skip")
        }
    }

    @MainActor
    func testCalculatedSetupCollectsRequiredInputsThroughPace() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-calculated-setup",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let setup = app.descendants(matching: .any)
            .matching(identifier: "calculated-plan-setup")
            .firstMatch
        let eligibility = app.switches["calculated-setup-eligibility"]
        let continueButton = app.buttons["calculated-setup-continue"]
        let loseGoal = app.buttons["calculated-goal-lose"]
        let heightField = app.textFields["calculated-height-centimeters"]
        let keyboardDone = app.buttons["calculated-setup-keyboard-done"]
        let femaleEquation = app.buttons["calculated-equation-female"]
        let moderateActivity = app.buttons["calculated-activity-moderate"]
        let gentleRate = app.buttons["calculated-rate-gentle"]

        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: uiTimeout),
            "Calculated launch: app did not reach foreground; state=\(app.state)."
        )
        assertExists(app.navigationBars["Welcome"], identifier: "Welcome", phase: "Calculated welcome")
        assertExists(setup, identifier: "calculated-plan-setup", phase: "Calculated welcome")
        eligibility.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        ).tap()
        assertExactValue(eligibility, expected: "1", phase: "Calculated welcome")
        continueButton.tap()
        assertHittable(loseGoal, identifier: "calculated-goal-lose", phase: "Calculated goal")
        loseGoal.tap()
        continueButton.tap()

        assertExists(app.navigationBars["Body Details"], identifier: "Body Details", phase: "Calculated body")
        app.swipeUp()
        if !heightField.isHittable {
            app.swipeUp()
        }
        replaceText(
            in: heightField,
            with: "170",
            app: app,
            identifier: "calculated-height-centimeters",
            phase: "Calculated body"
        )
        assertHittable(keyboardDone, identifier: "calculated-setup-keyboard-done", phase: "Calculated body")
        keyboardDone.tap()
        assertKeyboardDismissed(app, phase: "Calculated body")
        assertHittable(continueButton, identifier: "calculated-setup-continue", phase: "Calculated body")
        continueButton.tap()

        assertHittable(femaleEquation, identifier: "calculated-equation-female", phase: "Calculated equation")
        femaleEquation.tap()
        continueButton.tap()
        assertHittable(moderateActivity, identifier: "calculated-activity-moderate", phase: "Calculated activity")
        moderateActivity.tap()
        continueButton.tap()
        assertExists(app.navigationBars["Pace"], identifier: "Pace", phase: "Calculated pace")
        assertHittable(gentleRate, identifier: "calculated-rate-gentle", phase: "Calculated pace")
    }

    @MainActor
    func testCalculatedPaceContinuesToExplainedReview() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-calculated-pace",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let reviewGoal = app.descendants(matching: .any)
            .matching(identifier: "calculated-review-goal")
            .firstMatch

        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: uiTimeout),
            "Calculated pace launch: app did not reach foreground; state=\(app.state)."
        )
        assertExists(app.navigationBars["Pace"], identifier: "Pace", phase: "Calculated pace")
        app.buttons["calculated-setup-continue"].tap()
        assertExists(reviewGoal, identifier: "calculated-review-goal", phase: "Calculated review")
        XCTAssertTrue(
            reviewGoal.label.contains("1,730 kcal")
                || reviewGoal.label.contains("1.730 kcal"),
            "Calculated review: expected localized 1,730 kcal; \(diagnostic(for: reviewGoal))"
        )
    }

    @MainActor
    func testCalculatedReviewAppliesAndPersistsGoal() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-calculated-review",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let setup = app.descendants(matching: .any)
            .matching(identifier: "calculated-plan-setup")
            .firstMatch
        let reviewGoal = app.descendants(matching: .any)
            .matching(identifier: "calculated-review-goal")
            .firstMatch
        let settingsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Settings")
        ).firstMatch
        let planLink = app.descendants(matching: .any)
            .matching(identifier: "settings-plan-link")
            .firstMatch
        let planSource = app.descendants(matching: .any)
            .matching(identifier: "plan-goal-source")
            .firstMatch
        let planGoal = app.descendants(matching: .any)
            .matching(identifier: "plan-current-calorie-goal")
            .firstMatch

        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: uiTimeout),
            "Calculated review launch: app did not reach foreground; state=\(app.state)."
        )
        assertExists(reviewGoal, identifier: "calculated-review-goal", phase: "Calculated review")
        app.buttons["use-calculated-goal"].tap()
        assertAbsent(setup, identifier: "calculated-plan-setup", phase: "Calculated apply")
        settingsTab.tap()
        assertHittable(planLink, identifier: "settings-plan-link", phase: "Calculated result")
        planLink.tap()
        assertLabel(planSource, expected: "Source, Calculated", phase: "Calculated result")
        assertPlanGoal(planGoal, calories: 1_730, phase: "Calculated result")
        assertExists(
            app.staticTexts["Calculated basis"],
            identifier: "Calculated basis",
            phase: "Calculated result"
        )
    }

    @MainActor
    func testSettingsCalculatedSetupOpensContinuesAndResumes() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let settingsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Settings")
        ).firstMatch
        let planLink = app.descendants(matching: .any)
            .matching(identifier: "settings-plan-link")
            .firstMatch
        let startSetup = app.buttons["start-calculated-setup"]
        let eligibility = app.switches["calculated-setup-eligibility"]
        let continueButton = app.buttons["calculated-setup-continue"]
        let closeSetup = app.buttons["calculated-setup-close"]
        let planSource = app.descendants(matching: .any)
            .matching(identifier: "plan-goal-source")
            .firstMatch
        let planGoal = app.descendants(matching: .any)
            .matching(identifier: "plan-current-calorie-goal")
            .firstMatch

        XCTContext.runActivity(named: "Open calculated setup from Plan") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Settings setup launch: app did not reach foreground; state=\(app.state)."
            )
            assertHittable(settingsTab, identifier: "Settings tab", phase: "Settings setup")
            settingsTab.tap()
            assertHittable(planLink, identifier: "settings-plan-link", phase: "Settings setup")
            planLink.tap()
            assertHittable(startSetup, identifier: "start-calculated-setup", phase: "Settings setup")
            startSetup.tap()
            assertExists(app.navigationBars["Welcome"], identifier: "Welcome", phase: "Settings setup")
        }

        XCTContext.runActivity(named: "Continue then close without changing manual goal") { _ in
            assertHittable(eligibility, identifier: "calculated-setup-eligibility", phase: "Settings setup")
            eligibility.coordinate(
                withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
            ).tap()
            assertExactValue(eligibility, expected: "1", phase: "Settings setup")
            continueButton.tap()
            assertExists(app.navigationBars["Goal"], identifier: "Goal", phase: "Settings setup")
            closeSetup.tap()
            assertExists(app.navigationBars["Plan"], identifier: "Plan", phase: "Settings setup")
            assertLabel(planSource, expected: "Source, Manual", phase: "Settings setup")
            assertPlanGoal(planGoal, calories: 1_700, phase: "Settings setup")
        }

        XCTContext.runActivity(named: "Resume persisted Goal step from Plan") { _ in
            assertHittable(startSetup, identifier: "start-calculated-setup", phase: "Settings resume")
            startSetup.tap()
            assertExists(app.navigationBars["Goal"], identifier: "Goal", phase: "Settings resume")
            assertHittable(closeSetup, identifier: "calculated-setup-close", phase: "Settings resume")
            closeSetup.tap()
            assertLabel(planSource, expected: "Source, Manual", phase: "Settings resume")
            assertPlanGoal(planGoal, calories: 1_700, phase: "Settings resume")
        }
    }

    @MainActor
    func testMealReminderSummaryOpensEditorWithoutSaving() throws {
        let app = launchReminderSettings()
        let reminderEditor = app.descendants(matching: .any)
            .matching(identifier: "reminder-editor")
            .firstMatch
        let breakfastSummary = app.descendants(matching: .any)
            .matching(identifier: "breakfast-reminder-summary")
            .firstMatch

        assertHittable(breakfastSummary, identifier: "breakfast-reminder-summary", phase: "Meal summary")
        assertExactValue(breakfastSummary, expected: "Off", phase: "Meal summary")
        breakfastSummary.tap()
        assertExists(reminderEditor, identifier: "reminder-editor", phase: "Meal summary")
        assertHittable(
            app.switches["breakfast-reminder-toggle"],
            identifier: "breakfast-reminder-toggle",
            phase: "Meal summary"
        )
        app.buttons["reminders-cancel"].tap()
        assertExactValue(breakfastSummary, expected: "Off", phase: "Meal summary cancel")
    }

    @MainActor
    func testWeightAndWaterReminderSummariesOpenEditorWithoutSaving() throws {
        let app = launchReminderSettings()
        let reminderEditor = app.descendants(matching: .any)
            .matching(identifier: "reminder-editor")
            .firstMatch
        let weightSummary = app.descendants(matching: .any)
            .matching(identifier: "weight-reminder-summary")
            .firstMatch
        let waterSummary = app.descendants(matching: .any)
            .matching(identifier: "water-reminder-summary")
            .firstMatch

        for _ in 0..<3 where !weightSummary.isHittable {
            app.swipeUp()
        }
        assertHittable(weightSummary, identifier: "weight-reminder-summary", phase: "Weight summary")
        weightSummary.tap()
        assertExists(reminderEditor, identifier: "reminder-editor", phase: "Weight summary")
        assertHittable(
            app.switches["weight-reminder-toggle"],
            identifier: "weight-reminder-toggle",
            phase: "Weight summary"
        )
        app.buttons["reminders-cancel"].tap()
        assertExactValue(weightSummary, expected: "Off", phase: "Weight summary cancel")

        for _ in 0..<3 where !waterSummary.isHittable {
            app.swipeUp()
        }
        assertHittable(waterSummary, identifier: "water-reminder-summary", phase: "Water summary")
        waterSummary.tap()
        assertExists(reminderEditor, identifier: "reminder-editor", phase: "Water summary")
        assertHittable(
            app.switches["water-reminder-toggle"],
            identifier: "water-reminder-toggle",
            phase: "Water summary"
        )
        app.buttons["reminders-cancel"].tap()
        assertExactValue(waterSummary, expected: "Off", phase: "Water summary cancel")
    }

    @MainActor
    private func launchReminderSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: uiTimeout),
            "Reminder summary launch: app did not reach foreground; state=\(app.state)."
        )
        let settingsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Settings")
        ).firstMatch
        let remindersLink = app.descendants(matching: .any)
            .matching(identifier: "settings-reminders-link")
            .firstMatch
        assertHittable(settingsTab, identifier: "Settings tab", phase: "Reminder summary")
        settingsTab.tap()
        assertHittable(remindersLink, identifier: "settings-reminders-link", phase: "Reminder summary")
        remindersLink.tap()
        return app
    }

    @MainActor
    func testRootTabsAndSettingsRemainAvailable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        let tabs = app.tabBars.buttons
        let settingsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@", "Settings")
        ).firstMatch
        let planLink = app.descendants(matching: .any)
            .matching(identifier: "settings-plan-link")
            .firstMatch
        let profileLink = app.descendants(matching: .any)
            .matching(identifier: "settings-profile-link")
            .firstMatch
        let remindersLink = app.descendants(matching: .any)
            .matching(identifier: "settings-reminders-link")
            .firstMatch
        let planView = app.descendants(matching: .any)
            .matching(identifier: "plan-settings")
            .firstMatch
        let planGoal = app.descendants(matching: .any)
            .matching(identifier: "plan-current-calorie-goal")
            .firstMatch
        let planCarbs = app.descendants(matching: .any)
            .matching(identifier: "plan-reference-carbs")
            .firstMatch
        let planProtein = app.descendants(matching: .any)
            .matching(identifier: "plan-reference-protein")
            .firstMatch
        let planFat = app.descendants(matching: .any)
            .matching(identifier: "plan-reference-fat")
            .firstMatch
        let planFiber = app.descendants(matching: .any)
            .matching(identifier: "plan-reference-fiber")
            .firstMatch
        let planEdit = app.buttons["plan-edit"]
        let planEditor = app.descendants(matching: .any)
            .matching(identifier: "plan-editor")
            .firstMatch
        let planSave = app.buttons["plan-save"]
        let planCancel = app.buttons["plan-cancel"]
        let planTargetWeight = app.textFields["plan-target-weight"]
        let planKeyboardDone = app.buttons["plan-keyboard-done"]
        let reminderView = app.descendants(matching: .any)
            .matching(identifier: "reminder-settings")
            .firstMatch
        let remindersEdit = app.buttons["reminders-edit"]
        let reminderEditor = app.descendants(matching: .any)
            .matching(identifier: "reminder-editor")
            .firstMatch
        let breakfastToggle = app.switches["breakfast-reminder-toggle"]
        let weightToggle = app.switches["weight-reminder-toggle"]
        let waterToggle = app.switches["water-reminder-toggle"]
        let remindersCancel = app.buttons["reminders-cancel"]

        XCTContext.runActivity(named: "Launch and verify Settings root hierarchy") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Settings launch: app did not reach foreground; state=\(app.state), tabs=\(diagnostic(for: tabs))"
            )
            assertTabLabels(
                tabs,
                expected: ["Today", "Weight", "Progress", "Settings"],
                phase: "Settings launch"
            )
            assertExists(settingsTab, identifier: "Settings tab", phase: "Settings launch")
            XCTAssertFalse(
                app.tabBars.buttons["Config"].exists,
                "Settings launch: obsolete Config tab exists; tabs=\(diagnostic(for: tabs))"
            )
            settingsTab.tap()
            assertExists(
                app.navigationBars["Settings"],
                identifier: "Settings navigation title",
                phase: "Settings root"
            )
            assertHittable(planLink, identifier: "settings-plan-link", phase: "Settings root")
            assertExists(profileLink, identifier: "settings-profile-link", phase: "Settings root")
            assertExists(remindersLink, identifier: "settings-reminders-link", phase: "Settings root")
            assertQueryCount(
                app.buttons.matching(NSPredicate(format: "label == %@", "Save settings")),
                expected: 0,
                phase: "Settings save-model boundary"
            )
        }

        XCTContext.runActivity(named: "Verify manual Plan references and transaction") { _ in
            planLink.tap()
            assertExists(planView, identifier: "plan-settings", phase: "Plan")
            assertPlanGoal(planGoal, calories: 1_700, phase: "Plan")
            for (control, identifier) in [
                (planCarbs, "plan-reference-carbs"),
                (planProtein, "plan-reference-protein"),
                (planFat, "plan-reference-fat"),
                (planFiber, "plan-reference-fiber")
            ] {
                assertExists(control, identifier: identifier, phase: "Plan references")
            }
            assertHittable(planEdit, identifier: "plan-edit", phase: "Plan")
            planEdit.tap()
            assertExists(planEditor, identifier: "plan-editor", phase: "Plan editor")
            assertHittable(planSave, identifier: "plan-save", phase: "Plan editor")
            assertHittable(planCancel, identifier: "plan-cancel", phase: "Plan editor")
            assertHittable(planTargetWeight, identifier: "plan-target-weight", phase: "Plan editor")
            planTargetWeight.tap()
            assertHittable(planKeyboardDone, identifier: "plan-keyboard-done", phase: "Plan keyboard")
            planKeyboardDone.tap()
            assertKeyboardDismissed(app, phase: "Plan keyboard")
            planCancel.tap()
            assertAbsent(planEditor, identifier: "plan-editor", phase: "Plan cancel")
            app.navigationBars["Plan"].buttons.firstMatch.tap()
            assertExists(planLink, identifier: "settings-plan-link", phase: "Settings return")
        }

        XCTContext.runActivity(named: "Verify configurable reminder draft cancels cleanly") { _ in
            remindersLink.tap()
            assertExists(reminderView, identifier: "reminder-settings", phase: "Reminders")
            assertHittable(remindersEdit, identifier: "reminders-edit", phase: "Reminders")
            remindersEdit.tap()
            assertExists(reminderEditor, identifier: "reminder-editor", phase: "Reminder editor")
            assertHittable(breakfastToggle, identifier: "breakfast-reminder-toggle", phase: "Reminder editor")
            breakfastToggle.coordinate(
                withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
            ).tap()
            assertExactValue(breakfastToggle, expected: "1", phase: "Reminder time")
            let breakfastTime = app.descendants(matching: .any)
                .matching(identifier: "breakfast-reminder-time")
                .firstMatch
            assertExists(breakfastTime, identifier: "breakfast-reminder-time", phase: "Reminder time")

            for _ in 0..<3 {
                if weightToggle.isHittable && waterToggle.isHittable { break }
                app.swipeUp()
            }
            assertExists(weightToggle, identifier: "weight-reminder-toggle", phase: "Reminder editor")
            assertExists(waterToggle, identifier: "water-reminder-toggle", phase: "Reminder editor")
            assertHittable(remindersCancel, identifier: "reminders-cancel", phase: "Reminder cancel")
            remindersCancel.tap()
            assertAbsent(reminderEditor, identifier: "reminder-editor", phase: "Reminder cancel")
            let breakfastSummary = app.descendants(matching: .any)
                .matching(identifier: "breakfast-reminder-summary")
                .firstMatch
            assertExists(
                breakfastSummary,
                identifier: "breakfast-reminder-summary",
                phase: "Reminder cancel"
            )
            assertExactValue(breakfastSummary, expected: "Off", phase: "Reminder cancel")
        }
    }

    @MainActor
    func testPopulatedTodayClearsFloatingTabBar() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-design-review",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment = [
            "DESIGN_REVIEW_STATE": "normal",
            "DESIGN_REVIEW_APPEARANCE": "light",
            "DESIGN_REVIEW_DYNAMIC_TYPE": "normal"
        ]
        let nutrition = app.descendants(matching: .any)
            .matching(identifier: "nutrition-balance-link")
            .firstMatch
        let mealNames = ["breakfast", "lunch", "dinner", "snack"]
        let meals = mealNames.map { meal in
            app.descendants(matching: .any)
                .matching(identifier: "meal-summary-\(meal)")
                .firstMatch
        }
        let tabBar = app.tabBars.firstMatch

        XCTContext.runActivity(named: "Launch populated Today") { _ in
            app.launch()
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: uiTimeout),
                "Today layout: app did not reach foreground; state=\(app.state)."
            )
            assertExists(nutrition, identifier: "nutrition-balance-link", phase: "Today layout")
            assertExists(tabBar, identifier: "Tab Bar", phase: "Today layout")
        }

        XCTContext.runActivity(named: "Verify all meal summaries clear tab bar") { _ in
            for (meal, element) in zip(mealNames, meals) {
                assertExists(
                    element,
                    identifier: "meal-summary-\(meal)",
                    phase: "Today layout"
                )
                XCTAssertLessThanOrEqual(
                    element.frame.maxY,
                    tabBar.frame.minY,
                    "Today layout: \(meal) intersects tab bar; meal=\(element.frame), tab=\(tabBar.frame)."
                )
            }
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
