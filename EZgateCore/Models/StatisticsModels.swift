import Foundation

public struct TrafficRecord: Codable, Sendable {
    public let applicationIdentifier: String
    public let displayName: String
    public let date: Date
    public let sessionID: UUID
    public let profileID: UUID
    public let interface: NetworkInterfaceKind
    public let receivedBytes: UInt64
    public let sentBytes: UInt64

    public init(
        applicationIdentifier: String,
        displayName: String,
        date: Date = .now,
        sessionID: UUID,
        profileID: UUID,
        interface: NetworkInterfaceKind,
        receivedBytes: UInt64,
        sentBytes: UInt64
    ) {
        self.applicationIdentifier = applicationIdentifier
        self.displayName = displayName
        self.date = date
        self.sessionID = sessionID
        self.profileID = profileID
        self.interface = interface
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }
}

public struct TrafficTotals: Equatable, Sendable {
    public var receivedBytes: UInt64
    public var sentBytes: UInt64

    public init(receivedBytes: UInt64 = 0, sentBytes: UInt64 = 0) {
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }
}

