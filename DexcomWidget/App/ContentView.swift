import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if appState.isConfigured {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
    }
}
