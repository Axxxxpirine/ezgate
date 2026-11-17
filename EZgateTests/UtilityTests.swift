import XCTest
@testable import EZgateCore

final class UtilityTests: XCTestCase {
    func testFilterIPCRequirementPinsAppAndTeam() {
        XCTAssertEqual(
            FilterIPCConfiguration.clientCodeSigningRequirement(teamIdentifier: "ABCDE12345"),
            "anchor apple generic and identifier \"ch.ezgate.app\" and certificate leaf[subject.OU] = \"ABCDE12345\""
        )
    }

    func testMachServiceNameIsReadFromExtensionInfo() {
        let info: [String: Any] = ["NetworkExtension": ["NEMachServiceName": "group.ch.ezgate.shared.filter.18"]]
        XCTAssertEqual(FilterIPCConfiguration.machServiceName(fromInfoDictionary: info), "group.ch.ezgate.shared.filter.18")
        XCTAssertNil(FilterIPCConfiguration.machServiceName(fromInfoDictionary: nil))
        XCTAssertNil(FilterIPCConfiguration.machServiceName(fromInfoDictionary: ["NetworkExtension": ["NEMachServiceName": "other"]]))
    }

    func testFilterIPCRequirementRejectsMissingOrMalformedTeam() {
        XCTAssertNil(FilterIPCConfiguration.clientCodeSigningRequirement(teamIdentifier: nil))
        XCTAssertNil(FilterIPCConfiguration.clientCodeSigningRequirement(teamIdentifier: ""))
        XCTAssertNil(FilterIPCConfiguration.clientCodeSigningRequirement(teamIdentifier: "abcde12345"))
        XCTAssertNil(FilterIPCConfiguration.clientCodeSigningRequirement(teamIdentifier: "ABC\" or true"))
    }

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
