import Foundation
import NetworkExtension
import OSLog
import Security
import EZgateCore

final class FilterDataProvider: NEFilterDataProvider {
    private let ruleEngine = RuleEngine()
    private let logger = Logger(subsystem: "ch.ezgate.app.network-extension", category: "filtering")
    private let ruleState = RuleState()
    private let trafficAccumulator = TrafficReportAccumulator()
    private let flowIdentityCache = FlowIdentityCache()
    private var ipcServer: FilterIPCServer?

    override func startFilter(completionHandler: @escaping ((any Error)?) -> Void) {
        ipcServer = FilterIPCServer(
            machServiceName: FilterIPCConfiguration.machServiceName,
            ruleState: ruleState,
            trafficAccumulator: trafficAccumulator
        )
        ipcServer?.start()

        let settings = NEFilterSettings(rules: [], defaultAction: .filterData)
        apply(settings) { [weak self] error in
            if let error {
                self?.logger.error("Unable to apply filter settings: \(error.localizedDescription, privacy: .public)")
            } else {
                self?.logger.notice("EZgate filter started with XPC communication")
            }
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        ipcServer?.stop()
        logger.notice("EZgate filter stopped, reason: \(reason.rawValue)")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let snapshot = ruleState.load() else {
            return reportingVerdict(allowed: true)
        }

        let identifier = FlowIdentityResolver.signingIdentifier(for: flow)
        flowIdentityCache.store(identifier, for: flow.identifier.uuidString)
        let identity = AppIdentity(
            bundleIdentifier: identifier,
            signingIdentifier: identifier,
            displayName: identifier ?? "Unknown application"
        )
        let decision = ruleEngine.decide(
            for: identity,
            profile: snapshot.activeProfile,
            filteringPaused: snapshot.filteringPaused
        )
        return reportingVerdict(allowed: decision.isAllowed)
    }

    override func handle(_ report: NEFilterReport) {
        guard let flow = report.flow,
              report.event == .statistics || report.event == .flowClosed else { return }
        let flowIdentifier = flow.identifier.uuidString
        let cachedIdentity = flowIdentityCache.load(for: flowIdentifier)
        let signingIdentifier: String?
        if cachedIdentity.found {
            signingIdentifier = cachedIdentity.identifier
        } else {
            signingIdentifier = FlowIdentityResolver.signingIdentifier(for: flow)
            flowIdentityCache.store(signingIdentifier, for: flowIdentifier)
        }
        trafficAccumulator.record(
            TrafficReportEvent(
                flowIdentifier: flowIdentifier,
                signingIdentifier: signingIdentifier,
                receivedBytes: UInt64(report.bytesInboundCount),
                sentBytes: UInt64(report.bytesOutboundCount),
                isClosed: report.event == .flowClosed,
                timestamp: .now
            )
        )
        if report.event == .flowClosed {
            flowIdentityCache.remove(for: flowIdentifier)
        }
    }

    private func reportingVerdict(allowed: Bool) -> NEFilterNewFlowVerdict {
        let verdict: NEFilterNewFlowVerdict = allowed ? .allow() : .drop()
        verdict.shouldReport = true
        verdict.statisticsReportFrequency = .medium
        return verdict
    }
}

private final class FlowIdentityCache: @unchecked Sendable {
    private let lock = NSLock()
    private var identifiers: [String: String] = [:]
    private static let unknownSentinel = "\0"

    func store(_ identifier: String?, for flowIdentifier: String) {
        lock.withLock { identifiers[flowIdentifier] = identifier ?? Self.unknownSentinel }
    }

    func load(for flowIdentifier: String) -> (found: Bool, identifier: String?) {
        lock.withLock {
            guard let value = identifiers[flowIdentifier] else { return (false, nil) }
            return (true, value == Self.unknownSentinel ? nil : value)
        }
    }

    func remove(for flowIdentifier: String) {
        lock.withLock { _ = identifiers.removeValue(forKey: flowIdentifier) }
    }
}

private final class RuleState: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: SharedRuleSnapshot?

    func load() -> SharedRuleSnapshot? {
        lock.withLock { snapshot }
    }

    func store(_ snapshot: SharedRuleSnapshot) {
        lock.withLock { self.snapshot = snapshot }
    }
}

