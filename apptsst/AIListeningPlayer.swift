import AVFoundation
import Combine

@MainActor
final class AIListeningPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var elapsed: Double = 0
    @Published var duration: Double = 0
    @Published var error: String?
    @Published var activeID: Int?
    private var player: AVAudioPlayer?
    private var ticker: AnyCancellable?

    func toggle(url: URL, id: Int) {
        if activeID == id, let player {
            if player.isPlaying { player.pause(); isPlaying = false }
            else { isPlaying = player.play() }
            return
        }
        stop()
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            let recording = try AVAudioPlayer(contentsOf: url)
            recording.delegate = self
            recording.prepareToPlay()
            guard recording.play() else { throw AIListeningError.message("Impossible de démarrer l'audio.") }
            player = recording
            activeID = id
            duration = recording.duration
            isPlaying = true
            ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.elapsed = self?.player?.currentTime ?? 0 }
            }
        } catch { self.error = "Impossible de lire cet enregistrement. Réessayez." }
    }

    func replay(url: URL, id: Int) { stop(); toggle(url: url, id: id) }

    func stop() {
        player?.stop()
        player = nil
        ticker?.cancel()
        ticker = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        activeID = nil
        error = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.player else { return }
            self.isPlaying = false
            self.elapsed = self.duration
            self.player?.currentTime = 0
        }
    }
}
