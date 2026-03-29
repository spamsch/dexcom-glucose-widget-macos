import SwiftUI
import UserNotifications

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
                .frame(minWidth: 480, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 560)
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isConfigured: Bool
    @Published var currentReading: GlucoseReading?
    @Published var recentReadings: [GlucoseReading] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var notificationsEnabled: Bool

    private let store = GlucoseStore.shared
    private var refreshTimer: Timer?

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

                let readings = try await api.fetchReadings(minutes: 180, maxCount: 36)
                if !readings.isEmpty {
                    recentReadings = readings
                    store.saveReadings(readings)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        guard let api = store.createAPI() else { return }
        isLoading = true
        do {
            let reading = try await api.fetchCurrentReading()
            currentReading = reading
            store.saveReading(reading)

            let readings = try await api.fetchReadings(minutes: 180, maxCount: 36)
            recentReadings = readings
            store.saveReadings(readings)

            checkAndNotify(reading)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func checkAndNotify(_ reading: GlucoseReading) {
        guard notificationsEnabled else { return }
        let defaults = UserDefaults(suiteName: DexcomConstants.appGroupId) ?? .standard
        let notifyLow = defaults.object(forKey: "notify_low") as? Bool ?? true
        let notifyHigh = defaults.object(forKey: "notify_high") as? Bool ?? true
        let urgentOnly = defaults.bool(forKey: "notify_urgent_only")

        let range = reading.glucoseRange(low: store.lowThreshold, high: store.highThreshold)
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

    func logout() {
        store.clearCredentials()
        isConfigured = false
        currentReading = nil
        recentReadings = []
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
