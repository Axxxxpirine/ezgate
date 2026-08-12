import Foundation

public actor ProfileStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> PersistedConfiguration? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decoder.decode(PersistedConfiguration.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ configuration: PersistedConfiguration) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "EZgate", directoryHint: .isDirectory)
            .appending(path: "configuration.json")
    }
}

