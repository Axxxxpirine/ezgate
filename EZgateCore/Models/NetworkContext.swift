import Foundation

public enum NetworkInterfaceKind: String, Codable, Sendable {
    case wifi
    case ethernet
    case wired
    case other
    case unavailable
}

public struct NetworkContext: Codable, Equatable, Sendable {
    public var interface: NetworkInterfaceKind
    public var interfaceName: String?
    public var ssid: String?
    public var isExpensive: Bool
    public var isConstrained: Bool
    public var isAvailable: Bool

    public init(
        interface: NetworkInterfaceKind,
        interfaceName: String? = nil,
        ssid: String? = nil,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        isAvailable: Bool = true
    ) {
        self.interface = interface
        self.interfaceName = interfaceName
        self.ssid = ssid
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.isAvailable = isAvailable
    }

    public var signatures: Set<String> {
        var values = ["interface:\(interface.rawValue)"]
        if let interfaceName { values.append("device:\(interfaceName)") }
        if let ssid { values.append("ssid:\(ssid)") }
        if isExpensive { values.append("expensive") }
        if isConstrained { values.append("constrained") }
        return Set(values)
    }
}

