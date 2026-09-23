import Foundation
import Security

struct AICloudConfiguration: Decodable {
    let projectURL: String
    let publishableKey: String
    var backendURL: String { projectURL + "/functions/v1/listening-api" }

    static let current: AICloudConfiguration = {
        guard let url = Bundle.main.url(forResource: "CloudConfiguration", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let config = try? PropertyListDecoder().decode(AICloudConfiguration.self, from: data) else {
            return AICloudConfiguration(projectURL: "", publishableKey: "")
        }
        return config
    }()
}

@MainActor
final class AIListeningAuth {
    static let shared = AIListeningAuth()

    private struct Session: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double?
        var expiresAt: Double?
    }

    private var session: Session?
    private var pending: Task<String, Error>?
    private let configuration = AICloudConfiguration.current
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "tcf-listening-device-session",
         kSecAttrAccount as String: configuration.projectURL]
    }

    func accessToken(forceRefresh: Bool = false) async throws -> String {
        if let pending { return try await pending.value }
        if session == nil { session = readSession() }
        if !forceRefresh, let session, (session.expiresAt ?? 0) > Date().timeIntervalSince1970 + 60 {
            return session.accessToken
        }
        let task = Task { try await self.connect() }
        pending = task
        defer { pending = nil }
        return try await task.value
    }

    private func connect() async throws -> String {
        let path = session == nil ? "/auth/v1/signup" : "/auth/v1/token?grant_type=refresh_token"
        guard let url = URL(string: configuration.projectURL + path), !configuration.publishableKey.isEmpty else {
            throw AIListeningError.message("Le service d'écoute est momentanément indisponible.")
        }
        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(session.map { ["refresh_token": $0.refreshToken] } ?? [:])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw AIListeningError.message("Connexion automatique indisponible pour le moment. Vérifiez votre connexion Internet, puis réessayez.")
        }
        var connected = try decoder.decode(Session.self, from: data)
        if connected.expiresAt == nil { connected.expiresAt = Date().timeIntervalSince1970 + (connected.expiresIn ?? 3600) }
        try saveSession(connected)
        session = connected
        return connected.accessToken
    }

    private func readSession() -> Session? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    private func saveSession(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)
        let query = keychainQuery
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
                throw AIListeningError.message("Impossible de conserver la connexion sécurisée sur cet appareil.")
            }
        } else if status != errSecSuccess {
            throw AIListeningError.message("Impossible de mettre à jour la connexion sécurisée.")
        }
    }
}
