import Foundation

public struct AppIdentity: Codable, Hashable, Identifiable, Sendable {
    public let bundleIdentifier: String?
    public let signingIdentifier: String?
    public let displayName: String
    public let executableURL: URL?
    public let processIdentifiers: Set<Int32>
    public let processNames: Set<String>

    public var id: String {
        bundleIdentifier ?? signingIdentifier ?? executableURL?.path ?? displayName
    }

    public init(
        bundleIdentifier: String?,
        signingIdentifier: String? = nil,
        displayName: String,
        executableURL: URL? = nil,
        processIdentifiers: Set<Int32> = [],
        processNames: Set<String> = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.signingIdentifier = signingIdentifier
        self.displayName = displayName
        self.executableURL = executableURL
        self.processIdentifiers = processIdentifiers
        self.processNames = processNames
    }
}

