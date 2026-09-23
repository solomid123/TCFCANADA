import SwiftUI

struct ExpressionOraleView: View {
    var practice: TCFPracticeItem? = nil
    var onBack: (() -> Void)? = nil
    var isExamMode = false

    @ObservedObject private var audioService = TCFAudioService.shared

    @State private var selectedTaskIndex: Int = 0
    @State private var timerRemainingSeconds: Int = 120
    @State private var isTimerActive: Bool = false
    @State private var timer: Timer? = nil
    @State private var showIdeasSheet: Bool = false

    private let tasks = TCFMockData.speakingTasks

    init(practice: TCFPracticeItem? = nil, onBack: (() -> Void)? = nil, isExamMode: Bool = false) {
        self.practice = practice
        self.onBack = onBack
        self.isExamMode = isExamMode
        let index = ["speak_t1", "speak_t2", "speak_t3"].firstIndex(of: practice?.id ?? "") ?? 0
        _selectedTaskIndex = State(initialValue: index)
        _timerRemainingSeconds = State(initialValue: TCFMockData.speakingTasks[index].speakingSeconds)
    }

    var currentTask: TCFSpeakingTask {
        tasks[selectedTaskIndex]
    }

    var formattedSpeakingTimer: String {
        let mins = timerRemainingSeconds / 60
        let secs = timerRemainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // Header & Task Selector
                headerAndTaskSelector

                // Scenario Card
                scenarioCard

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
                }

                // Recording & Timer Card
                recordingAndTimerCard

                // Strategy Tips
                if !isExamMode { tipsCard }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 36)
        }
        .sheet(isPresented: $showIdeasSheet) {
            TCFIdeasBankView(onBack: { showIdeasSheet = false })
        }
        .onDisappear {
            timer?.invalidate()
            audioService.stopRecording()
            audioService.stopPlayingRecordedAudio()
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

                Text(practice?.title ?? "EXPRESSION ORALE")
                    .font(.centuryGothic(13, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(currentTask.speakingSeconds / 60) min")
                    .font(.centuryGothic(11.5, weight: .bold))
                    .foregroundColor(TCFTheme.mapleRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(TCFTheme.mapleRed.opacity(0.12)))
            }

            // Task Switcher
            HStack(spacing: 6) {
                ForEach(0..<tasks.count, id: \.self) { idx in
                    let isSelected = selectedTaskIndex == idx
                    Button(action: {
                        selectedTaskIndex = idx
                        resetTimersAndAudio()
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

    // MARK: - Scenario Card
    private var scenarioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentTask.title)
                .font(.centuryGothic(15, weight: .bold))
                .foregroundColor(TCFTheme.textPrimary)

            Text(currentTask.scenario)
                .font(.centuryGothic(13, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)
                .lineSpacing(4)

            Divider().background(Color.black.opacity(0.06))

            Text("QUESTIONS À TRAITER :")
                .font(.centuryGothic(10, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)

            ForEach(currentTask.promptQuestions, id: \.self) { q in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundColor(TCFTheme.azureBlue)
                    Text(q)
                        .font(.centuryGothic(12, weight: .medium))
                        .foregroundColor(TCFTheme.textSecondary)
                }
            }
        }
        .whiteGlassCard()
    }

    // MARK: - Recording Card
    private var recordingAndTimerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("ENREGISTREMENT")
                    .font(.centuryGothic(11, weight: .bold))
                    .foregroundColor(TCFTheme.textMuted)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 11))
                    Text(formattedSpeakingTimer)
                        .font(.centuryGothic(13, weight: .bold))
                }
                .foregroundColor(timerRemainingSeconds < 30 ? TCFTheme.mapleRed : TCFTheme.textPrimary)
            }

            // Record Button
            Button(action: {
                toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(audioService.isRecording ? TCFTheme.mapleRed : Color.white)
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)

                    Image(systemName: audioService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(audioService.isRecording ? .white : TCFTheme.mapleRed)
                }
            }
            .accessibilityLabel(audioService.isRecording ? "Arrêter l'enregistrement" : "Enregistrer la réponse")

            Text(audioService.isRecording ? "Enregistrement en cours..." : "Touchez pour enregistrer votre réponse")
                .font(.centuryGothic(12, weight: .medium))
                .foregroundColor(audioService.isRecording ? TCFTheme.mapleRed : TCFTheme.textMuted)

            // Playback
            if audioService.recordingDuration > 0 && !audioService.isRecording {
                Button(action: {
                    if audioService.isPlayingRecording {
                        audioService.stopPlayingRecordedAudio()
                    } else {
                        audioService.playRecordedAudio()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: audioService.isPlayingRecording ? "pause.fill" : "play.fill")
                        Text(audioService.isPlayingRecording ? "Pause" : "Réécouter ma réponse")
                    }
                    .font(.centuryGothic(12, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .whiteGlassButton(cornerRadius: 12)
            }
        }
        .whiteGlassCard()
    }

    // MARK: - Tips
    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONSEILS DE L'EXAMINATEUR")
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)

            ForEach(currentTask.strategyTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").foregroundColor(TCFTheme.amber)
                    Text(tip)
                        .font(.centuryGothic(12, weight: .regular))
                        .foregroundColor(TCFTheme.textSecondary)
                }
            }
        }
        .whiteGlassCard()
    }

    // MARK: - Helpers
    private func toggleRecording() {
        if audioService.isRecording {
            audioService.stopRecording()
            timer?.invalidate()
            isTimerActive = false
        } else {
            audioService.startRecording()
            startTimer()
        }
    }

    private func startTimer() {
        isTimerActive = true
        timerRemainingSeconds = currentTask.speakingSeconds

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timerRemainingSeconds > 0 {
                timerRemainingSeconds -= 1
            } else {
                audioService.stopRecording()
                timer?.invalidate()
                isTimerActive = false
            }
        }
    }

    private func resetTimersAndAudio() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        timerRemainingSeconds = currentTask.speakingSeconds
        audioService.stopRecording()
        audioService.stopPlayingRecordedAudio()
    }
}
