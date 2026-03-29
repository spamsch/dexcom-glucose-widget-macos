import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var username = ""
    @State private var password = ""
    @State private var isOUS = false
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: 0) {
            if currentPage == 0 {
                welcomePage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                loginPage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentPage)
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.1, green: 0.75, blue: 0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.4).opacity(0.4), radius: 20, y: 8)

                Image(systemName: "drop.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text("Glucose Widget")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Monitor your Dexcom CGM readings\nright from your desktop.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Features
            VStack(spacing: 16) {
                featureRow(icon: "gauge.with.dots.needle.33percent", title: "Live Readings", subtitle: "Current glucose value and trend")
                featureRow(icon: "chart.xyaxis.line", title: "Trend Charts", subtitle: "See your glucose over time")
                featureRow(icon: "square.grid.2x2", title: "Desktop Widget", subtitle: "Always visible on your desktop")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                currentPage = 1
            } label: {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.1, green: 0.7, blue: 0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .padding(.top, 24)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.35))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Login Page

    private var loginPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Sign In")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Enter your Dexcom Share credentials")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                // Username
                VStack(alignment: .leading, spacing: 6) {
                    Text("Username or Email")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("your@email.com", text: $username)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }

                // Password
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                        } else {
                            SecureField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }

                // Region toggle
                HStack {
                    Text("Region")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $isOUS) {
                        Text("USA").tag(false)
                        Text("Outside USA").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 40)

            // Error message
            if let error = appState.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        await appState.login(username: username, password: password, ous: isOUS)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if appState.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                        Text(appState.isLoading ? "Connecting..." : "Sign In")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: canLogin
                                ? [Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.1, green: 0.7, blue: 0.45)]
                                : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canLogin || appState.isLoading)

                Button {
                    currentPage = 0
                } label: {
                    Text("Back")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
    }

    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty
    }
}
