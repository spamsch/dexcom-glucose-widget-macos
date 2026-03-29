import Foundation
import WidgetKit

/// Shared store for glucose data between the main app and widget extension.
/// Uses UserDefaults with an App Group for cross-process data sharing.
final class GlucoseStore {
    static let shared = GlucoseStore()

    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: DexcomConstants.appGroupId) ?? .standard
    }

    // MARK: - Credentials

    var username: String? {
        get { defaults.string(forKey: DexcomConstants.usernameKey) }
        set { defaults.set(newValue, forKey: DexcomConstants.usernameKey) }
    }

    var isOUS: Bool {
        get { defaults.bool(forKey: DexcomConstants.regionOUSKey) }
        set { defaults.set(newValue, forKey: DexcomConstants.regionOUSKey) }
    }

    var isConfigured: Bool {
        get { defaults.bool(forKey: DexcomConstants.isConfiguredKey) }
        set { defaults.set(newValue, forKey: DexcomConstants.isConfiguredKey) }
    }

    var useMmol: Bool {
        get { defaults.bool(forKey: DexcomConstants.unitMmolKey) }
        set { defaults.set(newValue, forKey: DexcomConstants.unitMmolKey) }
    }

    var highThreshold: Double {
        get {
            let val = defaults.double(forKey: DexcomConstants.highThresholdKey)
            return val > 0 ? val : DexcomConstants.defaultHighThreshold
        }
        set { defaults.set(newValue, forKey: DexcomConstants.highThresholdKey) }
    }

    var lowThreshold: Double {
        get {
            let val = defaults.double(forKey: DexcomConstants.lowThresholdKey)
            return val > 0 ? val : DexcomConstants.defaultLowThreshold
        }
        set { defaults.set(newValue, forKey: DexcomConstants.lowThresholdKey) }
    }

    // MARK: - Glucose Data

    func saveReading(_ reading: GlucoseReading) {
        defaults.set(reading.value, forKey: DexcomConstants.lastGlucoseValueKey)
        defaults.set(reading.trend, forKey: DexcomConstants.lastGlucoseTrendKey)
        defaults.set(reading.timestamp.timeIntervalSince1970, forKey: DexcomConstants.lastGlucoseTimeKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadLastReading() -> GlucoseReading? {
        let value = defaults.integer(forKey: DexcomConstants.lastGlucoseValueKey)
        guard value > 0 else { return nil }
        let trend = defaults.integer(forKey: DexcomConstants.lastGlucoseTrendKey)
        let time = defaults.double(forKey: DexcomConstants.lastGlucoseTimeKey)
        guard time > 0 else { return nil }
        return GlucoseReading(
            value: value,
            trend: trend,
            timestamp: Date(timeIntervalSince1970: time)
        )
    }

    // MARK: - Recent Readings (for chart)

    func saveReadings(_ readings: [GlucoseReading]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(readings) {
            defaults.set(data, forKey: "recentReadings")
            defaults.synchronize()
        }
    }

    func loadReadings() -> [GlucoseReading] {
        guard let data = defaults.data(forKey: "recentReadings") else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([GlucoseReading].self, from: data)) ?? []
    }

    // MARK: - API Client

    func createAPI() -> DexcomAPI? {
        guard let username, let password = KeychainHelper.load(for: "dexcom_password") else {
            return nil
        }
        return DexcomAPI(username: username, password: password, ous: isOUS)
    }

    func saveCredentials(username: String, password: String, ous: Bool) {
        self.username = username
        self.isOUS = ous
        KeychainHelper.save(password: password, for: "dexcom_password")
        self.isConfigured = true
    }

    func clearCredentials() {
        username = nil
        isConfigured = false
        KeychainHelper.delete(for: "dexcom_password")
        defaults.removeObject(forKey: DexcomConstants.lastGlucoseValueKey)
        defaults.removeObject(forKey: DexcomConstants.lastGlucoseTrendKey)
        defaults.removeObject(forKey: DexcomConstants.lastGlucoseTimeKey)
        defaults.removeObject(forKey: "recentReadings")
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
