import XCTest

final class EZgateUITests: XCTestCase {
    func testApplicationLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
