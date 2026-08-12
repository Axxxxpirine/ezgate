import AppKit
import SwiftUI
import EZgateCore

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            if model.hasCompletedOnboarding {
                mainContent
            } else {
                OnboardingView()
            }
        }
        .frame(width: 420, height: 570)
        .background(.regularMaterial)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            totals
            Divider()
            controls
            Divider()
            appList
            Divider()
            footer
        }
    }

    private var header: some View {
        @Bindable var model = model
        return HStack(spacing: 10) {
            Image(systemName: "network")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("EZgate").font(.headline)
                Text(networkDescription).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Active profile", selection: $model.activeProfileID) {
                ForEach(model.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 150)
            .onChange(of: model.activeProfileID) { _, _ in model.profileSelectionDidChange() }
        }
        .padding(14)
    }

    private var totals: some View {
        HStack(spacing: 26) {
            TrafficMetric(title: "Downloaded", symbol: "arrow.down", value: ByteFormatter.string(model.sessionTotals.receivedBytes))
            TrafficMetric(title: "Uploaded", symbol: "arrow.up", value: ByteFormatter.string(model.sessionTotals.sentBytes))
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text("SESSION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(model.traffic.count) apps").font(.callout.monospacedDigit())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var controls: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search apps, processes, bundle IDs", text: $model.searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("trafficSearch")
            Picker("Sort", selection: $model.sortOrder) {
                ForEach(TrafficSortOrder.allCases, id: \.self) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .labelsHidden()
            .frame(width: 92)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var appList: some View {
        Group {
            if model.visibleTraffic.isEmpty {
                if model.searchText.isEmpty {
                    ContentUnavailableView(
                        model.filterController.status.isActive ? "No network activity yet" : "Network filter inactive",
                        systemImage: "network.slash",
                        description: Text(model.filterController.status.isActive
                            ? "Applications appear here when they create new network connections."
                            : "Install and approve the system extension to observe real traffic.")
                    )
                } else {
                    ContentUnavailableView.search(text: model.searchText)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.visibleTraffic) { row in
                            TrafficRow(
                                row: row,
                                isAllowed: model.isAllowed(row.identity),
                                setAllowed: { model.setAllowed($0, for: row.identity) }
                            )
                            Divider().padding(.leading, 54)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button {
                if model.filterController.status.isActive {
                    model.setFilteringPaused(!model.filteringPaused)
                } else {
                    model.activateFilter()
                }
            } label: {
                Label(
                    model.filterController.status.isActive
                        ? (model.filteringPaused ? "Filtering paused" : "Filtering active")
                        : model.filterController.status.label,
                    systemImage: "shield.lefthalf.filled"
                )
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                openSettings()
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Open EZgate Settings")
            Menu {
                Button("Quit EZgate") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(12)
    }

    private var networkDescription: String {
        let context = model.networkMonitor.context
        guard context.isAvailable else { return "Network unavailable" }
        let name = context.interfaceName.map { " · \($0)" } ?? ""
        let cost = context.isExpensive ? " · Expensive" : ""
        return context.interface.rawValue.capitalized + name + cost
    }
}

private struct TrafficMetric: View {
    let title: String
    let symbol: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title.uppercased(), systemImage: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit().weight(.medium))
        }
    }
}

private struct TrafficRow: View {
    let row: AppTraffic
    let isAllowed: Bool
    let setAllowed: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(identity: row.identity)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.identity.displayName).font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 10) {
                    Label(ByteFormatter.string(row.receivedBytes), systemImage: "arrow.down")
                    Label(ByteFormatter.string(row.sentBytes), systemImage: "arrow.up")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                Button {
                    setAllowed(!isAllowed)
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(isAllowed ? Color.green : Color.red).frame(width: 7, height: 7)
                        Text(isAllowed ? "Allow" : "Block")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(row.identity.displayName) network access")
                .accessibilityValue(isAllowed ? "Allowed" : "Blocked")
                HStack(spacing: 8) {
                    Text("↓ \(ByteFormatter.rate(row.receivedBytesPerSecond))")
                    Text("↑ \(ByteFormatter.rate(row.sentBytesPerSecond))")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .help("Real-time download and upload rates")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Real-time traffic")
                .accessibilityValue(
                    "Downloaded \(ByteFormatter.rate(row.receivedBytesPerSecond)), uploaded \(ByteFormatter.rate(row.sentBytesPerSecond))"
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct AppIconView: View {
    let identity: AppIdentity

    var body: some View {
        Group {
            if let executableURL = identity.executableURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: executableURL.path))
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(7)
                    .foregroundStyle(.secondary)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
}
