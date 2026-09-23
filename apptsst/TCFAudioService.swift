import Foundation
import AVFoundation
import Combine

// MARK: - TCF Audio & Speech Service
@MainActor
final class TCFAudioService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = TCFAudioService()

    // Text-to-Speech (Listening Comprehension)
    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false
    @Published var speechRate: Float = 0.48 // ~1.0x natural French rate

    private let speechSynthesizer = AVSpeechSynthesizer()

    // Audio Recorder (Speaking Practice)
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var isPlayingRecording: Bool = false
    @Published var recordingPlaybackProgress: Double = 0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var recordingURL: URL?

    override private init() {
        super.init()
        speechSynthesizer.delegate = self
        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
        #endif
    }

    // Pre-recorded exam audio (e.g. from YouTube Série 11)
    private var examAudioPlayer: AVAudioPlayer?

    func playAudioFileOrSynthesize(fileName: String?, fallbackText: String, language: String = "fr-CA") {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {}
        #endif

        if let fileName = fileName {
            let bundleUrl = Bundle.main.url(forResource: fileName, withExtension: "m4a")
                ?? Bundle.main.bundleURL.appendingPathComponent("\(fileName).m4a")
                ?? Bundle.main.bundleURL.appendingPathComponent("apptsst/\(fileName).m4a")
            
            if FileManager.default.fileExists(atPath: bundleUrl.path) {
                stopSpeaking()
                do {
                    examAudioPlayer = try AVAudioPlayer(contentsOf: bundleUrl)
                    examAudioPlayer?.delegate = self
                    examAudioPlayer?.enableRate = true
                    examAudioPlayer?.volume = 1.0
                    // Map speechRate (0.38..0.58) to AVAudioPlayer rate (0.8..1.2)
                    let audioRate: Float = speechRate < 0.42 ? 0.8 : (speechRate > 0.52 ? 1.2 : 1.0)
                    examAudioPlayer?.rate = audioRate
                    examAudioPlayer?.play()
                    isSpeaking = true
                    isPaused = false
                    return
                } catch {
                    print("Failed to play audio file: \(error.localizedDescription), falling back to speech")
                }
            }
        }
        speak(text: fallbackText, language: language)
    }

    // MARK: - Speech Synthesis (Compréhension Orale)

    func speak(text: String, language: String = "fr-CA") {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Select specified language (fr-CA or fr-FR) with graceful fallbacks
        if let voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "fr-CA") ?? AVSpeechSynthesisVoice(language: "fr-FR") {
            utterance.voice = voice
        }

        isSpeaking = true
        isPaused = false
        speechSynthesizer.speak(utterance)
    }

    func pauseSpeaking() {
        if let player = examAudioPlayer, player.isPlaying {
            player.pause()
            isPaused = true
            isSpeaking = false
        } else if isSpeaking && !isPaused {
            speechSynthesizer.pauseSpeaking(at: .immediate)
            isPaused = true
        }
    }

    func resumeSpeaking() {
        if let player = examAudioPlayer, isPaused {
            player.play()
            isPaused = false
            isSpeaking = true
        } else if isPaused {
            speechSynthesizer.continueSpeaking()
            isPaused = false
        }
    }

    func stopSpeaking() {
        examAudioPlayer?.stop()
        examAudioPlayer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
        }
    }

    // MARK: - Audio Recorder (Expression Orale)

    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("tcf_speaking_practice.m4a")
        self.recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            isRecording = true
            recordingDuration = 0

            recordingTimer?.invalidate()
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingDuration += 0.1
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func playRecordedAudio() {
        guard let url = recordingURL, FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlayingRecording = true

            playbackTimer?.invalidate()
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                if player.duration > 0 {
                    self.recordingPlaybackProgress = player.currentTime / player.duration
                }
            }
        } catch {
            print("Failed to play recording: \(error.localizedDescription)")
        }
    }

    func stopPlayingRecordedAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingRecording = false
        recordingPlaybackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if player == self.examAudioPlayer {
                self.isSpeaking = false
                self.isPaused = false
                self.examAudioPlayer = nil
            } else {
                self.isPlayingRecording = false
                self.recordingPlaybackProgress = 0
                self.playbackTimer?.invalidate()
                self.playbackTimer = nil
            }
        }
    }
}
