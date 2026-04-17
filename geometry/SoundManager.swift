import AVFoundation

// MARK: - SoundManager
/// Synthesises all game SFX and ambient music from raw PCM data.
/// Uses AVAudioPlayer — proven, reliable, no AVAudioEngine format issues.
/// All heavy computation runs on a background thread so the main thread never blocks.
enum SoundManager {

    // MARK: SFX event catalogue

    enum SFX: CaseIterable, Hashable {
        case tileRotate      // standard tile rotation
        case tileLocked      // rejected tap on a rotation-capped tile
        case relayEnergized  // relay tile enters powered state
        case targetOnline    // target tile reaches full power
        case win             // full circuit completed — rising arpeggio
        case lose            // out of moves or time — descending sweep
        case drift           // auto-drift fires
        case overloadArm     // overloaded tile armed on first tap
        case timerTick       // countdown — last-10-seconds tick
        case mechanicUnlock  // first encounter with a new mechanic
        case sectorComplete  // all missions in a sector done — access granted
        // UI navigation sounds
        case tapPrimary      // primary CTA (PLAY, CONTINUE, NEXT MISSION)
        case tapSecondary    // secondary/ghost buttons (map, dismiss, retry)
        case storyAdvance    // advance a story beat (data blip)
        case uiSuccess       // positive confirmation outside game (purchase, milestone)
        // Sonic logo — brand identity sound
        case sonicLogoFull   // ~1.4 s: full "Signal Lock" identity sound
        case sonicLogoShort  // ~0.5 s: compact version for sector unlock
        case sonicLogoSubtle // ~1.4 s at 35 % amp — ambient first-launch welcome
        // Reactive audio
        case nearFailurePulse // sub-bass D2 thud — near-failure heartbeat (looped by AudioManager)
        case comboNote        // F#4→A4 micro chirp — 3+ consecutive connections reward

        /// Minimum interval (seconds) before the same SFX can play again.
        /// Prevents audio stacking from rapid taps or tight loops.
        var minimumInterval: TimeInterval {
            switch self {
            case .tileRotate, .drift:
                return 0.080   // gameplay — fast feedback, short guard
            case .timerTick:
                return 0.800   // fires once/second in the loop; skip double-fires
            case .relayEnergized, .targetOnline, .overloadArm:
                return 0.120   // can trigger in quick succession during play
            case .sonicLogoFull, .sonicLogoShort, .sonicLogoSubtle:
                return 5.000   // milestone moments — never rapid-fires
            case .nearFailurePulse:
                return 0.700   // looped externally every 850 ms — guard against double-fire
            case .comboNote:
                return 0.100   // quick reward, but not faster than combos realistically fire
            default:
                return 0.200   // UI + win/lose + story — no need for rapid repeats
            }
        }

        /// Number of pre-built AVAudioPlayer instances in the pool.
        /// Logo sounds are long (1.4 s) and never overlap — 1 instance is enough.
        var poolSize: Int {
            switch self {
            case .sonicLogoFull, .sonicLogoShort, .sonicLogoSubtle: return 1
            case .nearFailurePulse, .comboNote: return 2
            default: return 3
            }
        }
    }

    // MARK: Persistent settings

