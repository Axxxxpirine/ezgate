import Foundation

public enum ByteFormatter {
    public static func string(_ bytes: UInt64, rate: Bool = false) -> String {
        if bytes == 0 { return rate ? "0 KB/s" : "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        let value = formatter.string(fromByteCount: Int64(clamping: bytes))
        return rate ? "\(value)/s" : value
    }

    public static func rate(_ bytesPerSecond: Double) -> String {
        string(UInt64(max(0, bytesPerSecond)), rate: true)
    }
}
