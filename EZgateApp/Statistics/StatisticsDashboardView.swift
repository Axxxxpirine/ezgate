import AppKit
import Charts
import SwiftUI
import EZgateCore

struct StatisticsDashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var period: StatisticsPeriod = .today
    @State private var selectedApplicationID: String?
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\StatisticsApplicationSummary.totalBytes, order: .reverse)]
    @State private var hoveredDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 820, minHeight: 620)
        .task(id: refreshKey) {
            while !Task.isCancelled {
                await model.loadStatistics(
                    period: period,
                    applicationIdentifier: selectedApplicationID
                )
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Network Statistics")
                    .font(.title2.weight(.semibold))
                Text(selectedApplicationName ?? "All Applications")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Period", selection: $period) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 330)
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if model.statisticsLoading, model.statisticsSnapshot == nil {
            ProgressView("Loading statistics…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.statisticsErrorMessage, model.statisticsSnapshot == nil {
            ContentUnavailableView(
                "Unable to Load Statistics",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if let snapshot = model.statisticsSnapshot {
            dashboard(snapshot)
        } else {
            ContentUnavailableView(
                "No Statistics Yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Network activity will appear here as applications use the Internet.")
            )
        }
    }

    private func dashboard(_ snapshot: StatisticsSnapshot) -> some View {
        VStack(spacing: 0) {
            summary(snapshot)
            Divider()
            chart(snapshot)
                .frame(minHeight: 220, idealHeight: 280)
                .padding(20)
            Divider()
            table(snapshot)
                .frame(minHeight: 240)
        }
        .overlay(alignment: .topTrailing) {
            if model.statisticsLoading {
                ProgressView().controlSize(.small).padding(8)
            }
        }
    }

    private func summary(_ snapshot: StatisticsSnapshot) -> some View {
        HStack(spacing: 14) {
            SummaryCard(
                title: "Downloaded",
                value: ByteFormatter.string(snapshot.totals.receivedBytes),
                symbol: "arrow.down",
                color: .blue
            )
            SummaryCard(
                title: "Uploaded",
                value: ByteFormatter.string(snapshot.totals.sentBytes),
                symbol: "arrow.up",
                color: .orange
            )
            SummaryCard(
                title: "Total Traffic",
                value: ByteFormatter.string(snapshot.totals.totalBytes),
                symbol: "arrow.up.arrow.down",
                color: .purple
            )
            SummaryCard(
                title: "Active Apps",
                value: "\(snapshot.applications.count)",
                symbol: "app.dashed",
                color: .secondary
            )
        }
        .padding(20)
    }

    private func chart(_ snapshot: StatisticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Traffic Over Time")
                    .font(.headline)
                Spacer()
                if selectedApplicationID != nil {
                    Button("All Applications", systemImage: "xmark.circle") {
                        selectedApplicationID = nil
                    }
                    .buttonStyle(.borderless)
                }
            }
            if snapshot.timeline.allSatisfy({ $0.totalBytes == 0 }) {
                ContentUnavailableView(
                    "No Traffic in This Period",
                    systemImage: "chart.line.flattrend.xyaxis"
                )
            } else {
                Chart {
                    ForEach(snapshot.timeline) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Bytes", point.receivedBytes),
                            series: .value("Direction", "Download")
                        )
                        .foregroundStyle(by: .value("Direction", "Download"))
                        .interpolationMethod(.linear)
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Bytes", point.sentBytes),
                            series: .value("Direction", "Upload")
                        )
                        .foregroundStyle(by: .value("Direction", "Upload"))
                        .interpolationMethod(.linear)
                    }
                    if let hoveredPoint = hoveredPoint(in: snapshot) {
                        RuleMark(x: .value("Selected", hoveredPoint.date))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                ChartPopover(point: hoveredPoint, granularity: snapshot.granularity)
                            }
                    }
                }
                .chartForegroundStyleScale([
                    "Download": Color.blue,
                    "Upload": Color.orange
                ])
                .chartLegend(position: .top, alignment: .leading, spacing: 16)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bytes = value.as(UInt64.self) {
                                Text(ByteFormatter.string(bytes))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: xAxisFormat(snapshot.granularity))
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let frame = geometry[plotFrame]
                                    hoveredDate = proxy.value(atX: location.x - frame.minX)
                                case .ended:
                                    hoveredDate = nil
                                }
                            }
                    }
                }
            }
        }
    }

    private func table(_ snapshot: StatisticsSnapshot) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search applications", text: $searchText)
                    .textFieldStyle(.plain)
                Spacer()
                Text("\(filteredApplications(snapshot).count) applications")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider()
            Table(
                filteredApplications(snapshot).sorted(using: sortOrder),
                selection: $selectedApplicationID,
                sortOrder: $sortOrder
            ) {
                TableColumn("Application", value: \.displayName) { app in
                    HStack(spacing: 8) {
                        StatisticsAppIcon(identifier: app.applicationIdentifier)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.displayName).lineLimit(1)
                            Text(app.applicationIdentifier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 190, ideal: 260)
                TableColumn("Download", value: \.receivedBytes) { app in
                    Text(ByteFormatter.string(app.receivedBytes)).monospacedDigit()
                }
                .width(min: 90, ideal: 110)
                TableColumn("Upload", value: \.sentBytes) { app in
                    Text(ByteFormatter.string(app.sentBytes)).monospacedDigit()
                }
                .width(min: 90, ideal: 110)
                TableColumn("Total", value: \.totalBytes) { app in
                    Text(ByteFormatter.string(app.totalBytes)).monospacedDigit()
                }
                .width(min: 90, ideal: 110)
                TableColumn("Share") { app in
                    Text(appShare(app, overallTotal: snapshot.applications.reduce(0) { $0 &+ $1.totalBytes }))
                        .monospacedDigit()
                }
                .width(min: 60, ideal: 70)
                TableColumn("Last Activity", value: \.lastActivity) { app in
                    Text(app.lastActivity, format: .relative(presentation: .named))
                }
                .width(min: 100, ideal: 125)
            }
            .overlay {
                if snapshot.applications.isEmpty {
                    ContentUnavailableView(
                        "No Applications",
                        systemImage: "app.dashed",
                        description: Text("No traffic was recorded during this period.")
                    )
                } else if filteredApplications(snapshot).isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private var refreshKey: String { "\(period.rawValue):\(selectedApplicationID ?? "all")" }

    private var selectedApplicationName: String? {
        guard let selectedApplicationID else { return nil }
        return model.statisticsSnapshot?.applications.first {
            $0.applicationIdentifier == selectedApplicationID
        }?.displayName
    }

    private func filteredApplications(_ snapshot: StatisticsSnapshot) -> [StatisticsApplicationSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return snapshot.applications }
        return snapshot.applications.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.applicationIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    private func hoveredPoint(in snapshot: StatisticsSnapshot) -> StatisticsTimePoint? {
        guard let hoveredDate else { return nil }
        return snapshot.timeline.min {
            abs($0.date.timeIntervalSince(hoveredDate)) < abs($1.date.timeIntervalSince(hoveredDate))
        }
    }

    private func xAxisFormat(_ granularity: StatisticsGranularity) -> Date.FormatStyle {
        switch granularity {
        case .fifteenMinutes, .hour: .dateTime.hour().minute()
        case .day: .dateTime.day().month(.abbreviated)
        case .week: .dateTime.day().month(.abbreviated).year()
        }
    }

    private func appShare(_ app: StatisticsApplicationSummary, overallTotal: UInt64) -> String {
        guard overallTotal > 0 else { return "0%" }
        return (Double(app.totalBytes) / Double(overallTotal)).formatted(.percent.precision(.fractionLength(1)))
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ChartPopover: View {
    let point: StatisticsTimePoint
    let granularity: StatisticsGranularity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateText).font(.caption.weight(.semibold))
            Label(ByteFormatter.string(point.receivedBytes), systemImage: "arrow.down")
                .foregroundStyle(.blue)
            Label(ByteFormatter.string(point.sentBytes), systemImage: "arrow.up")
                .foregroundStyle(.orange)
        }
        .font(.caption.monospacedDigit())
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 3)
    }

    private var dateText: String {
        switch granularity {
        case .fifteenMinutes, .hour:
            point.date.formatted(date: .abbreviated, time: .shortened)
        case .day, .week:
            point.date.formatted(date: .long, time: .omitted)
        }
    }
}

private struct StatisticsAppIcon: View {
    let identifier: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .foregroundStyle(.secondary)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
