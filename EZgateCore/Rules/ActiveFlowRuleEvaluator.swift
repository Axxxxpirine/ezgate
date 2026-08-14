import Foundation

public struct ActiveFlowRuleEvaluator: Sendable {
    private let ruleEngine = RuleEngine()

    public init() {}

    public func blockedFlowIdentifiers(
        in activeFlows: [String: AppIdentity],
        snapshot: SharedRuleSnapshot
    ) -> Set<String> {
        Set(activeFlows.compactMap { flowIdentifier, identity in
            let decision = ruleEngine.decide(
                for: identity,
                profile: snapshot.activeProfile,
                filteringPaused: snapshot.filteringPaused
            )
            return decision.isAllowed ? nil : flowIdentifier
        })
    }
}
