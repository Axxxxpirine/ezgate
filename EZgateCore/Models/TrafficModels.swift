import Foundation

public struct ProcessTrafficSample: Codable, Hashable, Sendable {
    public let identity: AppIdentity
    public let processIdentifier: Int32
    public let processName: String
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let receivedBytesPerSecond: Double
    public let sentBytesPerSecond: Double

    public init(
        identity: AppIdentity,
        processIdentifier: Int32,
        processName: String,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        receivedBytesPerSecond: Double = 0,
        sentBytesPerSecond: Double = 0
    ) {
        self.identity = identity
        self.processIdentifier = processIdentifier
        self.processName = processName
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.receivedBytesPerSecond = receivedBytesPerSecond
        self.sentBytesPerSecond = sentBytesPerSecond
    }
}

public struct AppTraffic: Codable, Hashable, Identifiable, Sendable {
    public let identity: AppIdentity
    public var receivedBytes: UInt64
    public var sentBytes: UInt64
    public var receivedBytesPerSecond: Double
    public var sentBytesPerSecond: Double

    public var id: String { identity.id }
    public var totalBytes: UInt64 { receivedBytes &+ sentBytes }

    public init(
        identity: AppIdentity,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        receivedBytesPerSecond: Double = 0,
        sentBytesPerSecond: Double = 0
    ) {
        self.identity = identity
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.receivedBytesPerSecond = receivedBytesPerSecond
        self.sentBytesPerSecond = sentBytesPerSecond
    }
}

public enum TrafficSortOrder: String, CaseIterable, Codable, Sendable {
    case total
    case download
    case upload
    case name
    case status

    public var displayName: String {
        switch self {
        case .total: "Total"
        case .download: "Download"
        case .upload: "Upload"
        case .name: "Name"
        case .status: "Access"
        }
    }
}

