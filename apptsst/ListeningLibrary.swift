import Foundation
import Combine

struct SavedListeningTest: Codable, Identifiable {
    let id: String
    let state: String
    let phase: String
    let planned: Int
    let createdAt: String
    let completedAt: String?
    let lastScore: Int?

    var dateLabel: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt)
        return date?.formatted(date: .abbreviated, time: .shortened) ?? "Test d'écoute"
    }

    var detail: String {
        if let lastScore, completedAt != nil { return "Terminé · \(lastScore)/39 bonnes réponses" }
        let answered = UserDefaults.standard.integer(forKey: "listening-progress-\(id)")
        if state == "ready", answered > 0 { return "En cours · \(answered)/39 réponses" }
        if state == "ready" { return "39 questions · Prêt à commencer" }
        if state == "failed" { return "Préparation à reprendre" }
        return "En préparation · \(planned)/39 questions"
    }
}

@MainActor
final class ListeningLibrary: ObservableObject {
    @Published private(set) var tests: [SavedListeningTest] = []
    @Published private(set) var bankCount: Int?
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private struct Page: Codable {
        let sessions: [SavedListeningTest]
        let bankCount: Int
        let hasMore: Bool
    }

    func reload(loadMore: Bool = false) async {
        guard !isLoading else { return }
        let base = AIListeningConnection.baseURL
        guard AIListeningConnection.isHosted(base) else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        if !loadMore, tests.isEmpty,
           let data = UserDefaults.standard.data(forKey: "listening-library-cache"),
           let page = try? JSONDecoder().decode(Page.self, from: data) {
            tests = page.sessions
            bankCount = page.bankCount
            hasMore = page.hasMore
        }
        do {
            let offset = loadMore ? tests.count : 0
            var request = URLRequest(url: URL(string: base + "/v1/listening/sessions?offset=\(offset)")!, timeoutInterval: 45)
            request.setValue("Bearer \(try await AIListeningConnection.authorization(for: base))", forHTTPHeaderField: "Authorization")
            var (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                request.setValue("Bearer \(try await AIListeningConnection.authorization(for: base, refresh: true))", forHTTPHeaderField: "Authorization")
                (data, response) = try await URLSession.shared.data(for: request)
            }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let page = try decoder.decode(Page.self, from: data)
            if loadMore {
                let existing = Set(tests.map(\.id))
                tests += page.sessions.filter { !existing.contains($0.id) }
            } else { tests = page.sessions }
            bankCount = page.bankCount
            hasMore = page.hasMore
            if let cached = try? JSONEncoder().encode(Page(sessions: tests, bankCount: page.bankCount, hasMore: page.hasMore)) {
                UserDefaults.standard.set(cached, forKey: "listening-library-cache")
            }
        } catch {
            self.error = "Impossible d'actualiser vos tests pour le moment. Vos tests déjà téléchargés restent disponibles."
        }
    }
}
