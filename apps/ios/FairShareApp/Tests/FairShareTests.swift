import XCTest
@testable import FairShare

final class FairShareTests: XCTestCase {
    func testCurrencyFormatterProducesValue() {
        let formatted = FairShareFormatters.currency(12.5, code: "INR")
        XCTAssertFalse(formatted.isEmpty)
    }
}

