import XCTest
@testable import EZgateCore

final class TrafficLiveSortingTests: XCTestCase {
    func testCalculatesRatesFromConsecutiveSnapshots() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let previous = SharedTrafficSnapshot(updatedAt: start, applications: [
            traffic("Safari", received: 1_000, sent: 500, receivedRate: 999, sentRate: 999)
        ])
        let current = SharedTrafficSnapshot(updatedAt: start.addingTimeInterval(2), applications: [
            traffic("Safari", received: 1_600, sent: 700)
        ])

        let result = TrafficRateCalculator.applyingRates(to: current, previous: previous)
        let safari = try XCTUnwrap(result.first)
        XCTAssertEqual(safari.receivedBytesPerSecond, 300)
        XCTAssertEqual(safari.sentBytesPerSecond, 100)
    }

    func testInactiveAppRateReturnsToZeroWhenTotalsDoNotChange() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let previous = SharedTrafficSnapshot(updatedAt: start, applications: [
            traffic("Safari", received: 1_000, sent: 500, receivedRate: 300, sentRate: 100)
        ])
        let current = SharedTrafficSnapshot(updatedAt: start, applications: [
            traffic("Safari", received: 1_000, sent: 500)
        ])

        let result = TrafficRateCalculator.applyingRates(to: current, previous: previous)
        let safari = try XCTUnwrap(result.first)
        XCTAssertEqual(safari.receivedBytesPerSecond, 0)
        XCTAssertEqual(safari.sentBytesPerSecond, 0)
    }

    func testLiveDownloadSortMovesHighestCurrentRateFirst() {
        let rows = [
            traffic("Large Total", received: 10_000, sent: 1_000, receivedRate: 10, sentRate: 5),
            traffic("Fast Now", received: 100, sent: 50, receivedRate: 900, sentRate: 2),
            traffic("Medium", received: 1_000, sent: 100, receivedRate: 300, sentRate: 8)
        ]

        let result = TrafficSorter.sorted(rows, by: .liveDownload) { _ in true }
        XCTAssertEqual(result.map(\.identity.displayName), ["Fast Now", "Medium", "Large Total"])
    }

    func testLiveUploadSortUsesTotalThenNameAsStableTieBreakers() {
        let rows = [
            traffic("Alpha", received: 10, sent: 20, receivedRate: 0, sentRate: 50),
            traffic("Beta", received: 1_000, sent: 20, receivedRate: 0, sentRate: 50),
            traffic("Gamma", received: 5, sent: 5, receivedRate: 0, sentRate: 100)
        ]

        let result = TrafficSorter.sorted(rows, by: .liveUpload) { _ in true }
        XCTAssertEqual(result.map(\.identity.displayName), ["Gamma", "Beta", "Alpha"])
    }

    private func traffic(
        _ name: String,
        received: UInt64,
        sent: UInt64,
        receivedRate: Double = 0,
        sentRate: Double = 0
    ) -> AppTraffic {
        AppTraffic(
            identity: AppIdentity(bundleIdentifier: "test.\(name)", displayName: name),
            receivedBytes: received,
            sentBytes: sent,
            receivedBytesPerSecond: receivedRate,
            sentBytesPerSecond: sentRate
        )
    }
}
