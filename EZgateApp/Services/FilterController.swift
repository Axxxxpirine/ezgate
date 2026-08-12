import Foundation
@preconcurrency import NetworkExtension
import Observation
import SystemExtensions

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

    func refresh(activateIfInactive: Bool = false) {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.status = .failed(error.localizedDescription)
                } else {
                    if manager.isEnabled {
                        self.status = .active
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
        status = .awaitingApproval
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        if result == .willCompleteAfterReboot {
            status = .rebootRequired
        } else {
            configureAndEnableFilter()
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: any Error) {
        status = .failed(error.localizedDescription)
    }

    private func configureAndEnableFilter() {
        status = .enabling
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] loadError in
            Task { @MainActor in
                guard let self else { return }
                if let loadError {
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
                        self.status = saveError.map { .failed($0.localizedDescription) } ?? .active
                    }
                }
            }
        }
    }
}
