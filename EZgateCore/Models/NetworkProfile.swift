import Foundation

public struct NetworkProfile: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var defaultPolicy: RuleAction
    public var rules: [String: RuleAction]
    public var networkSignatures: Set<String>

    public init(
        id: UUID = UUID(),
        name: String,
        defaultPolicy: RuleAction,
        rules: [String: RuleAction] = [:],
        networkSignatures: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.defaultPolicy = defaultPolicy
        self.rules = rules
        self.networkSignatures = networkSignatures
    }

    public static var defaults: [NetworkProfile] {
        [
            NetworkProfile(name: "Normal", defaultPolicy: .allow),
            NetworkProfile(name: "Hotspot", defaultPolicy: .block),
            NetworkProfile(name: "Restrictive", defaultPolicy: .block)
        ]
    }
}

public struct PersistedConfiguration: Codable, Sendable {
    public var profiles: [NetworkProfile]
    public var activeProfileID: UUID
    public var filteringPaused: Bool

    public init(profiles: [NetworkProfile], activeProfileID: UUID, filteringPaused: Bool) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.filteringPaused = filteringPaused
    }
}

