import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Account
    @State private var username: String
    @State private var password: String
    @State private var isOUS: Bool
    @State private var showPassword = false

    // Thresholds
    @State private var lowThreshold: Double
    @State private var highThreshold: Double

    // Units
    @State private var useMmol: Bool

    // Notifications
    @State private var notificationsEnabled: Bool
    @State private var notifyOnLow: Bool
    @State private var notifyOnHigh: Bool
    @State private var notifyOnUrgentOnly: Bool

    // Glooko
    @State private var glookoUsername: String
    @State private var glookoPassword: String
    @State private var showGlookoPassword = false

    // State
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var showDeleteConfirm = false

    private let store = GlucoseStore.shared
    private let originalUsername: String
    private let originalPassword: String
    private let originalOUS: Bool

    init() {
        let store = GlucoseStore.shared
        let savedUsername = store.username ?? ""
        let savedPassword = KeychainHelper.load(for: "dexcom_password") ?? ""
        let savedOUS = store.isOUS
        originalUsername = savedUsername
        originalPassword = savedPassword
        originalOUS = savedOUS
        _username = State(initialValue: savedUsername)
        _password = State(initialValue: savedPassword)
        _isOUS = State(initialValue: savedOUS)
        _lowThreshold = State(initialValue: store.lowThreshold)
        _highThreshold = State(initialValue: store.highThreshold)
        _useMmol = State(initialValue: store.useMmol)
        _glookoUsername = State(initialValue: store.glookoUsername ?? "")
        _glookoPassword = State(initialValue: KeychainHelper.load(for: "glooko_password") ?? "")

        let defaults = UserDefaults(suiteName: DexcomConstants.appGroupId) ?? .standard
        _notificationsEnabled = State(initialValue: defaults.bool(forKey: "notifications_enabled"))
        _notifyOnLow = State(initialValue: defaults.object(forKey: "notify_low") as? Bool ?? true)
        _notifyOnHigh = State(initialValue: defaults.object(forKey: "notify_high") as? Bool ?? true)
        _notifyOnUrgentOnly = State(initialValue: defaults.bool(forKey: "notify_urgent_only"))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    accountSection
                    glookoSection
                    thresholdSection
                    unitSection
                    notificationSection
                    dangerSection
                }
                .padding(24)
            }

            Divider()

            // Save button
            HStack {
                if let msg = saveMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(msg.contains("Saved") ? .green : .red)
                        .transition(.opacity)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 12)
                Button {
                    save()
                } label: {
                    Text(isSaving ? "Saving..." : "Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.15, green: 0.55, blue: 0.35))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 580)
    }

    // MARK: - Account

    private var accountSection: some View {
        settingsCard(title: "Account", icon: "person.circle") {
            VStack(spacing: 12) {
                LabeledField(label: "Username or Email") {
                    TextField("your@email.com", text: $username)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }

                LabeledField(label: "Password") {
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                        } else {
                            SecureField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }

                HStack {
                    Text("Region")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $isOUS) {
                        Text("USA").tag(false)
                        Text("Outside USA").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
        }
    }

    // MARK: - Glooko

    private var glookoSection: some View {
        settingsCard(title: "Glooko (Pump Data)", icon: "cross.case") {
            VStack(spacing: 12) {
                Text("Optional — connect to Glooko to see pump statistics like insulin delivery, pump mode, and IOB.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LabeledField(label: "Glooko Email") {
                    TextField("your@email.com", text: $glookoUsername)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }

                LabeledField(label: "Glooko Password") {
                    HStack {
                        if showGlookoPassword {
                            TextField("Password", text: $glookoPassword)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                        } else {
                            SecureField("Password", text: $glookoPassword)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                        }
                        Button {
                            showGlookoPassword.toggle()
                        } label: {
                            Image(systemName: showGlookoPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }

                if store.isGlookoConfigured {
                    Button {
                        glookoUsername = ""
                        glookoPassword = ""
                        store.clearGlookoCredentials()
                        saveMessage = "Glooko disconnected"
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                            Text("Disconnect Glooko")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Thresholds

    private var thresholdSection: some View {
        settingsCard(title: "Glucose Thresholds", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 16) {
                ThresholdRow(
                    label: "Low",
                    value: $lowThreshold,
                    range: 50...100,
                    color: .orange,
                    useMmol: useMmol
                )
                ThresholdRow(
                    label: "High",
                    value: $highThreshold,
                    range: 120...300,
                    color: .orange,
                    useMmol: useMmol
                )
            }
        }
    }

    // MARK: - Units

    private var unitSection: some View {
        settingsCard(title: "Display Unit", icon: "textformat.123") {
            Picker("", selection: $useMmol) {
                Text("mg/dL").tag(false)
                Text("mmol/L").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        settingsCard(title: "Notifications", icon: "bell.badge") {
            VStack(spacing: 12) {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                    .font(.system(size: 13))
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled { requestNotificationPermission() }
                    }

                if notificationsEnabled {
                    VStack(spacing: 8) {
                        Toggle("Notify on low glucose", isOn: $notifyOnLow)
                            .font(.system(size: 13))
                        Toggle("Notify on high glucose", isOn: $notifyOnHigh)
                            .font(.system(size: 13))
                        Toggle("Urgent alerts only", isOn: $notifyOnUrgentOnly)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)

                    Divider()

                    VStack(spacing: 8) {
                        Text("Test Notifications")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            testNotificationButton(
                                label: "Low",
                                color: .orange,
                                value: Int(lowThreshold) - 5,
                                trend: 6,
                                range: .low
                            )
                            testNotificationButton(
                                label: "Urgent Low",
                                color: .red,
                                value: 50,
                                trend: 7,
                                range: .urgentLow
                            )
                            testNotificationButton(
                                label: "High",
                                color: .orange,
                                value: Int(highThreshold) + 20,
                                trend: 2,
                                range: .high
                            )
                            testNotificationButton(
                                label: "Urgent High",
                                color: .red,
                                value: 260,
                                trend: 1,
                                range: .urgentHigh
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        settingsCard(title: "Account", icon: "exclamationmark.triangle", tint: .red) {
            Button {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out & Clear Data")
                }
                .font(.system(size: 13))
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .alert("Sign Out?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    appState.logout()
                    dismiss()
                }
            } message: {
                Text("This will remove your saved credentials and all cached data.")
            }
        }
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        tint: Color = Color(red: 0.15, green: 0.55, blue: 0.35),
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func testNotificationButton(label: String, color: Color, value: Int, trend: Int, range: GlucoseRange) -> some View {
        Button {
            sendTestNotification(label: label, value: value, trend: trend, range: range)
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.8))
                )
        }
        .buttonStyle(.plain)
    }

    private func sendTestNotification(label: String, value: Int, trend: Int, range: GlucoseRange) {
        let reading = GlucoseReading(value: value, trend: trend, timestamp: Date())
        let displayVal = reading.displayValue(useMmol: useMmol)
        let displayUnit = reading.displayUnit(useMmol: useMmol)

        // Ensure permission is granted before sending
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async {
                    saveMessage = "Notification permission denied. Enable in System Settings."
                }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "TEST: \(label) Glucose"
            content.body = "\(displayVal) \(displayUnit) \(reading.trendArrow) — This is a test notification"
            content.sound = range == .urgentLow || range == .urgentHigh
                ? .defaultCritical : .default

            let request = UNNotificationRequest(
                identifier: "test-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private var credentialsChanged: Bool {
        username != originalUsername || password != originalPassword || isOUS != originalOUS
    }

    private func save() {
        isSaving = true

        // Only write credentials to keychain if they actually changed
        if credentialsChanged {
            store.saveCredentials(username: username, password: password, ous: isOUS)
        }

        // Save Glooko credentials
        if !glookoUsername.isEmpty && !glookoPassword.isEmpty {
            store.saveGlookoCredentials(username: glookoUsername, password: glookoPassword)
        } else if glookoUsername.isEmpty {
            store.clearGlookoCredentials()
        }

        // Save thresholds
        store.lowThreshold = lowThreshold
        store.highThreshold = highThreshold
        store.useMmol = useMmol

        // Save notification prefs
        let defaults = UserDefaults(suiteName: DexcomConstants.appGroupId) ?? .standard
        defaults.set(notificationsEnabled, forKey: "notifications_enabled")
        defaults.set(notifyOnLow, forKey: "notify_low")
        defaults.set(notifyOnHigh, forKey: "notify_high")
        defaults.set(notifyOnUrgentOnly, forKey: "notify_urgent_only")
        defaults.synchronize()

        // Update app state
        appState.notificationsEnabled = notificationsEnabled

        withAnimation {
            saveMessage = "Saved!"
        }
        isSaving = false

        // Refresh data if needed
        Task {
            if credentialsChanged {
                await appState.refresh()
            }
            if store.isGlookoConfigured {
                await appState.refreshGlooko()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted {
                DispatchQueue.main.async {
                    notificationsEnabled = false
                    saveMessage = "Notification permission denied. Enable in System Settings."
                }
            }
        }
    }
}

// MARK: - Subviews

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct ThresholdRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    let useMmol: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 40, alignment: .leading)

            Slider(value: $value, in: range, step: 1)
                .tint(color)

            Text(displayValue)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
        }
    }

    private var displayValue: String {
        if useMmol {
            let mmol = value * DexcomConstants.mmolConversionFactor
            return String(format: "%.1f mmol", mmol)
        }
        return "\(Int(value)) mg/dL"
    }
}
