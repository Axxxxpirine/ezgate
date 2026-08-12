import Foundation

public struct SharedRuleSnapshot: Codable, Sendable {
    public var activeProfile: NetworkProfile
    public var filteringPaused: Bool
    public var revision: UInt64

    public init(activeProfile: NetworkProfile, filteringPaused: Bool, revision: UInt64) {
        self.activeProfile = activeProfile
        self.filteringPaused = filteringPaused
        self.revision = revision
    }
}

public enum SharedRuleSnapshotStore {
    public static let appGroupIdentifier = "group.ch.ezgate.shared"
    public static let filename = "rules.json"

    public static func fileURL(containerURL: URL) -> URL {
        containerURL.appending(path: filename)
    }

    public static func read(from fileURL: URL) throws -> SharedRuleSnapshot {
        try JSONDecoder().decode(SharedRuleSnapshot.self, from: Data(contentsOf: fileURL))
    }

    public static func write(_ snapshot: SharedRuleSnapshot, to fileURL: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}

