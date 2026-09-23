import SwiftUI
import Combine

struct FullExamSessionView: View {
    @Binding var isSessionActive: Bool
    @State private var currentSection = 0
    @State private var hasStarted = false
    @State private var isBetweenSections = false
    @State private var isFinished = false
    @State private var deadline = Date()
    @State private var secondsRemaining = 1200
    @State private var readingCorrect = 0
    @State private var listeningCorrect = 0
    @State private var readingAnswered = 0
    @State private var listeningAnswered = 0
    @State private var showExitConfirmation = false
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let titles = ["Compréhension écrite", "Compréhension orale", "Expression écrite", "Expression orale"]
    private let icons = ["book", "headphones", "pencil.line", "mic"]
    private let durations = [1200, 900, 3600, 720]

    init(isSessionActive: Binding<Bool> = .constant(false)) {
        _isSessionActive = isSessionActive
    }

    var body: some View {
        VStack(spacing: 0) {
            if isFinished {
                completionView
            } else if !hasStarted {
                introduction
            } else if isBetweenSections {
                sectionBreak
            } else {
                VStack(spacing: 12) {
                    activeHeader.padding(.horizontal, 18).padding(.top, 8)
                    activeContent.id(currentSection)
                    if currentSection >= 2 {
                        Button(action: finishSection) {
                            Text("Terminer cette épreuve")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                            .whiteGlassButton(isPrimary: true)
                            .accessibilityIdentifier("finish-section")
                            .padding(.horizontal, 18)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .onReceive(clock) { _ in updateClock() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { updateClock() } }
        .onDisappear { isSessionActive = false }
        .confirmationDialog("Quitter cet examen ?", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("Quitter la session", role: .destructive) { resetSession() }
            Button("Continuer", role: .cancel) { }
        } message: {
            Text("La progression de cette session sera effacée.")
        }
    }

    private var introduction: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("À vous de jouer.")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).tracking(-1)
                    Text("Un parcours chronométré, pour trouver votre rythme.")
                        .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                }
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(TCFTheme.azureBlue)
                        Spacer()
                        TCFLevelLabel(text: "Tous niveaux")
                    }
                    Text("Examen blanc")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("4 compétences · 1 h 47 maximum")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Format d'entraînement avec les questions disponibles dans l'app. Les séries de lecture et d'écoute sont plus courtes que les 39 questions de l'épreuve officielle.")
                        .font(.system(size: 13)).foregroundStyle(TCFTheme.textSecondary).lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .whiteGlassCard(cornerRadius: 28, padding: 22)

                VStack(alignment: .leading, spacing: 16) {
                    Text("VOTRE PARCOURS")
                        .font(.system(size: 10, weight: .bold)).tracking(1.6)
                        .foregroundStyle(TCFTheme.textMuted)
                    ForEach(0..<4) { index in
                        HStack(spacing: 14) {
                            Image(systemName: icons[index])
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(titles[index]).font(.system(size: 14, weight: .semibold))
                                Text(sectionCount(index)).font(.system(size: 12)).foregroundStyle(TCFTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(durations[index] / 60) min")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(TCFTheme.textSecondary)
                        }
                    }
                }
                Text("Corrections masquées pendant les épreuves. Une pause entre chaque compétence. Préparez vos écouteurs pour l'audio.")
                    .font(.system(size: 13)).foregroundStyle(TCFTheme.textSecondary).lineSpacing(3)
                Button(action: startSession) {
                    Label("Commencer l'examen", systemImage: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .whiteGlassButton(cornerRadius: 22, isPrimary: true)
                .accessibilityIdentifier("start-exam")
            }
            .foregroundStyle(TCFTheme.textPrimary)
            .padding(.horizontal, 22).padding(.bottom, 24)
        }
    }

    private var activeHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { showExitConfirmation = true } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).accessibilityLabel("Quitter l'examen")
                VStack(alignment: .leading, spacing: 4) {
                    Text("ÉPREUVE \(currentSection + 1) / 4")
                        .font(.system(size: 9, weight: .bold)).tracking(1.5)
                        .foregroundStyle(TCFTheme.textMuted)
                    Text(titles[currentSection]).font(.system(size: 13, weight: .semibold))
                }
                Spacer(minLength: 0)
                Text(String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60))
                    .font(.system(size: 19, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(secondsRemaining < 60 ? TCFTheme.mapleRed : TCFTheme.azureBlue)
                    .accessibilityLabel("Temps restant : \(secondsRemaining / 60) minutes et \(secondsRemaining % 60) secondes")
            }
            HStack(spacing: 5) {
                ForEach(0..<4) { index in
                    Capsule().fill(index <= currentSection ? TCFTheme.azureBlue : TCFTheme.textPrimary.opacity(0.08)).frame(height: 3)
                }
            }
        }
        .foregroundStyle(TCFTheme.textPrimary)
        .whiteGlassCard(cornerRadius: 22, padding: 12)
    }

    @ViewBuilder private var activeContent: some View {
        switch currentSection {
        case 0:
            ComprehensionEcriteView(practice: TCFMockData.readingPractices.last!, isExamMode: true, onComplete: finishSection, onProgress: { answered, correct in
                readingAnswered = answered
                readingCorrect = correct
            })
        case 1:
            ComprehensionOraleView(practice: TCFMockData.listeningPractices.last!, isExamMode: true, onComplete: finishSection, onProgress: { answered, correct in
                listeningAnswered = answered
                listeningCorrect = correct
            })
        case 2: ExpressionEcriteView(isExamMode: true)
        default: ExpressionOraleView(isExamMode: true)
        }
    }

    private var sectionBreak: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "checkmark.circle").font(.system(size: 48, weight: .light)).foregroundStyle(TCFTheme.emerald)
                Text("Une étape de plus.").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("\(titles[currentSection]) terminée. Prenez un instant avant de poursuivre.")
                    .foregroundStyle(TCFTheme.textSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text("À SUIVRE").font(.caption).foregroundStyle(TCFTheme.textMuted)
                    Text(titles[min(currentSection + 1, 3)]).font(.title3.bold())
                    Text("\(durations[min(currentSection + 1, 3)] / 60) minutes · \(sectionCount(min(currentSection + 1, 3)))")
                        .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).whiteGlassCard()
                Button {
                    currentSection += 1
                    isBetweenSections = false
                    startClock()
                } label: {
                    Text("Commencer l'épreuve suivante").frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .foregroundStyle(.white).whiteGlassButton(isPrimary: true)
                .accessibilityIdentifier("next-section")
                Button("Quitter la session") { showExitConfirmation = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundStyle(TCFTheme.textPrimary).padding(24).padding(.top, 30)
        }
    }

    private var completionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "checkmark.seal").font(.system(size: 52, weight: .light)).foregroundStyle(TCFTheme.emerald)
                Text("Session terminée.").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Bravo pour ce temps consacré à votre préparation.").foregroundStyle(TCFTheme.textSecondary)
                VStack(alignment: .leading, spacing: 16) {
                    Text("VOTRE BILAN").font(.caption.weight(.semibold)).foregroundStyle(TCFTheme.textMuted)
                    Text("Lecture : \(readingCorrect) / \(TCFMockData.readingQuestions.count) bonnes réponses")
                    Text("\(readingAnswered) réponses enregistrées").font(.caption).foregroundStyle(TCFTheme.textSecondary)
                    Divider()
                    Text("Écoute : \(listeningCorrect) / \(TCFMockData.listeningQuestions.count) bonnes réponses")
                    Text("\(listeningAnswered) réponses enregistrées").font(.caption).foregroundStyle(TCFTheme.textSecondary)
                    Divider()
                    Text("Écriture & parole : auto-évaluation en mode pratique.").font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading).whiteGlassCard()
                Text("Ce bilan porte sur la série d'entraînement et ne correspond pas à un score TCF ou NCLC officiel.")
                    .font(.caption).foregroundStyle(TCFTheme.textSecondary)
                Button(action: resetSession) {
                    Text("Revenir à l'examen")
                        .frame(maxWidth: .infinity).padding(.vertical, 8).foregroundStyle(.white)
                }
                .whiteGlassButton(isPrimary: true)
            }
            .foregroundStyle(TCFTheme.textPrimary).padding(24).padding(.top, 24)
        }
    }

    private func sectionCount(_ index: Int) -> String {
        switch index {
        case 0: "\(TCFMockData.readingQuestions.count) questions"
        case 1: "\(TCFMockData.listeningQuestions.count) questions"
        default: "3 tâches"
        }
    }

    private func startSession() {
        hasStarted = true
        isSessionActive = true
        startClock()
    }

    private func startClock() {
        secondsRemaining = durations[currentSection]
        deadline = Date().addingTimeInterval(TimeInterval(secondsRemaining))
    }

    private func updateClock() {
        guard hasStarted, !isBetweenSections, !isFinished else { return }
        secondsRemaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        if secondsRemaining == 0 { finishSection() }
    }

    private func finishSection() {
        guard !isBetweenSections, !isFinished else { return }
        TCFAudioService.shared.stopSpeaking()
        if currentSection == 3 {
            isFinished = true
            isSessionActive = false
        } else {
            isBetweenSections = true
        }
    }

    private func resetSession() {
        hasStarted = false
        isBetweenSections = false
        isFinished = false
        currentSection = 0
        readingCorrect = 0
        listeningCorrect = 0
        readingAnswered = 0
        listeningAnswered = 0
        isSessionActive = false
    }
}
