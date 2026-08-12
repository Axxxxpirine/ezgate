import Foundation

public struct SharedTrafficSnapshot: Codable, Sendable {
    public var updatedAt: Date
    public var applications: [AppTraffic]

    public init(updatedAt: Date = .now, applications: [AppTraffic]) {
        self.updatedAt = updatedAt
        self.applications = applications
    }
}

public enum SharedTrafficSnapshotStore {
    public static let filename = "traffic.json"

    public static func fileURL(containerURL: URL) -> URL {
        containerURL.appending(path: filename)
    }

    public static func read(from fileURL: URL) throws -> SharedTrafficSnapshot {
        try JSONDecoder().decode(SharedTrafficSnapshot.self, from: Data(contentsOf: fileURL))
    }

    public static func write(_ snapshot: SharedTrafficSnapshot, to fileURL: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}
