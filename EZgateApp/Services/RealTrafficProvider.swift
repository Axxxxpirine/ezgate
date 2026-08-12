import AppKit
import Foundation
import EZgateCore

final class RealTrafficProvider: TrafficProvider, @unchecked Sendable {
    func updates() -> AsyncStream<[AppTraffic]> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                guard let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: SharedRuleSnapshotStore.appGroupIdentifier
                ) else {
                    continuation.yield([])
                    continuation.finish()
                    return
                }

                let fileURL = SharedTrafficSnapshotStore.fileURL(containerURL: containerURL)
                var lastModificationDate: Date?
                while !Task.isCancelled {
                    let modificationDate = try? fileURL.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ).contentModificationDate
                    if modificationDate != nil, modificationDate != lastModificationDate {
                        do {
                            let snapshot = try SharedTrafficSnapshotStore.read(from: fileURL)
                            continuation.yield(snapshot.applications.map(self.enrichIdentity))
                            lastModificationDate = modificationDate
                        } catch {
                            // Atomic replacement can briefly race a directory notification; retry next tick.
                        }
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
