import AVFoundation

// MARK: - AudioState
/// Represents the current audio context of the app.
/// AudioManager uses this to select and crossfade the appropriate music track.
enum AudioState: Equatable {
    case homeIdle     // Home screen — calm / between sessions
    case inMission    // Active gameplay
    case victory      // Win overlay visible
    case story        // StoryModal / narrative beat visible
    case paywall      // Paywall overlay visible
    case cooldown     // Transitional / silence
}

extension AudioState {
    #if DEBUG
    var debugLabel: String {
        switch self {
        case .homeIdle:  return "HOME_IDLE"
        case .inMission: return "IN_MISSION"
        case .victory:   return "VICTORY"
        case .story:     return "STORY"
        case .paywall:   return "PAYWALL"
        case .cooldown:  return "COOLDOWN"
        }
    }
    #endif
}

// MARK: - AudioManager
/// Central audio coordinator.
///
/// Owns the current AudioState, crossfades between synthesized background music
/// tracks, and delegates SFX playback to SoundManager.
///
/// Music volume is capped at 35 % so SFX always cut through clearly.
/// All methods must be called from the Main thread (matches SwiftUI call sites).
final class AudioManager {

    static let shared = AudioManager()

    // MARK: Settings

    var sfxEnabled: Bool {
        get { SoundManager.sfxEnabled }
        set { SoundManager.sfxEnabled = newValue }
    }

