import Foundation
import EZgateCore

final class MockTrafficProvider: TrafficProvider, @unchecked Sendable {
    private struct Seed: Sendable {
        let bundleIdentifier: String
        let name: String
        var receivedBytes: UInt64
        var sentBytes: UInt64
        let receiveRange: ClosedRange<UInt64>
        let sendRange: ClosedRange<UInt64>
    }

    func updates() -> AsyncStream<[AppTraffic]> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                var seeds = [
                    Seed(bundleIdentifier: "com.apple.Safari", name: "Safari", receivedBytes: 42_000_000, sentBytes: 3_000_000, receiveRange: 25_000...1_200_000, sendRange: 4_000...90_000),
                    Seed(bundleIdentifier: "com.openai.chat", name: "ChatGPT", receivedBytes: 18_000_000, sentBytes: 2_000_000, receiveRange: 8_000...520_000, sendRange: 2_000...75_000),
                    Seed(bundleIdentifier: "com.adobe.CoreSync", name: "Adobe CoreSync", receivedBytes: 820_000_000, sentBytes: 28_000_000, receiveRange: 0...2_500_000, sendRange: 0...200_000),
                    Seed(bundleIdentifier: "com.getdropbox.dropbox", name: "Dropbox", receivedBytes: 130_000_000, sentBytes: 5_000_000, receiveRange: 0...900_000, sendRange: 0...350_000),
                    Seed(bundleIdentifier: "com.valvesoftware.steam", name: "Steam", receivedBytes: 2_400_000_000, sentBytes: 120_000_000, receiveRange: 0...3_800_000, sendRange: 0...180_000)
                ]

                while !Task.isCancelled {
                    let rows = seeds.indices.map { index -> AppTraffic in
                        let rx = UInt64.random(in: seeds[index].receiveRange)
                        let tx = UInt64.random(in: seeds[index].sendRange)
                        seeds[index].receivedBytes &+= rx
                        seeds[index].sentBytes &+= tx
                        let identity = AppIdentity(
                            bundleIdentifier: seeds[index].bundleIdentifier,
                            displayName: seeds[index].name,
                            processIdentifiers: [Int32(1_000 + index)],
                            processNames: [seeds[index].name]
                        )
                        return AppTraffic(
                            identity: identity,
                            receivedBytes: seeds[index].receivedBytes,
                            sentBytes: seeds[index].sentBytes,
                            receivedBytesPerSecond: Double(rx),
                            sentBytesPerSecond: Double(tx)
                        )
                    }
                    continuation.yield(rows)
                    try? await Task.sleep(for: .seconds(1))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

