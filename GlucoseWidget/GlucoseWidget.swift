import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct GlucoseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlucoseEntry {
        GlucoseEntry(
            date: Date(),
            reading: GlucoseReading(value: 120, trend: 4, timestamp: Date()),
            useMmol: false,
            lowThreshold: DexcomConstants.defaultLowThreshold,
            highThreshold: DexcomConstants.defaultHighThreshold,
            isConfigured: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        let store = GlucoseStore.shared
        let entry = GlucoseEntry(
            date: Date(),
            reading: store.loadLastReading(),
            useMmol: store.useMmol,
            lowThreshold: store.lowThreshold,
            highThreshold: store.highThreshold,
            isConfigured: store.isConfigured
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        let store = GlucoseStore.shared

        Task {
            var reading = store.loadLastReading()

            // Try to fetch fresh data
            if let api = store.createAPI() {
                if let fresh = try? await api.fetchCurrentReading() {
                    reading = fresh
                    store.saveReading(fresh)
                }
            }

            let entry = GlucoseEntry(
                date: Date(),
                reading: reading,
                useMmol: store.useMmol,
                lowThreshold: store.lowThreshold,
                highThreshold: store.highThreshold,
                isConfigured: store.isConfigured
            )

            // Refresh every 5 minutes (Dexcom update interval)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Entry

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let reading: GlucoseReading?
    let useMmol: Bool
    let lowThreshold: Double
    let highThreshold: Double
    let isConfigured: Bool
}

// MARK: - Widget Views

struct GlucoseWidgetSmallView: View {
    let entry: GlucoseEntry

    var body: some View {
        if !entry.isConfigured {
            notConfiguredView
        } else if let reading = entry.reading {
            readingView(reading)
        } else {
            noDataView
        }
    }

    private func readingView(_ reading: GlucoseReading) -> some View {
        let range = reading.glucoseRange(low: entry.lowThreshold, high: entry.highThreshold)
        let accent = range.widgetAccent

        return VStack(spacing: 6) {
            // Range indicator dot
            HStack(spacing: 4) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(range.label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(accent)
                Spacer()
            }

            Spacer()

            // Glucose value
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(reading.displayValue(useMmol: entry.useMmol))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundColor(.white)

                VStack(spacing: 2) {
                    Image(systemName: reading.trendSFSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(accent)
                }
            }

            Spacer()

            // Bottom info
            HStack {
                Text(reading.displayUnit(useMmol: entry.useMmol))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(reading.timeAgoText)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            ZStack {
                Color.black
                LinearGradient(
                    colors: range.widgetGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var notConfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            Text("Open app\nto set up")
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill, for: .widget)
    }

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No data")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill, for: .widget)
    }
}

struct GlucoseWidgetMediumView: View {
    let entry: GlucoseEntry

    var body: some View {
        if !entry.isConfigured {
            notConfiguredView
        } else if let reading = entry.reading {
            readingView(reading)
        } else {
            noDataView
        }
    }

    private func readingView(_ reading: GlucoseReading) -> some View {
        let range = reading.glucoseRange(low: entry.lowThreshold, high: entry.highThreshold)
        let accent = range.widgetAccent
        let store = GlucoseStore.shared
        let recentReadings = store.loadReadings().sorted { $0.timestamp < $1.timestamp }

        return HStack(spacing: 16) {
            // Left: glucose value
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                    Text(range.label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(accent)
                }

                Text(reading.displayValue(useMmol: entry.useMmol))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Image(systemName: reading.trendSFSymbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accent)
                    Text(reading.trendDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }

                Text(reading.timeAgoText)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(width: 130)

            // Right: mini chart
            if recentReadings.count >= 2 {
                miniChart(recentReadings, range: range)
            } else {
                Spacer()
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            ZStack {
                Color.black
                LinearGradient(
                    colors: range.widgetGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func miniChart(_ readings: [GlucoseReading], range: GlucoseRange) -> some View {
        Canvas { context, size in
            let values = readings.map { Double($0.value) }
            let minVal = max(40, (values.min() ?? 40) - 10)
            let maxVal = min(350, (values.max() ?? 350) + 10)
            let valueRange = maxVal - minVal

            guard valueRange > 0, values.count >= 2 else { return }

            // Draw target range band
            let lowY = size.height * (1 - (entry.lowThreshold - minVal) / valueRange)
            let highY = size.height * (1 - (entry.highThreshold - minVal) / valueRange)
            let bandRect = CGRect(x: 0, y: highY, width: size.width, height: lowY - highY)
            context.fill(Path(bandRect), with: .color(range.widgetAccent.opacity(0.15)))

            // Draw line
            var path = Path()
            for (i, val) in values.enumerated() {
                let x = size.width * Double(i) / Double(values.count - 1)
                let y = size.height * (1 - (val - minVal) / valueRange)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(range.widgetAccent), lineWidth: 2.5)

            // Draw last point
            if let lastVal = values.last {
                let x = size.width
                let y = size.height * (1 - (lastVal - minVal) / valueRange)
                let dot = Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
                context.fill(dot, with: .color(range.widgetAccent))
            }
        }
    }

    private var notConfiguredView: some View {
        HStack(spacing: 16) {
            Image(systemName: "drop.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Glucose Widget")
                    .font(.system(size: 16, weight: .bold))
                Text("Open app to sign in with Dexcom")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill, for: .widget)
    }

    private var noDataView: some View {
        HStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("No Data")
                    .font(.system(size: 16, weight: .medium))
                Text("Waiting for glucose readings...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill, for: .widget)
    }
}

// MARK: - Widget Configuration

struct GlucoseWidget: Widget {
    let kind: String = "GlucoseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GlucoseTimelineProvider()) { entry in
            GlucoseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Glucose Monitor")
        .description("Shows your current Dexcom CGM glucose reading.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GlucoseWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: GlucoseEntry

    var body: some View {
        switch family {
        case .systemSmall:
            GlucoseWidgetSmallView(entry: entry)
        case .systemMedium:
            GlucoseWidgetMediumView(entry: entry)
        default:
            GlucoseWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    GlucoseWidget()
} timeline: {
    GlucoseEntry(
        date: Date(),
        reading: GlucoseReading(value: 120, trend: 4, timestamp: Date().addingTimeInterval(-180)),
        useMmol: false,
        lowThreshold: 70,
        highThreshold: 180,
        isConfigured: true
    )
    GlucoseEntry(
        date: Date(),
        reading: GlucoseReading(value: 210, trend: 2, timestamp: Date().addingTimeInterval(-60)),
        useMmol: false,
        lowThreshold: 70,
        highThreshold: 180,
        isConfigured: true
    )
}

#Preview("Medium", as: .systemMedium) {
    GlucoseWidget()
} timeline: {
    GlucoseEntry(
        date: Date(),
        reading: GlucoseReading(value: 95, trend: 3, timestamp: Date().addingTimeInterval(-120)),
        useMmol: false,
        lowThreshold: 70,
        highThreshold: 180,
        isConfigured: true
    )
}
