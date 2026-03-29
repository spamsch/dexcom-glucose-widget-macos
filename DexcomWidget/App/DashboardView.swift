import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var selectedDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Glucose Widget")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    Task { await appState.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .rotationEffect(.degrees(appState.isLoading ? 360 : 0))
                        .animation(appState.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Main reading card
                    if let reading = appState.currentReading {
                        glucoseCard(reading)
                    } else {
                        noDataCard
                    }

                    // Chart
                    if !appState.recentReadings.isEmpty {
                        chartCard
                    }

                    // Error
                    if let error = appState.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .padding(24)
            }
        }
        .task {
            appState.startRefreshTimer()
            if appState.currentReading == nil {
                await appState.refresh()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    // MARK: - Glucose Card

    private func glucoseCard(_ reading: GlucoseReading) -> some View {
        let range = reading.glucoseRange(
            low: GlucoseStore.shared.lowThreshold,
            high: GlucoseStore.shared.highThreshold
        )
        let useMmol = GlucoseStore.shared.useMmol

        return VStack(spacing: 16) {
            // Range label
            Text(range.label)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(range.color)

            // Big glucose number
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reading.displayValue(useMmol: useMmol))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 4) {
                    // Trend arrow
                    HStack(spacing: 2) {
                        Image(systemName: reading.trendSFSymbol)
                            .font(.system(size: 20, weight: .bold))
                        if reading.isDoubleArrow {
                            Image(systemName: reading.trendSFSymbol)
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .foregroundStyle(range.color)

                    Text(reading.displayUnit(useMmol: useMmol))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            // Trend description & time
            HStack {
                Label(reading.trendDescription, systemImage: "arrow.triangle.swap")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Label(reading.timeAgoText, systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: range.gradient.map { $0.opacity(0.15) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(range.color.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var noDataCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No readings yet")
                .font(.system(size: 14, weight: .medium))
            Text("Waiting for glucose data...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        let sortedReadings = appState.recentReadings.sorted { $0.timestamp < $1.timestamp }
        let low = GlucoseStore.shared.lowThreshold
        let high = GlucoseStore.shared.highThreshold

        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 3 Hours")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            // Tooltip for selected reading
            if let selectedDate,
               let selected = sortedReadings.min(by: {
                   abs($0.timestamp.timeIntervalSince(selectedDate)) < abs($1.timestamp.timeIntervalSince(selectedDate))
               }) {
                selectedReadingTooltip(selected, low: low, high: high)
            }

            glucoseChart(sortedReadings: sortedReadings, low: low, high: high)
                .frame(height: 200)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func selectedReadingTooltip(_ reading: GlucoseReading, low: Double, high: Double) -> some View {
        let range = reading.glucoseRange(low: low, high: high)
        let useMmol = GlucoseStore.shared.useMmol
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        return HStack(spacing: 12) {
            Circle()
                .fill(range.color)
                .frame(width: 8, height: 8)
            Text(reading.displayValue(useMmol: useMmol))
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(reading.displayUnit(useMmol: useMmol))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(reading.trendArrow)
                .font(.system(size: 14))
            Spacer()
            Text(formatter.string(from: reading.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
    }

    private func glucoseChart(sortedReadings: [GlucoseReading], low: Double, high: Double) -> some View {
        let lineColor = Color(red: 0.15, green: 0.55, blue: 0.35)

        return Chart {
            RectangleMark(
                yStart: .value("Low", low),
                yEnd: .value("High", high)
            )
            .foregroundStyle(Color.green.opacity(0.08))

            ForEach(sortedReadings) { reading in
                LineMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("Glucose", reading.value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("Glucose", reading.value)
                )
                .foregroundStyle(reading.glucoseRange(low: low, high: high).color)
                .symbolSize(30)
            }

            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            RuleMark(y: .value("Low", low))
                .foregroundStyle(.orange.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            RuleMark(y: .value("High", high))
                .foregroundStyle(.orange.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartYScale(domain: 40...300)
        .chartXSelection(value: $selectedDate)
    }
}
