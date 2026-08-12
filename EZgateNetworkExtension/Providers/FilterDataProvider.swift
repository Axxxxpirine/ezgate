import Foundation
import NetworkExtension
import OSLog
import Security
import EZgateCore

final class FilterDataProvider: NEFilterDataProvider {
    private let ruleEngine = RuleEngine()
    private let logger = Logger(subsystem: "ch.ezgate.app.network-extension", category: "filtering")
    private var snapshot: SharedRuleSnapshot?
    private var lastRulesModificationDate: Date?
    private let trafficAccumulator = TrafficReportAccumulator()

    override func startFilter(completionHandler: @escaping ((any Error)?) -> Void) {
        reloadRules()
        let settings = NEFilterSettings(rules: [], defaultAction: .filterData)
        apply(settings) { [weak self] error in
            if let error {
                self?.logger.error("Unable to apply filter settings: \(error.localizedDescription, privacy: .public)")
            } else {
                self?.logger.notice("EZgate filter started")
            }
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.notice("EZgate filter stopped, reason: \(reason.rawValue)")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        reloadRulesIfChanged()
        guard let snapshot else {
            let verdict = NEFilterNewFlowVerdict.allow()
            verdict.shouldReport = true
            verdict.statisticsReportFrequency = .medium
            return verdict
        }

        let identifier = FlowIdentityResolver.signingIdentifier(for: flow)
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
        let verdict: NEFilterNewFlowVerdict = decision.isAllowed ? .allow() : .drop()
        verdict.shouldReport = true
        verdict.statisticsReportFrequency = .medium
        return verdict
    }

    override func handle(_ report: NEFilterReport) {
        guard let flow = report.flow,
              report.event == .statistics || report.event == .flowClosed else { return }
        let signingIdentifier = FlowIdentityResolver.signingIdentifier(for: flow)
        let event = TrafficReportEvent(
            flowIdentifier: flow.identifier.uuidString,
            signingIdentifier: signingIdentifier,
            receivedBytes: UInt64(report.bytesInboundCount),
            sentBytes: UInt64(report.bytesOutboundCount),
            isClosed: report.event == .flowClosed,
            timestamp: .now
        )
        let accumulator = trafficAccumulator
        Task { await accumulator.record(event) }
    }

    private func reloadRules() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedRuleSnapshotStore.appGroupIdentifier
        ) else {
            logger.error("App Group container unavailable; failing open")
            snapshot = nil
            return
        }
        do {
            let fileURL = SharedRuleSnapshotStore.fileURL(containerURL: containerURL)
            snapshot = try SharedRuleSnapshotStore.read(from: fileURL)
            lastRulesModificationDate = try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch {
            logger.warning("No readable rules snapshot; failing open: \(error.localizedDescription, privacy: .public)")
            snapshot = nil
        }
    }

    private func reloadRulesIfChanged() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedRuleSnapshotStore.appGroupIdentifier
        ) else { return }
        let fileURL = SharedRuleSnapshotStore.fileURL(containerURL: containerURL)
        let modificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        if modificationDate != lastRulesModificationDate { reloadRules() }
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

private actor TrafficReportAccumulator {
    private struct FlowTotals: Sendable {
        var receivedBytes: UInt64
        var sentBytes: UInt64
        var timestamp: Date
    }

    private var flows: [String: FlowTotals] = [:]
    private var applications: [String: AppTraffic] = [:]
    private var lastPublishDate = Date.distantPast

    func record(_ event: TrafficReportEvent) {
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

        if event.isClosed {
            flows.removeValue(forKey: event.flowIdentifier)
        } else {
            flows[event.flowIdentifier] = FlowTotals(
                receivedBytes: event.receivedBytes,
                sentBytes: event.sentBytes,
                timestamp: event.timestamp
            )
        }

        guard event.timestamp.timeIntervalSince(lastPublishDate) >= 0.75,
              let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedRuleSnapshotStore.appGroupIdentifier
              ) else { return }
        do {
            let snapshot = SharedTrafficSnapshot(
                updatedAt: event.timestamp,
                applications: applications.values.sorted { $0.totalBytes > $1.totalBytes }
            )
            try SharedTrafficSnapshotStore.write(
                snapshot,
                to: SharedTrafficSnapshotStore.fileURL(containerURL: containerURL)
            )
            lastPublishDate = event.timestamp
        } catch {
            // The next report retries the atomic snapshot write.
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
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dictionary = information as? [CFString: Any] else { return nil }
        return dictionary[kSecCodeInfoIdentifier] as? String
    }
}
