import Foundation

// MARK: - MusicSynthesizer
/// Synthesises all background music tracks from raw PCM data.
/// All methods are pure computation — safe to call from background threads.
/// Sample rate 22050 Hz (half of SFX) keeps memory around 4 MB total for all 5 tracks.
enum MusicSynthesizer {

    nonisolated static let sr = 22050

    // MARK: - Build all tracks

    static func buildAll() -> [AudioState: Data] {
        [
            .homeIdle:  homeIdle(),
            .inMission: missionActive(),
            .victory:   victory(),
            .story:     story(),
            // .paywall removed — state maps to .cooldown (silence) since Fase 11
        ]
    }

    // MARK: - home_idle  (16 s stereo loop)
    //
    // Soft A-minor pentatonic pad stack: A1·A2·E3·A3
    // Very slow breath LFO (~18 s cycle) — background presence only.

    nonisolated static func homeIdle() -> Data {
        let n = sampleCount(seconds: 16)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        let voices: [(fL: Double, fR: Double, amp: Double)] = [
            (55.00,  55.03,  0.30),
            (110.00, 110.05, 0.40),
            (164.81, 164.88, 0.30),
            (220.00, 220.09, 0.20),
        ]
        let lfoHz = 0.055    // ~18 s cycle

        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            let lfo = 0.78 + 0.22 * sin(2 * .pi * lfoHz * t)
            var vL  = 0.0, vR = 0.0
            for v in voices {
                vL += sin(2 * .pi * v.fL * t) * v.amp
                vR += sin(2 * .pi * v.fR * t) * v.amp
            }
            L[i] = Float(vL * lfo)
            R[i] = Float(vR * lfo)
        }

