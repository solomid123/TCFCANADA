import SwiftUI

struct AIListeningSessionView: View {
    let onBack: () -> Void
    var initialSessionID: String? = nil
    var startNewSession = false
    @StateObject private var store = AIListeningStore()
    @StateObject private var player = AIListeningPlayer()
    @State private var showConnection = false
    @State private var mistakesOnly = false
    @State private var expandedQuestion: Int?
    @State private var didLoad = false

    var body: some View {
        VStack(spacing: 12) {
            header
            switch store.stage {
            case .preparing: preparation
            case .ready: ready
            case .practice: practice
            case .review: review
            }
        }
        .foregroundStyle(TCFTheme.textPrimary)
        .padding(.top, 8)
        .onAppear {
            if !didLoad {
                didLoad = true
                store.prepare(newSession: startNewSession, savedSessionID: initialSessionID)
            }
        }
        .onDisappear { player.stop(); store.cancelPreparation() }
        #if DEBUG
        .sheet(isPresented: $showConnection) {
            AIListeningConnectionView {
                showConnection = false
                store.prepare()
            }
        }
        #endif
    }

    private var header: some View {
        HStack {
            Button { player.stop(); onBack() } label: {
                Label("Pratique", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
            }
            .whiteGlassButton()
            Spacer()
            Label("COMPRÉHENSION ORALE", systemImage: "headphones")
                .font(.system(size: 11, weight: .bold)).tracking(1)
            Spacer()
            #if DEBUG
            Button { showConnection = true } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
            }
            .whiteGlassButton()
            .accessibilityLabel("Connexion au serveur IA")
            #else
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            #endif
        }
        .padding(.horizontal, 18)
    }

