import XCTest
@testable import EZgateCore

final class StatisticsStoreTests: XCTestCase {
    func testRecordsAndTotalsSession() async throws {
        let store = StatisticsStore(fileURL: temporaryDatabaseURL())
        let session = UUID()
        try await record(
            store: store,
            app: "com.apple.Safari",
            name: "Safari",
            date: .now,
            session: session,
            received: 1_000,
            sent: 200
        )
        try await record(
            store: store,
            app: "com.openai.chat",
            name: "ChatGPT",
            date: .now,
            session: session,
            received: 500,
            sent: 100
        )

        let totals = try await store.totals(for: session)
        XCTAssertEqual(totals, TrafficTotals(receivedBytes: 1_500, sentBytes: 300))
    }

    func testDashboardAggregatesAppsAndFiltersSelectedApplication() async throws {
        let store = StatisticsStore(fileURL: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_786_543_200)
        let calendar = utcCalendar
        try await record(store: store, app: "safari", name: "Safari", date: now.addingTimeInterval(-1_800), received: 1_000, sent: 200)
        try await record(store: store, app: "safari", name: "Safari", date: now.addingTimeInterval(-900), received: 500, sent: 100)
        try await record(store: store, app: "chatgpt", name: "ChatGPT", date: now.addingTimeInterval(-600), received: 300, sent: 700)

        let all = try await store.dashboard(period: .today, now: now, calendar: calendar)
        XCTAssertEqual(all.totals, TrafficTotals(receivedBytes: 1_800, sentBytes: 1_000))
        XCTAssertEqual(all.applications.map(\.applicationIdentifier), ["safari", "chatgpt"])
        XCTAssertEqual(all.applications.first?.receivedBytes, 1_500)
        XCTAssertEqual(all.granularity, .fifteenMinutes)
        XCTAssertTrue(all.timeline.contains { $0.totalBytes == 0 }, "Empty intervals should be zero-filled")

        let selected = try await store.dashboard(
            period: .today,
            applicationIdentifier: "chatgpt",
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(selected.totals, TrafficTotals(receivedBytes: 300, sentBytes: 700))
        XCTAssertEqual(selected.applications.count, 2, "Selecting an app must keep the complete ranking")
    }

    func testPeriodsUseCalendarBoundariesAndExpectedGranularity() async throws {
        let store = StatisticsStore(fileURL: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_786_543_200)
        let calendar = utcCalendar
        try await record(store: store, app: "recent", name: "Recent", date: now.addingTimeInterval(-60 * 60), received: 10, sent: 1)
        try await record(store: store, app: "week", name: "Week", date: now.addingTimeInterval(-5 * 24 * 60 * 60), received: 20, sent: 2)
        try await record(store: store, app: "month", name: "Month", date: now.addingTimeInterval(-20 * 24 * 60 * 60), received: 30, sent: 3)
        try await record(store: store, app: "old", name: "Old", date: now.addingTimeInterval(-60 * 24 * 60 * 60), received: 40, sent: 4)

        let today = try await store.dashboard(period: .today, now: now, calendar: calendar)
        let week = try await store.dashboard(period: .sevenDays, now: now, calendar: calendar)
        let month = try await store.dashboard(period: .thirtyDays, now: now, calendar: calendar)
        let all = try await store.dashboard(period: .all, now: now, calendar: calendar)

        XCTAssertEqual(today.granularity, .fifteenMinutes)
        XCTAssertEqual(week.granularity, .hour)
        XCTAssertEqual(month.granularity, .day)
        XCTAssertEqual(all.granularity, .day)
        XCTAssertEqual(today.totals.totalBytes, 11)
        XCTAssertEqual(week.totals.totalBytes, 33)
        XCTAssertEqual(month.totals.totalBytes, 66)
        XCTAssertEqual(all.totals.totalBytes, 110)
    }

    func testMaintenancePreservesTotalsAndIsIdempotent() async throws {
        let store = StatisticsStore(fileURL: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_786_543_200)
        let calendar = utcCalendar
        try await record(store: store, app: "recent", name: "Recent", date: now.addingTimeInterval(-60 * 60), received: 1_000, sent: 100)
        try await record(store: store, app: "hourly", name: "Hourly", date: now.addingTimeInterval(-10 * 24 * 60 * 60), received: 2_000, sent: 200)
        try await record(store: store, app: "daily", name: "Daily", date: now.addingTimeInterval(-120 * 24 * 60 * 60), received: 3_000, sent: 300)

        let before = try await store.dashboard(period: .all, now: now, calendar: calendar)
        try await store.performMaintenance(now: now)
        let afterFirst = try await store.dashboard(period: .all, now: now, calendar: calendar)
        try await store.performMaintenance(now: now)
        let afterSecond = try await store.dashboard(period: .all, now: now, calendar: calendar)

        XCTAssertEqual(before.totals, TrafficTotals(receivedBytes: 6_000, sentBytes: 600))
        XCTAssertEqual(afterFirst.totals, before.totals)
        XCTAssertEqual(afterSecond.totals, before.totals)
        XCTAssertEqual(afterSecond.applications, afterFirst.applications)
        let storedTotals = try await store.totals()
        XCTAssertEqual(storedTotals, before.totals)
    }

    func testDeleteAllClearsEveryStorageLevel() async throws {
        let store = StatisticsStore(fileURL: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_786_543_200)
        try await record(store: store, app: "old", name: "Old", date: now.addingTimeInterval(-120 * 24 * 60 * 60), received: 10, sent: 5)
        try await store.performMaintenance(now: now)
        try await record(store: store, app: "new", name: "New", date: now, received: 20, sent: 10)

        try await store.deleteAll()
        let snapshot = try await store.dashboard(period: .all, now: now, calendar: utcCalendar)
        XCTAssertEqual(snapshot.totals, TrafficTotals())
        XCTAssertTrue(snapshot.applications.isEmpty)
        let storedTotals = try await store.totals()
        XCTAssertEqual(storedTotals, TrafficTotals())
    }

    private func record(
        store: StatisticsStore,
        app: String,
        name: String,
        date: Date,
        session: UUID = UUID(),
        received: UInt64,
        sent: UInt64
    ) async throws {
        try await store.record(TrafficRecord(
            applicationIdentifier: app,
            displayName: name,
            date: date,
            sessionID: session,
            profileID: UUID(),
            interface: .wifi,
            receivedBytes: received,
            sentBytes: sent
        ))
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "ezgate-statistics-\(UUID().uuidString).sqlite")
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
