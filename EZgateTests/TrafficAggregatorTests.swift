import XCTest
@testable import EZgateCore

final class TrafficAggregatorTests: XCTestCase {
    func testAggregatesMultipleProcessesIntoOneApplication() throws {
        let identity = AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        let samples = [
            ProcessTrafficSample(identity: identity, processIdentifier: 10, processName: "Chrome Helper", receivedBytes: 100, sentBytes: 20),
            ProcessTrafficSample(identity: identity, processIdentifier: 11, processName: "Chrome Renderer", receivedBytes: 200, sentBytes: 30)
        ]
        let result = TrafficAggregator().aggregate(samples)
        let app = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(app.receivedBytes, 300)
        XCTAssertEqual(app.sentBytes, 50)
        XCTAssertEqual(app.identity.processIdentifiers, [10, 11])
    }
}

