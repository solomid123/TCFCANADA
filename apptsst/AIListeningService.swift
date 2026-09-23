import SwiftUI
import Combine
import CryptoKit
import Security

struct AIListeningAsset: Codable {
    let name: String
    let sha256: String
    let bytes: Int
}

struct AIListeningQuestion: Codable, Identifiable {
    let id: Int
    let kind: String
    let level: String
    let question: String
    let options: [String]
    let audio: AIListeningAsset
    let image: AIListeningAsset?
    let duration: Double
    var spokenOptions: Bool { kind == "picture" || kind == "response" }
}

struct AIListeningManifest: Codable {
    let id: String
    let title: String
    let questions: [AIListeningQuestion]
}

struct AIListeningJob: Decodable {
    let id: String
    let state: String
    let phase: String
    let planned: Int
    let images: Int
    let audio: Int
    let total: Int
    let error: String?
}

struct AIListeningCorrection: Codable, Identifiable {
    let id: Int
    let options: [String]
    let correctIndex: Int
    let explanation: String
    let transcript: String
}

struct AIListeningResult: Codable {
    let correct: Int
    let total: Int
    let answered: Int
    let questions: [AIListeningCorrection]
}

private struct AIListeningAttempt: Codable {
    var answers: [Int: Int] = [:]
    var index = 0
    var started = false
    var result: AIListeningResult?
}

enum AIListeningError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}

enum AIListeningConnection {
    static var baseURL: String {
        #if DEBUG
        if ProcessInfo.processInfo.environment["TCF_USE_HOSTED_LISTENING"] == "1" { return AICloudConfiguration.current.backendURL }
        if let override = ProcessInfo.processInfo.environment["TCF_BACKEND_URL"] { return override }
        if let saved = UserDefaults.standard.string(forKey: "ai-listening-backend") { return saved }
        #endif
        return AICloudConfiguration.current.backendURL
    }

    static func isHosted(_ url: String) -> Bool { url == AICloudConfiguration.current.backendURL }

    static func authorization(for url: String, refresh: Bool = false) async throws -> String {
        if isHosted(url) { return try await AIListeningAuth.shared.accessToken(forceRefresh: refresh) }
        return token(for: url)
    }

    static func token(for baseURL: String) -> String {
        if let override = ProcessInfo.processInfo.environment["TCF_BACKEND_TOKEN"] { return override }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "tcf-listening-backend",
                                   kSecAttrAccount as String: baseURL,
                                   kSecReturnData as String: true,
                                   kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func save(baseURL: String, token: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "tcf-listening-backend",
                                   kSecAttrAccount as String: baseURL]
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
                throw AIListeningError.message("Impossible d'enregistrer le jeton dans le trousseau.")
            }
        } else if status != errSecSuccess {
            throw AIListeningError.message("Impossible de mettre à jour le jeton.")
        }
        UserDefaults.standard.set(baseURL, forKey: "ai-listening-backend")
    }
}

@MainActor
final class AIListeningStore: ObservableObject {
    enum Stage { case preparing, ready, practice, review }
    @Published var stage: Stage = .preparing
    @Published var job: AIListeningJob?
    @Published var manifest: AIListeningManifest?
    @Published var error: String?
    @Published var downloads = 0
    @Published var downloadTotal = 43
    @Published var isSubmitting = false
    @Published private var attempt = AIListeningAttempt()
    private var preparation: Task<Void, Never>?
    private var baseURL = ""
    private var sessionID = ""
    private var folder: URL?
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    var answers: [Int: Int] { attempt.answers }
    var index: Int { attempt.index }
    var result: AIListeningResult? { attempt.result }
    var question: AIListeningQuestion? {
        guard let questions = manifest?.questions, questions.indices.contains(index) else { return nil }
        return questions[index]
    }

    func prepare(retry: Bool = false, newSession: Bool = false, savedSessionID: String? = nil) {
        preparation?.cancel()
        preparation = Task { await load(retry: retry, newSession: newSession, savedSessionID: savedSessionID) }
    }

    func cancelPreparation() { preparation?.cancel() }

