import Foundation

public struct NetworkContextMatcher: Sendable {
    public init() {}

    public func matchingProfile(in profiles: [NetworkProfile], for context: NetworkContext) -> NetworkProfile? {
        let signatures = context.signatures
        return profiles.first { !$0.networkSignatures.isDisjoint(with: signatures) }
    }
}