    private var preparation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 48, weight: .light)).foregroundStyle(TCFTheme.emerald)
                Text("Votre prochain test\nse prépare.")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("39 questions progressives, des illustrations et des voix françaises canadiennes. Votre test sera disponible dans Mes tests.")
                    .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                VStack(alignment: .leading, spacing: 18) {
                    progressRow("Questions", count: store.job?.planned ?? 0, total: 39, icon: "text.bubble")
                    progressRow("Images vérifiées", count: store.job?.images ?? 0, total: 4, icon: "photo")
                    progressRow("Enregistrements", count: store.job?.audio ?? 0, total: 39, icon: "waveform")
                    if store.job?.state == "ready" {
                        progressRow("Téléchargements", count: store.downloads, total: store.downloadTotal, icon: "arrow.down.circle")
                    }
                    if store.error == nil {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(store.job?.state == "ready" ? "Enregistrement sur votre appareil" : store.job?.phase ?? "Connexion au serveur")
                                .font(.caption).foregroundStyle(TCFTheme.textSecondary)
                        }
                    }
                }
                .whiteGlassCard()
                if let error = store.error {
                    errorMessage(error)
                    Button { store.prepare(retry: true) } label: {
                        Label("Reprendre la préparation", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity).padding(.vertical, 8).foregroundStyle(.white)
                    }
                    .whiteGlassButton(isPrimary: true)
                    #if DEBUG
                    Button("Configurer la connexion") { showConnection = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    #endif
                }
                Text("Vous pouvez revenir plus tard. Retrouvez ce test et votre progression dans votre banque d'entraînement.")
                    .font(.caption).foregroundStyle(TCFTheme.textSecondary)
            }
            .padding(24)
        }
    }

    private func progressRow(_ title: String, count: Int, total: Int, icon: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: count == total ? "checkmark.circle.fill" : icon)
                Spacer()
                Text("\(count)/\(total)").monospacedDigit()
            }
            .font(.system(size: 13, weight: .medium))
            ProgressView(value: Double(count), total: Double(total)).tint(TCFTheme.emerald)
        }
    }

    private var ready: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "headphones.circle")
                    .font(.system(size: 64, weight: .light)).foregroundStyle(TCFTheme.emerald)
                Text("Prêt à tendre l'oreille ?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 16) {
                    Label("39 questions · difficulté progressive", systemImage: "list.number")
                    Label("Voix françaises canadiennes", systemImage: "waveform")
                    Label("Images et audio téléchargés", systemImage: "checkmark.icloud")
                    Label("Correction complète à la fin", systemImage: "checkmark.bubble")
                }
                .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).whiteGlassCard()
                Text("Une session d'entraînement à votre rythme. Pour les premières questions, écoutez les propositions A, B, C et D : leur texte sera révélé dans la correction. Une connexion est nécessaire pour obtenir le bilan final.")
                    .font(.subheadline).foregroundStyle(TCFTheme.textSecondary).lineSpacing(4)
                Button(action: store.begin) {
                    Label("Commencer les 39 questions", systemImage: "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .whiteGlassButton(isPrimary: true)
                .accessibilityIdentifier("start-ai-listening")
                Text("Entraînement au format TCF Canada. Votre bilan reste disponible dans Mes tests.")
                    .font(.caption).foregroundStyle(TCFTheme.textMuted)
            }
            .padding(24)
        }
    }

    private var practice: some View {
        VStack(spacing: 8) {
            if let question = store.question {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Question \(question.id) sur 39").font(.headline)
                            Spacer()
                            TCFLevelLabel(text: question.level)
                        }
                        ProgressView(value: Double(question.id), total: 39).tint(TCFTheme.emerald)
                        Text(question.question).font(.system(size: 19, weight: .semibold, design: .rounded))
                        imageView(question)
                        audioControls(question)
                        if question.spokenOptions {
                            Label("Les quatre propositions sont dans l'audio.", systemImage: "ear")
                                .font(.caption).foregroundStyle(TCFTheme.textSecondary)
                        }
                        ForEach(0..<4, id: \.self) { option in
                            answerButton(question, option: option)
                        }
                        if let error = store.error { errorMessage(error) }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 16)
                }
                .id(question.id)
                HStack(spacing: 12) {
                    Button { player.stop(); store.move(-1) } label: {
                        Text("Précédent").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .whiteGlassButton().disabled(store.index == 0 || store.isSubmitting)
                    .accessibilityIdentifier("ai-previous")
                    Button {
                        player.stop()
                        if store.index < 38 { store.move(1) }
                        else { Task { await store.submit() } }
                    } label: {
                        HStack {
                            if store.isSubmitting { ProgressView().tint(.white) }
                            Text(store.index < 38 ? "Suivant" : "Terminer")
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8).foregroundStyle(.white)
                    }
                    .whiteGlassButton(isPrimary: true)
                    .disabled(store.answers[question.id] == nil || store.isSubmitting)
                    .accessibilityIdentifier("ai-next")
                }
                .padding(.horizontal, 18).padding(.bottom, 8)
            }
        }
    }

    private func answerButton(_ question: AIListeningQuestion, option: Int) -> some View {
        let selected = store.answers[question.id] == option
        return Button { store.select(option) } label: {
            HStack(spacing: 12) {
                Text(["A", "B", "C", "D"][option])
                    .font(.system(size: 14, weight: .bold)).frame(width: 32, height: 32)
                    .background(TCFTheme.emerald.opacity(selected ? 0.18 : 0.06), in: Circle())
                Text(question.spokenOptions ? "Proposition \(["A", "B", "C", "D"][option])" : question.options[option])
                    .font(.system(size: 14, weight: .medium)).multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(TCFTheme.emerald) }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(selected ? TCFTheme.emerald.opacity(0.1) : Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(selected ? TCFTheme.emerald.opacity(0.6) : .white.opacity(0.7)))
        }
        .buttonStyle(.plain).disabled(store.isSubmitting)
        .accessibilityIdentifier("ai-answer-\(option)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private func imageView(_ question: AIListeningQuestion) -> some View {
        if let asset = question.image, let url = store.localURL(asset), let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Illustration de la question \(question.id)")
        }
    }

    private func audioControls(_ question: AIListeningQuestion) -> some View {
        let active = player.activeID == question.id
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if let url = store.localURL(question.audio) { player.toggle(url: url, id: question.id) }
                } label: {
                    Label(active && player.isPlaying ? "Pause" : "Écouter", systemImage: active && player.isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 6).foregroundStyle(.white)
                }
                .whiteGlassButton(isPrimary: true)
                .accessibilityIdentifier("ai-play-\(question.id)")
                Button {
                    if let url = store.localURL(question.audio) { player.replay(url: url, id: question.id) }
                } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                    .whiteGlassButton().accessibilityLabel("Réécouter")
            }
            HStack {
                ProgressView(value: active ? min(player.elapsed, question.duration) : 0, total: max(1, question.duration)).tint(TCFTheme.emerald)
                Text(time(active ? player.elapsed : question.duration)).font(.caption.monospacedDigit()).foregroundStyle(TCFTheme.textSecondary)
            }
            if let error = player.error { errorMessage(error) }
        }
        .whiteGlassCard(cornerRadius: 22, padding: 14)
    }

    private func time(_ seconds: Double) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    private var review: some View {
        ScrollView {
            if let result = store.result, let manifest = store.manifest {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chaque écoute vous fait avancer.").font(.system(size: 27, weight: .bold, design: .rounded))
                        Text("\(result.correct) / \(result.total)").font(.system(size: 46, weight: .medium, design: .rounded))
                            .foregroundStyle(TCFTheme.emerald).accessibilityIdentifier("ai-result-score")
                        Text("bonnes réponses · score d'entraînement").font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                    }
                    .padding(.vertical, 12)
                    Button(action: onBack) {
                        Label("Mes tests", systemImage: "tray.full")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .whiteGlassButton()
                    .accessibilityIdentifier("open-saved-listening-tests")
                    Picker("Afficher les corrections", selection: $mistakesOnly) {
                        Text("Toutes (39)").tag(false)
                        Text("Erreurs (\(39 - result.correct))").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if mistakesOnly && result.correct == 39 {
                        Label("Aucune erreur. Bravo !", systemImage: "checkmark.seal").padding(.vertical)
                    }
                    ForEach(result.questions.filter { !mistakesOnly || store.answers[$0.id] != $0.correctIndex }) { correction in
                        if let question = manifest.questions.first(where: { $0.id == correction.id }) {
                            correctionCard(question, correction)
                        }
                    }
                    Button {
                        player.stop()
                        expandedQuestion = nil
                        mistakesOnly = false
                        store.prepare(newSession: true)
                    } label: {
                        Label("Nouveau test d'écoute", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity).padding(.vertical, 10).foregroundStyle(.white)
                    }
                    .whiteGlassButton(isPrimary: true)
                    Text("Ce test et sa correction sont enregistrés dans Mes tests. Vous pouvez les consulter à nouveau à tout moment.")
                        .font(.caption).foregroundStyle(TCFTheme.textSecondary)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
    }

    private func correctionCard(_ question: AIListeningQuestion, _ correction: AIListeningCorrection) -> some View {
        let correct = store.answers[question.id] == correction.correctIndex
        return VStack(alignment: .leading, spacing: 14) {
            Button {
                player.stop()
                expandedQuestion = expandedQuestion == question.id ? nil : question.id
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? TCFTheme.emerald : TCFTheme.mapleRed)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Question \(question.id)").font(.system(size: 14, weight: .semibold))
                        Text(question.question).font(.caption).foregroundStyle(TCFTheme.textSecondary).lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: expandedQuestion == question.id ? "chevron.up" : "chevron.down")
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("ai-review-\(question.id)")
            if expandedQuestion == question.id {
                imageView(question)
                audioControls(question)
                ForEach(0..<4, id: \.self) { option in
                    HStack(alignment: .top, spacing: 8) {
                        Text(["A", "B", "C", "D"][option]).bold()
                        Text(correction.options[option])
                        Spacer(minLength: 0)
                        if option == correction.correctIndex { Image(systemName: "checkmark.circle.fill").foregroundStyle(TCFTheme.emerald) }
                        else if option == store.answers[question.id] { Image(systemName: "xmark.circle.fill").foregroundStyle(TCFTheme.mapleRed) }
                    }
                    .font(.subheadline)
                }
                Text("Votre réponse : \(store.answers[question.id].map { ["A", "B", "C", "D"][$0] } ?? "aucune")")
                    .font(.caption.weight(.semibold)).foregroundStyle(TCFTheme.textSecondary)
                Divider()
                Text("Pourquoi ?").font(.headline)
                Text(correction.explanation).font(.subheadline).lineSpacing(3)
                Text("Transcription").font(.headline)
                Text(correction.transcript).font(.subheadline).foregroundStyle(TCFTheme.textSecondary).lineSpacing(4)
            }
        }
        .whiteGlassCard()
    }

    private func errorMessage(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.subheadline).foregroundStyle(TCFTheme.mapleRed).fixedSize(horizontal: false, vertical: true)
    }
}