    private func load(retry: Bool, newSession: Bool, savedSessionID: String?) async {
        stage = .preparing
        error = nil
        job = nil
        downloads = 0
        manifest = nil
        attempt = AIListeningAttempt()
        baseURL = AIListeningConnection.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        do {
            guard let url = URL(string: baseURL), ["http", "https"].contains(url.scheme), url.host != nil else {
                throw AIListeningError.message("Le service d'écoute est momentanément indisponible. Réessayez.")
            }
            #if DEBUG
            // Simulator launch configuration can bootstrap the same Keychain settings as the form.
            if let token = ProcessInfo.processInfo.environment["TCF_BACKEND_TOKEN"], !token.isEmpty {
                try? AIListeningConnection.save(baseURL: baseURL, token: token)
            }
            #endif
            let hostKey = SHA256.hash(data: Data(baseURL.utf8)).map { String(format: "%02x", $0) }.joined()
            let defaultsKey = "ai-listening-session-\(hostKey)"
            let storedID = savedSessionID ?? ProcessInfo.processInfo.environment["TCF_LISTENING_SESSION_ID"] ?? UserDefaults.standard.string(forKey: defaultsKey)
            sessionID = (!newSession ? storedID.flatMap { UUID(uuidString: $0)?.uuidString.lowercased() } : nil) ?? UUID().uuidString.lowercased()
            UserDefaults.standard.set(sessionID, forKey: defaultsKey)
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("AIListening/\(hostKey)/\(sessionID)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            folder = directory
            if let saved = try? Data(contentsOf: directory.appendingPathComponent("attempt.json")),
               let decoded = try? JSONDecoder().decode(AIListeningAttempt.self, from: saved) { attempt = decoded }

            if let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
               let cached = try? decoder.decode(AIListeningManifest.self, from: data), isValid(cached) {
                manifest = cached
                if allAssetsValid(cached) {
                    await restoreCompletedTest()
                    restoreStage()
                    return
                }
            }
            guard AIListeningConnection.isHosted(baseURL) || !AIListeningConnection.token(for: baseURL).isEmpty else {
                throw AIListeningError.message("La connexion au serveur de développement n'est pas configurée.")
            }
            job = try await request("", method: "POST", query: retry ? "retry=true" : nil)
            while let current = job, current.state != "ready" {
                try Task.checkCancellation()
                if current.state == "failed" {
                    throw AIListeningError.message(current.error ?? "La préparation a été interrompue.")
                }
                try await Task.sleep(for: .seconds(2))
                job = try await request("")
                if job?.state == "interrupted" { job = try await request("", method: "POST") }
            }
            let data = try await dataRequest("/content")
            let content = try decoder.decode(AIListeningManifest.self, from: data)
            guard isValid(content) else { throw AIListeningError.message("La session reçue est incomplète ou invalide.") }
            manifest = content
            try data.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
            let assets = content.questions.flatMap { [$0.audio] + ($0.image.map { [$0] } ?? []) }
            downloadTotal = assets.count
            for asset in assets {
                try Task.checkCancellation()
                if !assetValid(asset) {
                    let data = try await dataRequest("/assets/\(asset.name)")
                    guard data.count == asset.bytes, digest(data) == asset.sha256 else {
                        throw AIListeningError.message("Un téléchargement est incomplet. Réessayez pour le reprendre.")
                    }
                    try data.write(to: directory.appendingPathComponent(asset.name), options: .atomic)
                }
                downloads += 1
            }
            await restoreCompletedTest()
            restoreStage()
        } catch is CancellationError {
            // Returning to the hub leaves the backend job intact for the next visit.
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    private func restoreStage() {
        attempt.index = min(max(0, attempt.index), 38)
        attempt.answers = attempt.answers.filter { (1...39).contains($0.key) && (0...3).contains($0.value) }
        stage = attempt.result != nil ? .review : attempt.started ? .practice : .ready
    }

    private func restoreCompletedTest() async {
        guard attempt.result == nil, AIListeningConnection.isHosted(baseURL) else { return }
        struct SavedAttempt: Decodable {
            let answers: [String: Int]
            let result: AIListeningResult?
        }
        guard let saved: SavedAttempt = try? await request("/attempt"), let result = saved.result,
              result.total == 39, result.questions.map(\.id) == Array(1...39),
              result.questions.allSatisfy({ $0.options.count == 4 && (0...3).contains($0.correctIndex) }) else { return }
        attempt.answers = Dictionary(uniqueKeysWithValues: saved.answers.compactMap { key, value in
            guard let id = Int(key), (1...39).contains(id), (0...3).contains(value) else { return nil }
            return (id, value)
        })
        attempt.result = result
        attempt.index = 38
        attempt.started = true
        saveAttempt()
    }

    private func isValid(_ content: AIListeningManifest) -> Bool {
        content.id == sessionID && content.questions.map(\.id) == Array(1...39) && content.questions.allSatisfy { question in
            ["picture", "response", "dialogue", "report"].contains(question.kind) && question.options.count == 4 &&
            (question.kind != "picture" || question.image != nil) &&
            ([question.audio] + (question.image.map { [$0] } ?? [])).allSatisfy { asset in
                asset.name.range(of: "^(audio-[0-9]+\\.wav|image-[0-9]+\\.(png|jpg))$", options: .regularExpression) != nil && asset.bytes > 0 && asset.bytes < 30_000_000
            }
        }
    }

    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func assetValid(_ asset: AIListeningAsset) -> Bool {
        guard let url = localURL(asset), let data = try? Data(contentsOf: url) else { return false }
        return data.count == asset.bytes && digest(data) == asset.sha256
    }
    private func allAssetsValid(_ content: AIListeningManifest) -> Bool {
        content.questions.allSatisfy { assetValid($0.audio) && ($0.image.map(assetValid) ?? true) }
    }
    func localURL(_ asset: AIListeningAsset) -> URL? { folder?.appendingPathComponent(asset.name) }

    private func dataRequest(_ path: String, method: String = "GET", query: String? = nil, body: Data? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + "/v1/listening/sessions/" + sessionID + path + (query.map { "?" + $0 } ?? "")) else {
            throw AIListeningError.message("Adresse de serveur invalide.")
        }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = method
        request.setValue("Bearer \(try await AIListeningConnection.authorization(for: baseURL))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        var (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401, AIListeningConnection.isHosted(baseURL) {
            request.setValue("Bearer \(try await AIListeningConnection.authorization(for: baseURL, refresh: true))", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: request)
        }
        guard let response = response as? HTTPURLResponse else { throw AIListeningError.message("Réponse du serveur invalide.") }
        guard (200..<300).contains(response.statusCode) else {
            struct APIError: Decodable { let detail: String }
            throw AIListeningError.message((try? JSONDecoder().decode(APIError.self, from: data).detail) ?? "Le serveur est indisponible (\(response.statusCode)). Réessayez.")
        }
        return data
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET", query: String? = nil) async throws -> T {
        try await decoder.decode(T.self, from: dataRequest(path, method: method, query: query))
    }

    private func saveAttempt() {
        guard let folder else { return }
        do {
            try JSONEncoder().encode(attempt).write(to: folder.appendingPathComponent("attempt.json"), options: .atomic)
            UserDefaults.standard.set(attempt.answers.count, forKey: "listening-progress-\(sessionID)")
        }
        catch { self.error = "Impossible de sauvegarder votre progression sur cet appareil." }
    }

    func begin() { attempt.started = true; stage = .practice; saveAttempt() }
    func select(_ option: Int) {
        guard let question, (0...3).contains(option) else { return }
        attempt.answers[question.id] = option
        saveAttempt()
    }
    func move(_ offset: Int) { attempt.index = min(38, max(0, index + offset)); error = nil; saveAttempt() }

    func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        do {
            let payload = ["answers": Dictionary(uniqueKeysWithValues: answers.map { (String($0.key), $0.value) })]
            let data = try await dataRequest("/submit", method: "POST", body: JSONEncoder().encode(payload))
            let result = try decoder.decode(AIListeningResult.self, from: data)
            guard result.total == 39, result.questions.map(\.id) == Array(1...39), result.questions.allSatisfy({ (0...3).contains($0.correctIndex) && $0.options.count == 4 }) else {
                throw AIListeningError.message("La correction reçue est incomplète. Réessayez.")
            }
            attempt.result = result
            stage = .review
            saveAttempt()
        } catch { self.error = error.localizedDescription }
    }
}
