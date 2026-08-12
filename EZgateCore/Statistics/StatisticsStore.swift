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
    // SQLite is opened and used only through this actor. `deinit` is nonisolated,
    // so the storage needs this annotation solely to close the native handle.
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
        var conditions: [String] = []
        if sessionID != nil { conditions.append("session_id = ?") }
        if since != nil { conditions.append("recorded_at >= ?") }
        let whereClause = conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND ")
        let sql = "SELECT COALESCE(SUM(rx_bytes), 0), COALESCE(SUM(tx_bytes), 0) FROM traffic_samples\(whereClause);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepare(message(database))
        }
        defer { sqlite3_finalize(statement) }
        var index: Int32 = 1
        if let sessionID {
            bind(sessionID.uuidString, at: index, statement: statement)
            index += 1
        }
        if let since { sqlite3_bind_double(statement, index, since.timeIntervalSince1970) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw StoreError.execute(message(database))
        }
        return TrafficTotals(
            receivedBytes: UInt64(max(0, sqlite3_column_int64(statement, 0))),
            sentBytes: UInt64(max(0, sqlite3_column_int64(statement, 1)))
        )
    }

    public func deleteAll() throws {
        let database = try openIfNeeded()
        guard sqlite3_exec(database, "DELETE FROM traffic_samples;", nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execute(message(database))
        }
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
        """
        guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.execute(message(handle))
        }
        return handle
    }

    private func bind(_ value: String, at index: Int32, statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
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
