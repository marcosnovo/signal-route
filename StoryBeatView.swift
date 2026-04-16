import SwiftUI

// MARK: - StoryBeatView
/// Compact floating-card overlay for lightweight narrative beats
/// (mechanic unlocks, first-win confirmation, etc.).
///
/// For high-impact narrative moments with images use `StoryModal` instead.
struct StoryBeatView: View {

    let beat:      StoryBeat
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    @State private var appeared  = false
    @State private var dismissed = false

    // Resolved accent colour (beat-specific or fallback to accentPrimary)
    private var accentColor: Color {
        beat.accentHex.flatMap { Color(hex: $0) } ?? AppTheme.accentPrimary
    }

    var body: some View {
        ZStack {
            // ── Backdrop ──────────────────────────────────────────────
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture {
                    if beat.isSkippable { dismiss() }
                }

            // ── Subtle ambient glow ───────────────────────────────────
            RadialGradient(
                gradient: Gradient(colors: [accentColor.opacity(0.08), .clear]),
                center: .center,
                startRadius: 40,
                endRadius: 260
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Card ──────────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Optional image banner
                    if let name = beat.imageName, let uiImage = UIImage(named: name)?.normalizedForDisplay {
                        imageBanner(uiImage, accent: accentColor)
                    }
                    transmissionHeader
                    beatContent
                    acknowledgeButton
                }
                .background(
                    ZStack {
                        AppTheme.backgroundSecondary
                        accentColor.opacity(0.03)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(accentColor.opacity(0.30), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 22)
                .scaleEffect(appeared ? 1.0 : 0.95)

                Spacer()
            }
        }
        // Opacity at ZStack level so backdrop + glow + card all fade together on dismiss.
        // Prevents the backdrop staying visible after the card animates out.
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                appeared = true
            }
        }
    }

    // MARK: - Sub-views

    /// Full-width image banner with bottom gradient fade into the card background.
    @ViewBuilder
    private func imageBanner(_ uiImage: UIImage, accent: Color) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .clipped()

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: AppTheme.backgroundSecondary.opacity(0.55), location: 0.78),
                    .init(color: AppTheme.backgroundSecondary, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Transmission origin header — styled like a comms channel indicator.
    private var transmissionHeader: some View {
        HStack(spacing: 8) {
            BlinkingDot(color: accentColor)

            Text(S.incomingTransmission)
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(accentColor.opacity(0.70))
                .kerning(1.5)

            Spacer()

            Text(beat.source)
                .font(AppTheme.mono(7, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .kerning(0.8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.06))
        .overlay(alignment: .bottom) { TechDivider() }
    }

    /// Main narrative content — trigger badge, title, body, footer hint.
    private var beatContent: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Trigger label badge
            Text(S.storyTriggerLabel(beat.trigger))
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(accentColor)
                .kerning(1.2)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(accentColor.opacity(0.30), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Title
            Text(beat.displayTitle(for: settings.language))
                .font(AppTheme.mono(24, weight: .black))
                .foregroundStyle(Color.white)
                .kerning(3)
                .fixedSize(horizontal: false, vertical: true)

            // Body
            Text(beat.displayBody(for: settings.language))
                .font(AppTheme.mono(11))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // Optional footer hint — localized via AppStrings
            if let hint = beat.footerHint {
                HStack(spacing: 5) {
                    Rectangle()
                        .fill(accentColor.opacity(0.50))
                        .frame(width: 14, height: 1)
                    Text(S.storyFooterHint(hint))
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(accentColor.opacity(0.70))
                        .kerning(1.0)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    /// "ACKNOWLEDGE" CTA — the sole interactive element.
    private var acknowledgeButton: some View {
        Button(action: dismiss) {
            HStack(spacing: 6) {
                Text(S.acknowledge)
                    .font(AppTheme.mono(10, weight: .bold))
                    .kerning(2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func dismiss() {
        guard !dismissed else { return }
        dismissed = true
        withAnimation(.easeOut(duration: 0.22)) { appeared = false }
        // Use Task + withAnimation so the structural removal of this view runs inside
        // a valid animation context — mirrors StoryModal's dismiss pattern.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeOut(duration: 0.18)) { onDismiss() }
        }
    }
}

// MARK: - StoryModal
/// Cinematic narrative modal — a tall card (~82 % screen height).
///
/// Use for high-impact story moments: sector completions, rank-ups, pass unlocks.
/// Distinct from `StoryBeatView` (compact card) — more expansive and cinematic,
/// always uses the orange brand accent regardless of the beat's `accentHex`.
///
/// ```swift
/// if let beat = storyQueue.current {
///     StoryModal(beat: beat, hasNext: storyQueue.hasNext) {
///         storyQueue.advance()
///     }
///     .transition(.opacity)
///     .zIndex(50)
/// }
/// ```
struct StoryModal: View {

    let beat:      StoryBeat
    /// When `true` the CTA reads "CONTINUE ›" — when `false`, "UNDERSTOOD ✓"
    let hasNext:   Bool
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    @State private var appeared      = false
    @State private var dismissed     = false
    @State private var textVisible   = false
    @State private var displayedBody = ""
    @State private var isTyping      = true
    @State private var typeTask: Task<Void, Never>? = nil

    // StoryModal always uses brand orange so it reads as a distinct, important event.
    private let accent = AppTheme.accentPrimary

    var body: some View {
        GeometryReader { geo in
            let cardH   = geo.size.height * 0.82
            let uiImage = beat.imageName.flatMap { UIImage(named: $0)?.normalizedForDisplay }

            ZStack {
                // ── Backdrop ──────────────────────────────────────────
                Color.black.opacity(0.88)
                    .ignoresSafeArea()
                    .onTapGesture { handleTap() }

                // ── Ambient glow ───────────────────────────────────────
                RadialGradient(
                    gradient: Gradient(colors: [accent.opacity(0.14), .clear]),
                    center: .center,
                    startRadius: 50,
                    endRadius: 320
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // ── Card ──────────────────────────────────────────────
                VStack(spacing: 0) {
                    // Thin brand-orange accent line at the top edge
                    accent.frame(height: 2)

                    if let img = uiImage {
                        AnimatedImageFrame(
                            uiImage: img,
                            height: cardH * 0.44,
                            source: beat.source,
                            accent: accent
                        )
                    } else {
                        compactHeader
                    }

                    textZone

                    TechDivider()

                    ctaButton
                }
                .frame(width: geo.size.width - 40)
                .frame(height: cardH)
                .background(
                    ZStack {
                        AppTheme.backgroundPrimary
                        accent.opacity(0.04)  // warm orange wash
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(accent.opacity(0.60), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(appeared ? 1.0 : 0.93)
                // Tap on the card itself also skips / dismisses
                .contentShape(Rectangle())
                .onTapGesture { handleTap() }
            }
        }
        // Whole-overlay opacity: backdrop + glow + card fade together.
        // Keeping this at the GeometryReader level makes it impossible for the
        // backdrop to remain visible after dismiss() runs.
        .opacity(appeared ? 1.0 : 0.0)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                appeared = true
            }
            withAnimation(.easeIn(duration: 0.32).delay(0.28)) {
                textVisible = true
            }
            // Start typewriter after the card + text fade-in settle (~440 ms)
            typeTask = Task {
                try? await Task.sleep(for: .milliseconds(440))
                await runTypewriter()
            }
        }
        .onDisappear { typeTask?.cancel() }
    }

    // MARK: - Compact header (no image)

    /// Used when the beat has no image — mirrors StoryBeatView's transmission header.
    private var compactHeader: some View {
        HStack(spacing: 8) {
            BlinkingDot(color: accent)
            Text(S.incomingTransmission)
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(accent.opacity(0.70))
                .kerning(1.5)
            Spacer()
            Text(beat.source)
                .font(AppTheme.mono(7, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .kerning(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(accent.opacity(0.06))
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: - Text zone

    private var textZone: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Trigger badge
            Text(S.storyTriggerLabel(beat.trigger))
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(accent)
                .kerning(1.5)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(accent.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(accent.opacity(0.50), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Title — appears immediately (short, punchy headline)
            Text(beat.displayTitle(for: settings.language))
                .font(AppTheme.mono(24, weight: .black))
                .foregroundStyle(.white)
                .kerning(2.5)
                .fixedSize(horizontal: false, vertical: true)

            // Body — typewriter effect.
            // Invisible spaceholder reserves layout height so the card doesn't shift.
            ZStack(alignment: .topLeading) {
                Text(beat.displayBody(for: settings.language))
                    .opacity(0)
                    .font(AppTheme.mono(11))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                Text(displayedBody)
                    .font(AppTheme.mono(11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // Footer hint — fades in once typing is complete; localized via AppStrings
            if let hint = beat.footerHint {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(accent.opacity(0.50))
                        .frame(width: 16, height: 1)
                    Text(S.storyFooterHint(hint))
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(accent.opacity(0.80))
                        .kerning(1.2)
                }
                .opacity(isTyping ? 0 : 1)
                .animation(.easeIn(duration: 0.28), value: isTyping)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .opacity(textVisible ? 1.0 : 0.0)
        .offset(y: textVisible ? 0 : 8)
    }

    // MARK: - CTA button

    /// Label adapts to language and beat context.
    /// Middle beats: CONTINUE / CONTINUAR / CONTINUER
    /// Last beat — firstMissionReady: PLAY / JUGAR / JOUER
    /// Last beat — other: UNDERSTOOD / ENTENDIDO / COMPRIS
    private var ctaLabel: String {
        if hasNext {
            switch settings.language {
            case .en: return "CONTINUE"
            case .es: return "CONTINUAR"
            case .fr: return "CONTINUER"
            }
        }
        switch beat.trigger {
        case .firstMissionReady:
            switch settings.language {
            case .en: return "PLAY"
            case .es: return "JUGAR"
            case .fr: return "JOUER"
            }
        default:
            switch settings.language {
            case .en: return "UNDERSTOOD"
            case .es: return "ENTENDIDO"
            case .fr: return "COMPRIS"
            }
        }
    }

    private var ctaIcon: String {
        if hasNext { return "chevron.right" }
        if beat.trigger == .firstMissionReady { return "play.fill" }
        return "checkmark"
    }

    private var ctaButton: some View {
        Button(action: dismiss) {
            HStack(spacing: 8) {
                Text(ctaLabel)
                    .font(AppTheme.mono(11, weight: .bold))
                    .kerning(2)
                Image(systemName: ctaIcon)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(isTyping ? Color.black.opacity(0.45) : Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isTyping ? accent.opacity(0.45) : accent)
        }
        .buttonStyle(.plain)
        .disabled(isTyping)
        .animation(.easeOut(duration: 0.22), value: isTyping)
    }

    // MARK: - Helpers

    /// Tap anywhere while typing → skip to full text; tap after typing → dismiss.
    private func handleTap() {
        if isTyping {
            completeTyping()
        } else if beat.isSkippable {
            dismiss()
        }
    }

    /// Shows the full body immediately and activates the button.
    private func completeTyping() {
        typeTask?.cancel()
        typeTask = nil
        displayedBody = beat.displayBody(for: settings.language)
        withAnimation(.easeIn(duration: 0.18)) { isTyping = false }
    }

    /// Character-by-character reveal at 28 ms per character (~36 fps).
    /// Perceptibly identical to 22 ms but reduces SwiftUI body re-evaluations by ~20%.
    @MainActor
    private func runTypewriter() async {
        let localizedBody = beat.displayBody(for: settings.language)
        displayedBody = ""
        for char in localizedBody {
            guard !Task.isCancelled else { return }
            displayedBody.append(char)
            try? await Task.sleep(for: .milliseconds(28))
        }
        guard !Task.isCancelled else { return }
        displayedBody = localizedBody       // ensure exact final string
        withAnimation(.easeIn(duration: 0.18)) { isTyping = false }
    }

    private func dismiss() {
        guard !dismissed else { return }
        dismissed = true
        typeTask?.cancel()
        withAnimation(.easeOut(duration: 0.24)) { appeared = false }
        // Use Task + withAnimation instead of DispatchQueue so the structural removal
        // of this view (when storyQueue.current becomes nil) runs inside a valid
        // animation context — preventing the backdrop from getting stuck in the hierarchy.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            withAnimation(.easeOut(duration: 0.20)) { onDismiss() }
        }
    }
}

// MARK: - AnimatedImageFrame

/// Full-bleed image banner with slow zoom + drift, scanlines, and film grain.
/// Used inside `StoryModal` for high-impact story beats that have an `imageName`.
private struct AnimatedImageFrame: View {

    let uiImage: UIImage
    let height:  CGFloat
    let source:  String
    let accent:  Color

    @State private var scale: CGFloat = 1.0
    @State private var drift: CGSize  = .zero
    @State private var grain: [(x: CGFloat, y: CGFloat, op: CGFloat)] = []

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // ── Image with slow zoom + parallax drift ──────────────────
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .scaleEffect(scale, anchor: .center)
                .offset(drift)
                .clipped()

            // ── Gradient fade into card background ─────────────────────
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear,                                   location: 0.0),
                    .init(color: AppTheme.backgroundPrimary.opacity(0.22), location: 0.60),
                    .init(color: AppTheme.backgroundPrimary,               location: 1.0),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)

            // ── Scanlines ──────────────────────────────────────────────
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                        with: .color(.black.opacity(0.09))
                    )
                    y += 4
                }
            }
            .allowsHitTesting(false)

            // ── Film grain (positions generated once on appear) ────────
            if !grain.isEmpty {
                Canvas { ctx, size in
                    for dot in grain {
                        ctx.fill(
                            Path(ellipseIn: CGRect(
                                x: dot.x * size.width,
                                y: dot.y * size.height,
                                width: 1.5, height: 1.5
                            )),
                            with: .color(.white.opacity(dot.op))
                        )
                    }
                }
                .allowsHitTesting(false)
            }

            // ── Source label (bottom-left over the faded area) ─────────
            HStack(spacing: 6) {
                BlinkingDot(color: accent)
                Text(source)
                    .font(AppTheme.mono(7, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .kerning(1.0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(height: height)
        .onAppear {
            // Slow zoom + gentle drift gives a parallax / living-photo feel
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                scale = 1.06
                drift = CGSize(width: -5, height: 3)
            }
            // Generate stable grain (computed once; Canvas doesn't re-render unless grain changes)
            grain = (0..<320).map { _ in
                (
                    x:  .random(in: 0...1),
                    y:  .random(in: 0...1),
                    op: .random(in: 0.04...0.14)
                )
            }
        }
    }
}

// MARK: - Shared trigger label helper (used by both StoryBeatView and StoryModal)


// MARK: - BlinkingDot

/// Small animated signal indicator — shared by StoryBeatView, StoryModal, etc.
struct BlinkingDot: View {
    let color: Color
    @State private var on = true

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .opacity(on ? 1.0 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) {
                    on = false
                }
            }
    }
}

// MARK: - StoryBeatQueue

/// Helper for presenting a sequence of beats one after another.
///
/// Inject `@State private var storyQueue = StoryBeatQueue()` into a view,
/// then call `storyQueue.enqueue(_:)` when beats arrive.
///
/// ```swift
/// .overlay {
///     if let beat = storyQueue.current {
///         StoryModal(beat: beat, hasNext: storyQueue.hasNext) {
///             storyQueue.advance()
///         }
///         .transition(.opacity)
///         .zIndex(50)
///     }
/// }
/// ```
@MainActor @Observable
final class StoryBeatQueue {

    private(set) var current: StoryBeat? = nil
    private var queue: [StoryBeat] = []

    /// Deferred post-win batches (one per win event). Dispatched on Home return.
    private var pendingBatches: [[StoryBeat]] = []

    /// True when at least one more beat is waiting after `current`.
    var hasNext: Bool { !queue.isEmpty }

    /// Add beats to the end of the queue. Shows the first one immediately if idle.
    func enqueue(_ beats: [StoryBeat]) {
        queue.append(contentsOf: beats)
        if current == nil { showNext() }
    }

    /// Convenience for a single beat.
    func enqueue(_ beat: StoryBeat) {
        enqueue([beat])
    }

    /// Stage post-win beats for deferred display on Home return.
    /// Does nothing if `beats` is empty.
    func enqueueBatch(_ beats: [StoryBeat]) {
        guard !beats.isEmpty else { return }
        pendingBatches.append(beats)
    }

    /// Call when the player returns to Home. Promotes the most-recent pending
    /// batch to the live queue and silently marks all older batches seen,
    /// preventing narrative flooding when multiple wins happened in sequence.
    func dispatchPendingBatches() {
        guard !pendingBatches.isEmpty else { return }
        // Mark all older batches seen (suppress duplicates / stale beats)
        pendingBatches.dropLast().flatMap { $0 }.forEach { StoryStore.markSeen($0) }
        // Show only the most recent batch
        if let batch = pendingBatches.last { enqueue(batch) }
        pendingBatches.removeAll()
    }

    /// Dismiss the current beat (marks it seen) and advance to the next, if any.
    func advance() {
        if let beat = current {
            StoryStore.markSeen(beat)
        }
        showNext()
    }

    private func showNext() {
        if queue.isEmpty {
            current = nil
        } else {
            current = queue.removeFirst()
        }
    }
}
