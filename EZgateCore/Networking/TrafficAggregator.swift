import Foundation

public struct TrafficAggregator: Sendable {
    public init() {}

    public func aggregate(_ samples: [ProcessTrafficSample]) -> [AppTraffic] {
        var grouped: [String: AppTraffic] = [:]

        for sample in samples {
            let key = sample.identity.id
            if var existing = grouped[key] {
                existing.receivedBytes &+= sample.receivedBytes
                existing.sentBytes &+= sample.sentBytes
                existing.receivedBytesPerSecond += sample.receivedBytesPerSecond
                existing.sentBytesPerSecond += sample.sentBytesPerSecond
                let merged = AppIdentity(
                    bundleIdentifier: existing.identity.bundleIdentifier ?? sample.identity.bundleIdentifier,
                    signingIdentifier: existing.identity.signingIdentifier ?? sample.identity.signingIdentifier,
                    displayName: existing.identity.displayName,
                    executableURL: existing.identity.executableURL ?? sample.identity.executableURL,
                    processIdentifiers: existing.identity.processIdentifiers.union([sample.processIdentifier]),
                    processNames: existing.identity.processNames.union([sample.processName])
                )
                existing = AppTraffic(
                    identity: merged,
                    receivedBytes: existing.receivedBytes,
                    sentBytes: existing.sentBytes,
                    receivedBytesPerSecond: existing.receivedBytesPerSecond,
                    sentBytesPerSecond: existing.sentBytesPerSecond
                )
                grouped[key] = existing
            } else {
                let identity = AppIdentity(
                    bundleIdentifier: sample.identity.bundleIdentifier,
                    signingIdentifier: sample.identity.signingIdentifier,
                    displayName: sample.identity.displayName,
                    executableURL: sample.identity.executableURL,
                    processIdentifiers: sample.identity.processIdentifiers.union([sample.processIdentifier]),
                    processNames: sample.identity.processNames.union([sample.processName])
                )
                grouped[key] = AppTraffic(
                    identity: identity,
                    receivedBytes: sample.receivedBytes,
                    sentBytes: sample.sentBytes,
                    receivedBytesPerSecond: sample.receivedBytesPerSecond,
                    sentBytesPerSecond: sample.sentBytesPerSecond
                )
            }
        }

        return Array(grouped.values)
    }
}

