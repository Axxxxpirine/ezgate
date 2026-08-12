import Foundation

public enum RuleAction: String, Codable, CaseIterable, Sendable {
    case allow
    case block
}

public enum RuleDecision: Equatable, Sendable {
    case allow(reason: String)
    case block(reason: String)

    public var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }
}

public struct NetworkRule: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var applicationIdentifier: String
    public var action: RuleAction

    public init(id: UUID = UUID(), applicationIdentifier: String, action: RuleAction) {
        self.id = id
        self.applicationIdentifier = applicationIdentifier
        self.action = action
    }
}

