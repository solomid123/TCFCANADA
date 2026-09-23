import SwiftUI

struct PreparationView: View {
    @Binding var isPracticeActive: Bool
    @StateObject private var listeningLibrary = ListeningLibrary()
    @State private var isShowingSession = false
    @State private var savedSessionID: String?
    @State private var startNewTest = false
    @State private var selectedSkill = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isPracticeActive: Binding<Bool> = .constant(false)) {
        _isPracticeActive = isPracticeActive
        _isShowingSession = State(initialValue: ProcessInfo.processInfo.arguments.contains("-test-ai-listening"))
    }

    var body: some View {
        VStack(spacing: 0) {
            if isShowingSession {
                AIListeningSessionView(onBack: { isShowingSession = false }, initialSessionID: savedSessionID, startNewSession: startNewTest)
            } else {
                library
            }
        }
        .onAppear { isPracticeActive = isShowingSession }
        .onChange(of: isShowingSession) { _, active in isPracticeActive = active }
    }

    private var library: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Votre banque d'entraînement.")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).tracking(-1)
                    Text("Questions, exercices et tests pour progresser.")
                        .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                }
                .padding(.top, 10)

                skillSelector

                if selectedSkill == 1 {
                Text("Compréhension orale")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                if let count = listeningLibrary.bankCount {
                    Label("\(count.formatted()) questions dans votre banque", systemImage: "books.vertical")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(TCFTheme.textSecondary)
                }
                Button {
                    savedSessionID = nil
                    startNewTest = true
                    isShowingSession = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "headphones").font(.system(size: 30, weight: .medium))
                            .foregroundStyle(TCFTheme.emerald)
                            .frame(width: 58, height: 64)
                            .background(TCFTheme.emerald.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nouveau test d'écoute")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text("39 questions · Niveau progressif")
                                .font(.system(size: 12)).foregroundStyle(TCFTheme.textSecondary)
                            Text("Illustrations et voix françaises canadiennes")
                                .font(.system(size: 11)).foregroundStyle(TCFTheme.textMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(TCFTheme.textPrimary).padding(20)
                }
                .whiteGlassButton(cornerRadius: 26)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("listen_ai")

                savedTests
                } else {
                    unavailableSkill
                }
            }
            .foregroundStyle(TCFTheme.textPrimary)
            .padding(.horizontal, 22).padding(.bottom, 28)
        }
        .task(id: selectedSkill) { if selectedSkill == 1 { await listeningLibrary.reload() } }
        .refreshable { if selectedSkill == 1 { await listeningLibrary.reload() } }
    }

    private var skillSelector: some View {
        HStack(spacing: 6) {
            skillButton("Lecture", icon: "book", index: 0)
            skillButton("Écoute", icon: "headphones", index: 1)
            skillButton("Écriture", icon: "pencil.line", index: 2)
            skillButton("Parole", icon: "mic", index: 3)
        }
        .padding(6).tcfGlass(cornerRadius: 26)
    }

    private func skillButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { selectedSkill = index }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 21, weight: .medium))
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selectedSkill == index ? TCFTheme.azureBlue : TCFTheme.textSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background {
                if selectedSkill == index { RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.65)) }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedSkill == index ? .isSelected : [])
    }

    private var unavailableSkill: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(["Compréhension écrite", "Compréhension orale", "Expression écrite", "Expression orale"][selectedSkill])
                .font(.system(size: 24, weight: .bold, design: .rounded))
            VStack(alignment: .leading, spacing: 10) {
                Label("Banque en préparation", systemImage: "books.vertical")
                    .font(.headline)
                Text("Les nouveaux tests de cette compétence seront disponibles ici.")
                    .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).whiteGlassCard()
        }
    }

    private var savedTests: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MES TESTS").font(.system(size: 10, weight: .bold)).tracking(1.6)
                Spacer()
                if listeningLibrary.isLoading { ProgressView() }
            }
            .foregroundStyle(TCFTheme.textMuted).padding(.leading, 4)
            if listeningLibrary.tests.isEmpty && !listeningLibrary.isLoading {
                Text("Vos tests préparés et vos résultats apparaîtront ici.")
                    .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).whiteGlassCard()
            }
            ForEach(listeningLibrary.tests) { test in
                Button {
                    savedSessionID = test.id
                    startNewTest = false
                    isShowingSession = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: test.completedAt != nil ? "checkmark.seal" : test.state == "ready" ? "doc.text" : "clock")
                            .font(.system(size: 22)).foregroundStyle(TCFTheme.emerald).frame(width: 34)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(test.dateLabel).font(.system(size: 14, weight: .semibold))
                            Text(test.detail).font(.system(size: 12)).foregroundStyle(TCFTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(17)
                    .foregroundStyle(TCFTheme.textPrimary).multilineTextAlignment(.leading)
                }
                .whiteGlassButton(cornerRadius: 24)
                .accessibilityIdentifier("saved-listening-\(test.id)")
            }
            if listeningLibrary.hasMore {
                Button("Charger plus de tests") { Task { await listeningLibrary.reload(loadMore: true) } }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            if let error = listeningLibrary.error {
                Text(error).font(.caption).foregroundStyle(TCFTheme.textSecondary)
                Button("Actualiser mes tests") { Task { await listeningLibrary.reload() } }
                    .frame(minHeight: 44)
            }
        }
    }
}
