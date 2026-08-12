import Foundation
import OSLog
import EZgateCore

final class FilterIPCClient: @unchecked Sendable {
    static let shared = FilterIPCClient()

    private let lock = NSLock()
    private let logger = Logger(subsystem: "ch.ezgate.app", category: "ipc")
    private var connection: NSXPCConnection?

    func updateRules(_ snapshot: SharedRuleSnapshot) async -> Bool {
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        return await withCheckedContinuation { continuation in
            let reply = OneShotReply(continuation)
            guard let proxy = proxy(onError: { [weak self] in
                self?.invalidateConnection()
                reply.resolve(false)
            }) else {
                reply.resolve(false)
                return
            }
            proxy.updateRules(data) { accepted in reply.resolve(accepted) }
        }
    }

    func trafficSnapshot() async -> SharedTrafficSnapshot? {
        let data: Data? = await withCheckedContinuation { continuation in
            let reply = OneShotReply(continuation)
            guard let proxy = proxy(onError: { [weak self] in
                self?.invalidateConnection()
                reply.resolve(nil)
            }) else {
                reply.resolve(nil)
                return
            }
            proxy.trafficSnapshot { data in reply.resolve(data) }
        }
        guard let data else { return nil }
        guard let snapshot = try? JSONDecoder().decode(SharedTrafficSnapshot.self, from: data) else { return nil }
        if !snapshot.applications.isEmpty {
            logger.debug("Received traffic snapshot with \(snapshot.applications.count) applications")
        }
        return snapshot
    }

    func resetTraffic() async -> Bool {
        await withCheckedContinuation { continuation in
            let reply = OneShotReply(continuation)
            guard let proxy = proxy(onError: { [weak self] in
                self?.invalidateConnection()
                reply.resolve(false)
            }) else {
                reply.resolve(false)
                return
            }
            proxy.resetTraffic { accepted in reply.resolve(accepted) }
        }
    }

    private func proxy(onError: @escaping @Sendable () -> Void) -> (any FilterIPCProtocol)? {
        guard let connection = activeConnection() else { return nil }
        return connection.remoteObjectProxyWithErrorHandler { (_: any Error) in
            onError()
        } as? any FilterIPCProtocol
    }

    private func activeConnection() -> NSXPCConnection? {
        lock.lock()
        defer { lock.unlock() }
        if let connection { return connection }
        let newConnection = NSXPCConnection(machServiceName: FilterIPCConfiguration.machServiceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: FilterIPCProtocol.self)
        newConnection.invalidationHandler = { [weak self] in self?.invalidateConnection() }
        newConnection.interruptionHandler = { [weak self] in self?.invalidateConnection() }
        newConnection.activate()
        connection = newConnection
        return newConnection
    }

    private func invalidateConnection() {
        lock.lock()
        let staleConnection = connection
        connection = nil
        lock.unlock()
        staleConnection?.invalidate()
    }
}

private final class OneShotReply<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resolve(_ value: Value) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
