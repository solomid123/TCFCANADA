import SwiftUI

struct ComprehensionOraleView: View {
    var practice: TCFPracticeItem = TCFMockData.listeningPractices[0]
    var onBack: (() -> Void)? = nil
    var isExamMode = false
    var onComplete: (() -> Void)? = nil
    var onProgress: ((Int, Int) -> Void)? = nil

    @ObservedObject private var audioService = TCFAudioService.shared

    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var hasSubmitted: Bool = false
    @State private var showTranscript: Bool = false
    @State private var answers: [Int: Int] = [:]
    @State private var showResults = false

    private var correctCount: Int {
        questions.filter { answers[$0.id] == $0.correctIndex }.count
    }

    private var questions: [TCFListeningQuestion] {
        TCFMockData.listeningQuestions(forPracticeId: practice.id)
    }

    var currentQuestion: TCFListeningQuestion {
        if questions.isEmpty {
            return TCFMockData.listeningQuestions[0]
        }
        return questions[min(currentIndex, questions.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Header Bar with Back to Practices Action
                    headerControlBar

                    ProgressView(value: Double(currentIndex + 1), total: Double(max(questions.count, 1)))
                        .tint(TCFTheme.emerald)
                        .accessibilityLabel("Progression de la série")

                    // Audio Player Card
                    audioPlayerCard

                    // Question Prompt & Choices
                    questionAndOptionsCard

                    // Transcript & Explanation Card
                    if !isExamMode && (hasSubmitted || showTranscript) {
                        transcriptCard
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
        .onDisappear {
            audioService.stopSpeaking()
        }
        .onAppear { if isExamMode { audioService.speechRate = 0.48 } }
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
                    audioService.stopSpeaking()
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

            if !isExamMode { TCFLevelLabel(text: currentQuestion.level.rawValue) }
        }
        .whiteGlassCard(cornerRadius: 16, padding: 12)
    }

    // MARK: - Audio Player Card (Minimalist Apple Player)
    private var audioPlayerCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Play / Pause Glass Button
                Button(action: {
                    if audioService.isSpeaking {
                        audioService.pauseSpeaking()
                    } else if audioService.isPaused {
                        audioService.resumeSpeaking()
                    } else {
                        audioService.playAudioFileOrSynthesize(
                            fileName: currentQuestion.audioFileName,
                            fallbackText: currentQuestion.spokenScript,
                            language: currentQuestion.languageCode
                        )
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: audioService.isSpeaking ? "waveform" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(audioService.isSpeaking ? "En lecture..." : "Écouter l'extrait")
                            .font(.centuryGothic(14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .whiteGlassButton(cornerRadius: 14, isPrimary: true)

                // Replay Button
                Button(action: {
                    audioService.playAudioFileOrSynthesize(
                        fileName: currentQuestion.audioFileName,
                        fallbackText: currentQuestion.spokenScript,
                        language: currentQuestion.languageCode
                    )
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(TCFTheme.textPrimary)
                        .frame(width: 42, height: 42)
                }
                .whiteGlassButton(cornerRadius: 14)
            }

            // Speed chips & transcription toggle row
            if !isExamMode {
            HStack {
                Text("Vitesse :")
                    .font(.centuryGothic(11, weight: .medium))
                    .foregroundColor(TCFTheme.textMuted)

                speedButton(title: "0.8x", rate: 0.38)
                speedButton(title: "1.0x", rate: 0.48)
                speedButton(title: "1.2x", rate: 0.58)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTranscript.toggle()
                    }
                }) {
                    Text(showTranscript ? "Masquer texte" : "Transcription")
                        .font(.centuryGothic(11.5, weight: .semibold))
                        .foregroundColor(TCFTheme.azureBlue)
                }
            }
            }
        }
        .whiteGlassCard(cornerRadius: 16, padding: 13)
    }

    private func speedButton(title: String, rate: Float) -> some View {
        let isSelected = audioService.speechRate == rate
        return Button(action: {
            audioService.speechRate = rate
        }) {
            Text(title)
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(isSelected ? TCFTheme.textPrimary : TCFTheme.textMuted)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(6)
                .shadow(color: isSelected ? Color.black.opacity(0.04) : Color.clear, radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Question & Choices
    private var questionAndOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentQuestion.question)
                .font(.centuryGothic(15.5, weight: .bold))
                .foregroundColor(TCFTheme.textPrimary)
                .lineSpacing(3.5)
                .padding(.horizontal, 2)

            // Extracted Official Exam Illustration
            if let imgName = currentQuestion.imageFileName,
               let uiImage = UIImage(named: imgName) ?? UIImage(contentsOfFile: Bundle.main.path(forResource: imgName, ofType: "png") ?? "") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .frame(maxWidth: .infinity)
                    .whiteGlassCard(cornerRadius: 16, padding: 6)
            }

            VStack(spacing: 8) {
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
                    .font(.centuryGothic(14.5, weight: .semibold))
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

    // MARK: - Transcript & Explanation (Uncrowded)
    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "quote.opening")
                    .foregroundColor(TCFTheme.azureBlue)
                    .font(.system(size: 14, weight: .bold))

                Text("Transcription")
                    .font(.centuryGothic(12.5, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
            }

            Text("« \(currentQuestion.spokenScript) »")
                .font(.centuryGothic(13.5, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)
                .italic()
                .lineSpacing(3)

            if hasSubmitted {
                Divider()
                    .background(Color.black.opacity(0.06))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(TCFTheme.emerald)
                        .font(.system(size: 14))

                    Text(currentQuestion.explanationFR)
                        .font(.centuryGothic(13, weight: .medium))
                        .foregroundColor(TCFTheme.textPrimary)
                        .lineSpacing(2.5)
                }
            }
        }
        .whiteGlassCard(cornerRadius: 16, padding: 14)
    }

    // MARK: - Classic Bottom Navigation (Side-by-side buttons)
    private var bottomNavigation: some View {
        HStack(spacing: 12) {
            Button(action: {
                if currentIndex > 0 {
                    audioService.stopSpeaking()
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
                audioService.stopSpeaking()
                if currentIndex < questions.count - 1 {
                    currentIndex += 1
                    resetState()
                } else {
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
        showTranscript = false
    }
}
