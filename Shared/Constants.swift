import Foundation

enum DexcomConstants {
    static let applicationId = "d89443d2-327c-4a6f-89e5-496bbb0317db"
    static let baseURL = "https://share2.dexcom.com/ShareWebServices/Services"
    static let baseURLOUS = "https://shareous1.dexcom.com/ShareWebServices/Services"
    static let defaultSessionId = "00000000-0000-0000-0000-000000000000"

    static let authenticateEndpoint = "/General/AuthenticatePublisherAccount"
    static let loginEndpoint = "/General/LoginPublisherAccountById"
    static let glucoseEndpoint = "/Publisher/ReadPublisherLatestGlucoseValues"

    static let appGroupId = "group.com.dexcomwidget.shared"
    static let keychainService = "com.dexcomwidget.credentials"

    // UserDefaults keys (shared via App Group)
    static let lastGlucoseValueKey = "lastGlucoseValue"
    static let lastGlucoseTrendKey = "lastGlucoseTrend"
    static let lastGlucoseTimeKey = "lastGlucoseTime"
    static let isConfiguredKey = "isConfigured"
    static let usernameKey = "dexcom_username"
    static let regionOUSKey = "dexcom_ous"
    static let unitMmolKey = "unit_mmol"
    static let highThresholdKey = "high_threshold"
    static let lowThresholdKey = "low_threshold"

    // Glucose ranges
    static let defaultLowThreshold: Double = 70
    static let defaultHighThreshold: Double = 180
    static let urgentLow: Double = 55
    static let urgentHigh: Double = 250

    static let mmolConversionFactor: Double = 0.0555

    // Glooko
    static let glookoUsernameKey = "glooko_username"
}
