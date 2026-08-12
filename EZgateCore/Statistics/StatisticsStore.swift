import Foundation
import SQLite3

public actor StatisticsStore {
    public enum StoreError: Error, LocalizedError {
        case open(String)
        case prepare(String)
        case execute(String)

        public var errorDescription: String? {
            switch self {
            case .open(let message): "Unable to open statistics database: \(message)"
            case .prepare(let message): "Unable to prepare statistics query: \(message)"
            case .execute(let message): "Unable to update statistics: \(message)"
            }
        }
    }

    private let fileURL: URL
    nonisolated(unsafe) private var database: OpaquePointer?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    public func record(_ record: TrafficRecord) throws {
        let database = try openIfNeeded()
        let sql = """
        INSERT INTO traffic_samples
        (application_identifier, display_name, recorded_at, session_id, profile_id, interface, rx_bytes, tx_bytes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepare(message(database))
        }
        defer { sqlite3_finalize(statement) }

        bind(record.applicationIdentifier, at: 1, statement: statement)
        bind(record.displayName, at: 2, statement: statement)
        sqlite3_bind_double(statement, 3, record.date.timeIntervalSince1970)
        bind(record.sessionID.uuidString, at: 4, statement: statement)
        bind(record.profileID.uuidString, at: 5, statement: statement)
        bind(record.interface.rawValue, at: 6, statement: statement)
        sqlite3_bind_int64(statement, 7, sqlite3_int64(clamping: record.receivedBytes))
        sqlite3_bind_int64(statement, 8, sqlite3_int64(clamping: record.sentBytes))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.execute(message(database))
        }
    }

    public func totals(for sessionID: UUID? = nil, since: Date? = nil) throws -> TrafficTotals {
        let database = try openIfNeeded()
        if sessionID == nil {
            let dateFilter = since == nil ? "" : " WHERE traffic_date >= ?"
            let sql = """
            WITH all_traffic AS (\(trafficUnion))
            SELECT COALESCE(SUM(rx_bytes), 0), COALESCE(SUM(tx_bytes), 0)
            FROM all_traffic\(dateFilter);
            """
            let statement = try prepare(database, sql)
            defer { sqlite3_finalize(statement) }
            if let since { sqlite3_bind_double(statement, 1, since.timeIntervalSince1970) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw StoreError.execute(message(database))
            }
            return TrafficTotals(
                receivedBytes: unsignedColumn(statement, 0),
                sentBytes: unsignedColumn(statement, 1)
            )
        }
        var conditions: [String] = []
        conditions.append("session_id = ?")
        if since != nil { conditions.append("recorded_at >= ?") }
        let whereClause = conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND ")
        let sql = "SELECT COALESCE(SUM(rx_bytes), 0), COALESCE(SUM(tx_bytes), 0) FROM traffic_samples\(whereClause);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepare(message(database))
        }
        defer { sqlite3_finalize(statement) }
        var index: Int32 = 1
        bind(sessionID!.uuidString, at: index, statement: statement)
        index += 1
        if let since { sqlite3_bind_double(statement, index, since.timeIntervalSince1970) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw StoreError.execute(message(database))
        }
        return TrafficTotals(
            receivedBytes: unsignedColumn(statement, 0),
            sentBytes: unsignedColumn(statement, 1)
        )
    }

    public func dashboard(
        period: StatisticsPeriod,
        applicationIdentifier: String? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> StatisticsSnapshot {
        let database = try openIfNeeded()
        let requestedStart = period.startDate(relativeTo: now, calendar: calendar)
        let earliest = try earliestDate(database: database)
        let rangeStart = requestedStart ?? earliest ?? now
        let rangeEnd = now
        let granularity = granularity(for: period, from: rangeStart, to: rangeEnd)
        let applications = try applicationSummaries(
            database: database,
            from: rangeStart,
            to: rangeEnd
        )
        let timeline = try timeline(
            database: database,
            from: rangeStart,
            to: rangeEnd,
            granularity: granularity,
            applicationIdentifier: applicationIdentifier,
            calendar: calendar
        )
        let totals = timeline.reduce(into: TrafficTotals()) { totals, point in
            totals.receivedBytes &+= point.receivedBytes
            totals.sentBytes &+= point.sentBytes
        }
        return StatisticsSnapshot(
            period: period,
            selectedApplicationIdentifier: applicationIdentifier,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            granularity: granularity,
            totals: totals,
            applications: applications,
            timeline: timeline
        )
    }

    public func performMaintenance(now: Date = .now) throws {
        let database = try openIfNeeded()
        let rawCutoff = now.addingTimeInterval(-48 * 60 * 60).timeIntervalSince1970
        let hourlyCutoff = now.addingTimeInterval(-90 * 24 * 60 * 60).timeIntervalSince1970
        try execute(database, "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute(database, """
            INSERT INTO traffic_hourly
                (application_identifier, display_name, bucket_start, last_activity, rx_bytes, tx_bytes)
            SELECT application_identifier, MAX(display_name),
                   CAST(recorded_at / 3600 AS INTEGER) * 3600,
                   MAX(recorded_at), SUM(rx_bytes), SUM(tx_bytes)
            FROM traffic_samples
            WHERE recorded_at < \(rawCutoff)
            GROUP BY application_identifier, CAST(recorded_at / 3600 AS INTEGER)
            ON CONFLICT(application_identifier, bucket_start) DO UPDATE SET
                display_name = excluded.display_name,
                last_activity = MAX(traffic_hourly.last_activity, excluded.last_activity),
                rx_bytes = traffic_hourly.rx_bytes + excluded.rx_bytes,
                tx_bytes = traffic_hourly.tx_bytes + excluded.tx_bytes;
            DELETE FROM traffic_samples WHERE recorded_at < \(rawCutoff);

            INSERT INTO traffic_daily
                (application_identifier, display_name, bucket_start, last_activity, rx_bytes, tx_bytes)
            SELECT application_identifier, MAX(display_name),
                   CAST(strftime('%s', datetime(bucket_start, 'unixepoch', 'localtime', 'start of day'), 'utc') AS REAL),
                   MAX(last_activity), SUM(rx_bytes), SUM(tx_bytes)
            FROM traffic_hourly
            WHERE bucket_start < \(hourlyCutoff)
            GROUP BY application_identifier,
                     datetime(bucket_start, 'unixepoch', 'localtime', 'start of day')
            ON CONFLICT(application_identifier, bucket_start) DO UPDATE SET
                display_name = excluded.display_name,
                last_activity = MAX(traffic_daily.last_activity, excluded.last_activity),
                rx_bytes = traffic_daily.rx_bytes + excluded.rx_bytes,
                tx_bytes = traffic_daily.tx_bytes + excluded.tx_bytes;
            DELETE FROM traffic_hourly WHERE bucket_start < \(hourlyCutoff);
            """)
            try execute(database, "COMMIT;")
        } catch {
            try? execute(database, "ROLLBACK;")
            throw error
        }
    }

    public func deleteAll() throws {
        let database = try openIfNeeded()
        try execute(database, "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute(database, """
            DELETE FROM traffic_samples;
            DELETE FROM traffic_hourly;
            DELETE FROM traffic_daily;
            """)
            try execute(database, "COMMIT;")
        } catch {
            try? execute(database, "ROLLBACK;")
            throw error
        }
    }

    private func applicationSummaries(
        database: OpaquePointer,
        from start: Date,
        to end: Date
    ) throws -> [StatisticsApplicationSummary] {
        let sql = """
        WITH all_traffic AS (\(trafficUnion))
        SELECT application_identifier, MAX(display_name),
               COALESCE(SUM(rx_bytes), 0), COALESCE(SUM(tx_bytes), 0), MAX(last_activity)
        FROM all_traffic
        WHERE traffic_date >= ? AND traffic_date <= ?
        GROUP BY application_identifier
        ORDER BY SUM(rx_bytes + tx_bytes) DESC;
        """
        let statement = try prepare(database, sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, end.timeIntervalSince1970)
        var results: [StatisticsApplicationSummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(StatisticsApplicationSummary(
                applicationIdentifier: textColumn(statement, 0),
                displayName: textColumn(statement, 1),
                receivedBytes: unsignedColumn(statement, 2),
                sentBytes: unsignedColumn(statement, 3),
                lastActivity: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            ))
        }
        return results
    }

    private func timeline(
        database: OpaquePointer,
        from start: Date,
        to end: Date,
        granularity: StatisticsGranularity,
        applicationIdentifier: String?,
        calendar: Calendar
    ) throws -> [StatisticsTimePoint] {
        let filter = applicationIdentifier == nil ? "" : " AND application_identifier = ?"
        let sql = """
        WITH all_traffic AS (\(trafficUnion))
        SELECT traffic_date, rx_bytes, tx_bytes
        FROM all_traffic
        WHERE traffic_date >= ? AND traffic_date <= ?\(filter)
        ORDER BY traffic_date;
        """
        let statement = try prepare(database, sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, end.timeIntervalSince1970)
        if let applicationIdentifier { bind(applicationIdentifier, at: 3, statement: statement) }

        var grouped: [Date: TrafficTotals] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let date = Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
            let bucket = bucketStart(for: date, granularity: granularity, calendar: calendar)
            var totals = grouped[bucket, default: TrafficTotals()]
            totals.receivedBytes &+= unsignedColumn(statement, 1)
            totals.sentBytes &+= unsignedColumn(statement, 2)
            grouped[bucket] = totals
        }

        let firstBucket = bucketStart(for: start, granularity: granularity, calendar: calendar)
        let lastBucket = bucketStart(for: end, granularity: granularity, calendar: calendar)
        var result: [StatisticsTimePoint] = []
        var cursor = firstBucket
        while cursor <= lastBucket {
            let totals = grouped[cursor, default: TrafficTotals()]
            result.append(StatisticsTimePoint(
                date: cursor,
                receivedBytes: totals.receivedBytes,
                sentBytes: totals.sentBytes
            ))
            guard let next = nextBucket(after: cursor, granularity: granularity, calendar: calendar), next > cursor else {
                break
            }
            cursor = next
        }
        return result
    }

    private func earliestDate(database: OpaquePointer) throws -> Date? {
        let sql = """
        WITH all_dates AS (
            SELECT recorded_at AS traffic_date FROM traffic_samples
            UNION ALL SELECT bucket_start FROM traffic_hourly
            UNION ALL SELECT bucket_start FROM traffic_daily
        )
        SELECT MIN(traffic_date) FROM all_dates;
        """
        let statement = try prepare(database, sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_type(statement, 0) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
    }

    private func granularity(for period: StatisticsPeriod, from start: Date, to end: Date) -> StatisticsGranularity {
        switch period {
        case .today: .fifteenMinutes
        case .sevenDays: .hour
        case .thirtyDays: .day
        case .all: end.timeIntervalSince(start) > 2 * 365 * 24 * 60 * 60 ? .week : .day
        }
    }

    private func bucketStart(
        for date: Date,
        granularity: StatisticsGranularity,
        calendar: Calendar
    ) -> Date {
        switch granularity {
        case .fifteenMinutes:
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            var bucket = components
            bucket.minute = ((components.minute ?? 0) / 15) * 15
            return calendar.date(from: bucket) ?? date
        case .hour:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private func nextBucket(
        after date: Date,
        granularity: StatisticsGranularity,
        calendar: Calendar
    ) -> Date? {
        switch granularity {
        case .fifteenMinutes: calendar.date(byAdding: .minute, value: 15, to: date)
        case .hour: calendar.date(byAdding: .hour, value: 1, to: date)
        case .day: calendar.date(byAdding: .day, value: 1, to: date)
        case .week: calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        }
    }

    private var trafficUnion: String {
        """
        SELECT application_identifier, display_name, recorded_at AS traffic_date,
               recorded_at AS last_activity, rx_bytes, tx_bytes
        FROM traffic_samples
        UNION ALL
        SELECT application_identifier, display_name, bucket_start,
               last_activity, rx_bytes, tx_bytes
        FROM traffic_hourly
        UNION ALL
        SELECT application_identifier, display_name, bucket_start,
               last_activity, rx_bytes, tx_bytes
        FROM traffic_daily
        """
    }

    private func openIfNeeded() throws -> OpaquePointer {
        if let database { return database }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var handle: OpaquePointer?
        guard sqlite3_open_v2(fileURL.path, &handle, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let handle else {
            throw StoreError.open(message(handle))
        }
        database = handle
        let schema = """
        PRAGMA journal_mode = WAL;
        CREATE TABLE IF NOT EXISTS traffic_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            application_identifier TEXT NOT NULL,
            display_name TEXT NOT NULL,
            recorded_at REAL NOT NULL,
            session_id TEXT NOT NULL,
            profile_id TEXT NOT NULL,
            interface TEXT NOT NULL,
            rx_bytes INTEGER NOT NULL CHECK(rx_bytes >= 0),
            tx_bytes INTEGER NOT NULL CHECK(tx_bytes >= 0)
        );
        CREATE INDEX IF NOT EXISTS traffic_samples_date ON traffic_samples(recorded_at);
        CREATE INDEX IF NOT EXISTS traffic_samples_session ON traffic_samples(session_id);
        CREATE INDEX IF NOT EXISTS traffic_samples_app_date ON traffic_samples(application_identifier, recorded_at);

        CREATE TABLE IF NOT EXISTS traffic_hourly (
            application_identifier TEXT NOT NULL,
            display_name TEXT NOT NULL,
            bucket_start REAL NOT NULL,
            last_activity REAL NOT NULL,
            rx_bytes INTEGER NOT NULL CHECK(rx_bytes >= 0),
            tx_bytes INTEGER NOT NULL CHECK(tx_bytes >= 0),
            PRIMARY KEY(application_identifier, bucket_start)
        );
        CREATE INDEX IF NOT EXISTS traffic_hourly_date ON traffic_hourly(bucket_start);

        CREATE TABLE IF NOT EXISTS traffic_daily (
            application_identifier TEXT NOT NULL,
            display_name TEXT NOT NULL,
            bucket_start REAL NOT NULL,
            last_activity REAL NOT NULL,
            rx_bytes INTEGER NOT NULL CHECK(rx_bytes >= 0),
            tx_bytes INTEGER NOT NULL CHECK(tx_bytes >= 0),
            PRIMARY KEY(application_identifier, bucket_start)
        );
        CREATE INDEX IF NOT EXISTS traffic_daily_date ON traffic_daily(bucket_start);
        """
        guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execute(message(handle))
        }
        return handle
    }

    private func prepare(_ database: OpaquePointer, _ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw StoreError.prepare(message(database)) }
        return statement
    }

    private func execute(_ database: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execute(message(database))
        }
    }

    private func bind(_ value: String, at index: Int32, statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func textColumn(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private func unsignedColumn(_ statement: OpaquePointer?, _ index: Int32) -> UInt64 {
        UInt64(max(0, sqlite3_column_int64(statement, index)))
    }

    private func message(_ database: OpaquePointer?) -> String {
        guard let database, let value = sqlite3_errmsg(database) else { return "Unknown SQLite error" }
        return String(cString: value)
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "EZgate", directoryHint: .isDirectory)
            .appending(path: "statistics.sqlite")
    }
}

private extension sqlite3_int64 {
    init(clamping value: UInt64) {
        self = value > UInt64(Int64.max) ? Int64.max : Int64(value)
    }
}
