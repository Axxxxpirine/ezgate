import XCTest
@testable import EZgateCore

final class UtilityTests: XCTestCase {
    func testByteFormatterIncludesUnit() {
        let output = ByteFormatter.string(2_400_000_000)
        XCTAssertFalse(output.isEmpty)
        XCTAssertNotEqual(output, "2400000000")
        XCTAssertEqual(ByteFormatter.string(0), "0 KB")
        XCTAssertEqual(ByteFormatter.rate(0), "0 KB/s")
    }

    func testNetworkContextMatchesExpensiveProfile() {
        let hotspot = NetworkProfile(
            name: "Hotspot",
            defaultPolicy: .block,
            networkSignatures: ["expensive"]
        )
        let context = NetworkContext(interface: .wifi, isExpensive: true)
        XCTAssertEqual(NetworkContextMatcher().matchingProfile(in: [hotspot], for: context)?.id, hotspot.id)
    }
}
