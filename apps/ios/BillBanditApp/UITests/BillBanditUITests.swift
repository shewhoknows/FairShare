import Foundation
import XCTest

@MainActor
final class BillBanditUITests: XCTestCase {
    private var runsRailwayUITests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["BILLBANDIT_RUN_RAILWAY_UI_TESTS"] == "1"
            || environment["TEST_RUNNER_BILLBANDIT_RUN_RAILWAY_UI_TESTS"] == "1"
    }

    private func requireRailwayUITests() throws {
        guard runsRailwayUITests else {
            throw XCTSkip("Railway UI tests are opt-in because they mutate live Railway test data.")
        }
    }

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
        app.dismissKeyboardIfNeeded()

        let completeProfileButton = app.buttons["inkAuth.completeProfile"]
        if completeProfileButton.waitForExistence(timeout: 2) {
            completeProfileButton.tap()
        }

        XCTAssertTrue(app.staticTexts["No tabs running"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["top.right"].exists)
        XCTAssertTrue(app.buttons["Start a trip"].exists)
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

    func testRailwayOTPAuthSignsIntoReceiptTrips() throws {
        try requireRailwayUITests()

        let app = XCUIApplication()
        signIntoRailwayWithOTP(app)
        XCTAssertTrue(app.buttons["top.right"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["inkAuth.otp"].exists)

        XCTAssertTrue(app.buttons["bottomTab.profile"].waitForExistence(timeout: 5))
        app.buttons["bottomTab.profile"].tap()
        XCTAssertTrue(app.staticTexts["ACCOUNT PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.logout"].waitForExistence(timeout: 5))
        app.buttons["profile.logout"].tap()
        XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 8))
    }

    func testRailwayCanCreateEditDeleteAndFinalizeInkLedger() throws {
        try requireRailwayUITests()

        let app = XCUIApplication()
        signIntoRailwayWithOTP(app)

        let suffix = String(Int(Date().timeIntervalSince1970))
        let ledgerName = "Codex QA \(suffix)"
        let expenseTitle = "Railway chai \(suffix)"
        let editedTitle = "Railway chai done \(suffix)"

        XCTAssertTrue(app.buttons["top.right"].waitForExistence(timeout: 5))
        app.buttons["top.right"].tap()

        let ledgerNameField = app.textFields["newLedger.name"]
        XCTAssertTrue(ledgerNameField.waitForExistence(timeout: 8))
        ledgerNameField.replaceText(with: ledgerName, placeholder: "Expense Name")
        app.dismissKeyboardIfNeeded()

        app.buttons["newLedger.open"].tap()
        XCTAssertTrue(app.staticTexts["ledger.title"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["ledger.addEntry"].waitForExistence(timeout: 10))

        app.buttons["ledger.addEntry"].tap()
        XCTAssertTrue(app.textFields["addEntry.amount"].waitForExistence(timeout: 8))
        app.textFields["addEntry.amount"].replaceText(with: "123", placeholder: "0")
        app.textFields["addEntry.title"].replaceText(with: expenseTitle, placeholder: "For")
        app.dismissKeyboardIfNeeded()
        app.buttons["addEntry.save"].tap()

        let createdRow = app.buttons["expenseRow.\(expenseTitle)"]
        XCTAssertTrue(createdRow.waitForExistence(timeout: 20))

        createdRow.tap()
        XCTAssertTrue(app.buttons["addEntry.delete"].waitForExistence(timeout: 8))
        app.textFields["addEntry.title"].replaceText(with: editedTitle)
        app.dismissKeyboardIfNeeded()
        app.buttons["addEntry.save"].tap()

        XCTAssertFalse(createdRow.waitForExistence(timeout: 2))
        let editedRow = app.buttons["expenseRow.\(editedTitle)"]
        XCTAssertTrue(editedRow.waitForExistence(timeout: 20))

        editedRow.tap()
        XCTAssertTrue(app.buttons["addEntry.delete"].waitForExistence(timeout: 8))
        app.buttons["addEntry.delete"].tap()
        XCTAssertTrue(app.staticTexts["ledger.empty"].waitForExistence(timeout: 20))

        app.buttons["ledger.markFinal"].tap()
        XCTAssertTrue(app.buttons["finalBill.seeAll"].waitForExistence(timeout: 20))
        app.buttons["finalBill.seeAll"].tap()
        XCTAssertTrue(app.staticTexts["ledger.title"].waitForExistence(timeout: 8))
    }

    func testRailwayCanAddFriendSplitExpenseAndRecordSettlement() async throws {
        try requireRailwayUITests()

        let friend = try await registerRailwayFriend()
        let app = XCUIApplication()
        signIntoRailwayWithOTP(app)

        let suffix = String(Int(Date().timeIntervalSince1970))
        let ledgerName = "Codex QA Settle \(suffix)"
        let expenseTitle = "Railway dinner \(suffix)"

        XCTAssertTrue(app.buttons["top.right"].waitForExistence(timeout: 5))
        app.buttons["top.right"].tap()

        let ledgerNameField = app.textFields["newLedger.name"]
        XCTAssertTrue(ledgerNameField.waitForExistence(timeout: 8))
        ledgerNameField.replaceText(with: ledgerName, placeholder: "Expense Name")
        app.dismissKeyboardIfNeeded()

        app.buttons["newLedger.open"].tap()
        XCTAssertTrue(app.staticTexts["ledger.title"].waitForExistence(timeout: 20))

        app.buttons["top.right"].tap()
        let friendField = app.textFields["addFriend.name"]
        XCTAssertTrue(friendField.waitForExistence(timeout: 8))
        friendField.replaceText(with: friend.email, placeholder: "Email")
        XCTAssertTrue(app.staticTexts["Account found"].waitForExistence(timeout: 12))
        app.dismissKeyboardIfNeeded()
        if app.buttons["addFriend.save"].waitForExistence(timeout: 2) {
            app.buttons["addFriend.save"].tap()
        }
        XCTAssertTrue(app.staticTexts["ledger.title"].waitForExistence(timeout: 20))

        app.buttons["ledger.addEntry"].tap()
        XCTAssertTrue(app.textFields["addEntry.amount"].waitForExistence(timeout: 8))
        app.textFields["addEntry.amount"].replaceText(with: "200", placeholder: "0")
        app.textFields["addEntry.title"].replaceText(with: expenseTitle, placeholder: "For")
        let friendSplit = app.buttons["addEntry.split.\(friend.name)"]
        XCTAssertTrue(friendSplit.waitForExistence(timeout: 5))
        XCTAssertTrue(friendSplit.waitForValue("selected", timeout: 2))
        app.dismissKeyboardIfNeeded()
        app.buttons["addEntry.save"].tap()

        XCTAssertTrue(app.buttons["expenseRow.\(expenseTitle)"].waitForExistence(timeout: 20))
        app.buttons["bottomTab.settle"].tap()
        XCTAssertTrue(app.buttons["settlementRow.0"].waitForExistence(timeout: 20))
        app.buttons["settlementRow.0"].tap()

        XCTAssertTrue(app.textFields["recordPayment.amount"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["recordPayment.counterpartyMenu"].exists)
        XCTAssertTrue(app.buttons["recordPayment.ledgerMenu"].exists)
        app.buttons["recordPayment.save"].tap()

        XCTAssertTrue(
            app.waitForAnyElement(
                [
                    app.buttons["finalBill.seeAll"],
                    app.staticTexts["All square. Nothing left to settle."],
                    app.buttons["settle.ledgerMenu"],
                ],
                timeout: 25
            )
        )

        if app.buttons["finalBill.seeAll"].exists {
            app.buttons["finalBill.seeAll"].tap()
        } else {
            app.buttons["bottomTab.ledger"].tap()
        }
        XCTAssertTrue(app.staticTexts["ledger.title"].waitForExistence(timeout: 8))

        app.buttons["ledger.markFinal"].tap()
        XCTAssertTrue(app.buttons["finalBill.seeAll"].waitForExistence(timeout: 20))
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
        let arjunSplit = app.buttons["addEntry.split.Arjun"]
        XCTAssertTrue(arjunSplit.waitForExistence(timeout: 2))
        arjunSplit.tap()
        XCTAssertTrue(arjunSplit.waitForValue("not selected", timeout: 2))
        arjunSplit.tap()
        XCTAssertTrue(arjunSplit.waitForValue("selected", timeout: 2))
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

    func testPrototypeSettleRecordPaymentAndBottomTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["--root=prototype", "--ink-demo-data", "--ink-screen=07"]
        app.launch()

        XCTAssertTrue(app.buttons["settle.ledgerMenu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["bottomTab.trips"].exists)
        XCTAssertTrue(app.buttons["bottomTab.settle"].exists)

        app.buttons["bottomTab.trips"].tap()
        XCTAssertTrue(app.firstTripCard.waitForExistence(timeout: 5))

        app.buttons["bottomTab.settle"].tap()
        XCTAssertTrue(app.buttons["settle.ledgerMenu"].waitForExistence(timeout: 5))

        let firstSettlement = app.buttons["settlementRow.0"]
        XCTAssertTrue(firstSettlement.waitForExistence(timeout: 5))
        firstSettlement.tap()

        XCTAssertTrue(app.textFields["recordPayment.amount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recordPayment.counterpartyMenu"].exists)
        XCTAssertTrue(app.buttons["recordPayment.ledgerMenu"].exists)
        XCTAssertTrue(app.buttons["recordPayment.flipDirection"].exists)
        XCTAssertTrue(app.buttons["recordPayment.save"].exists)

        app.buttons["recordPayment.flipDirection"].tap()
        app.buttons["recordPayment.save"].tap()
        XCTAssertTrue(app.buttons["settle.ledgerMenu"].waitForExistence(timeout: 5))
    }

    func testPrototypeFinalBillSeeAllReturnsToLedger() {
        let app = XCUIApplication()
        app.launchArguments = ["--root=prototype", "--ink-demo-data", "--ink-screen=09"]
        app.launch()

        XCTAssertTrue(app.buttons["finalBill.seeAll"].waitForExistence(timeout: 5))
        app.buttons["finalBill.seeAll"].tap()
        XCTAssertTrue(app.staticTexts["ledger.title"].waitForExistence(timeout: 5))
    }

    func testPrototypeCanMarkLedgerFinalAndReturnToLedger() {
        let app = XCUIApplication()
        app.launchArguments = ["--root=prototype", "--ink-demo-data", "--ink-screen=06"]
        app.launch()

        XCTAssertTrue(app.buttons["ledger.markFinal"].waitForExistence(timeout: 5))
        app.buttons["ledger.markFinal"].tap()
        XCTAssertTrue(app.buttons["finalBill.seeAll"].waitForExistence(timeout: 5))
        app.buttons["finalBill.seeAll"].tap()
        XCTAssertTrue(app.staticTexts["ledger.title"].waitForExistence(timeout: 5))
    }

    private func signIntoRailwayWithOTP(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.launchArguments = ["--volatile-auth-session", "--reset-auth-session"]
        app.launch()

        XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 8), file: file, line: line)
        app.buttons["welcome.login"].tap()

        let identifierField = app.textFields["inkAuth.identifier"]
        XCTAssertTrue(identifierField.waitForExistence(timeout: 8), file: file, line: line)
        identifierField.tap()
        identifierField.typeText("+15555550199")
        app.dismissKeyboardIfNeeded()

        let otpField = app.textFields["inkAuth.otp"]
        if !otpField.waitForExistence(timeout: 4) {
            let continueButton = app.buttons["inkAuth.continue"]
            XCTAssertTrue(continueButton.waitForExistence(timeout: 5), file: file, line: line)
            continueButton.tap()
        }

        XCTAssertTrue(otpField.waitForExistence(timeout: 12), file: file, line: line)
        otpField.tap()
        otpField.typeText("123456")
        app.dismissKeyboardIfNeeded()

        let verifyButton = app.buttons["inkAuth.verify"]
        if verifyButton.waitForExistence(timeout: 2) == false || verifyButton.isHittable == false {
            app.swipeUp()
        }
        if verifyButton.waitForExistence(timeout: 2) {
            verifyButton.tap()
        }

        completeProfileIfNeeded(app, file: file, line: line)
        waitForTripsRoot(app, file: file, line: line)
    }

    private func completeProfileIfNeeded(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let upiField = app.textFields["inkAuth.upi"]
        guard upiField.waitForExistence(timeout: 3) else { return }

        let nameField = app.textFields["inkAuth.name"]
        if nameField.waitForExistence(timeout: 1) {
            nameField.replaceText(with: "Production Smoke Owner", placeholder: "Full name")
        }
        let preferredNameField = app.textFields["inkAuth.preferredName"]
        if preferredNameField.waitForExistence(timeout: 1) {
            preferredNameField.replaceText(with: "Smoke Owner", placeholder: "Username")
        }
        upiField.replaceText(with: "owner@upi", placeholder: "meera@upi")
        app.dismissKeyboardIfNeeded()

        let completeProfileButton = app.buttons["inkAuth.completeProfile"]
        XCTAssertTrue(completeProfileButton.waitForExistence(timeout: 5), file: file, line: line)
        completeProfileButton.tap()
    }

    private func waitForTripsRoot(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.waitForAnyElement(
                [
                    app.staticTexts["No tabs running"],
                    app.staticTexts["Your Expenses"],
                    app.staticTexts["No expenses yet"],
                    app.firstTripCard,
                ],
                timeout: 25
            ),
            file: file,
            line: line
        )
    }

    private func registerRailwayFriend() async throws -> RailwaySeededFriend {
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let friend = RailwaySeededFriend(
            name: "Codex QA Friend \(suffix)",
            email: "codex-ios-friend-\(suffix)@billbandit-test.com"
        )
        let baseURLString = ProcessInfo.processInfo.environment["BILLBANDIT_RAILWAY_BASE_URL"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_BILLBANDIT_RAILWAY_BASE_URL"]
            ?? "https://billbandit-api.contenthelper.in"
        let url = URL(string: "/api/mobile/auth/register", relativeTo: URL(string: baseURLString))!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": friend.name,
            "email": friend.email,
            "password": "TestPass123!",
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw NSError(
                domain: "BillBanditUITests.RailwaySeed",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Registering Railway friend failed with \(statusCode): \(body)"]
            )
        }
        return friend
    }
}

