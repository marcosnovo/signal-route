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
    }

    // MARK: Persistent settings

    static var sfxEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "sfxEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sfxEnabled") }
    }
    static var musicEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "musicEnabled")
            if newValue { musicPlayer?.play() } else { musicPlayer?.pause() }
        }
    }

    // MARK: Private state (main thread only)

    nonisolated private static let sr = 44100
    private static var pools:    [SFX: [AVAudioPlayer]] = [:]
    private static var poolIdx:  [SFX: Int]             = [:]
    private static var musicPlayer: AVAudioPlayer?

    // MARK: - Public API

    /// Call once at app launch from an async context.
    /// All heavy work (PCM synthesis + AVAudioPlayer creation) runs on a background thread
    /// so the main thread is never blocked. Only the final pool assignment and music start
    /// happen on the caller's actor context, and those are trivially fast.
    static func prepare() async {
        configureSession()

        // Synthesise PCM, pack WAV, and build the player pool entirely off the main actor.
        // Priority: .userInitiated — needs to complete before the player opens the first level.
        typealias PoolResult = ([SFX: [AVAudioPlayer]], AVAudioPlayer?)
        let (readyPools, readyDrone): PoolResult =
            await Task.detached(priority: .userInitiated) {
                let sfxDataList = SFX.allCases.map { wavData(samples: synthesizeMono($0), channels: 1) }
                let droneData   = wavData(samples: synthesizeDroneInterleaved(), channels: 2)

                // Create and prepareToPlay on the background thread — safe for AVAudioPlayer.
                var pools: [SFX: [AVAudioPlayer]] = [:]
                for (sfx, data) in zip(SFX.allCases, sfxDataList) {
                    pools[sfx] = (0..<3).compactMap { _ in
                        guard let p = try? AVAudioPlayer(data: data, fileTypeHint: nil) else { return nil }
                        p.volume = 1.0
                        p.prepareToPlay()
                        return p
                    }
                }

                let drone = try? AVAudioPlayer(data: droneData, fileTypeHint: nil)
                drone?.numberOfLoops = -1
                drone?.volume        = 0.15
                drone?.prepareToPlay()

                return (pools, drone)
            }.value

        // Back on caller's actor: only trivially-fast assignments + music start.
        pools = readyPools
        musicPlayer = readyDrone
        if musicEnabled { musicPlayer?.play() }
    }

    /// Play a synthesised sound effect. Safe to call from @MainActor.
    static func play(_ sfx: SFX) {
        guard sfxEnabled, let pool = pools[sfx], !pool.isEmpty else { return }
        let i = poolIdx[sfx, default: 0]
        poolIdx[sfx] = (i + 1) % pool.count
        pool[i].currentTime = 0
        pool[i].play()
    }

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
        case .tileRotate:     return laser(f0: 2000, f1: 900,  dur: 0.042, decay: 52)
        // Dissonant dual-tone thunk — blocked / rejected
        case .tileLocked:     return glitchBuzz(freq: 155, dur: 0.11)
        // Rising signal lock — energy flowing into relay
        case .relayEnergized: return energySweep(f0: 340, f1: 780, dur: 0.17)
        // Metallic network-ping — connection established
        case .targetOnline:   return chime(freq: 1320, dur: 0.30, amp: 0.62)
        // 4-note rising chime arpeggio — premium mission-complete
        case .win:            return missionComplete()
        // Exponential power-down with detuning drift — failure
        case .lose:           return powerDown(f0: 540, f1: 85, dur: 0.44)
        // Tiny upward laser blip — auto-drift tick
        case .drift:          return laser(f0: 1500, f1: 2400, dur: 0.026, decay: 95)
        // Rising vibrato charge — overload armed warning
        case .overloadArm:    return warningCharge(f0: 255, f1: 680, dur: 0.13)
        // Ultra-sharp clean tick — timer countdown
        case .timerTick:      return digitalTick()
        // 3-note warm chime sequence — discovery / mechanic unlock
        case .mechanicUnlock: return discoveryJingle()
        // Bass thud + four-voice rising chord — sector clearance granted
        case .sectorComplete: return accessGranted()
        }
    }

    // MARK: - Generators (called from background thread — pure computation, no shared state)

    /// Exponential frequency chirp — the core "laser" primitive.
    /// Frequency moves in log space from f0→f1 with a sharp exponential decay.
    nonisolated private static func laser(f0: Double, f1: Double, dur: Double, decay: Double = 30.0) -> [Float] {
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
            return Float((sin(phase) * 0.85 + sin(phase * 2) * 0.15) * env * 0.62)
        }
    }

    /// Dissonant dual-tone buzz — rejected / blocked feedback.
    /// Two voices ~91 cents apart create an audible beating pattern.
    nonisolated private static func glitchBuzz(freq: Double, dur: Double) -> [Float] {
        let n      = Int(Double(sr) * dur)
        let detune = freq * 1.055
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let env = exp(-11 * t)
            let v   = sin(2 * .pi * freq      * t) * 0.50
                    + sin(2 * .pi * detune     * t) * 0.35
                    + sin(2 * .pi * freq * 3.0 * t) * 0.15
            return Float(v * env * 0.55)
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
            return Float((sin(ph1) * 0.70 + sin(ph2) * 0.30) * env * 0.55)
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
            return Float((sin(ph1) * 0.60 + sin(ph2) * 0.40) * env * 0.55)
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
            return Float(sin(phase) * env * 0.55)
        }
    }

    /// Ultra-short, very clean digital tick — precise like a system clock.
    nonisolated private static func digitalTick() -> [Float] {
        let dur  = 0.018
        let n    = Int(Double(sr) * dur)
        let freq = 3400.0
        return (0..<n).map { i in
            let t   = Double(i) / Double(sr)
            let env = exp(-200.0 * t)
            return Float(sin(2 * .pi * freq * t) * env * 0.68)
        }
    }

    /// 4-note chime arpeggio — mission complete (A5 D6 E6 A6 pentatonic).
    nonisolated private static func missionComplete() -> [Float] {
        let freqs: [Double] = [880, 1175, 1319, 1760]
        let step    = 0.075
        let noteDur = 0.32
        let total   = step * Double(freqs.count) + noteDur
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
        return out
    }

    /// 3-note warm chime sequence — discovery / mechanic unlock (C5 E5 G5 major).
    nonisolated private static func discoveryJingle() -> [Float] {
        let freqs: [Double] = [523.25, 659.25, 783.99]
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
        return out
    }

    /// Deep bass thud followed by a four-voice arpeggiated chord — space-station access granted.
    /// Total ~1.5 s: sub-bass transient (0–0.22 s) then D-major arpeggio (0.15–1.5 s).
    nonisolated private static func accessGranted() -> [Float] {
        let total = 1.5
        let n     = Int(Double(sr) * total)
        var out   = [Float](repeating: 0, count: n)

        // Phase 1: sub-bass confirmation thud (88 Hz, fast exponential decay)
        let thudN = Int(Double(sr) * 0.22)
        for i in 0..<thudN {
            let t = Double(i) / Double(sr)
            out[i] += Float(sin(2 * .pi * 88.0 * t) * exp(-10.0 * t) * 0.72)
        }

        // Phase 2: D-major four-note arpeggio — D4 A4 D5 F#5, staggered 65 ms apart
        let chordFreqs: [Double] = [293.66, 440.00, 587.33, 739.99]
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

    // MARK: - Ambient drone (interleaved stereo)

    nonisolated private static func synthesizeDroneInterleaved() -> [Float] {
        // 12 s loop — long enough that the repeat is never obvious
        let seconds = 12.0
        let n       = Int(Double(sr) * seconds)

        // Bass partials: (frequency, amplitude, stereo-detuning in Hz)
        // A1 stack with E2 minor-seventh tension + a 240 Hz mid presence
        let partials: [(f: Double, a: Double, d: Double)] = [
            (55.00,  0.36, 0.00),
            (82.41,  0.20, 0.20),   // E2 — minor-seventh tension
            (110.00, 0.17, 0.12),
            (164.81, 0.09, 0.30),
            (220.00, 0.05, 0.08),
            (240.00, 0.03, 0.14),   // mid shimmer — adds air above the bass
        ]

        // Slow LFO (~13 s cycle) — volume breathes very gently
        let lfoHz  = 0.077
        // Second, faster LFO modulates only the high partial for an electrical flutter
        let lfo2Hz = 0.31

        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        for i in 0..<n {
            let t    = Double(i) / Double(sr)
            let lfoL = 0.82 + 0.18 * sin(2 * .pi * lfoHz * t)
            let lfoR = 0.82 + 0.18 * sin(2 * .pi * lfoHz * t + 1.57)  // 90° offset — wide stereo breath
            var vL = 0.0, vR = 0.0
            for p in partials {
                vL += sin(2 * .pi * (p.f + p.d)        * t) * p.a
                vR += sin(2 * .pi * (p.f - p.d * 0.60) * t) * p.a
            }
            // Faint high-frequency electrical shimmer (3.5 kHz) — barely audible, adds texture
            let shimmer = sin(2 * .pi * 3500.0 * t) * 0.006
                        * (0.5 + 0.5 * sin(2 * .pi * lfo2Hz * t))
            L[i] = Float((vL * lfoL + shimmer) * 0.28)
            R[i] = Float((vR * lfoR - shimmer) * 0.28)  // shimmer panned opposite for width
        }

        // 1.2 s fade at each end for seamless looping
        let fade = Int(Double(sr) * 1.2)
        for i in 0..<fade {
            let f = Float(i) / Float(fade)
            L[i] *= f;     R[i] *= f
            L[n-1-i] *= f; R[n-1-i] *= f
        }

        // Interleave: L0 R0 L1 R1 …
        var out = [Float](repeating: 0, count: n * 2)
        for i in 0..<n { out[i*2] = L[i]; out[i*2+1] = R[i] }
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
