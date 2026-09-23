import SwiftUI

struct PreparationView: View {
    @Binding var isPracticeActive: Bool
    @State private var selectedSkill = 0
    @State private var selectedPractice: TCFPracticeItem?
    @State private var selectedLevel: CEFRLevel?
    @StateObject private var listeningLibrary = ListeningLibrary()
    @State private var savedListeningSessionID: String?
    @State private var startNewListeningTest = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isPracticeActive: Binding<Bool> = .constant(false)) {
        _isPracticeActive = isPracticeActive
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-test-listening-library") {
            _selectedSkill = State(initialValue: 1)
        } else if arguments.contains("-test-ai-listening") {
            _selectedSkill = State(initialValue: 1)
            _selectedPractice = State(initialValue: Self.aiListeningPractice)
        } else if arguments.contains("-test-reading-session") {
            _selectedPractice = State(initialValue: TCFMockData.readingPractices[0])
        } else if arguments.contains("-test-ideas-bank") {
            _selectedSkill = State(initialValue: 2)
            _selectedPractice = State(initialValue: TCFMockData.writingPractices[0])
        } else if arguments.contains("-test-writing-list") {
            _selectedSkill = State(initialValue: 2)
        } else if arguments.contains("-test-listening-session") {
            _selectedSkill = State(initialValue: 1)
            _selectedPractice = State(initialValue: TCFMockData.listeningPractices[0])
        }
    }

    private static let aiListeningPractice = TCFPracticeItem(id: "listen_ai", title: "Nouveau test d'écoute", subtitle: "Voix françaises canadiennes", levelBadge: "A1–C2", questionCountText: "39 questions", durationText: "À votre rythme", iconName: "headphones")

    private var currentPractices: [TCFPracticeItem] {
        switch selectedSkill {
        case 1: TCFMockData.listeningPractices
        case 2: TCFMockData.writingPractices
        case 3: TCFMockData.speakingPractices
        default: TCFMockData.readingPractices
        }
    }

    private var accent: Color {
        [TCFTheme.azureBlue, TCFTheme.emerald, TCFTheme.amber, TCFTheme.mapleRed][selectedSkill]
    }

    private var skillDescription: String {
        ["Comprendre un texte, une idée, une intention.",
         "Affiner votre écoute, un extrait à la fois.",
         "Structurer vos idées et écrire avec clarté.",
         "Prendre la parole avec confiance."][selectedSkill]
    }

    private func levels(for practice: TCFPracticeItem) -> [CEFRLevel] {
        if selectedSkill == 0 {
            return TCFMockData.readingQuestions(forPracticeId: practice.id).map(\.level)
        }
        return TCFMockData.listeningQuestions(forPracticeId: practice.id).map(\.level)
    }

    private var availableLevels: [CEFRLevel] {
        CEFRLevel.allCases.filter { level in currentPractices.contains { levels(for: $0).contains(level) } }
    }

    private var filteredPractices: [TCFPracticeItem] {
        currentPractices.filter { practice in
            guard let selectedLevel, selectedSkill < 2 else { return true }
            return levels(for: practice).contains(selectedLevel)
        }
    }

    var body: some View {
        Group {
            if let practice = selectedPractice {
                practiceSessionView(practice: practice)
            } else {
                availablePracticesList
            }
        }
        .onAppear { isPracticeActive = selectedPractice != nil }
        .onChange(of: selectedPractice) { _, practice in isPracticeActive = practice != nil }
    }

    private var availablePracticesList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Votre banque d'entraînement.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .tracking(-1)
                        .foregroundStyle(TCFTheme.textPrimary)
                    Text("Questions, exercices et tests pour progresser.")
                        .font(.subheadline)
                        .foregroundStyle(TCFTheme.textSecondary)
                }
                .padding(.top, 10)

                skillSelector

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(["Lecture", "Écoute", "Écriture", "Expression orale"][selectedSkill])
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(TCFTheme.textPrimary)
                            Text(skillDescription)
                                .font(.system(size: 13))
                                .foregroundStyle(TCFTheme.textSecondary)
                        }
                        Spacer(minLength: 8)
                        if selectedSkill < 2 { levelFilter }
                    }

                    if selectedSkill == 1 {
                        if let count = listeningLibrary.bankCount {
                            Label("\(count.formatted()) questions dans votre banque d'écoute", systemImage: "books.vertical")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(TCFTheme.textSecondary)
                        }
                        practiceGroup(title: "BANQUE D'ÉCOUTE", practices: [Self.aiListeningPractice])
                        savedListeningTests
                    }
                    practiceGroup(title: selectedSkill == 1 ? "SÉRIES DISPONIBLES HORS LIGNE" : selectedSkill < 2 ? "ENTRAÎNEMENT CIBLÉ" : "LES 3 TÂCHES", practices: filteredPractices.filter { !$0.isResource && !$0.isCompleteSeries })
                    practiceGroup(title: "POUR ALLER PLUS LOIN", practices: filteredPractices.filter(\.isCompleteSeries))
                    practiceGroup(title: "VOTRE BOÎTE À OUTILS", practices: filteredPractices.filter(\.isResource))
                }
                .id(selectedSkill)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .task(id: selectedSkill) {
            if selectedSkill == 1 { await listeningLibrary.reload() }
        }
    }

    private var skillSelector: some View {
        HStack(spacing: 6) {
            skillButton(title: "Lecture", icon: "book", index: 0)
            skillButton(title: "Écoute", icon: "headphones", index: 1)
            skillButton(title: "Écriture", icon: "pencil.line", index: 2)
            skillButton(title: "Parole", icon: "mic", index: 3)
        }
        .padding(6)
        .tcfGlass(cornerRadius: 26)
    }

    private func skillButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                selectedSkill = index
                selectedLevel = nil
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 21, weight: .medium))
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selectedSkill == index ? accent : TCFTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                if selectedSkill == index {
                    RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.65))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedSkill == index ? .isSelected : [])
    }

    private var levelFilter: some View {
        Menu {
            Button("Tous les niveaux") { selectedLevel = nil }
            ForEach(availableLevels) { level in
                Button("Niveau \(level.rawValue)") { selectedLevel = level }
            }
        } label: {
            HStack(spacing: 5) {
                Text(selectedLevel?.rawValue ?? "Niveaux")
                Image(systemName: "line.3.horizontal.decrease")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(TCFTheme.textSecondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .tcfGlass(cornerRadius: 18, interactive: true)
        }
        .accessibilityLabel("Filtrer les séries : \(selectedLevel?.rawValue ?? "tous les niveaux")")
    }

    @ViewBuilder
    private func practiceGroup(title: String, practices: [TCFPracticeItem]) -> some View {
        if !practices.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(TCFTheme.textMuted)
                    .padding(.leading, 4)
                ForEach(practices) { practice in practiceCard(practice) }
            }
        }
    }

    private func practiceCard(_ practice: TCFPracticeItem) -> some View {
        Button {
            if practice.id == "listen_ai" {
                savedListeningSessionID = nil
                startNewListeningTest = true
            }
            selectedPractice = practice
        } label: {
            HStack(spacing: 14) {
                Image(systemName: practice.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 48)
                    .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 7) {
                    Text(practice.displayTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(TCFTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(practice.itemCountText) · \(practice.durationText)")
                        .font(.system(size: 12))
                        .foregroundStyle(TCFTheme.textSecondary)
                    if !practice.isResource {
                        Text(selectedSkill < 2 ? "Niveau \(practice.levelBadge)" : practice.levelBadge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TCFTheme.textMuted)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TCFTheme.textMuted)
            }
            .padding(17)
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .whiteGlassButton(cornerRadius: 24)
        .accessibilityIdentifier(practice.id)
        .multilineTextAlignment(.leading)
    }

    private func closePractice() { selectedPractice = nil }

    @ViewBuilder
    private func practiceSessionView(practice: TCFPracticeItem) -> some View {
        if practice.id == "listen_ai" {
            AIListeningSessionView(onBack: closePractice, initialSessionID: savedListeningSessionID, startNewSession: startNewListeningTest)
        } else if practice.id == "ideas_bank" {
            TCFIdeasBankView(onBack: closePractice)
        } else if practice.id == "write_connectors" {
            connectorsReference
        } else {
            switch selectedSkill {
            case 1: ComprehensionOraleView(practice: practice, onBack: closePractice)
            case 2: ExpressionEcriteView(practice: practice, onBack: closePractice)
            case 3: ExpressionOraleView(practice: practice, onBack: closePractice)
            default: ComprehensionEcriteView(practice: practice, onBack: closePractice)
            }
        }
    }

    private var savedListeningTests: some View {
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
                    savedListeningSessionID = test.id
                    startNewListeningTest = false
                    selectedPractice = Self.aiListeningPractice
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: test.completedAt != nil ? "checkmark.seal" : test.state == "ready" ? "doc.text" : "clock")
                            .font(.system(size: 22)).foregroundStyle(TCFTheme.emerald)
                            .frame(width: 34)
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

    private var connectorsReference: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: closePractice) {
                    Label("Pratique", systemImage: "chevron.left").padding(.horizontal, 14)
                }
                .whiteGlassButton()
                Text("Les connecteurs logiques")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                ForEach(TCFMockData.connectors) { connector in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(connector.category.uppercased()).font(.caption2).foregroundStyle(TCFTheme.textMuted)
                        Text(connector.french).font(.headline)
                        Text(connector.english).font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                        Text(connector.exampleSentence).font(.subheadline).italic()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .whiteGlassCard()
                }
            }
            .padding(22)
            .foregroundStyle(TCFTheme.textPrimary)
        }
    }
}
