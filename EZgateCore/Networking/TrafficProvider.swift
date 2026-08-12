import Foundation

public protocol TrafficProvider: Sendable {
    func updates() -> AsyncStream<[AppTraffic]>
}

