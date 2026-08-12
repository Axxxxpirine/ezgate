import Foundation

public struct RuleEngine: Sendable {
    public init() {}

    public func decide(
        for application: AppIdentity,
        profile: NetworkProfile,
        filteringPaused: Bool
    ) -> RuleDecision {
        if filteringPaused {
            return .allow(reason: "Filtering is paused")
        }

        if let action = profile.rules[application.id] {
            return decision(for: action, reason: "Application rule in \(profile.name)")
        }

        if let bundleIdentifier = application.bundleIdentifier,
           let action = profile.rules[bundleIdentifier] {
            return decision(for: action, reason: "Bundle rule in \(profile.name)")
        }

        return decision(for: profile.defaultPolicy, reason: "Default policy in \(profile.name)")
    }

    private func decision(for action: RuleAction, reason: String) -> RuleDecision {
        switch action {
        case .allow: .allow(reason: reason)
        case .block: .block(reason: reason)
        }
    }
}

