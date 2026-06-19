import XCTest

@MainActor
final class BillBanditUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testMockAppleAuthCompletesProfileAndReachesTrips() {
        let app = XCUIApplication()
        app.launchArguments = ["--volatile-auth-session", "--apple-auth=success"]
        app.launch()

        XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 5))
        app.buttons["welcome.login"].tap()

        XCTAssertTrue(app.buttons["inkAuth.apple"].waitForExistence(timeout: 5))
        app.buttons["inkAuth.apple"].tap()

        let upiField = app.textFields["inkAuth.upi"]
        XCTAssertTrue(upiField.waitForExistence(timeout: 5))
        upiField.tap()
        upiField.typeText("meera@upi")
        app.keyboards.buttons["Done"].tap()

        XCTAssertTrue(app.buttons["inkAuth.completeProfile"].waitForExistence(timeout: 5))
        app.buttons["inkAuth.completeProfile"].tap()

        XCTAssertTrue(app.staticTexts["MY TRIPS"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["No tabs running"].exists)
        XCTAssertTrue(app.buttons["top.right"].exists)
    }

    func testProfileCompletionRequiresUPI() {
        let app = XCUIApplication()
        app.launchArguments = ["--volatile-auth-session", "--apple-auth=success"]
        app.launch()

        XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 5))
        app.buttons["welcome.login"].tap()

        XCTAssertTrue(app.buttons["inkAuth.apple"].waitForExistence(timeout: 5))
        app.buttons["inkAuth.apple"].tap()

        let saveButton = app.buttons["inkAuth.completeProfile"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertFalse(saveButton.isEnabled)
    }

    func testPrototypeLedgerCanAddEditAndDeleteExpense() {
        let app = XCUIApplication()
        app.launchArguments = ["--root=prototype", "--ink-screen=03"]
        app.launch()

        XCTAssertTrue(app.staticTexts["No tabs running"].waitForExistence(timeout: 5))
        app.buttons["top.right"].tap()

        XCTAssertTrue(app.textFields["newLedger.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Meera"].waitForExistence(timeout: 2))
        app.buttons["Meera"].tap()
        app.buttons["Arjun"].tap()
        XCTAssertEqual(app.buttons["Meera"].value as? String, "selected")
        XCTAssertEqual(app.buttons["Arjun"].value as? String, "selected")

        app.buttons["newLedger.open"].tap()
        XCTAssertTrue(app.staticTexts["ledger.empty"].waitForExistence(timeout: 5))

        app.buttons["ledger.addEntry"].tap()
        XCTAssertTrue(app.textFields["addEntry.amount"].waitForExistence(timeout: 5))
        app.textFields["addEntry.amount"].replaceText(with: "2400")
        app.textFields["addEntry.title"].replaceText(with: "Dinner check")
        app.dismissKeyboardIfNeeded()
        app.buttons["addEntry.save"].tap()

        let firstRow = app.buttons["expenseRow.Dinner check"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        firstRow.tap()
        XCTAssertTrue(app.buttons["addEntry.delete"].waitForExistence(timeout: 5))
        app.textFields["addEntry.title"].replaceText(with: "Dinner settled")
        app.dismissKeyboardIfNeeded()
        app.buttons["addEntry.save"].tap()

        XCTAssertFalse(firstRow.waitForExistence(timeout: 1))
        let editedRow = app.buttons["expenseRow.Dinner settled"]
        XCTAssertTrue(editedRow.waitForExistence(timeout: 5))

        editedRow.tap()
        XCTAssertTrue(app.buttons["addEntry.delete"].waitForExistence(timeout: 5))
        app.buttons["addEntry.delete"].tap()
        XCTAssertTrue(app.staticTexts["ledger.empty"].waitForExistence(timeout: 5))
    }
}

private extension XCUIApplication {
    func dismissKeyboardIfNeeded() {
        let doneButton = keyboards.buttons["Done"]
        if doneButton.waitForExistence(timeout: 1) {
            doneButton.tap()
        }
    }
}

private extension XCUIElement {
    func replaceText(with text: String) {
        tap()
        if let currentValue = value as? String, currentValue.isEmpty == false {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        typeText(text)
    }
}
