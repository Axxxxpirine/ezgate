import Foundation

public enum TrafficSorter {
    public static func sorted(
        _ rows: [AppTraffic],
        by order: TrafficSortOrder,
        isAllowed: (AppIdentity) -> Bool
    ) -> [AppTraffic] {
        rows.sorted { lhs, rhs in
            switch order {
            case .total:
                return ordered(lhs, rhs, by: lhs.totalBytes, rhs.totalBytes)
            case .download:
                return ordered(lhs, rhs, by: lhs.receivedBytes, rhs.receivedBytes)
            case .upload:
                return ordered(lhs, rhs, by: lhs.sentBytes, rhs.sentBytes)
            case .liveDownload:
                return liveOrdered(lhs, rhs, by: lhs.receivedBytesPerSecond, rhs.receivedBytesPerSecond)
            case .liveUpload:
                return liveOrdered(lhs, rhs, by: lhs.sentBytesPerSecond, rhs.sentBytesPerSecond)
            case .name:
                return nameComesFirst(lhs, rhs)
            case .status:
                let left = isAllowed(lhs.identity)
                let right = isAllowed(rhs.identity)
                return left == right
                    ? ordered(lhs, rhs, by: lhs.totalBytes, rhs.totalBytes)
                    : !left && right
            }
        }
    }

    private static func ordered<T: Comparable>(
        _ lhs: AppTraffic,
        _ rhs: AppTraffic,
        by leftValue: T,
        _ rightValue: T
    ) -> Bool {
        if leftValue != rightValue { return leftValue > rightValue }
        return nameComesFirst(lhs, rhs)
    }

    private static func liveOrdered(
        _ lhs: AppTraffic,
        _ rhs: AppTraffic,
        by leftRate: Double,
        _ rightRate: Double
    ) -> Bool {
        if leftRate != rightRate { return leftRate > rightRate }
        if lhs.totalBytes != rhs.totalBytes { return lhs.totalBytes > rhs.totalBytes }
        return nameComesFirst(lhs, rhs)
    }

    private static func nameComesFirst(_ lhs: AppTraffic, _ rhs: AppTraffic) -> Bool {
        lhs.identity.displayName.localizedCaseInsensitiveCompare(rhs.identity.displayName) == .orderedAscending
    }
}
