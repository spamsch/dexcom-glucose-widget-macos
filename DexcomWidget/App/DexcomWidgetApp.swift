import SwiftUI
import UserNotifications
import GlookoReader

/// Allows notifications to display while the app is in the foreground.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct DexcomWidgetApp: App {
    @StateObject private var appState = AppState()
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 480, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 700)
    }
}

struct GlookoStats {
    var pumpMode: String
    var autoPercentage: Double
    var totalInsulinPerDay: Double
    var basalPercentage: Double
    var bolusPercentage: Double
    var carbsPerDay: Double
    var iob: Double?
    var lastSync: Date?
    var lastUpdated: Date
}

@MainActor
class AppState: ObservableObject {
    @Published var isConfigured: Bool
    @Published var currentReading: GlucoseReading?
    @Published var recentReadings: [GlucoseReading] = []
    @Published var dailyReadings: [GlucoseReading] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var notificationsEnabled: Bool
    @Published var glookoStats: GlookoStats?
    @Published var glookoError: String?

    private let store = GlucoseStore.shared
    private var refreshTimer: Timer?
    private var glookoClient: GlookoClient?

    init() {
        isConfigured = store.isConfigured
        currentReading = store.loadLastReading()
        recentReadings = store.loadReadings()
        let defaults = UserDefaults(suiteName: DexcomConstants.appGroupId) ?? .standard
        notificationsEnabled = defaults.bool(forKey: "notifications_enabled")
    }