private final class FilterIPCServer: NSObject, NSXPCListenerDelegate, FilterIPCProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "ch.ezgate.app.network-extension", category: "ipc")
    private let listener: NSXPCListener
    private let ruleState: RuleState
    private let trafficAccumulator: TrafficReportAccumulator

    init(machServiceName: String, ruleState: RuleState, trafficAccumulator: TrafficReportAccumulator) {
        listener = NSXPCListener(machServiceName: machServiceName)
        self.ruleState = ruleState
        self.trafficAccumulator = trafficAccumulator
        super.init()
        listener.delegate = self
    }

    func start() { listener.activate() }
    func stop() { listener.invalidate() }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: FilterIPCProtocol.self)
        connection.exportedObject = self
        connection.activate()
        return true
    }

    func updateRules(_ data: Data, withReply reply: @escaping (Bool) -> Void) {
        guard let snapshot = try? JSONDecoder().decode(SharedRuleSnapshot.self, from: data) else {
            reply(false)
            return
        }
        ruleState.store(snapshot)
        logger.notice("Accepted rule snapshot revision \(snapshot.revision)")
        reply(true)
    }

    func trafficSnapshot(withReply reply: @escaping (Data?) -> Void) {
        reply(trafficAccumulator.encodedSnapshot())
    }
}

private struct TrafficReportEvent: Sendable {
    let flowIdentifier: String
    let signingIdentifier: String?
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let isClosed: Bool
    let timestamp: Date
}

private final class TrafficReportAccumulator: @unchecked Sendable {
    private struct FlowTotals: Sendable {
        var receivedBytes: UInt64
        var sentBytes: UInt64
        var timestamp: Date
    }

    private let lock = NSLock()
    private let logger = Logger(subsystem: "ch.ezgate.app.network-extension", category: "traffic")
    private var flows: [String: FlowTotals] = [:]
    private var applications: [String: AppTraffic] = [:]
    private var lastUpdateDate = Date.distantPast
    private var hasLoggedFirstSnapshot = false

    func record(_ event: TrafficReportEvent) {
        lock.withLock {
            let key = event.signingIdentifier ?? "unknown"
            let previous = flows[event.flowIdentifier]
            let receivedDelta = event.receivedBytes >= (previous?.receivedBytes ?? 0)
                ? event.receivedBytes - (previous?.receivedBytes ?? 0) : 0
            let sentDelta = event.sentBytes >= (previous?.sentBytes ?? 0)
                ? event.sentBytes - (previous?.sentBytes ?? 0) : 0
            let interval = max(event.timestamp.timeIntervalSince(previous?.timestamp ?? event.timestamp), 1)

            var row = applications[key] ?? AppTraffic(
                identity: AppIdentity(
                    bundleIdentifier: event.signingIdentifier,
                    signingIdentifier: event.signingIdentifier,
                    displayName: event.signingIdentifier ?? "Unknown application"
                ),
                receivedBytes: 0,
                sentBytes: 0
            )
            row.receivedBytes &+= receivedDelta
            row.sentBytes &+= sentDelta
            row.receivedBytesPerSecond = Double(receivedDelta) / interval
            row.sentBytesPerSecond = Double(sentDelta) / interval
            applications[key] = row
            lastUpdateDate = event.timestamp

            if event.isClosed {
                flows.removeValue(forKey: event.flowIdentifier)
            } else {
                flows[event.flowIdentifier] = FlowTotals(
                    receivedBytes: event.receivedBytes,
                    sentBytes: event.sentBytes,
                    timestamp: event.timestamp
                )
            }
        }
    }

    func encodedSnapshot() -> Data? {
        lock.withLock {
            if !applications.isEmpty, !hasLoggedFirstSnapshot {
                hasLoggedFirstSnapshot = true
                logger.notice("Returning first real traffic snapshot with \(self.applications.count) applications")
            }
            let snapshot = SharedTrafficSnapshot(
                updatedAt: lastUpdateDate,
                applications: applications.values.sorted { $0.totalBytes > $1.totalBytes }
            )
            return try? JSONEncoder().encode(snapshot)
        }
    }
}

private enum FlowIdentityResolver {
    static func signingIdentifier(for flow: NEFilterFlow) -> String? {
        guard let auditToken = flow.sourceAppAuditToken ?? flow.sourceProcessAuditToken else { return nil }
        var code: SecCode?
        let attributes = [kSecGuestAttributeAudit: auditToken] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let code else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
              let dictionary = information as? [CFString: Any] else { return nil }
        return dictionary[kSecCodeInfoIdentifier] as? String
    }
}
