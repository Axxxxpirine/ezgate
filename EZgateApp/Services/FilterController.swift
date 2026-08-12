import Foundation
@preconcurrency import NetworkExtension
import Observation
import OSLog
import SystemExtensions
import EZgateCore

enum FilterStatus: Equatable {
    case inactive
    case installing
    case awaitingApproval
    case enabling
    case active
    case rebootRequired
    case failed(String)

    var label: String {
        switch self {
        case .inactive: "Not installed"
        case .installing: "Installing system extension…"
        case .awaitingApproval: "Approval required in System Settings"
        case .enabling: "Enabling network filter…"
        case .active: "Filtering active"
        case .rebootRequired: "Restart required"
        case .failed(let message): "Unavailable: \(message)"
        }
    }

    var isActive: Bool { self == .active }
}

@MainActor
@Observable
final class FilterController: NSObject, @preconcurrency OSSystemExtensionRequestDelegate {
    static let extensionIdentifier = "ch.ezgate.app.network-extension"

    private(set) var status: FilterStatus = .inactive
    var onFilterActive: (() -> Void)?
    private let logger = Logger(subsystem: "ch.ezgate.app", category: "filter-controller")

    func refresh(activateIfInactive: Bool = false) {
        logger.notice("Loading Network Extension preferences; activate if inactive: \(activateIfInactive)")
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.logger.error("Unable to load filter preferences: \(error.localizedDescription, privacy: .public)")
                    self.status = .failed(error.localizedDescription)
                } else {
                    self.logger.notice("Filter preferences loaded; enabled: \(manager.isEnabled)")
                    if manager.isEnabled {
                        self.status = .active
                        if activateIfInactive { self.activate() }
                    } else if activateIfInactive {
                        self.activate()
                    } else {
                        self.status = .inactive
                    }
                }
            }
        }
    }

    func activate() {
        logger.notice("Submitting activation request for \(Self.extensionIdentifier, privacy: .public)")
        status = .installing
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.notice("System Extension requires user approval")
        status = .awaitingApproval
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        if result == .willCompleteAfterReboot {
            logger.notice("System Extension activation requires restart")
            status = .rebootRequired
        } else {
            logger.notice("System Extension activated; configuring filter")
            configureAndEnableFilter()
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: any Error) {
        logger.error("System Extension activation failed: \(error.localizedDescription, privacy: .public)")
        status = .failed(error.localizedDescription)
    }

    private func configureAndEnableFilter() {
        logger.notice("Configuring NEFilterManager")
        status = .enabling
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] loadError in
            Task { @MainActor in
                guard let self else { return }
                if let loadError {
                    self.logger.error("Unable to reload filter preferences: \(loadError.localizedDescription, privacy: .public)")
                    self.status = .failed(loadError.localizedDescription)
                    return
                }

                let configuration = NEFilterProviderConfiguration()
                configuration.filterSockets = true
                configuration.filterDataProviderBundleIdentifier = Self.extensionIdentifier
                configuration.organization = "EZgate"
                manager.localizedDescription = "EZgate Application Firewall"
                manager.providerConfiguration = configuration
                manager.grade = .firewall
                manager.isEnabled = true
                manager.saveToPreferences { [weak self] saveError in
                    Task { @MainActor in
                        guard let self else { return }
                        if let saveError {
                            self.logger.error("Unable to enable filter: \(saveError.localizedDescription, privacy: .public)")
                        } else {
                            self.logger.notice("Network filter enabled")
                            self.onFilterActive?()
                        }
                        self.status = saveError.map { .failed($0.localizedDescription) } ?? .active
                    }
                }
            }
        }
    }
}
