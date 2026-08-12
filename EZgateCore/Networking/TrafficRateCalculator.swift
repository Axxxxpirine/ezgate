import Foundation

public enum TrafficRateCalculator {
    public static func applyingRates(
        to snapshot: SharedTrafficSnapshot,
        previous previousSnapshot: SharedTrafficSnapshot?
    ) -> [AppTraffic] {
        guard let previousSnapshot else {
            return snapshot.applications.map { zeroedRates($0) }
        }
        let interval = max(snapshot.updatedAt.timeIntervalSince(previousSnapshot.updatedAt), 1)
        let previousRows = Dictionary(
            uniqueKeysWithValues: previousSnapshot.applications.map { ($0.id, $0) }
        )
        return snapshot.applications.map { row in
            guard let previous = previousRows[row.id] else { return zeroedRates(row) }
            var row = row
            let receivedDelta = row.receivedBytes >= previous.receivedBytes
                ? row.receivedBytes - previous.receivedBytes : 0
            let sentDelta = row.sentBytes >= previous.sentBytes
                ? row.sentBytes - previous.sentBytes : 0
            row.receivedBytesPerSecond = Double(receivedDelta) / interval
            row.sentBytesPerSecond = Double(sentDelta) / interval
            return row
        }
    }

    private static func zeroedRates(_ row: AppTraffic) -> AppTraffic {
        var row = row
        row.receivedBytesPerSecond = 0
        row.sentBytesPerSecond = 0
        return row
    }
}