private struct AIListeningConnectionView: View {
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var url = AIListeningConnection.baseURL
    @State private var token = AIListeningConnection.token(for: AIListeningConnection.baseURL)
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Serveur de génération") {
                    TextField("https://votre-serveur", text: $url)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .accessibilityIdentifier("ai-backend-url")
                    SecureField("Jeton d'accès du serveur", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("ai-backend-token")
                }
                Section {
                    Text("Utilisez l'adresse et le jeton de votre backend TCF. Les clés Azure restent sur le serveur.")
                    Text("Sur un iPhone, localhost désigne l'iPhone. Utilisez une adresse HTTPS accessible depuis l'appareil.")
                }
                .font(.caption)
                if let error { Text(error).foregroundStyle(TCFTheme.mapleRed) }
            }
            .navigationTitle("Connexion IA").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let normalized = url.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        guard let parsed = URL(string: normalized), ["https", "http"].contains(parsed.scheme), parsed.host != nil,
                              parsed.user == nil, parsed.password == nil, parsed.query == nil, parsed.fragment == nil,
                              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            error = "Saisissez une adresse valide et un jeton d'accès."
                            return
                        }
                        do {
                            try AIListeningConnection.save(baseURL: normalized, token: token.trimmingCharacters(in: .whitespacesAndNewlines))
                            onSave()
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
        }
    }
}