        normalize(&L, &R)
        fadeBothEnds(&L, &R, fadeSamples: sampleCount(seconds: 2.0))
        return wavData(L: L, R: R)
    }

    // MARK: - mission_active  (8 s stereo loop)
    //
    // D-Dorian tension pad (D3·G3·A3·D4) with slow LFO pulse.
    // 120 BPM soft electronic tick adds rhythmic drive without melody.

    nonisolated static func missionActive() -> Data {
        let n = sampleCount(seconds: 8)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        let pad: [(fL: Double, fR: Double, amp: Double)] = [
            (146.83, 146.89, 0.35),
            (196.00, 196.07, 0.28),
            (220.00, 220.08, 0.22),
            (293.66, 293.74, 0.15),
        ]
        let lfoHz = 0.14    // slight tension pulse

        // Pad layer
        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            let lfo = 0.72 + 0.28 * sin(2 * .pi * lfoHz * t)
            var vL  = 0.0, vR = 0.0
            for p in pad {
                vL += sin(2 * .pi * p.fL * t) * p.amp
                vR += sin(2 * .pi * p.fR * t) * p.amp
            }
            L[i] = Float(vL * lfo)
            R[i] = Float(vR * lfo)
        }

        // Rhythmic tick layer — 120 BPM quarter notes, centered in stereo
        let beatSamples = Int(Double(sr) * 60.0 / 120.0)   // 0.5 s
        let clickN      = sampleCount(seconds: 0.040)
        var beat        = 0
        while beat < n {
            for j in 0..<min(clickN, n - beat) {
                let t   = Double(j) / Double(sr)
                let env = exp(-80.0 * t)
                let s   = Float(sin(2 * .pi * 280.0 * t) * env * 0.55)
                L[beat + j] += s
                R[beat + j] += s
            }
            beat += beatSamples
        }

        normalize(&L, &R)
        fadeBothEnds(&L, &R, fadeSamples: sampleCount(seconds: 0.4))
        return wavData(L: L, R: R)
    }

    // MARK: - victory  (3 s, non-looping)
    //
    // D-major warm sustain: D4·F#4·A4·D5
    // Soft 2nd harmonic for warmth. 180 ms attack, 30 % release tail.

    nonisolated static func victory() -> Data {
        let n = sampleCount(seconds: 3)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        let chord: [(fL: Double, fR: Double, amp: Double)] = [
            (293.66, 294.00, 0.30),
            (369.99, 370.40, 0.25),
            (440.00, 440.55, 0.22),
            (587.33, 587.90, 0.18),
        ]

        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            let tN  = Double(i) / Double(n)
            let att = min(1.0, t / 0.18)
            let rel = tN > 0.70 ? 1.0 - (tN - 0.70) / 0.30 : 1.0
            let env = att * rel
            var vL  = 0.0, vR = 0.0
            for c in chord {
                vL += (sin(2 * .pi * c.fL * t) + sin(2 * .pi * c.fL * 2 * t) * 0.18) * c.amp
                vR += (sin(2 * .pi * c.fR * t) + sin(2 * .pi * c.fR * 2 * t) * 0.18) * c.amp
            }
            L[i] = Float(vL * env)
            R[i] = Float(vR * env)
        }

        normalize(&L, &R)
        return wavData(L: L, R: R)   // no loop fade needed — envelope handles it
    }

    // MARK: - story  (12 s stereo loop)
    //
    // Deep cinematic sub stack: A0·A1·E2·A2
    // High shimmer (2100 Hz) modulated by a second slow LFO — spacious, no rhythm.

    nonisolated static func story() -> Data {
        let n = sampleCount(seconds: 12)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        let bass: [(fL: Double, fR: Double, amp: Double)] = [
            (27.50,  27.52,  0.20),
            (55.00,  55.04,  0.38),
            (82.41,  82.47,  0.22),
            (110.00, 110.07, 0.15),
        ]
        let shimmer = 2100.0
        let lfo1Hz  = 0.040   // ~25 s breath
        let lfo2Hz  = 0.071   // shimmer flutter

        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            let lo1 = 0.68 + 0.32 * sin(2 * .pi * lfo1Hz * t)
            let lo2 = 0.50 + 0.50 * sin(2 * .pi * lfo2Hz * t + 1.1)
            var vL  = 0.0, vR = 0.0
            for b in bass {
                vL += sin(2 * .pi * b.fL * t) * b.amp
                vR += sin(2 * .pi * b.fR * t) * b.amp
            }
            let shL = sin(2 * .pi * shimmer       * t) * 0.06 * lo2
            let shR = sin(2 * .pi * (shimmer + 5) * t) * 0.06 * lo2
            L[i] = Float(vL * lo1 + shL)
            R[i] = Float(vR * lo1 + shR)
        }

        normalize(&L, &R)
        fadeBothEnds(&L, &R, fadeSamples: sampleCount(seconds: 1.6))
        return wavData(L: L, R: R)
    }

    // MARK: - paywall  (8 s stereo loop)
    //
    // B2·C3 minor 2nd creates audible beating tension (~7.3 Hz flutter).
    // F#2·F#3 tritone underneath deepens the unease.
    // Slow one-sided LFO pulse (0.17 Hz) — "important decision" feel.

    nonisolated static func paywall() -> Data {
        let n = sampleCount(seconds: 8)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        let voices: [(fL: Double, fR: Double, amp: Double)] = [
            (92.50,  92.54,  0.20),   // F#2 — tritone
            (123.47, 123.52, 0.38),   // B2  — root
            (130.81, 130.87, 0.30),   // C3  — minor 2nd → beating
            (185.00, 185.07, 0.18),   // F#3 — upper tritone
        ]
        let lfoHz = 0.17

        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            // One-sided sine pulse: 0.65 … 1.0
            let lfo = 0.65 + 0.35 * (0.5 + 0.5 * sin(2 * .pi * lfoHz * t - .pi / 2))
            var vL  = 0.0, vR = 0.0
            for v in voices {
                vL += sin(2 * .pi * v.fL * t) * v.amp
                vR += sin(2 * .pi * v.fR * t) * v.amp
            }
            L[i] = Float(vL * lfo)
            R[i] = Float(vR * lfo)
        }

        normalize(&L, &R)
        fadeBothEnds(&L, &R, fadeSamples: sampleCount(seconds: 0.6))
        return wavData(L: L, R: R)
    }

    // MARK: - Private helpers

    nonisolated private static func sampleCount(seconds: Double) -> Int {
        Int(Double(sr) * seconds)
    }

    /// Peak-normalise both channels to `target` amplitude.
    nonisolated private static func normalize(_ L: inout [Float], _ R: inout [Float],
                                              target: Float = 0.85) {
        var peak: Float = 0
        for i in 0..<L.count { peak = max(peak, abs(L[i]), abs(R[i])) }
        guard peak > 0 else { return }
        let scale = target / peak
        for i in 0..<L.count { L[i] *= scale; R[i] *= scale }
    }

    /// Apply a linear fade at both ends of the buffer for seamless looping.
    nonisolated private static func fadeBothEnds(_ L: inout [Float], _ R: inout [Float],
                                                 fadeSamples: Int) {
        let n = L.count
        let f = min(fadeSamples, n / 2)
        for i in 0..<f {
            let g = Float(i) / Float(f)
            L[i] *= g;         R[i] *= g
            L[n-1-i] *= g;     R[n-1-i] *= g
        }
    }

    /// Interleave two mono channels and pack as 16-bit PCM WAV at `sr`.
    nonisolated private static func wavData(L: [Float], R: [Float]) -> Data {
        var interleaved = [Float](repeating: 0, count: L.count * 2)
        for i in 0..<L.count { interleaved[i*2] = L[i]; interleaved[i*2+1] = R[i] }
        return packWAV(samples: interleaved, channels: 2, sampleRate: sr)
    }

    nonisolated private static func packWAV(samples: [Float], channels: Int, sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let byteRate       = UInt32(sampleRate * channels * bytesPerSample)
        let blockAlign     = UInt16(channels * bytesPerSample)
        let pcm            = samples.map { Int16(clamping: Int(($0 * 32767).rounded())) }
        let dataSize       = UInt32(pcm.count * bytesPerSample)
        let fmtSize: UInt32 = 16
        let riffSize: UInt32 = 4 + (8 + fmtSize) + (8 + dataSize)

        var d = Data()
        d.reserveCapacity(Int(riffSize) + 8)

        func le<T: FixedWidthInteger>(_ v: T) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
        }

        d += "RIFF".utf8; le(riffSize); d += "WAVE".utf8
        d += "fmt ".utf8; le(fmtSize)
        le(UInt16(1)); le(UInt16(channels)); le(UInt32(sampleRate))
        le(byteRate); le(blockAlign); le(UInt16(16))
        d += "data".utf8; le(dataSize)
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }
}
