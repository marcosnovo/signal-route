import Foundation

// MARK: - MusicSynthesizer
/// Synthesises all background music tracks from raw PCM data.
/// All methods are pure computation — safe to call from background threads.
/// Sample rate 22050 Hz keeps memory around 4 MB total for all 4 tracks.
///
/// Design: Interstellar-inspired cinematic organ/pad synthesis.
///   • Drawbar organ: 8' (fundamental) + 16' (×0.5 sub) + 4' (×2 upper) harmonics
///   • Stereo width: L/R detuning ±0.01–0.02% → beating period >50 s (imperceptible)
///   • Breath LFO: very slow sinusoidal AM, depth 6–8% — large acoustic space feel
enum MusicSynthesizer {

    nonisolated static let sr = 22050

    // MARK: - Build all tracks

    /// Builds synthesized tracks for states that don't have bundled audio.
    /// homeIdle is loaded from `home_ambient.m4a` by AudioManager — no need to synthesize it.
    static func buildAll() -> [AudioState: Data] {
        [
            .inMission: missionActive(),
            .victory:   victory(),
            .story:     story(),
        ]
    }

    // MARK: - mission_active  (10 s stereo loop)
    //
    // A-minor drawbar organ: A2·E3·A3·C4
    // 60 BPM sub-bass heartbeat (A1, 55 Hz) — focused tension, not aggressive.
    // Slow 10 s LFO for subtle intensity variation.

    nonisolated static func missionActive() -> Data {
        let n = sampleCount(seconds: 10)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        // A natural minor drawbar pad
        let pad: [(fL: Double, fR: Double, amp: Double, d16: Double)] = [
            (109.989, 110.011, 0.44, 0.40),   // A2 root
            (164.797, 164.823, 0.32, 0.28),   // E3 fifth
            (219.978, 220.022, 0.26, 0.20),   // A3 upper
            (261.620, 261.640, 0.18, 0.14),   // C4 minor third
        ]
        let lfoHz   = 0.10    // 10 s slow tension pulse
        let lfoBase = 0.82    // range: 0.82–1.00 (subtle)

        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            let lfo = lfoBase + (1.0 - lfoBase) * (0.5 + 0.5 * sin(2 * .pi * lfoHz * t))
            var vL  = 0.0, vR = 0.0
            for p in pad {
                vL += (sin(2 * .pi * p.fL * t)
                     + sin(2 * .pi * p.fL * 0.5 * t) * p.d16) * p.amp
                vR += (sin(2 * .pi * p.fR * t)
                     + sin(2 * .pi * p.fR * 0.5 * t) * p.d16) * p.amp
            }
            L[i] = Float(vL * lfo)
            R[i] = Float(vR * lfo)
        }

        // 60 BPM sub-bass heartbeat — soft A1 (55 Hz) thud, 120 ms, exp(-18) decay
        let beatSamples = Int(Double(sr) * 1.0)   // 60 BPM = 1.0 s per beat
        let thumN       = sampleCount(seconds: 0.120)
        var beat        = 0
        while beat < n {
            for j in 0..<min(thumN, n - beat) {
                let t = Double(j) / Double(sr)
                let s = Float(sin(2 * .pi * 55.0 * t) * exp(-18.0 * t) * 0.60)
                L[beat + j] += s
                R[beat + j] += s
            }
            beat += beatSamples
        }

        normalize(&L, &R)
        fadeBothEnds(&L, &R, fadeSamples: sampleCount(seconds: 0.6))
        return wavData(L: L, R: R)
    }

    // MARK: - victory  (3 s, non-looping)
    //
    // A-major chord bloom: A2·E3·A3·C#4 with staggered entry.
    // Bass enters first; each subsequent voice follows 180 ms later.
    // 200 ms per-voice attack; global release tail starts at 65%.

    nonisolated static func victory() -> Data {
        let n = sampleCount(seconds: 3)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        // Staggered bloom: bass → fifth → octave → major third
        let entries: [(fL: Double, fR: Double, amp: Double, startT: Double)] = [
            (109.989, 110.011, 0.40, 0.00),   // A2 — first
            (164.797, 164.823, 0.33, 0.18),   // E3 — second
            (219.978, 220.022, 0.28, 0.36),   // A3 — third
            (277.167, 277.213, 0.22, 0.55),   // C#4 — fourth
        ]
        let attackTime = 0.20   // 200 ms per-voice attack

        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            let tN  = Double(i) / Double(n)
            let rel = tN > 0.65 ? max(0.0, 1.0 - (tN - 0.65) / 0.35) : 1.0
            var vL  = 0.0, vR = 0.0
            for e in entries {
                guard t >= e.startT else { continue }
                let elapsed = t - e.startT
                let att = min(1.0, elapsed / attackTime)
                // 8' fundamental + gentle 4' upper partial for warmth
                vL += (sin(2 * .pi * e.fL * t) + sin(2 * .pi * e.fL * 2.0 * t) * 0.18)
                     * e.amp * att * rel
                vR += (sin(2 * .pi * e.fR * t) + sin(2 * .pi * e.fR * 2.0 * t) * 0.18)
                     * e.amp * att * rel
            }
            L[i] = Float(vL)
            R[i] = Float(vR)
        }

        normalize(&L, &R)
        return wavData(L: L, R: R)   // no loop fade — envelope handles it
    }

    // MARK: - story  (16 s stereo loop)
    //
    // G·D open fifth: G1·G2·D3·G3 — no thirds, maximum openness.
    // Cinematic and minimal — pure fifths only, vast resonant space feel.
    // 32 s breath LFO (6% depth). Soft D5 shimmer at 587 Hz.

    nonisolated static func story() -> Data {
        let n = sampleCount(seconds: 16)
        var L = [Float](repeating: 0, count: n)
        var R = [Float](repeating: 0, count: n)

        // G·D open fifth — pure fifth intervals only, no thirds
        let bass: [(fL: Double, fR: Double, amp: Double)] = [
            (48.999,  49.008,  0.24),   // G1 sub-bass — deep foundation
            (97.999,  98.013,  0.42),   // G2 root
            (146.832, 146.848, 0.28),   // D3 perfect fifth
            (195.997, 196.020, 0.16),   // G3 upper
        ]
        let shimmerF = 587.33   // D5 — harmonic echo of the fifth, two octaves up
        let lfoHz    = 1.0 / 32.0   // 32 s breath — barely perceptible
        let lfoDepth = 0.06          // 6% AM depth

        for i in 0..<n {
            let t   = Double(i) / Double(sr)
            let lfo = 1.0 - lfoDepth + lfoDepth * (0.5 + 0.5 * sin(2 * .pi * lfoHz * t - .pi / 2))
            var vL  = 0.0, vR = 0.0
            for b in bass {
                vL += sin(2 * .pi * b.fL * t) * b.amp
                vR += sin(2 * .pi * b.fR * t) * b.amp
            }
            // D5 shimmer — L/R detuned ±2.5 Hz for natural stereo width
            vL += sin(2 * .pi * (shimmerF - 2.5) * t) * 0.04
            vR += sin(2 * .pi * (shimmerF + 2.5) * t) * 0.04
            L[i] = Float(vL * lfo)
            R[i] = Float(vR * lfo)
        }

        normalize(&L, &R)
        fadeBothEnds(&L, &R, fadeSamples: sampleCount(seconds: 2.5))
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
