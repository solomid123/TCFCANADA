import SwiftUI

struct ComprehensionEcriteView: View {
    var practice: TCFPracticeItem = TCFMockData.readingPractices[0]
    var onBack: (() -> Void)? = nil
    var isExamMode = false
    var onComplete: (() -> Void)? = nil
    var onProgress: ((Int, Int) -> Void)? = nil

    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var hasSubmitted: Bool = false
    @State private var isExamTimerActive: Bool = false
    @State private var timeRemainingSeconds: Int = 3600
    @State private var timer: Timer? = nil
    @State private var answers: [Int: Int] = [:]
    @State private var showResults = false

    private var correctCount: Int {
        questions.filter { answers[$0.id] == $0.correctIndex }.count
    }

    private var questions: [TCFReadingQuestion] {
        TCFMockData.readingQuestions(forPracticeId: practice.id)
    }

    var currentQuestion: TCFReadingQuestion {
        if questions.isEmpty {
            return TCFMockData.readingQuestions[0]
        }
        return questions[min(currentIndex, questions.count - 1)]
    }

    var timerFormatted: String {
        let mins = timeRemainingSeconds / 60
        let secs = timeRemainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Header Bar with Back to Practices Action
                    headerControlBar

                    ProgressView(value: Double(currentIndex + 1), total: Double(max(questions.count, 1)))
                        .tint(TCFTheme.azureBlue)
                        .accessibilityLabel("Progression de la série")

                    // Passage Card
                    passageCard

                    // Question & Choices
                    questionAndOptionsCard

                    // Explanation (Shown after selection)
                    if hasSubmitted && !isExamMode {
                        explanationCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
            .id(currentIndex)

            // Clean Floating Bottom Navigation (Zero menu collision, docked above home indicator)
            bottomNavigation
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .onAppear {
            if let minutes = Int(practice.durationText.filter(\.isNumber)), !isExamMode {
                timeRemainingSeconds = minutes * 60
            }
        }
        .onDisappear { timer?.invalidate(); timer = nil; isExamTimerActive = false }
        .sheet(isPresented: $showResults) {
            TCFPracticeResultView(correct: correctCount, total: questions.count, onRetry: {
                answers = [:]
                currentIndex = 0
                resetState()
                showResults = false
            }, onDone: {
                showResults = false
                onBack?()
            })
        }
    }

    // MARK: - Header Bar (Clean minimal layout with back button)
    private var headerControlBar: some View {
        HStack {
            if let onBack = onBack {
                Button(action: {
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Pratiques")
                            .font(.centuryGothic(12.5, weight: .bold))
                    }
                    .foregroundColor(TCFTheme.azureBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(TCFTheme.azureBlue.opacity(0.10))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(practice.title)
                    .font(.centuryGothic(11, weight: .bold))
                    .foregroundColor(TCFTheme.textMuted)
                    .lineLimit(1)
                Text("Question \(currentIndex + 1) sur \(questions.count)")
                    .font(.centuryGothic(14.5, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
            }

            Spacer()

            if !isExamMode {
            Button(action: {
                toggleTimer()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                    Text(timerFormatted)
                        .font(.centuryGothic(12, weight: .bold))
                }
                .foregroundColor(isExamTimerActive ? TCFTheme.amber : TCFTheme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .background(Capsule().fill(.ultraThinMaterial))
                )
                .overlay(
                    Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            }
            }
        }
        .whiteGlassCard(cornerRadius: 16, padding: 12)
    }

    // MARK: - Passage Card (Clean, uncrowded)
    private var passageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(currentQuestion.contextTitle)
                    .font(.centuryGothic(11.5, weight: .medium))
                    .foregroundColor(TCFTheme.textMuted)
                    .lineLimit(1)

                Spacer()

                if !isExamMode { TCFLevelLabel(text: currentQuestion.level.rawValue) }
            }

            Divider()
                .background(Color.black.opacity(0.05))

            Text(currentQuestion.passage)
                .font(.centuryGothic(15.5, weight: .regular))
                .foregroundColor(TCFTheme.textPrimary)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .whiteGlassCard(cornerRadius: 16, padding: 16)
    }

    // MARK: - Question & Options (Classic clean rows)
    private var questionAndOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentQuestion.question)
                .font(.centuryGothic(16, weight: .bold))
                .foregroundColor(TCFTheme.textPrimary)
                .lineSpacing(3.5)
                .padding(.horizontal, 2)

            VStack(spacing: 9) {
                ForEach(0..<currentQuestion.options.count, id: \.self) { idx in
                    optionButton(idx: idx)
                }
            }
        }
    }

    private func optionButton(idx: Int) -> some View {
        let isSelected = selectedOptionIndex == idx
        let isCorrect = idx == currentQuestion.correctIndex

        return Button(action: {
            if !hasSubmitted {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    selectedOptionIndex = idx
                    answers[currentQuestion.id] = idx
                    hasSubmitted = !isExamMode
                    onProgress?(answers.count, correctCount)
                }
            }
        }) {
            HStack(spacing: 12) {
                Text(["A", "B", "C", "D"][idx])
                    .font(.centuryGothic(13, weight: .bold))
                    .foregroundColor(optionLetterColor(idx: idx))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(optionLetterBg(idx: idx)))

                Text(currentQuestion.options[idx])
                    .font(.centuryGothic(14.5, weight: .medium))
                    .foregroundColor(TCFTheme.textPrimary)
                    .lineSpacing(2.5)
                    .multilineTextAlignment(.leading)

                Spacer()

                if hasSubmitted {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(TCFTheme.emerald)
                            .font(.system(size: 18))
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(TCFTheme.mapleRed)
                            .font(.system(size: 18))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(optionRowBg(idx: idx))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(optionRowBorder(idx: idx), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(hasSubmitted)
        .accessibilityIdentifier("answer-\(idx)")
    }

    private func optionLetterBg(idx: Int) -> Color {
        if isExamMode && idx == selectedOptionIndex { return TCFTheme.azureBlue.opacity(0.18) }
        if hasSubmitted {
            if idx == currentQuestion.correctIndex { return TCFTheme.emerald.opacity(0.18) }
            if idx == selectedOptionIndex { return TCFTheme.mapleRed.opacity(0.18) }
        }
        return Color.black.opacity(0.05)
    }

    private func optionLetterColor(idx: Int) -> Color {
        if isExamMode && idx == selectedOptionIndex { return TCFTheme.azureBlue }
        if hasSubmitted {
            if idx == currentQuestion.correctIndex { return TCFTheme.emerald }
            if idx == selectedOptionIndex { return TCFTheme.mapleRed }
        }
        return TCFTheme.textSecondary
    }

    private func optionRowBg(idx: Int) -> Color {
        if isExamMode && idx == selectedOptionIndex { return TCFTheme.azureBlue.opacity(0.12) }
        if hasSubmitted {
            if idx == currentQuestion.correctIndex { return TCFTheme.emerald.opacity(0.15) }
            if idx == selectedOptionIndex { return TCFTheme.mapleRed.opacity(0.15) }
        }
        return Color.white.opacity(0.30)
    }

    private func optionRowBorder(idx: Int) -> Color {
        if isExamMode && idx == selectedOptionIndex { return TCFTheme.azureBlue }
        if hasSubmitted {
            if idx == currentQuestion.correctIndex { return TCFTheme.emerald.opacity(0.50) }
            if idx == selectedOptionIndex { return TCFTheme.mapleRed.opacity(0.50) }
        }
        return Color.white.opacity(0.80)
    }

    // MARK: - Explanation Card (Minimalist & Uncrowded)
    private var explanationCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundColor(selectedOptionIndex == currentQuestion.correctIndex ? TCFTheme.emerald : TCFTheme.amber)

            Text(currentQuestion.explanationFR)
                .font(.centuryGothic(13.5, weight: .medium))
                .foregroundColor(TCFTheme.textPrimary)
                .lineSpacing(3)
        }
        .whiteGlassCard(cornerRadius: 16, padding: 14)
    }

    // MARK: - Classic Bottom Navigation (Side-by-side buttons)
    private var bottomNavigation: some View {
        HStack(spacing: 12) {
            Button(action: {
                if currentIndex > 0 {
                    currentIndex -= 1
                    resetState()
                }
            }) {
                Text("Précédent")
                    .font(.centuryGothic(14, weight: .semibold))
                    .foregroundColor(currentIndex > 0 ? TCFTheme.textPrimary : TCFTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .whiteGlassButton(cornerRadius: 14)
            .disabled(currentIndex == 0)
            .accessibilityIdentifier("previous-question")

            Button(action: {
                if currentIndex < questions.count - 1 {
                    currentIndex += 1
                    resetState()
                } else {
                    timer?.invalidate()
                    isExamTimerActive = false
                    if let onComplete { onComplete() } else { showResults = true }
                }
            }) {
                Text(currentIndex < questions.count - 1 ? "Suivant" : "Terminer")
                    .font(.centuryGothic(14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .whiteGlassButton(cornerRadius: 14, isPrimary: true)
            .disabled(selectedOptionIndex == nil)
            .accessibilityIdentifier("next-question")
        }
    }

    private func resetState() {
        selectedOptionIndex = answers[currentQuestion.id]
        hasSubmitted = selectedOptionIndex != nil && !isExamMode
    }

    private func toggleTimer() {
        isExamTimerActive.toggle()
        if isExamTimerActive {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if timeRemainingSeconds > 0 {
                    timeRemainingSeconds -= 1
                } else {
                    timer?.invalidate()
                    isExamTimerActive = false
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
}
