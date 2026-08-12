import AppKit
import Foundation
import Observation
import OSLog
import EZgateCore

@MainActor
@Observable
final class AppModel {
    var traffic: [AppTraffic] = []
    var profiles: [NetworkProfile] = NetworkProfile.defaults
    var activeProfileID: UUID
    var filteringPaused = false
    var searchText = ""
    var sortOrder: TrafficSortOrder = .total
    var todayTotals = TrafficTotals()
    var errorMessage: String?
    var hasCompletedOnboarding: Bool
    var refreshFrequency = 1.0

    let networkMonitor = NetworkContextMonitor()
    let launchAtLogin = LaunchAtLoginController()
    let filterController = FilterController()

    private let ruleEngine = RuleEngine()
    private let profileStore: ProfileStore
    private let statisticsStore: StatisticsStore
    private let provider: any TrafficProvider
    private let filterIPC = FilterIPCClient.shared
    private let sessionID = UUID()
    private var streamTask: Task<Void, Never>?
    private var previousTraffic: [String: AppTraffic] = [:]
    private var configurationRevision: UInt64 = 0
    private let logger = Logger(subsystem: "ch.ezgate.app", category: "ui")

    init(
        provider: any TrafficProvider = RealTrafficProvider(),
        profileStore: ProfileStore = ProfileStore(),
        statisticsStore: StatisticsStore = StatisticsStore()
    ) {
        let defaults = NetworkProfile.defaults
        self.activeProfileID = defaults[0].id
        self.profiles = defaults
        self.provider = provider
        self.profileStore = profileStore
        self.statisticsStore = statisticsStore
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    var activeProfile: NetworkProfile {
        get { profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0] }
        set {
            guard let index = profiles.firstIndex(where: { $0.id == newValue.id }) else { return }
            profiles[index] = newValue
        }
    }

