import SwiftUI
import EZgateCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            GeneralSettingsView().tabItem { Label("General", systemImage: "gear") }
            ProfilesSettingsView().tabItem { Label("Profiles", systemImage: "person.2") }
            RulesSettingsView().tabItem { Label("Rules", systemImage: "switch.2") }
            StatisticsSettingsView().tabItem { Label("Statistics", systemImage: "chart.bar") }
            PrivacySettingsView().tabItem { Label("Privacy", systemImage: "hand.raised") }
            AdvancedSettingsView().tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .padding(18)
    }
}

private struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Startup") {
                LabeledContent("Launch EZgate at login") {
                    Button(model.launchAtLogin.isEnabled ? "Disable" : "Enable") {
                        model.launchAtLogin.setEnabled(!model.launchAtLogin.isEnabled)
                    }
                }
                if let error = model.launchAtLogin.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Monitoring") {
                Picker("Refresh frequency", selection: $model.refreshFrequency) {
                    Text("0.5 seconds").tag(0.5)
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                }
                LabeledContent("Data source", value: "Network Extension")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ProfilesSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HSplitView {
            List {
                ForEach(model.profiles) { profile in
                    Button {
                        model.selectProfile(profile.id)
                    } label: {
                        HStack {
                            Text(profile.name)
                            Spacer()
                            if profile.id == model.activeProfileID {
                                Image(systemName: "checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minWidth: 180)
            VStack(alignment: .leading, spacing: 16) {
                TextField("Profile name", text: Binding(
                    get: { model.activeProfile.name },
                    set: { model.renameProfile(model.activeProfileID, to: $0) }
                ))
                Picker("Default policy", selection: Binding(
                    get: { model.activeProfile.defaultPolicy },
                    set: { model.setDefaultPolicy($0, for: model.activeProfileID) }
                )) {
                    Text("Allow new apps").tag(RuleAction.allow)
                    Text("Block new apps").tag(RuleAction.block)
                }
                Text("Network matching can use interface, expensive/constrained path status, and an SSID when macOS legally exposes it. No hotspot name is guessed.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Associate Current Network") {
                        model.associateCurrentNetwork(with: model.activeProfileID)
                    }
                    .disabled(!model.currentNetworkCanBeAssociated)
                    Button("Clear Associations") {
                        model.clearNetworkAssociations(for: model.activeProfileID)
                    }
                    .disabled(model.activeProfile.networkSignatures.isEmpty)
                }
                if !model.activeProfile.networkSignatures.isEmpty {
                    Text(model.activeProfile.networkSignatures.sorted().joined(separator: ", "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    Button("Add Profile", systemImage: "plus", action: model.addProfile)
                    Button("Delete", systemImage: "trash") { model.deleteProfile(model.activeProfileID) }
                        .disabled(model.profiles.count <= 1)
                }
            }
            .padding()
            .frame(minWidth: 380)
        }
    }
}

private struct RulesSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List(model.traffic) { row in
            HStack {
                VStack(alignment: .leading) {
                    Text(row.identity.displayName)
                    Text(row.id).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Access", selection: Binding(
                    get: { model.isAllowed(row.identity) ? RuleAction.allow : RuleAction.block },
                    set: { model.setAllowed($0 == .allow, for: row.identity) }
                )) {
                    Text("Allow").tag(RuleAction.allow)
                    Text("Block").tag(RuleAction.block)
                }
                .frame(width: 120)
            }
        }
        .overlay {
            if model.traffic.isEmpty { ContentUnavailableView("No applications", systemImage: "network.slash") }
        }
    }
}

private struct StatisticsSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Today").font(.title2.weight(.semibold))
            HStack(spacing: 32) {
                Label(ByteFormatter.string(model.todayTotals.receivedBytes), systemImage: "arrow.down.circle")
                Label(ByteFormatter.string(model.todayTotals.sentBytes), systemImage: "arrow.up.circle")
            }
            .font(.title3.monospacedDigit())
            Text("Statistics are stored locally in SQLite. Session totals are also visible in the menu panel.")
                .foregroundStyle(.secondary)
            Button("Open Network Statistics", systemImage: "chart.xyaxis.line") {
                openWindow(id: "statistics")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button("Delete All Statistics", role: .destructive) {
                Task { await model.deleteStatistics() }
            }
        }
        .padding()
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section("Local by design") {
                Label("No account", systemImage: "person.crop.circle.badge.xmark")
                Label("No telemetry or analytics", systemImage: "chart.line.downtrend.xyaxis")
                Label("No cloud service", systemImage: "icloud.slash")
                Label("Rules and traffic totals remain on this Mac", systemImage: "internaldrive")
            }
            Text("EZgate records application identifiers, timestamps, active profile, network interface type, and byte totals. It never stores packet contents.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct AdvancedSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Network Extension") {
                LabeledContent("Status", value: model.filterController.status.label)
                if !model.filterController.status.isActive {
                    Button("Install Network Filter") { model.activateFilter() }
                }
                Text("macOS requires explicit approval for the signed system extension. EZgate displays only traffic reported by that extension.")
                    .foregroundStyle(.secondary)
            }
            if let error = model.errorMessage {
                Section("Last error") { Text(error).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
    }
}
