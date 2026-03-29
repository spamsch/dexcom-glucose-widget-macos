import Foundation
import SwiftUI

struct GlucoseReading: Codable, Identifiable {
    let id = UUID()
    let value: Int
    let trend: Int
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case value = "Value"
        case trend = "Trend"
        case timestamp = "WT"
    }

    init(value: Int, trend: Int, timestamp: Date) {
        self.value = value
        self.trend = trend
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Int.self, forKey: .value)
        trend = try container.decode(Int.self, forKey: .trend)

        let wtString = try container.decode(String.self, forKey: .timestamp)
        timestamp = GlucoseReading.parseDate(from: wtString)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(trend, forKey: .trend)
        let ms = Int(timestamp.timeIntervalSince1970 * 1000)
        try container.encode("/Date(\(ms))/", forKey: .timestamp)
    }

    private static func parseDate(from wtString: String) -> Date {
        // Format: /Date(1698765432000)/
        let pattern = /\/Date\((-?\d+)\)\//
        if let match = wtString.firstMatch(of: pattern),
           let ms = Double(match.1) {
            return Date(timeIntervalSince1970: ms / 1000.0)
        }
        return Date()
    }

    var mgDl: Int { value }

    var mmolL: Double {
        (Double(value) * DexcomConstants.mmolConversionFactor * 10).rounded() / 10
    }

    var trendArrow: String {
        switch trend {
        case 1: return "↑↑"
        case 2: return "↑"
        case 3: return "↗"
        case 4: return "→"
        case 5: return "↘"
        case 6: return "↓"
        case 7: return "↓↓"
        case 8: return "?"
        case 9: return "-"
        default: return ""
        }
    }

    var trendDescription: String {
        switch trend {
        case 1: return "Rising quickly"
        case 2: return "Rising"
        case 3: return "Rising slightly"
        case 4: return "Steady"
        case 5: return "Falling slightly"
        case 6: return "Falling"
        case 7: return "Falling quickly"
        case 8: return "Unable to determine"
        case 9: return "Unavailable"
        default: return "Unknown"
        }
    }

    var trendSFSymbol: String {
        switch trend {
        case 1: return "arrow.up"
        case 2: return "arrow.up"
        case 3: return "arrow.up.right"
        case 4: return "arrow.right"
        case 5: return "arrow.down.right"
        case 6: return "arrow.down"
        case 7: return "arrow.down"
        case 8: return "questionmark"
        case 9: return "minus"
        default: return "questionmark"
        }
    }

    var isDoubleArrow: Bool {
        trend == 1 || trend == 7
    }

    func glucoseRange(low: Double = DexcomConstants.defaultLowThreshold,
                      high: Double = DexcomConstants.defaultHighThreshold) -> GlucoseRange {
        let v = Double(value)
        if v < DexcomConstants.urgentLow { return .urgentLow }
        if v < low { return .low }
        if v > DexcomConstants.urgentHigh { return .urgentHigh }
        if v > high { return .high }
        return .inRange
    }

    var minutesAgo: Int {
        Int(Date().timeIntervalSince(timestamp) / 60)
    }

    var timeAgoText: String {
        let mins = minutesAgo
        if mins < 1 { return "Just now" }
        if mins == 1 { return "1 min ago" }
        if mins < 60 { return "\(mins) min ago" }
        let hours = mins / 60
        if hours == 1 { return "1 hr ago" }
        return "\(hours) hrs ago"
    }

    func displayValue(useMmol: Bool) -> String {
        useMmol ? String(format: "%.1f", mmolL) : "\(mgDl)"
    }

    func displayUnit(useMmol: Bool) -> String {
        useMmol ? "mmol/L" : "mg/dL"
    }
}

enum GlucoseRange {
    case urgentLow, low, inRange, high, urgentHigh

    var color: Color {
        switch self {
        case .urgentLow: return .red
        case .low: return .orange
        case .inRange: return .green
        case .high: return .orange
        case .urgentHigh: return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .urgentLow: return Color(red: 0.3, green: 0.05, blue: 0.05)
        case .low: return Color(red: 0.3, green: 0.2, blue: 0.05)
        case .inRange: return Color(red: 0.05, green: 0.2, blue: 0.1)
        case .high: return Color(red: 0.3, green: 0.2, blue: 0.05)
        case .urgentHigh: return Color(red: 0.3, green: 0.05, blue: 0.05)
        }
    }

    var gradient: [Color] {
        switch self {
        case .urgentLow:
            return [Color(red: 0.6, green: 0.1, blue: 0.1), Color(red: 0.4, green: 0.05, blue: 0.1)]
        case .low:
            return [Color(red: 0.7, green: 0.4, blue: 0.1), Color(red: 0.5, green: 0.25, blue: 0.05)]
        case .inRange:
            return [Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.1, green: 0.4, blue: 0.3)]
        case .high:
            return [Color(red: 0.7, green: 0.4, blue: 0.1), Color(red: 0.5, green: 0.25, blue: 0.05)]
        case .urgentHigh:
            return [Color(red: 0.6, green: 0.1, blue: 0.1), Color(red: 0.4, green: 0.05, blue: 0.1)]
        }
    }

    var label: String {
        switch self {
        case .urgentLow: return "URGENT LOW"
        case .low: return "LOW"
        case .inRange: return "IN RANGE"
        case .high: return "HIGH"
        case .urgentHigh: return "URGENT HIGH"
        }
    }
}
