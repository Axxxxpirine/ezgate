import Foundation

@objc public protocol FilterIPCProtocol {
    func updateRules(_ data: Data, withReply reply: @escaping (Bool) -> Void)
    func trafficSnapshot(withReply reply: @escaping (Data?) -> Void)
}

public enum FilterIPCConfiguration {
    public static let machServiceName = "group.ch.ezgate.shared.filter"
}
