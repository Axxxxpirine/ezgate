import XCTest
@testable import EZgateCore

final class RuleEngineTests: XCTestCase {
    private let engine = RuleEngine()
    private let safari = AppIdentity(bundleIdentifier: "com.apple.Safari", displayName: "Safari")

    func testExplicitAllowRuleOverridesBlockDefault() {
        let profile = NetworkProfile(
            name: "Hotspot",
            defaultPolicy: .block,
            rules: ["com.apple.Safari": .allow]
        )
        XCTAssertTrue(engine.decide(for: safari, profile: profile, filteringPaused: false).isAllowed)
    }

    func testExplicitBlockRuleOverridesAllowDefault() {
        let profile = NetworkProfile(
            name: "Normal",
            defaultPolicy: .allow,
            rules: ["com.apple.Safari": .block]
        )
        XCTAssertFalse(engine.decide(for: safari, profile: profile, filteringPaused: false).isAllowed)
    }

    func testUnknownApplicationUsesDefaultPolicy() {
        let profile = NetworkProfile(name: "Hotspot", defaultPolicy: .block)
        XCTAssertFalse(engine.decide(for: safari, profile: profile, filteringPaused: false).isAllowed)
    }

    func testPauseFilteringAllowsEverything() {
        let profile = NetworkProfile(name: "Hotspot", defaultPolicy: .block)
        XCTAssertTrue(engine.decide(for: safari, profile: profile, filteringPaused: true).isAllowed)
    }
}