    /// Whether background music should play. Default ON.
    var musicEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "musicEnabled")
            if newValue { resumeCurrentTrack() } else { stopMusic() }
        }
    }

    // MARK: State

    private(set) var currentState: AudioState = .homeIdle

    // MARK: Private

    /// One pre-built AVAudioPlayer per state (loaded at launch in `prepare()`).
    private var musicPlayers: [AudioState: AVAudioPlayer] = [:]
    /// The player currently assigned as "active" — may be fading in or playing at full volume.
    private var currentMusicPlayer: AVAudioPlayer?
    /// The player currently fading out — kept so rapid transitions can stop it cleanly.
    private var fadingOutPlayer: AVAudioPlayer?
    /// Cancellable task that calls `.pause()` on `fadingOutPlayer` after the fade completes.
    private var activeFadeTask: Task<Void, Never>?

    private let maxMusicVolume:  Float         = 0.35
    private let duckVolume:      Float         = 0.06   // 6 % of full — barely audible under story text
    private let fadeOutDuration: TimeInterval  = 0.55
    private let fadeInDuration:  TimeInterval  = 0.70

    private(set) var isDucked = false

    // MARK: Reactive audio state

    /// Progress 0–1 for current mission (targets connected / total). Lerps volume.
    private var missionIntensity: Float = 0
    /// Consecutive good connections within the combo window (≤800 ms apart).
    private var comboCount: Int = 0
    private var lastConnectionTime: TimeInterval = 0
    /// True while near-failure pulse is active.
    private(set) var isNearFailure = false
    private var nearFailureTask: Task<Void, Never>?

    // Mission music lerps between these two volumes based on intensity (0–1).
    private let missionLowVolume:  Float = 0.22
    // maxMusicVolume (0.35) is the ceiling reached at intensity = 1.

    /// Volume target for the current state, accounting for intensity ramp.
    private var targetVolumeForState: Float {
        if currentState == .inMission {
            return missionLowVolume + (maxMusicVolume - missionLowVolume) * missionIntensity
        }
        return maxMusicVolume
    }

    /// Human-readable label for the current music track (for debug UI).
    var currentTrackLabel: String {
        guard currentMusicPlayer != nil else { return "NONE" }
        switch currentState {
        case .homeIdle:  return "home_idle"
        case .inMission: return "mission_active"
        case .victory:   return "victory"
        case .story:     return "story"
        case .paywall:   return "paywall"
        case .cooldown:  return "NONE"
        }
    }

    private init() {}

    // MARK: - Public API

    /// Call once at app launch. Synthesises SFX + all music tracks on a background thread.
    /// Immediately starts the track for the current state once tracks are built —
    /// ContentView.onAppear fires before this completes, so the initial transition()
    /// call is a no-op (state already matches). This call ensures music starts.
    func prepare() async {
        await SoundManager.prepare()

        let trackData: [AudioState: Data] = await Task.detached(priority: .utility) {
            MusicSynthesizer.buildAll()
        }.value

        for (state, data) in trackData {
            guard let player = try? AVAudioPlayer(data: data, fileTypeHint: nil) else { continue }
            player.numberOfLoops = (state == .victory) ? 0 : -1   // victory plays once
            player.volume = 0
            player.prepareToPlay()
            musicPlayers[state] = player
        }

        // Start music for currentState now that tracks are ready.
        resumeCurrentTrack()
    }

    /// Switch to a new audio state and crossfade to the matching track.
    func transition(to newState: AudioState) {
        guard newState != currentState else { return }
        #if DEBUG
        print("[Audio] \(currentState.debugLabel) → \(newState.debugLabel)")
        #endif
        if newState == .inMission { missionIntensity = 0 }   // fresh ramp for each mission
        currentState = newState
        resumeCurrentTrack()
    }

    /// Play a synthesised SFX. Respects sfxEnabled.
    func playSFX(_ sfx: SoundManager.SFX) {
        SoundManager.play(sfx)
    }

    /// Lower music volume for narrative overlay (story beat, tutorial text).
    /// No-op when music is off or already ducked.
    func duck() {
        guard musicEnabled, !isDucked else { return }
        isDucked = true
        currentMusicPlayer?.setVolume(duckVolume, fadeDuration: 0.25)
    }

    /// Restore music to full volume after a narrative overlay closes.
    func unduck() {
        guard isDucked else { return }
        isDucked = false
        guard musicEnabled else { return }
        currentMusicPlayer?.setVolume(targetVolumeForState, fadeDuration: 0.35)
    }

    /// Fade out and stop whatever is currently playing.
    func stopMusic() {
        activeFadeTask?.cancel()
        fadingOutPlayer?.volume = 0
        fadingOutPlayer?.pause()
        fadingOutPlayer = nil

        let old = currentMusicPlayer
        currentMusicPlayer = nil
        guard let old else { return }

        old.setVolume(0, fadeDuration: fadeOutDuration)
        let duration = fadeOutDuration
        activeFadeTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            old.pause()
        }
    }

    // MARK: - Reactive Audio API

    /// Called on each target/relay connection. Ramps mission music volume up and tracks combos.
    /// Play a rising combo note after 3+ consecutive connections within the combo window.
    func notifyConnection() {
        let now = CACurrentMediaTime()
        if now - lastConnectionTime < 0.800 {
            comboCount += 1
        } else {
            comboCount = 1
        }
        lastConnectionTime = now
        if comboCount >= 3 {
            SoundManager.play(.comboNote)
        }
    }

    /// Brief music volume dip on a wrong tap — signals "that didn't work" without interrupting flow.
    func missEvent() {
        guard currentState == .inMission, musicEnabled, !isDucked else { return }
        let current = targetVolumeForState
        let dip     = max(0.05, current * 0.45)
        currentMusicPlayer?.setVolume(dip, fadeDuration: 0.04)
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard self.currentState == .inMission, !self.isDucked else { return }
            self.currentMusicPlayer?.setVolume(self.targetVolumeForState, fadeDuration: 0.28)
        }
    }

    /// Lerps mission music volume between missionLowVolume (0 targets) and maxMusicVolume (all targets).
    func setMissionIntensity(_ progress: Float) {
        guard currentState == .inMission, musicEnabled, !isDucked else { return }
        missionIntensity = min(1, max(0, progress))
        currentMusicPlayer?.setVolume(targetVolumeForState, fadeDuration: 0.30)
    }

    /// Starts or stops the near-failure low-frequency pulse loop (sub-bass D2 every 850 ms).
    /// On activate: cuts music so the SFX pulse rings in silence for maximum tension.
    /// On deactivate: resumes the mission track (if still in-mission) for the relief contrast.
    func setNearFailure(_ active: Bool) {
        guard active != isNearFailure else { return }
        isNearFailure = active
        if active {
            stopMusic()   // silence — only the sub-bass pulse during countdown
            nearFailureTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    SoundManager.play(.nearFailurePulse)
                    try? await Task.sleep(nanoseconds: 850_000_000)
                    guard let self, self.isNearFailure else { return }
                }
            }
        } else {
            nearFailureTask?.cancel()
            nearFailureTask = nil
            if currentState == .inMission { resumeCurrentTrack() }   // music returns with relief
        }
    }

    // MARK: - App lifecycle

    /// Call when the app moves to background (scenePhase == .background).
    /// Fades music to silence so there is no audible bleed while the app is suspended.
    /// Cancels any in-flight fade task to avoid competing volume ramps.
    func handleBackground() {
        activeFadeTask?.cancel()
        currentMusicPlayer?.setVolume(0, fadeDuration: 0.20)
    }

    /// Call when the app returns to foreground (scenePhase == .active).
    /// Restores music to the correct volume for the current state.
    /// Restarts the player if it was paused by an audio-session interruption.
    func handleForeground() {
        guard musicEnabled, let player = currentMusicPlayer else { return }
        if !player.isPlaying { player.play() }
        let target = isDucked ? duckVolume : targetVolumeForState
        player.setVolume(target, fadeDuration: 0.50)
    }

    // MARK: - Private

    /// Start (or crossfade to) the music track for `currentState`.
    private func resumeCurrentTrack() {
        guard musicEnabled else {
            #if DEBUG
            print("[Audio] ⛔ track blocked — musicEnabled=false")
            #endif
            stopMusic()
            return
        }

        let newPlayer = musicPlayers[currentState]
        let old       = currentMusicPlayer

        // If the target is a different player, fade out the old one.
        if old !== newPlayer {
            // Cancel any previous in-flight fade, cleanly stopping that player now.
            activeFadeTask?.cancel()
            fadingOutPlayer?.volume = 0
            fadingOutPlayer?.pause()

            if let old {
                old.setVolume(0, fadeDuration: fadeOutDuration)
                fadingOutPlayer = old
                let capturedOld  = old
                let duration     = fadeOutDuration
                activeFadeTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    capturedOld.pause()
                }
            }
        }

        guard let player = newPlayer else {
            #if DEBUG
            print("[Audio] ⚠️ no track built for state \(currentState.debugLabel)")
            #endif
            currentMusicPlayer = nil
            return
        }
        currentMusicPlayer = player

        let targetVolume = isDucked ? duckVolume : targetVolumeForState
        if player.isPlaying {
            // May have been fading out — restore volume to target (ducked or full).
            player.setVolume(targetVolume, fadeDuration: fadeInDuration)
        } else {
            if currentState == .victory { player.currentTime = 0 }
            player.volume = 0
            player.play()
            player.setVolume(targetVolume, fadeDuration: fadeInDuration)
            #if DEBUG
            print("[Audio] ▶️ \(currentTrackLabel) started")
            #endif
        }
    }
}
