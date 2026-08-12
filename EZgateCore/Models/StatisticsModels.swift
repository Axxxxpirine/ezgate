import Foundation

public struct TrafficRecord: Codable, Sendable {
    public let applicationIdentifier: String
    public let displayName: String
    public let date: Date
    public let sessionID: UUID
    public let profileID: UUID
    public let interface: NetworkInterfaceKind
    public let receivedBytes: UInt64
    public let sentBytes: UInt64

    public init(
        applicationIdentifier: String,
        displayName: String,
        date: Date = .now,
        sessionID: UUID,
        profileID: UUID,
        interface: NetworkInterfaceKind,
        receivedBytes: UInt64,
        sentBytes: UInt64
    ) {
        self.applicationIdentifier = applicationIdentifier
        self.displayName = displayName
        self.date = date
        self.sessionID = sessionID
        self.profileID = profileID
        self.interface = interface
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }
}

public struct TrafficTotals: Equatable, Sendable {
    public var receivedBytes: UInt64
    public var sentBytes: UInt64

    public init(receivedBytes: UInt64 = 0, sentBytes: UInt64 = 0) {
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }

    public var totalBytes: UInt64 { receivedBytes &+ sentBytes }
}

public enum StatisticsPeriod: String, CaseIterable, Codable, Sendable {
    case today
    case sevenDays
    case thirtyDays
    case all

    public var displayName: String {
        switch self {
        case .today: "Today"
        case .sevenDays: "7 Days"
        case .thirtyDays: "30 Days"
        case .all: "All"
        }
    }

    public func startDate(relativeTo now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .today:
            calendar.startOfDay(for: now)
        case .sevenDays:
            calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        case .thirtyDays:
            calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
        case .all:
            nil
        }
    }
}

public enum StatisticsGranularity: String, Codable, Sendable {
    case fifteenMinutes
    case hour
    case day
    case week

    public var interval: TimeInterval {
        switch self {
        case .fifteenMinutes: 15 * 60
        case .hour: 60 * 60
        case .day: 24 * 60 * 60
        case .week: 7 * 24 * 60 * 60
        }
    }
}

public struct StatisticsApplicationSummary: Identifiable, Equatable, Sendable {
    public let applicationIdentifier: String
    public let displayName: String
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let lastActivity: Date

    public var id: String { applicationIdentifier }
    public var totalBytes: UInt64 { receivedBytes &+ sentBytes }

    public init(
        applicationIdentifier: String,
        displayName: String,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        lastActivity: Date
    ) {
        self.applicationIdentifier = applicationIdentifier
        self.displayName = displayName
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.lastActivity = lastActivity
    }
}

public struct StatisticsTimePoint: Identifiable, Equatable, Sendable {
    public let date: Date
    public let receivedBytes: UInt64
    public let sentBytes: UInt64

    public var id: Date { date }
    public var totalBytes: UInt64 { receivedBytes &+ sentBytes }

    public init(date: Date, receivedBytes: UInt64 = 0, sentBytes: UInt64 = 0) {
        self.date = date
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }
}

public struct StatisticsSnapshot: Equatable, Sendable {
    public let period: StatisticsPeriod
    public let selectedApplicationIdentifier: String?
    public let rangeStart: Date
    public let rangeEnd: Date
    public let granularity: StatisticsGranularity
    public let totals: TrafficTotals
    public let applications: [StatisticsApplicationSummary]
    public let timeline: [StatisticsTimePoint]

    public init(
        period: StatisticsPeriod,
        selectedApplicationIdentifier: String?,
        rangeStart: Date,
        rangeEnd: Date,
        granularity: StatisticsGranularity,
        totals: TrafficTotals,
        applications: [StatisticsApplicationSummary],
        timeline: [StatisticsTimePoint]
    ) {
        self.period = period
        self.selectedApplicationIdentifier = selectedApplicationIdentifier
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.granularity = granularity
        self.totals = totals
        self.applications = applications
        self.timeline = timeline
    }
}
