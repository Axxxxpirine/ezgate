import AppKit
import Foundation
import EZgateCore

final class RealTrafficProvider: TrafficProvider, @unchecked Sendable {
    private let client = FilterIPCClient.shared

    func updates() -> AsyncStream<[AppTraffic]> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) { [client] in
                var previousSnapshot: SharedTrafficSnapshot?
                while !Task.isCancelled {
                    if let snapshot = await client.trafficSnapshot() {
                        let rows = TrafficRateCalculator.applyingRates(
                            to: snapshot,
                            previous: previousSnapshot
                        )
                        continuation.yield(rows.map(self.enrichIdentity))
                        previousSnapshot = snapshot
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func enrichIdentity(_ row: AppTraffic) -> AppTraffic {
        guard let bundleIdentifier = row.identity.bundleIdentifier,
              let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
              ) else { return row }
        let bundle = Bundle(url: applicationURL)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent
        return AppTraffic(
            identity: AppIdentity(
                bundleIdentifier: bundleIdentifier,
                signingIdentifier: row.identity.signingIdentifier,
                displayName: name,
                executableURL: applicationURL
            ),
            receivedBytes: row.receivedBytes,
            sentBytes: row.sentBytes,
            receivedBytesPerSecond: row.receivedBytesPerSecond,
            sentBytesPerSecond: row.sentBytesPerSecond
        )
    }
}
