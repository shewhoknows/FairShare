import XCTest

@MainActor
final class FairShareUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testMockLoginReachesDashboard() {
        let app = XCUIApplication()
        app.launch()

        if app.textFields["auth.email"].waitForExistence(timeout: 2) {
            let emailField = app.textFields["auth.email"]
            emailField.tap()
            emailField.typeText("alice@example.com")

            let passwordField = app.secureTextFields["auth.password"]
            XCTAssertTrue(passwordField.waitForExistence(timeout: 2))
            passwordField.tap()
            passwordField.typeText("password123")

            app.buttons["auth.submit"].tap()
        }

        XCTAssertTrue(app.staticTexts["Dashboard"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Hello, Alice Johnson"].exists)
        XCTAssertTrue(app.buttons["New expense"].exists)
        XCTAssertTrue(app.staticTexts["Hotel - 3 nights"].exists)
        XCTAssertTrue(app.staticTexts["Dinner at Carbone"].exists)
    }
}
