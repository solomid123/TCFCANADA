import SwiftUI

struct ExpressionEcriteView: View {
    var practice: TCFPracticeItem? = nil
    var onBack: (() -> Void)? = nil
    var isExamMode = false

    @State private var selectedTaskIndex: Int = 0
    @State private var drafts: [Int: String] = [:]
    @State private var selectedSampleTab: Int = 0 // 0: Mon Texte, 1: NCLC 7, 2: NCLC 9
    @State private var showIdeasSheet: Bool = false

    private let tasks = TCFMockData.writingTasks

    init(practice: TCFPracticeItem? = nil, onBack: (() -> Void)? = nil, isExamMode: Bool = false) {
        self.practice = practice
        self.onBack = onBack
        self.isExamMode = isExamMode
        let index = ["write_t1", "write_t2", "write_t3"].firstIndex(of: practice?.id ?? "") ?? 0
        _selectedTaskIndex = State(initialValue: index)
    }

    private var userText: String { drafts[selectedTaskIndex, default: ""] }

    var currentTask: TCFWritingTask {
        tasks[selectedTaskIndex]
    }

    var wordCount: Int {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        let components = trimmed.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.count
    }

    var wordCountStatusColor: Color {
        if wordCount < currentTask.minWords {
            return TCFTheme.amber
        } else if wordCount > currentTask.maxWords {
            return TCFTheme.mapleRed
        } else {
            return TCFTheme.emerald
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // Header & Task Selector
                headerAndTaskSelector

                // Prompt Card
                promptCard

                // Ideas Bank Quick Consultation Button
                if !isExamMode {
                Button(action: { showIdeasSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13))
                            .foregroundColor(TCFTheme.amber)
                        Text("Idées & arguments")
                            .font(.centuryGothic(12, weight: .bold))
                            .foregroundColor(TCFTheme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13))
                            .foregroundColor(TCFTheme.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 14).fill(TCFTheme.amber.opacity(0.08)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(TCFTheme.amber.opacity(0.20), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)

                // Mode Selector
                sampleModeSelector
                }

                // Active Workspace
                if selectedSampleTab == 0 {
                    writingWorkspace
                } else if selectedSampleTab == 1 {
                    sampleCard(title: "Modèle NCLC 7 (B2)", content: currentTask.sampleAnswerNCLC7)
                } else {
                    sampleCard(title: "Modèle NCLC 9 (C1)", content: currentTask.sampleAnswerNCLC9)
                }

                // Connectors Card
                if !isExamMode { connectorsCard }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 36)
        }
        .sheet(isPresented: $showIdeasSheet) {
            TCFIdeasBankView(onBack: { showIdeasSheet = false })
        }
    }

    // MARK: - Header & Selector
    private var headerAndTaskSelector: some View {
        VStack(spacing: 8) {
            HStack {
                if let onBack = onBack {
                    Button(action: {
                        onBack()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Pratiques")
                                .font(.centuryGothic(12, weight: .bold))
                        }
                        .foregroundColor(TCFTheme.azureBlue)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(TCFTheme.azureBlue.opacity(0.10)))
                    }
                }

                Text(practice?.title ?? "EXPRESSION ÉCRITE")
                    .font(.centuryGothic(13, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(currentTask.minWords)-\(currentTask.maxWords) mots")
                    .font(.centuryGothic(11.5, weight: .bold))
                    .foregroundColor(TCFTheme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(TCFTheme.amber.opacity(0.12)))
            }

            // Task Selector
            HStack(spacing: 6) {
                ForEach(0..<tasks.count, id: \.self) { idx in
                    let isSelected = selectedTaskIndex == idx
                    Button(action: {
                        selectedTaskIndex = idx
                        selectedSampleTab = 0
                    }) {
                        Text("Tâche \(idx + 1)")
                            .font(.centuryGothic(11, weight: .bold))
                            .foregroundColor(isSelected ? TCFTheme.textPrimary : TCFTheme.textMuted)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? Color.white : Color.clear)
                            .cornerRadius(9)
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color.black.opacity(0.04)))
        }
        .whiteGlassCard(cornerRadius: 14, padding: 12)
    }

    // MARK: - Prompt Card
    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentTask.title)
                .font(.centuryGothic(15, weight: .bold))
                .foregroundColor(TCFTheme.textPrimary)

            Text(currentTask.prompt)
                .font(.centuryGothic(13, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)
                .lineSpacing(4)
        }
        .whiteGlassCard()
    }

    // MARK: - Mode Selector
    private var sampleModeSelector: some View {
        HStack(spacing: 8) {
            modeBtn(title: "Mon Texte", index: 0)
            modeBtn(title: "Modèle NCLC 7", index: 1)
            modeBtn(title: "Modèle NCLC 9", index: 2)
        }
    }

    private func modeBtn(title: String, index: Int) -> some View {
        let isSelected = selectedSampleTab == index
        return Button(action: {
            selectedSampleTab = index
        }) {
            Text(title)
                .font(.centuryGothic(12, weight: .semibold))
                .foregroundColor(isSelected ? TCFTheme.textPrimary : TCFTheme.textMuted)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.4))
                .cornerRadius(10)
        }
    }

    // MARK: - Writing Workspace
    private var writingWorkspace: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RÉDACTION")
                    .font(.centuryGothic(11, weight: .bold))
                    .foregroundColor(TCFTheme.textMuted)

                Spacer()

                HStack(spacing: 4) {
                    Text("\(wordCount)")
                        .font(.centuryGothic(13, weight: .bold))
                    Text("/ \(currentTask.minWords)-\(currentTask.maxWords) mots")
                        .font(.centuryGothic(11, weight: .regular))
                }
                .foregroundColor(wordCountStatusColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(wordCountStatusColor.opacity(0.12)))
            }

            TextEditor(text: Binding(get: { userText }, set: { drafts[selectedTaskIndex] = $0 }))
                .accessibilityIdentifier("writing-draft")
                .accessibilityLabel("Votre réponse à la tâche \(selectedTaskIndex + 1)")
                .font(.centuryGothic(14, weight: .regular))
                .foregroundColor(TCFTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 180)
                .background(Color.white.opacity(0.85))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(wordCountStatusColor.opacity(0.3), lineWidth: 1)
                )
        }
        .whiteGlassCard()
    }

    // MARK: - Sample Card
    private func sampleCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.centuryGothic(13, weight: .bold))
                .foregroundColor(TCFTheme.textPrimary)

            Text(content)
                .font(.centuryGothic(13, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)
                .lineSpacing(4)
                .padding(12)
                .background(Color.white.opacity(0.85))
                .cornerRadius(12)
        }
        .whiteGlassCard()
    }

    // MARK: - Connectors Card
    private var connectorsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONNECTEURS SUGGÉRÉS")
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(currentTask.essentialConnectors, id: \.self) { conn in
                    Text(conn)
                        .font(.centuryGothic(11, weight: .bold))
                        .foregroundColor(TCFTheme.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.8)))
                }
            }
        }
        .whiteGlassCard()
    }
}
