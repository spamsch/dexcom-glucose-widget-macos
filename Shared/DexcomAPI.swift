import Foundation

enum DexcomAPIError: LocalizedError {
    case invalidCredentials
    case accountNotFound
    case maxAttemptsExceeded
    case sessionExpired
    case networkError(String)
    case noData
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid username or password."
        case .accountNotFound: return "Dexcom account not found. Check your username."
        case .maxAttemptsExceeded: return "Too many login attempts. Try again later."
        case .sessionExpired: return "Session expired. Reconnecting..."
        case .networkError(let msg): return "Network error: \(msg)"
        case .noData: return "No glucose data available."
        case .invalidResponse: return "Unexpected response from Dexcom."
        }
    }
}

actor DexcomAPI {
    private let username: String
    private let password: String
    private let baseURL: String
    private var sessionId: String?
    private var accountId: String?

    init(username: String, password: String, ous: Bool) {
        self.username = username
        self.password = password
        self.baseURL = ous ? DexcomConstants.baseURLOUS : DexcomConstants.baseURL
    }

    func authenticate() async throws {
        accountId = try await getAccountId()
        sessionId = try await getSessionId()
    }

    func fetchCurrentReading() async throws -> GlucoseReading {
        if sessionId == nil {
            try await authenticate()
        }
        do {
            return try await fetchLatestReading()
        } catch DexcomAPIError.sessionExpired {
            try await authenticate()
            return try await fetchLatestReading()
        }
    }

    func fetchReadings(minutes: Int = 1440, maxCount: Int = 288) async throws -> [GlucoseReading] {
        if sessionId == nil {
            try await authenticate()
        }
        do {
            return try await fetchGlucoseReadings(minutes: minutes, maxCount: maxCount)
        } catch DexcomAPIError.sessionExpired {
            try await authenticate()
            return try await fetchGlucoseReadings(minutes: minutes, maxCount: maxCount)
        }
    }

    // MARK: - Private

    private func getAccountId() async throws -> String {
        let body: [String: String] = [
            "accountName": username,
            "password": password,
            "applicationId": DexcomConstants.applicationId
        ]
        let data = try await post(endpoint: DexcomConstants.authenticateEndpoint, body: body)
        guard let id = parseStringResponse(data), id != DexcomConstants.defaultSessionId else {
            throw DexcomAPIError.accountNotFound
        }
        return id
    }

    private func getSessionId() async throws -> String {
        guard let accountId else { throw DexcomAPIError.accountNotFound }
        let body: [String: String] = [
            "accountId": accountId,
            "password": password,
            "applicationId": DexcomConstants.applicationId
        ]
        let data = try await post(endpoint: DexcomConstants.loginEndpoint, body: body)
        guard let id = parseStringResponse(data), id != DexcomConstants.defaultSessionId else {
            throw DexcomAPIError.invalidCredentials
        }
        return id
    }

    private func fetchLatestReading() async throws -> GlucoseReading {
        // Use 1440 minutes (24h) window to find the most recent reading
        let readings = try await fetchGlucoseReadings(minutes: 1440, maxCount: 1)
        guard let reading = readings.first else {
            throw DexcomAPIError.noData
        }
        return reading
    }

    private func fetchGlucoseReadings(minutes: Int, maxCount: Int) async throws -> [GlucoseReading] {
        guard let sessionId else { throw DexcomAPIError.sessionExpired }

        var components = URLComponents(string: baseURL + DexcomConstants.glucoseEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "minutes", value: "\(minutes)"),
            URLQueryItem(name: "maxCount", value: "\(maxCount)")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try checkErrorResponse(data)
        }

        let decoder = JSONDecoder()
        let readings = try decoder.decode([GlucoseReading].self, from: data)
        return readings
    }

    private func post(endpoint: String, body: [String: String]) async throws -> Data {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try checkErrorResponse(data)
        }

        return data
    }

    private func checkErrorResponse(_ data: Data) throws {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["Code"] as? String {
            switch code {
            case "SSO_AuthenticateAccountNotFound":
                throw DexcomAPIError.accountNotFound
            case "AccountPasswordInvalid":
                throw DexcomAPIError.invalidCredentials
            case "SSO_AuthenticateMaxAttemptsExceeed":
                throw DexcomAPIError.maxAttemptsExceeded
            case "SessionNotValid", "SessionIdNotFound":
                throw DexcomAPIError.sessionExpired
            default:
                let message = json["Message"] as? String ?? "Unknown error"
                throw DexcomAPIError.networkError(message)
            }
        }
        throw DexcomAPIError.invalidResponse
    }

    private func parseStringResponse(_ data: Data) -> String? {
        // API returns a quoted string like "abc-def-123"
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        return str.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
