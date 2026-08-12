import Foundation
import EZgateCore

enum StatisticsResetCLI {
    static var shouldRun: Bool {
        CommandLine.arguments.contains("--reset-statistics-now")
    }

    static func run() async -> Int32 {
        let store = StatisticsStore()
        do {
            try await store.deleteAll()
            guard await FilterIPCClient.shared.resetTraffic() else { return 2 }
            return 0
        } catch {
            return 1
        }
    }
}