    var visibleTraffic: [AppTraffic] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = traffic.filter { row in
            query.isEmpty
                || row.identity.displayName.lowercased().contains(query)
                || row.identity.bundleIdentifier?.lowercased().contains(query) == true
                || row.identity.processNames.contains(where: { $0.lowercased().contains(query) })
        }
        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .total: return lhs.totalBytes > rhs.totalBytes
            case .download: return lhs.receivedBytes > rhs.receivedBytes
            case .upload: return lhs.sentBytes > rhs.sentBytes
            case .name: return lhs.identity.displayName.localizedCaseInsensitiveCompare(rhs.identity.displayName) == .orderedAscending
            case .status:
                let left = isAllowed(lhs.identity)
                let right = isAllowed(rhs.identity)
                return left == right ? lhs.totalBytes > rhs.totalBytes : !left && right
            }
        }
    }

    var sessionTotals: TrafficTotals {
        TrafficTotals(
            receivedBytes: traffic.reduce(0) { $0 &+ $1.receivedBytes },
            sentBytes: traffic.reduce(0) { $0 &+ $1.sentBytes }
        )
    }

    func start() async {
        guard streamTask == nil else { return }
        do {
            if let persisted = try await profileStore.load(), !persisted.profiles.isEmpty {
                profiles = persisted.profiles
                activeProfileID = profiles.contains(where: { $0.id == persisted.activeProfileID })
                    ? persisted.activeProfileID
                    : profiles[0].id
                filteringPaused = persisted.filteringPaused
            }
            todayTotals = try await statisticsStore.totals(since: Calendar.current.startOfDay(for: .now))
        } catch {
            errorMessage = error.localizedDescription
        }
        networkMonitor.onContextChange = { [weak self] context in
            self?.networkContextDidChange(context)
        }
        networkMonitor.start()
        filterController.onFilterActive = { [weak self] in
            guard let self else { return }
            let revision = self.configurationRevision
            Task { await self.synchronizeRules(revision: revision) }
        }
        filterController.refresh(activateIfInactive: true)
        await synchronizeRules(revision: configurationRevision)
        streamTask = Task { [weak self, provider] in
            for await update in provider.updates() {
                guard let self, !Task.isCancelled else { return }
                await self.accept(update)
            }
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func activateFilter() {
        filterController.activate()
    }

    func selectProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        persistConfiguration()
    }

    func profileSelectionDidChange() {
        persistConfiguration()
    }

    func setFilteringPaused(_ paused: Bool) {
        filteringPaused = paused
        persistConfiguration()
    }

    func isAllowed(_ identity: AppIdentity) -> Bool {
        ruleEngine.decide(for: identity, profile: activeProfile, filteringPaused: filteringPaused).isAllowed
    }

    func setAllowed(_ allowed: Bool, for identity: AppIdentity) {
        var profile = activeProfile
        profile.rules[identity.id] = allowed ? .allow : .block
        activeProfile = profile
        persistConfiguration()
    }

    func setDefaultPolicy(_ policy: RuleAction, for profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].defaultPolicy = policy
        persistConfiguration()
    }

    func associateCurrentNetwork(with profileID: UUID) {
        guard let signature = preferredNetworkSignature(for: networkMonitor.context),
              let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].networkSignatures.insert(signature)
        persistConfiguration()
    }

    func clearNetworkAssociations(for profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].networkSignatures.removeAll()
        persistConfiguration()
    }

    var currentNetworkCanBeAssociated: Bool {
        preferredNetworkSignature(for: networkMonitor.context) != nil
    }

    func addProfile() {
        let profile = NetworkProfile(name: "New Profile", defaultPolicy: .allow)
        profiles.append(profile)
        activeProfileID = profile.id
        persistConfiguration()
    }

    func deleteProfile(_ id: UUID) {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles.remove(at: index)
        if activeProfileID == id { activeProfileID = profiles[0].id }
        persistConfiguration()
    }

    func renameProfile(_ id: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profiles[index].name = trimmed
        persistConfiguration()
    }

    func deleteStatistics() async {
        do {
            try await statisticsStore.deleteAll()
            todayTotals = TrafficTotals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func accept(_ update: [AppTraffic]) async {
        traffic = update
        var newRX: UInt64 = 0
        var newTX: UInt64 = 0
        for row in update {
            let previous = previousTraffic[row.id]
            let deltaRX = row.receivedBytes >= (previous?.receivedBytes ?? row.receivedBytes)
                ? row.receivedBytes - (previous?.receivedBytes ?? row.receivedBytes) : 0
            let deltaTX = row.sentBytes >= (previous?.sentBytes ?? row.sentBytes)
                ? row.sentBytes - (previous?.sentBytes ?? row.sentBytes) : 0
            guard deltaRX > 0 || deltaTX > 0 else { continue }
            newRX &+= deltaRX
            newTX &+= deltaTX
            let record = TrafficRecord(
                applicationIdentifier: row.id,
                displayName: row.identity.displayName,
                sessionID: sessionID,
                profileID: activeProfileID,
                interface: networkMonitor.context.interface,
                receivedBytes: deltaRX,
                sentBytes: deltaTX
            )
            do { try await statisticsStore.record(record) }
            catch { logger.error("Statistics write failed: \(error.localizedDescription, privacy: .public)") }
        }
        previousTraffic = Dictionary(uniqueKeysWithValues: update.map { ($0.id, $0) })
        todayTotals.receivedBytes &+= newRX
        todayTotals.sentBytes &+= newTX
    }

    private func networkContextDidChange(_ context: NetworkContext) {
        guard let profile = NetworkContextMatcher().matchingProfile(in: profiles, for: context),
              profile.id != activeProfileID else { return }
        activeProfileID = profile.id
        persistConfiguration()
    }

    private func preferredNetworkSignature(for context: NetworkContext) -> String? {
        if let ssid = context.ssid { return "ssid:\(ssid)" }
        if context.isExpensive { return "expensive" }
        if context.isConstrained { return "constrained" }
        return nil
    }

    private func persistConfiguration() {
        let configuration = PersistedConfiguration(
            profiles: profiles,
            activeProfileID: activeProfileID,
            filteringPaused: filteringPaused
        )
        configurationRevision &+= 1
        let revision = configurationRevision
        Task { [profileStore] in
            do { try await profileStore.save(configuration) }
            catch { logger.error("Configuration write failed: \(error.localizedDescription, privacy: .public)") }
            await synchronizeRules(revision: revision)
        }
    }

    private func synchronizeRules(revision: UInt64) async {
        let snapshot = SharedRuleSnapshot(
            activeProfile: activeProfile,
            filteringPaused: filteringPaused,
            revision: revision
        )
        for attempt in 0..<20 {
            if await filterIPC.updateRules(snapshot) { return }
            guard attempt < 19 else {
                logger.error("Unable to synchronize rules with the network extension")
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