private struct RailwaySeededFriend {
    let name: String
    let email: String
}

private extension XCUIApplication {
    var firstTripCard: XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "tripCard."))
            .firstMatch
    }

    func dismissKeyboardIfNeeded() {
        if tapFirstButton(identifierOrLabel: "keyboard.done", timeout: 0.8) {
            return
        }

        for buttonTitle in ["Done", "continue", "Continue", "go", "Go", "return", "Return"] {
            if tapFirstButton(identifierOrLabel: buttonTitle, timeout: 0.4) {
                return
            }
        }
    }

    private func tapFirstButton(identifierOrLabel: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(
            format: "identifier == %@ OR label == %@",
            identifierOrLabel,
            identifierOrLabel
        )
        let candidates = [
            keyboards.buttons.matching(predicate).firstMatch,
            buttons.matching(predicate).firstMatch,
        ]

        for button in candidates {
            if button.waitForExistence(timeout: timeout) {
                button.tap()
                _ = keyboards.element.waitForNonExistence(timeout: 1.5)
                return true
            }
        }
        return false
    }

    func waitForAnyElement(_ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elements.contains(where: { $0.exists }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return elements.contains(where: { $0.exists })
    }
}

private extension XCUIElement {
    func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if value as? String == expected {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return value as? String == expected
    }

    func replaceText(with text: String, placeholder: String? = nil) {
        tap()
        if let currentValue = value as? String,
           currentValue.isEmpty == false,
           currentValue != placeholder {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        typeText(text)
    }
}