    static var sfxEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "sfxEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sfxEnabled") }
    }

    // MARK: Private state (main thread only)

    nonisolated private static let sr = 44100
    private static var pools:        [SFX: [AVAudioPlayer]] = [:]
    private static var poolIdx:      [SFX: Int]             = [:]
    /// Monotonic timestamp of the last successful play per SFX — used for anti-spam debounce.
    private static var lastPlayedAt: [SFX: TimeInterval]    = [:]

    // MARK: - Public API

    /// Call once at app launch from an async context.
    /// All heavy work (PCM synthesis + AVAudioPlayer creation) runs on a background thread
    /// so the main thread is never blocked. Only the final pool assignment and music start
    /// happen on the caller's actor context, and those are trivially fast.
    static func prepare() async {
        configureSession()

        // Synthesise PCM, pack WAV, and build the player pool entirely off the main actor.
        // Priority: .userInitiated — needs to complete before the player opens the first level.
        let readyPools: [SFX: [AVAudioPlayer]] =
            await Task.detached(priority: .userInitiated) {
                let sfxDataList = SFX.allCases.map { wavData(samples: synthesizeMono($0), channels: 1) }

                // Create and prepareToPlay on the background thread — safe for AVAudioPlayer.
                var pools: [SFX: [AVAudioPlayer]] = [:]
                for (sfx, data) in zip(SFX.allCases, sfxDataList) {
                    pools[sfx] = (0..<sfx.poolSize).compactMap { _ in
                        guard let p = try? AVAudioPlayer(data: data, fileTypeHint: nil) else { return nil }
                        p.volume = 1.0
                        p.prepareToPlay()
                        return p
                    }
                }
                return pools
            }.value

        pools = readyPools
    }

    /// Play a synthesised sound effect. Safe to call from @MainActor.
    /// Anti-spam: skips the play if the same SFX fired within its `minimumInterval`.
    static func play(_ sfx: SFX) {
        guard sfxEnabled, let pool = pools[sfx], !pool.isEmpty else { return }

        // Anti-spam debounce — prevent stacking from rapid taps or tight loops
        let now = CACurrentMediaTime()
        if let last = lastPlayedAt[sfx], now - last < sfx.minimumInterval { return }
        lastPlayedAt[sfx] = now

        let i = poolIdx[sfx, default: 0]
        poolIdx[sfx] = (i + 1) % pool.count
        pool[i].currentTime = 0
        pool[i].play()
    }

    #if DEBUG
    /// Debug-only play that bypasses the anti-spam debounce.
    /// Use only from DevMenuView — never from production code paths.
    static func debugPlay(_ sfx: SFX) {
        lastPlayedAt.removeValue(forKey: sfx)
        play(sfx)
    }
    #endif

    // MARK: - Private: audio session

    private static func configureSession() {
        // .playback ignores the silent switch so SFX are always audible.
        // .mixWithOthers lets music apps keep playing alongside the game.
        try? AVAudioSession.sharedInstance().setCategory(.playback,
                                                         mode: .default,
                                                         options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Private: synthesis dispatch

    nonisolated private static func synthesizeMono(_ sfx: SFX) -> [Float] {
        switch sfx {
        // Downward laser snap — mechanical, instant, distinctive
        case .tileRotate:     return laser(f0: 293, f1: 185, dur: 0.038, decay: 58)
        // Dissonant dual-tone thunk — blocked / rejected
        case .tileLocked:     return glitchBuzz(freq: 147, dur: 0.080)
        // Rising signal lock — energy flowing into relay
        case .relayEnergized: return energySweep(f0: 293, f1: 440, dur: 0.150)
        // Metallic network-ping — connection established
        case .targetOnline:   return chime(freq: 587, dur: 0.280, amp: 0.56)
        // 4-note rising chime arpeggio — premium mission-complete
        case .win:            return missionComplete()
        // Exponential power-down with detuning drift — failure
        case .lose:           return powerDown(f0: 293, f1: 74, dur: 0.400)
        // Tiny upward laser blip — auto-drift tick
        case .drift:          return laser(f0: 440, f1: 587, dur: 0.024, decay: 100, amp: 0.32)
        // Rising vibrato charge — overload armed warning
        case .overloadArm:    return warningCharge(f0: 147, f1: 220, dur: 0.120)
        // Ultra-sharp clean tick — timer countdown
        case .timerTick:      return digitalTick()
        // 3-note warm chime sequence — discovery / mechanic unlock
        case .mechanicUnlock: return discoveryJingle()
        // Bass thud + four-voice rising chord — sector clearance granted
        case .sectorComplete: return accessGranted()
        // Ascending laser chirp — clean digital confirm
        case .tapPrimary:     return tapPrimaryLayered()
        // Short soft descending blip — secondary/ghost buttons
        case .tapSecondary:   return laser(f0: 440, f1: 293, dur: 0.020, decay: 100, amp: 0.28)
        // Dual-pip data blip — story text advance
        case .storyAdvance:  return dataPip()
        // 2-note rising chime — positive UI confirmation (purchase, pass)
        case .uiSuccess:     return twoNoteConfirm()
        // Sonic logo — brand identity sound "Signal Lock"
        case .sonicLogoFull:   return sonicLogoBase(amp: 1.00)
        case .sonicLogoShort:  return sonicLogoShort()
        case .sonicLogoSubtle: return sonicLogoBase(amp: 0.35)
        // Reactive audio
        case .nearFailurePulse: return nearFailurePulse()
        case .comboNote:        return comboNote()
        }
    }

    // MARK: - Generators (called from background thread — pure computation, no shared state)

    /// Exponential frequency chirp — the core "laser" primitive.
    /// Frequency moves in log space from f0→f1 with a sharp exponential decay.
    nonisolated private static func laser(f0: Double, f1: Double, dur: Double,
                                          decay: Double = 30.0, amp: Double = 0.62) -> [Float] {
        let n = Int(Double(sr) * dur)
        let logF0 = log(f0), logRatio = log(f1 / f0)
        var phase = 0.0
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let tN  = Double(i) / Double(n)
            let env  = exp(-decay * t)
            let freq = exp(logF0 + logRatio * tN)
            phase += 2 * .pi * freq / Double(sr)
            // 15% 2nd harmonic adds upper-register brightness
            return Float((sin(phase) * 0.85 + sin(phase * 2) * 0.15) * env * amp)
        }
    }

    /// Dissonant dual-tone buzz — rejected / blocked feedback.
    /// Two voices ~91 cents apart create an audible beating pattern.
    nonisolated private static func glitchBuzz(freq: Double, dur: Double) -> [Float] {
        let n      = Int(Double(sr) * dur)
        let detune = freq * 1.055
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let env = exp(-12 * t)
            let v   = sin(2 * .pi * freq      * t) * 0.52
                    + sin(2 * .pi * detune     * t) * 0.36
                    + sin(2 * .pi * freq * 3.0 * t) * 0.10   // lighter 3rd harmonic
            return Float(v * env * 0.42)
        }
    }

    /// Rising energy sweep with 2nd-harmonic reinforcement — relay activation.
    nonisolated private static func energySweep(f0: Double, f1: Double, dur: Double) -> [Float] {
        let n = Int(Double(sr) * dur)
        var ph1 = 0.0, ph2 = 0.0
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let tN  = Double(i) / Double(n)
            // Convex attack-sustain-release (biased toward sustain)
            let env  = sin(.pi * pow(tN, 0.55))
            let freq = f0 + (f1 - f0) * tN
            ph1 += 2 * .pi * freq       / Double(sr)
            ph2 += 2 * .pi * freq * 2.0 / Double(sr)
            return Float((sin(ph1) * 0.72 + sin(ph2) * 0.28) * env * 0.54)
        }
    }

    /// Metallic bell chime using physically-inspired partial ratios.
    /// Higher partials decay faster, giving a natural ring-out.
    nonisolated private static func chime(freq: Double, dur: Double, amp: Double = 0.58) -> [Float] {
        let n = Int(Double(sr) * dur)
        // (frequency ratio, weight, extra decay factor)
        let partials: [(Double, Double, Double)] = [
            (1.000, 0.50, 1.0),
            (2.000, 0.22, 1.8),
            (3.011, 0.12, 3.0),
            (4.166, 0.08, 5.0),
            (5.433, 0.04, 8.0),
        ]
        let baseDecay = 7.5 / dur
        return (0..<n).map { i in
            let t = Double(i) / Double(sr)
            var v = 0.0
            for (ratio, weight, dk) in partials {
                v += sin(2 * .pi * freq * ratio * t) * weight * exp(-baseDecay * dk * t)
            }
            return Float(v * amp)
        }
    }

    /// Exponential power-down sweep with a detuned voice that drifts apart —
    /// increasing dissonance as the signal falls, creating a "dying system" feel.
    nonisolated private static func powerDown(f0: Double, f1: Double, dur: Double) -> [Float] {
        let n = Int(Double(sr) * dur)
        var ph1 = 0.0, ph2 = 0.0
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let tN  = Double(i) / Double(n)
            let env    = (1.0 - tN) * exp(-1.4 * tN)
            let freq   = f0 * pow(f1 / f0, tN)    // exponential descent
            let detune = 1.0 + 0.045 * tN          // widens as freq falls
            ph1 += 2 * .pi * freq          / Double(sr)
            ph2 += 2 * .pi * freq * detune / Double(sr)
            return Float((sin(ph1) * 0.60 + sin(ph2) * 0.40) * env * 0.54)
        }
    }

    /// Rising vibrato charge — overload armed warning.
    nonisolated private static func warningCharge(f0: Double, f1: Double, dur: Double) -> [Float] {
        let n = Int(Double(sr) * dur)
        var phase = 0.0
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let tN  = Double(i) / Double(n)
            let env     = min(1.0, tN * (dur / 0.010))   // 10 ms linear attack
            let vibrato = 1.0 + 0.014 * sin(2 * .pi * 20.0 * t)
            let freq    = (f0 + (f1 - f0) * tN) * vibrato
            phase += 2 * .pi * freq / Double(sr)
            return Float(sin(phase) * env * 0.54)
        }
    }

    /// Ultra-short, very clean digital tick — precise like a system clock.
    nonisolated private static func digitalTick() -> [Float] {
        let dur  = 0.014
        let n    = Int(Double(sr) * dur)
        let freq = 587.33   // D5 — mid-range, precise without harshness
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let env = exp(-250.0 * t)
            return Float(sin(2 * .pi * freq * t) * env * 0.44)   // 0.62→0.44: fires 10× in countdown, lower amp prevents fatigue
        }
    }

    /// 4-note chime arpeggio — mission complete (A5 D6 E6 A6 pentatonic).
    nonisolated private static func missionComplete() -> [Float] {
        let freqs: [Double] = [293.66, 369.99, 440.00, 587.33]   // D4 F#4 A4 D5
        let step    = 0.075
        let noteDur = 0.32
        let total   = step * Double(freqs.count) + noteDur + 0.100   // +100ms for harmonic tail
        let n       = Int(Double(sr) * total)
        var out     = [Float](repeating: 0, count: n)
        let partials: [(Double, Double, Double)] = [
            (1.000, 0.50, 1.0), (2.000, 0.22, 1.8), (3.011, 0.10, 3.2)
        ]
        for (idx, freq) in freqs.enumerated() {
            let start     = Int(Double(sr) * step * Double(idx))
            let noteN     = Int(Double(sr) * noteDur)
            let baseDecay = 7.5 / noteDur
            for j in 0..<noteN {
                let gi = start + j; guard gi < n else { break }
                let t = Double(j) / Double(sr)
                var v = 0.0
                for (ratio, weight, dk) in partials {
                    v += sin(2 * .pi * freq * ratio * t) * weight * exp(-baseDecay * dk * t)
                }
                out[gi] += Float(v * 0.50)
            }
        }

        // Layer 2: Harmonic sustain haze — all 4 voices together, fades in at 200ms.
        // Creates the sense of the chord "crystallizing" as the last arpeggio note lands.
        let tailStart   = Int(Double(sr) * 0.200)
        let tailDur     = total - 0.200
        let tailN       = Int(Double(sr) * tailDur)
        let tailAttackN = Int(Double(sr) * 0.030)
        for freq in freqs {
            for j in 0..<tailN {
                let gi = tailStart + j; guard gi < n else { break }
                let t      = Double(j) / Double(sr)
                let tN     = Double(j) / Double(tailN)
                let attack = min(1.0, Double(j) / Double(tailAttackN))
                let env    = attack * exp(-3.8 * tN)
                out[gi] += Float(sin(2 * .pi * freq * t) * env * 0.13)
            }
        }
        return out
    }

    /// 3-note warm chime sequence — discovery / mechanic unlock (C5 E5 G5 major).
    nonisolated private static func discoveryJingle() -> [Float] {
        let freqs: [Double] = [293.66, 369.99, 440.00]   // D4 F#4 A4
        let step    = 0.10
        let noteDur = 0.36
        let total   = step * Double(freqs.count) + noteDur
        let n       = Int(Double(sr) * total)
        var out     = [Float](repeating: 0, count: n)
        let partials: [(Double, Double, Double)] = [
            (1.000, 0.46, 1.0), (2.000, 0.24, 1.6), (3.011, 0.12, 2.6), (4.166, 0.06, 4.2)
        ]
        for (idx, freq) in freqs.enumerated() {
            let start     = Int(Double(sr) * step * Double(idx))
            let noteN     = Int(Double(sr) * noteDur)
            let baseDecay = 6.0 / noteDur
            for j in 0..<noteN {
                let gi = start + j; guard gi < n else { break }
                let t = Double(j) / Double(sr)
                var v = 0.0
                for (ratio, weight, dk) in partials {
                    v += sin(2 * .pi * freq * ratio * t) * weight * exp(-baseDecay * dk * t)
                }
                out[gi] += Float(v * 0.44)
            }
        }

        // Layer 2: Confirm click at 370ms — system seals the unlock.
        // A sharp D5 digital pulse lands just after the last jingle note settles.
        let clickStart = Int(Double(sr) * 0.370)
        let clickN     = Int(Double(sr) * 0.014)
        for j in 0..<clickN {
            let gi = clickStart + j; guard gi < n else { break }
            let t   = Double(j) / Double(sr)
            out[gi] += Float(sin(2 * .pi * 587.33 * t) * exp(-300.0 * t) * 0.42)
        }
        return out
    }

    /// Deep bass thud followed by a four-voice arpeggiated chord — space-station access granted.
    /// Total ~1.5 s: sub-bass transient (0–0.22 s) then D-major arpeggio (0.15–1.5 s).
    nonisolated private static func accessGranted() -> [Float] {
        let total = 1.4
        let n     = Int(Double(sr) * total)
        var out   = [Float](repeating: 0, count: n)

        // Phase 1: sub-bass confirmation thud (D2 = 73.4 Hz)
        let thudN = Int(Double(sr) * 0.22)
        for i in 0..<thudN {
            let t = Double(i) / Double(sr)
            out[i] += Float(sin(2 * .pi * 73.42 * t) * exp(-10.0 * t) * 0.70)
        }

        // Phase 2: D-major four-note arpeggio — D3 A3 D4 F#4, staggered 65 ms apart
        // Lower register: richer, more resonant, fully within the D-palette
        let chordFreqs: [Double] = [146.83, 220.00, 293.66, 369.99]   // D3 A3 D4 F#4
        let noteStep = 0.065
        let chordStart = 0.15
        let noteDur = total - chordStart
        let baseDecay = 2.2 / noteDur   // slow decay — chord sustains across the screen

        let partials: [(Double, Double, Double)] = [
            (1.000, 0.44, 1.0),
            (2.000, 0.20, 1.7),
            (3.011, 0.09, 3.0),
        ]

        for (fi, freq) in chordFreqs.enumerated() {
            let start = Int(Double(sr) * (chordStart + noteStep * Double(fi)))
            for j in 0..<(n - start) {
                let gi = start + j; guard gi < n else { break }
                let t      = Double(j) / Double(sr)
                let attack = min(1.0, Double(j) / Double(Int(Double(sr) * 0.035))) // 35 ms ramp
                var v      = 0.0
                for (ratio, weight, dk) in partials {
                    v += sin(2 * .pi * freq * ratio * t) * weight * exp(-baseDecay * dk * t)
                }
                out[gi] += Float(v * attack * 0.30)
            }
        }
        return out
    }

    /// Dual-pip data blip — two staggered short tones (1100 Hz → 1500 Hz, 20 ms apart).
    /// Conveys "data received / page advance" without distracting from the narrative.
    nonisolated private static func dataPip() -> [Float] {
        let dur  = 0.060   // extended to fit 3-pip cascade
        let n    = Int(Double(sr) * dur)
        var out  = [Float](repeating: 0, count: n)
        // Triple cascade: D5 → F#5 → A5 each 20ms apart — "data traversing nodes"
        let pips: [(start: Double, freq: Double, amp: Float)] = [
            (0.000, 587.33, 0.44),   // D5 — primary blip
            (0.020, 739.99, 0.44),   // F#5 — echo
            (0.040, 880.00, 0.24),   // A5  — trailing whisper
        ]
        let pipDur = 0.018
        let pipN   = Int(Double(sr) * pipDur)
        for pip in pips {
            let start = Int(Double(sr) * pip.start)
            for j in 0..<min(pipN, n - start) {
                let t   = Double(j) / Double(sr)
                let env = exp(-120.0 * t)
                out[start + j] += Float(sin(2 * .pi * pip.freq * t) * env) * pip.amp
            }
        }
        return out
    }

    /// 2-note rising chime — C5 (523 Hz) → E5 (659 Hz), 80 ms apart, total ~260 ms.
    /// Lighter and shorter than missionComplete; suitable for purchase/pass confirmation.
    nonisolated private static func twoNoteConfirm() -> [Float] {
        let freqs: [Double] = [587.33, 739.99]   // D5 F#5
        let step    = 0.080
        let noteDur = 0.16
        let total   = step * Double(freqs.count) + noteDur
        let n       = Int(Double(sr) * total)
        var out     = [Float](repeating: 0, count: n)
        let partials: [(Double, Double, Double)] = [
            (1.000, 0.48, 1.0), (2.000, 0.22, 1.8), (3.011, 0.11, 3.0)
        ]
        for (idx, freq) in freqs.enumerated() {
            let start     = Int(Double(sr) * step * Double(idx))
            let noteN     = Int(Double(sr) * noteDur)
            let baseDecay = 8.0 / noteDur
            for j in 0..<noteN {
                let gi = start + j; guard gi < n else { break }
                let t = Double(j) / Double(sr)
                var v = 0.0
                for (ratio, weight, dk) in partials {
                    v += sin(2 * .pi * freq * ratio * t) * weight * exp(-baseDecay * dk * t)
                }
                out[gi] += Float(v * 0.50)
            }
        }
        return out
    }

    // MARK: - Reactive audio generators

    /// Sub-bass D2 (73.4 Hz) thud — near-failure pulse. Felt as much as heard.
    /// 2 ms attack, 100 ms total. AudioManager loops this every 850 ms.
    nonisolated private static func nearFailurePulse() -> [Float] {
        let dur = 0.100
        let n   = Int(Double(sr) * dur)
        let attackN = Int(Double(sr) * 0.002)
        return (0..<n).map { i in
            let t      = Double(i) / Double(sr)
            let attack = min(1.0, Double(i) / Double(attackN))
            let env    = attack * exp(-12.0 * t)
            return Float(sin(2 * .pi * 73.42 * t) * env * 0.38)
        }
    }

    /// F#4→A4 micro chirp (369→440 Hz) — combo reward after 3+ consecutive connections.
    /// 80 ms, sine + 15 % 2nd harmonic, quiet (amp=0.35) so it layers under the main SFX.
    nonisolated private static func comboNote() -> [Float] {
        let dur = 0.080
        let n   = Int(Double(sr) * dur)
        let logF0 = log(369.99), logRatio = log(440.00 / 369.99)
        var phase = 0.0
        return (0..<n).map { i in
            let t  = Double(i) / Double(sr)
            let tN = Double(i) / Double(n)
            let env  = exp(-45.0 * t)
            let freq = exp(logF0 + logRatio * tN)
            phase += 2 * .pi * freq / Double(sr)
            return Float((sin(phase) * 0.85 + sin(phase * 2) * 0.15) * env * 0.35)
        }
    }

    // MARK: - Layered sound generators

    /// Primary CTA tap — 2-layer experience:
    ///   Layer 1 (0ms):   A3→D5 ascending chirp (30ms) — base click
    ///   Layer 2 (65ms):  D5+F#5 resonance bloom — activation glow
    ///
    /// The 35ms gap between click and glow creates a "press... light up" feel,
    /// like a button activating its indicator after contact.
    nonisolated private static func tapPrimaryLayered() -> [Float] {
        let dur = 0.160
        let n   = Int(Double(sr) * dur)
        var out = [Float](repeating: 0, count: n)

        // Layer 1: Base click — A3→D5 ascending chirp (0–30ms)
        do {
            let chirpN = Int(Double(sr) * 0.030)
            let logF0 = log(220.0), logRatio = log(587.33 / 220.0)
            var ph = 0.0
            for i in 0..<chirpN {
                let t  = Double(i) / Double(sr)
                let tN = Double(i) / Double(chirpN)
                let env  = exp(-85.0 * t)
                let freq = exp(logF0 + logRatio * tN)
                ph += 2 * .pi * freq / Double(sr)
                out[i] += Float((sin(ph) * 0.85 + sin(ph * 2) * 0.15) * env * 0.52)
            }
        }

        // Layer 2: Activation glow — D5+F#5 resonance bloom (65–160ms)
        do {
            let tailStart = Int(Double(sr) * 0.065)
            let tailN     = n - tailStart
            let attackN   = Int(Double(sr) * 0.012)
            let glowFreqs: [Double] = [587.33, 739.99]   // D5 F#5
            for freq in glowFreqs {
                for j in 0..<tailN {
                    let gi = tailStart + j; guard gi < n else { break }
                    let t      = Double(j) / Double(sr)
                    let tN     = Double(j) / Double(tailN)
                    let attack = min(1.0, Double(j) / Double(attackN))
                    let env    = attack * exp(-8.0 * tN)
                    out[gi] += Float(sin(2 * .pi * freq * t) * env * 0.19)
                }
            }
        }

        return out
    }

    // MARK: - Sonic Logo generators

    /// Core "Signal Lock" sonic logo — shared by full (~1.4 s) and subtle (35 % amp) variants.
    ///
    /// Structure:
    ///   Arc 1  (0.00–0.18 s): D3→A3 chirp  — "signal sent"
    ///   Arc 2  (0.18–0.36 s): D4→A4 chirp  — "path laid"
    ///   Bell   (0.36–0.65 s): D5 bell ping  — "signal arrived"
    ///   Bloom  (0.45–1.40 s): D-major 6-voice chord spreading outward — "circuit complete"
    ///
    /// Output is peak-normalized to 0.72, then scaled by `amp` (so subtle = 0.72 × 0.35 = 0.25).
    nonisolated private static func sonicLogoBase(amp: Double) -> [Float] {
        let dur = 1.40
        let n   = Int(Double(sr) * dur)
        var out = [Float](repeating: 0, count: n)

        // ── Arc 1: D3 (147 Hz) → A3 (220 Hz), 0.00–0.18 s ─────────────────
        do {
            let arcN = Int(Double(sr) * 0.180)
            let logF0 = log(146.83), logRatio = log(220.00 / 146.83)
            var ph = 0.0
            for i in 0..<arcN {
                let t  = Double(i) / Double(sr)
                let tN = Double(i) / Double(arcN)
                let env  = exp(-22.0 * t)
                let freq = exp(logF0 + logRatio * tN)
                ph += 2 * .pi * freq / Double(sr)
                out[i] += Float((sin(ph) * 0.85 + sin(ph * 2) * 0.15) * env * 0.56)
            }
        }

        // ── Arc 2: D4 (294 Hz) → A4 (440 Hz), 0.185–0.365 s ───────────────
        do {
            let startN = Int(Double(sr) * 0.185)
            let arcN   = Int(Double(sr) * 0.180)
            let logF0 = log(293.66), logRatio = log(440.00 / 293.66)
            var ph = 0.0
            for i in 0..<arcN {
                let gi = startN + i; guard gi < n else { break }
                let t  = Double(i) / Double(sr)
                let tN = Double(i) / Double(arcN)
                let env  = exp(-22.0 * t)
                let freq = exp(logF0 + logRatio * tN)
                ph += 2 * .pi * freq / Double(sr)
                out[gi] += Float((sin(ph) * 0.85 + sin(ph * 2) * 0.15) * env * 0.56)
            }
        }

        // ── Bell arrival: D5 (587 Hz), 0.365–0.655 s ────────────────────────
        do {
            let startN = Int(Double(sr) * 0.365)
            let bellN  = Int(Double(sr) * 0.290)
            let bellPartials: [(Double, Double, Double)] = [
                (1.000, 0.50, 1.0), (2.000, 0.22, 1.8),
                (3.011, 0.12, 3.0), (4.166, 0.06, 5.0)
            ]
            let baseDecay = 6.8 / 0.290
            for j in 0..<bellN {
                let gi = startN + j; guard gi < n else { break }
                let t = Double(j) / Double(sr)
                var v = 0.0
                for (ratio, weight, dk) in bellPartials {
                    v += sin(2 * .pi * 587.33 * ratio * t) * weight * exp(-baseDecay * dk * t)
                }
                out[gi] += Float(v * 0.52)
            }
        }

        // ── Chord bloom: D3 A3 D4 F#4 A4 D5 — staggered 28 ms, 0.45–1.40 s ─
        do {
            let bloomFreqs: [Double] = [146.83, 220.00, 293.66, 369.99, 440.00, 587.33]
            let bloomPartials: [(Double, Double, Double)] = [
                (1.000, 0.44, 1.0), (2.000, 0.20, 1.8), (3.011, 0.08, 3.2)
            ]
            for (fi, freq) in bloomFreqs.enumerated() {
                let vStartT = 0.450 + 0.028 * Double(fi)
                let vStart  = Int(Double(sr) * vStartT)
                let remDur  = dur - vStartT
                let vN      = Int(Double(sr) * remDur)
                let attackN = Int(Double(sr) * 0.022)
                for j in 0..<vN {
                    let gi = vStart + j; guard gi < n else { break }
                    let t      = Double(j) / Double(sr)
                    let tN     = Double(j) / Double(vN)
                    let attack = min(1.0, Double(j) / Double(attackN))
                    var v = 0.0
                    for (ratio, weight, dk) in bloomPartials {
                        v += sin(2 * .pi * freq * ratio * t) * weight * exp(-3.0 * dk * tN)
                    }
                    out[gi] += Float(v * attack * 0.28)
                }
            }
        }

        // ── Peak-normalize to 0.72, then scale by amp ────────────────────────
        let peak = out.map(abs).max() ?? 1
        if peak > 0.001 {
            let scale = Float(0.72 * amp / Double(peak))
            for i in out.indices { out[i] *= scale }
        }
        return out
    }

    /// Sonic logo — short variant (~0.5 s).
    /// Quick D4→D5 chirp followed by a 3-voice D-major bloom (D4 F#4 D5).
    nonisolated private static func sonicLogoShort() -> [Float] {
        let dur = 0.50
        let n   = Int(Double(sr) * dur)
        var out = [Float](repeating: 0, count: n)

        // Quick D4→D5 chirp (0–70 ms)
        do {
            let chirpN = Int(Double(sr) * 0.070)
            let logF0 = log(293.66), logRatio = log(587.33 / 293.66)
            var ph = 0.0
            for i in 0..<chirpN {
                let t  = Double(i) / Double(sr)
                let tN = Double(i) / Double(chirpN)
                let env  = exp(-38.0 * t)
                let freq = exp(logF0 + logRatio * tN)
                ph += 2 * .pi * freq / Double(sr)
                out[i] += Float((sin(ph) * 0.85 + sin(ph * 2) * 0.15) * env * 0.60)
            }
        }

        // D-major 3-voice bloom: D4 F#4 D5 — staggered 25 ms (55 ms–500 ms)
        do {
            let bloomFreqs: [Double] = [293.66, 369.99, 587.33]
            let bloomPartials: [(Double, Double, Double)] = [
                (1.000, 0.46, 1.0), (2.000, 0.22, 1.8), (3.011, 0.10, 3.0)
            ]
            for (fi, freq) in bloomFreqs.enumerated() {
                let vStartT = 0.055 + 0.025 * Double(fi)
                let vStart  = Int(Double(sr) * vStartT)
                let remDur  = dur - vStartT
                let vN      = Int(Double(sr) * remDur)
                let baseDecay = 6.5 / remDur
                let attackN   = Int(Double(sr) * 0.018)
                for j in 0..<vN {
                    let gi = vStart + j; guard gi < n else { break }
                    let t      = Double(j) / Double(sr)
                    let attack = min(1.0, Double(j) / Double(attackN))
                    var v = 0.0
                    for (ratio, weight, dk) in bloomPartials {
                        v += sin(2 * .pi * freq * ratio * t) * weight * exp(-baseDecay * dk * t)
                    }
                    out[gi] += Float(v * attack * 0.34)
                }
            }
        }

        // Peak-normalize to 0.72
        let peak = out.map(abs).max() ?? 1
        if peak > 0.001 {
            let scale = Float(0.72 / Double(peak))
            for i in out.indices { out[i] *= scale }
        }
        return out
    }

    // MARK: - WAV packaging

    /// Wraps float32 PCM samples into a 16-bit signed PCM WAV file (universally
    /// supported by AVAudioPlayer on all iOS versions).
    /// channels=1 → mono, channels=2 → interleaved stereo.
    nonisolated private static func wavData(samples: [Float], channels: Int) -> Data {
        let bytesPerSample = 2                       // 16-bit
        let byteRate   = UInt32(sr * channels * bytesPerSample)
        let blockAlign = UInt16(channels * bytesPerSample)
        let pcm        = samples.map { Int16(clamping: Int(($0 * 32767).rounded())) }
        let dataSize   = UInt32(pcm.count * bytesPerSample)
        let fmtSize: UInt32 = 16                     // standard PCM fmt chunk
        let riffSize: UInt32 = 4 + (8 + fmtSize) + (8 + dataSize)

        var d = Data()
        d.reserveCapacity(Int(riffSize) + 8)

        func le<T: FixedWidthInteger>(_ v: T) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
        }

        d += "RIFF".utf8; le(riffSize); d += "WAVE".utf8
        d += "fmt ".utf8; le(fmtSize)
        le(UInt16(1))            // PCM
        le(UInt16(channels))
        le(UInt32(sr))
        le(byteRate)
        le(blockAlign)
        le(UInt16(16))           // bits per sample
        d += "data".utf8; le(dataSize)
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }

        return d
    }
}
