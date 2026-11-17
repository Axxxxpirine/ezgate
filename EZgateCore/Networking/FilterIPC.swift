import Foundation

@objc public protocol FilterIPCProtocol {
    func updateRules(_ data: Data, withReply reply: @escaping (Bool) -> Void)
    func trafficSnapshot(withReply reply: @escaping (Data?) -> Void)
    func resetTraffic(withReply reply: @escaping (Bool) -> Void)
}

public enum FilterIPCConfiguration {
    /// Base name of the filter's XPC service. The real name carries the filter build
    /// number (see `NEMachServiceName` in the extension Info.plist) so that an update
    /// does not collide with the previous filter's endpoint before a restart.
    public static let machServiceNamePrefix = "group.ch.ezgate.shared.filter"

    /// Reads `NetworkExtension.NEMachServiceName` from a system-extension Info.plist.
    public static func machServiceName(fromInfoDictionary info: [String: Any]?) -> String? {
        guard let networkExtension = info?["NetworkExtension"] as? [String: Any],
              let name = networkExtension["NEMachServiceName"] as? String,
              name.hasPrefix(machServiceNamePrefix) else { return nil }
        return name
    }

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
