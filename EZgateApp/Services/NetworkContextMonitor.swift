import Foundation
import Network
import Observation
import EZgateCore

@MainActor
@Observable
final class NetworkContextMonitor {
    private(set) var context = NetworkContext(interface: .unavailable, isAvailable: false)
    var onContextChange: (@MainActor (NetworkContext) -> Void)?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ch.ezgate.network-context", qos: .utility)
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let context = Self.context(from: path)
            Task { @MainActor [weak self] in
                self?.context = context
                self?.onContextChange?(context)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard started else { return }
        monitor.cancel()
        started = false
    }

    private nonisolated static func context(from path: NWPath) -> NetworkContext {
        let kind: NetworkInterfaceKind
        if path.usesInterfaceType(.wifi) {
            kind = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            kind = .ethernet
        } else if path.status == .satisfied {
            kind = .other
        } else {
            kind = .unavailable
        }
        let interfaceName = path.availableInterfaces.first { interface in
            switch kind {
            case .wifi: interface.type == .wifi
            case .ethernet: interface.type == .wiredEthernet
            default: true
            }
        }?.name
        return NetworkContext(
            interface: kind,
            interfaceName: interfaceName,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            isAvailable: path.status == .satisfied
        )
    }
}
