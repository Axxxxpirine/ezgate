import XCTest
@testable import EZgateCore

final class ActiveFlowRuleEvaluatorTests: XCTestCase {
    private let evaluator = ActiveFlowRuleEvaluator()
    private let updater = AppIdentity(
        bundleIdentifier: "com.microsoft.autoupdate.fba",
        displayName: "Microsoft Update Assistant"
    )
    private let safari = AppIdentity(
        bundleIdentifier: "com.apple.Safari",
        displayName: "Safari"
    )

    func testExplicitBlockDropsEveryActiveFlowForApplication() {
        let profile = NetworkProfile(
            name: "Normal",
            defaultPolicy: .allow,
            rules: [updater.id: .block]
        )
        let snapshot = SharedRuleSnapshot(
            activeProfile: profile,
            filteringPaused: false,
            revision: 1
        )

        let blocked = evaluator.blockedFlowIdentifiers(
            in: ["update-1": updater, "update-2": updater, "safari-1": safari],
            snapshot: snapshot
        )

        XCTAssertEqual(blocked, ["update-1", "update-2"])
    }

    func testPausedFilteringKeepsActiveFlowsAllowed() {
        let profile = NetworkProfile(
            name: "Normal",
            defaultPolicy: .allow,
            rules: [updater.id: .block]
        )
        let snapshot = SharedRuleSnapshot(
            activeProfile: profile,
            filteringPaused: true,
            revision: 2
        )

        let blocked = evaluator.blockedFlowIdentifiers(
            in: ["update-1": updater],
            snapshot: snapshot
        )

        XCTAssertTrue(blocked.isEmpty)
    }

    func testBlockByDefaultDropsUnknownActiveFlow() {
        let profile = NetworkProfile(name: "Hotspot", defaultPolicy: .block)
        let snapshot = SharedRuleSnapshot(
            activeProfile: profile,
            filteringPaused: false,
            revision: 3
        )

        let blocked = evaluator.blockedFlowIdentifiers(
            in: ["safari-1": safari],
            snapshot: snapshot
        )

        XCTAssertEqual(blocked, ["safari-1"])
    }
}
