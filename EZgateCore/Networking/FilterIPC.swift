import Foundation

@objc public protocol FilterIPCProtocol {
    func updateRules(_ data: Data, withReply reply: @escaping (Bool) -> Void)
    func trafficSnapshot(withReply reply: @escaping (Data?) -> Void)
    func resetTraffic(withReply reply: @escaping (Bool) -> Void)
}

public enum FilterIPCConfiguration {
    public static let machServiceName = "group.ch.ezgate.shared.filter"

    /// Signing identifier of the only client allowed to talk to the filter.
    public static let clientSigningIdentifier = "ch.ezgate.app"

    /// Code-signing requirement a connecting process must satisfy: the EZgate app,
    /// signed by Apple-issued certificates of the same team as the filter.
    /// Returns nil when the team identifier is missing or malformed, in which case
    /// every connection must be rejected.
    public static func clientCodeSigningRequirement(teamIdentifier: String?) -> String? {
        guard let teamIdentifier, isValidTeamIdentifier(teamIdentifier) else { return nil }
        return "anchor apple generic"
            + " and identifier \"\(clientSigningIdentifier)\""
            + " and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }

    static func isValidTeamIdentifier(_ value: String) -> Bool {
        value.count == 10 && value.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
    }
}
