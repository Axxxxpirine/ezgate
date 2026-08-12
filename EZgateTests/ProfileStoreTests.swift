import XCTest
@testable import EZgateCore

final class ProfileStoreTests: XCTestCase {
    func testPersistsAndReloadsRules() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "ezgate-profile-\(UUID().uuidString).json")
        let store = ProfileStore(fileURL: fileURL)
        let profile = NetworkProfile(
            name: "Hotspot",
            defaultPolicy: .block,
            rules: ["com.apple.Safari": .allow]
        )
        let configuration = PersistedConfiguration(
            profiles: [profile],
            activeProfileID: profile.id,
            filteringPaused: false
        )
        try await store.save(configuration)
        let loaded = try await store.load()
        XCTAssertEqual(loaded?.profiles, [profile])
        XCTAssertEqual(loaded?.activeProfileID, profile.id)
        try await store.deleteAll()
    }
}

