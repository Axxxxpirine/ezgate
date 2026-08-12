import XCTest
@testable import EZgateCore

final class StatisticsStoreTests: XCTestCase {
    func testRecordsAndTotalsSession() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "ezgate-statistics-\(UUID().uuidString).sqlite")
        let store = StatisticsStore(fileURL: fileURL)
        let session = UUID()
        let profile = UUID()
        try await store.record(TrafficRecord(
            applicationIdentifier: "com.apple.Safari",
            displayName: "Safari",
            sessionID: session,
            profileID: profile,
            interface: .wifi,
            receivedBytes: 1_000,
            sentBytes: 200
        ))
        try await store.record(TrafficRecord(
            applicationIdentifier: "com.openai.chat",
            displayName: "ChatGPT",
            sessionID: session,
            profileID: profile,
            interface: .wifi,
            receivedBytes: 500,
            sentBytes: 100
        ))
        let totals = try await store.totals(for: session)
        XCTAssertEqual(totals, TrafficTotals(receivedBytes: 1_500, sentBytes: 300))
        try await store.deleteAll()
    }
}

