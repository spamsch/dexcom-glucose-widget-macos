import SwiftUI

@main
struct DexcomWidgetApp: App {
    @StateObject private var appState = AppState()

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

    private let store = GlucoseStore.shared
    private var refreshTimer: Timer?

    init() {
        isConfigured = store.isConfigured
        currentReading = store.loadLastReading()
        recentReadings = store.loadReadings()
    }

    func login(username: String, password: String, ous: Bool) async {
        isLoading = true
        errorMessage = nil

        let api = DexcomAPI(username: username, password: password, ous: ous)
        do {
            try await api.authenticate()
            let reading = try await api.fetchCurrentReading()

            store.saveCredentials(username: username, password: password, ous: ous)
            store.saveReading(reading)
            currentReading = reading

            // Fetch recent readings for chart
            let readings = try await api.fetchReadings(minutes: 180, maxCount: 36)
            recentReadings = readings
            store.saveReadings(readings)

            isConfigured = true
            startRefreshTimer()
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

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
