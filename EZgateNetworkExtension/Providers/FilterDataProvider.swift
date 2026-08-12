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