    func login(username: String, password: String, ous: Bool) async {
        isLoading = true
        errorMessage = nil

        let api = DexcomAPI(username: username, password: password, ous: ous)
        do {
            try await api.authenticate()

            // Auth succeeded — save credentials and proceed regardless of data availability
            store.saveCredentials(username: username, password: password, ous: ous)
            isConfigured = true
            startRefreshTimer()

            // Try to fetch current data (non-blocking for onboarding)
            do {
                let reading = try await api.fetchCurrentReading()
                store.saveReading(reading)
                currentReading = reading

                let allReadings = try await api.fetchReadings(minutes: 1440, maxCount: 288)
                if !allReadings.isEmpty {
                    dailyReadings = allReadings
                    let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
                    recentReadings = allReadings.filter { $0.timestamp >= threeHoursAgo }
                    store.saveReadings(recentReadings)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Light refresh: only fetches the latest reading. Called every 5 minutes by the timer.
    func refresh() async {
        guard let api = store.createAPI() else { return }
        isLoading = true
        do {
            let reading = try await api.fetchCurrentReading()
            currentReading = reading
            store.saveReading(reading)

            // Append to existing daily readings (avoid re-fetching all 288)
            if !dailyReadings.contains(where: { $0.timestamp == reading.timestamp }) {
                dailyReadings.insert(reading, at: 0)
                // Trim readings older than 24h
                let cutoff = Date().addingTimeInterval(-24 * 3600)
                dailyReadings.removeAll { $0.timestamp < cutoff }
            }
            let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
            recentReadings = dailyReadings.filter { $0.timestamp >= threeHoursAgo }
            store.saveReadings(recentReadings)

            checkAndNotify(reading)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Full refresh: fetches all 24h of data. Called on launch and manual refresh.
    func fullRefresh() async {
        guard let api = store.createAPI() else { return }
        isLoading = true
        do {
            let reading = try await api.fetchCurrentReading()
            currentReading = reading
            store.saveReading(reading)

            let allReadings = try await api.fetchReadings(minutes: 1440, maxCount: 288)
            dailyReadings = allReadings
            let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
            recentReadings = allReadings.filter { $0.timestamp >= threeHoursAgo }
            store.saveReadings(recentReadings)

            checkAndNotify(reading)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        await refreshGlooko()
    }

    private func checkAndNotify(_ reading: GlucoseReading) {
        guard notificationsEnabled else { return }
        let defaults = UserDefaults(suiteName: DexcomConstants.appGroupId) ?? .standard
        let notifyLow = defaults.object(forKey: "notify_low") as? Bool ?? true
        let notifyHigh = defaults.object(forKey: "notify_high") as? Bool ?? true
        let urgentOnly = defaults.bool(forKey: "notify_urgent_only")

        let range = reading.glucoseRange()
        let useMmol = store.useMmol

        var shouldNotify = false
        var title = ""
        var body = ""
        let valueText = "\(reading.displayValue(useMmol: useMmol)) \(reading.displayUnit(useMmol: useMmol))"

        switch range {
        case .urgentLow:
            if notifyLow {
                shouldNotify = true
                title = "Urgent Low Glucose"
                body = "\(valueText) \(reading.trendArrow) — Take action immediately"
            }
        case .low:
            if notifyLow && !urgentOnly {
                shouldNotify = true
                title = "Low Glucose"
                body = "\(valueText) \(reading.trendArrow) — \(reading.trendDescription)"
            }
        case .high:
            if notifyHigh && !urgentOnly {
                shouldNotify = true
                title = "High Glucose"
                body = "\(valueText) \(reading.trendArrow) — \(reading.trendDescription)"
            }
        case .urgentHigh:
            if notifyHigh {
                shouldNotify = true
                title = "Urgent High Glucose"
                body = "\(valueText) \(reading.trendArrow) — Take action"
            }
        case .inRange:
            break
        }

        guard shouldNotify else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = range == .urgentLow || range == .urgentHigh
            ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: "glucose-\(reading.timestamp.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Glooko

    func refreshGlooko() async {
        guard store.isGlookoConfigured,
              let email = store.glookoUsername,
              let password = KeychainHelper.load(for: "glooko_password") else {
            glookoStats = nil
            return
        }

        do {
            // Always create a fresh client to avoid stale sessions
            let client = GlookoClient(email: email, password: password, sessionTimeoutMinutes: 4)
            glookoClient = client
            try await client.authenticate()

            // Fetch statistics and graph data in parallel
            async let statsData = client.getStatistics(dateRange: .lastDays(1))
            async let graphData = client.getGraphData(dateRange: .lastDays(1))
            async let deviceData = client.getDeviceSettings()

            let stats = try await statsData
            let graph = try await graphData
            let devices = try await deviceData

            var pumpStats: PumpStatistics?
            if let stats { pumpStats = parsePumpMode(from: stats) }

            var iob: Double?
            var lastDataTimestamp: Date?
            if let graph {
                iob = parseIOBFromBolus(from: graph)
                let boluses = parseBolusEntries(from: graph)
                lastDataTimestamp = boluses.map(\.timestamp).max()
            }

            var lastSync: Date?
            if let devices {
                let deviceList = parseDevices(from: devices)
                lastSync = deviceList.compactMap(\.lastSync).max()
            }
            // Prefer device sync time, fall back to most recent bolus timestamp
            let lastPumpUpdate = lastSync ?? lastDataTimestamp

            glookoStats = GlookoStats(
                pumpMode: pumpStats?.mode?.rawValue.capitalized ?? "Unknown",
                autoPercentage: pumpStats?.autoPercentage ?? 0,
                totalInsulinPerDay: pumpStats?.totalInsulinPerDay ?? 0,
                basalPercentage: pumpStats?.basalPercentage ?? 0,
                bolusPercentage: pumpStats?.bolusPercentage ?? 0,
                carbsPerDay: pumpStats?.carbsPerDay ?? 0,
                iob: iob,
                lastSync: lastPumpUpdate,
                lastUpdated: Date()
            )
            glookoError = nil
        } catch {
            glookoError = error.localizedDescription
            // Keep stale stats visible, just show error
        }
    }

    func logout() {
        store.clearCredentials()
        isConfigured = false
        currentReading = nil
        recentReadings = []
        glookoStats = nil
        glookoClient = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }
}
