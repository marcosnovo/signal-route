import SwiftUI

// MARK: - NarrativeIntroView
/// Four cinematic inter-title panels that play before the gameplay onboarding.
///
/// Sentences within each panel fade in sequentially (0.45 s apart).
/// After all sentences are visible a "TAP TO CONTINUE" prompt appears.
/// Tapping while sentences are still animating in skips to showing all of them;
/// tapping again advances to the next panel (or completes the intro).
///
/// `onComplete` is called when the player taps past the last panel.
/// `onSkip`    is called immediately when the SKIP button is pressed.
/// Both callbacks should mark the narrative as seen in `OnboardingStore`.
struct NarrativeIntroView: View {

    let onComplete: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    private var S: AppStrings { AppStrings(lang: settings.language) }

    // ── Content ───────────────────────────────────────────────────────────
    // Panels are computed so the text always matches the current language.

    private var panels: [(sentences: [String], accentHex: String)] {
        switch settings.language {
        case .es: return panelsES
        case .fr: return panelsFR
        default:  return panelsEN
        }
    }

    private var panelsEN: [(sentences: [String], accentHex: String)] { [
        (sentences: ["Humanity can already travel",
                     "farther than ever before.",
                     "",
                     "Distance is no longer the barrier.",
                     "Stability is."],
         accentHex: "4DB87A"),
        (sentences: ["Every station, gate and orbital corridor",
                     "depends on fragile energy systems.",
                     "",
                     "A single routing failure",
                     "can stall an entire mission."],
         accentHex: "D4A055"),
        (sentences: ["You are not here to fly.",
                     "",
                     "You are here to restore the network.",
                     "",
                     "Your engineering skills",
                     "will decide how far we can go."],
         accentHex: "7EC8E3"),
        (sentences: ["Prove your precision.",
                     "Earn your rank.",
                     "",
                     "Unlock the routes that will carry",
                     "humanity deeper into space."],
         accentHex: "4B70DD"),
    ] }

    private var panelsES: [(sentences: [String], accentHex: String)] { [
        (sentences: ["La humanidad ya puede viajar",
                     "más lejos que nunca antes.",
                     "",
                     "La distancia ya no es la barrera.",
                     "La estabilidad, sí."],
         accentHex: "4DB87A"),
        (sentences: ["Cada estación, puerta y corredor orbital",
                     "depende de frágiles sistemas de energía.",
                     "",
                     "Un solo fallo de enrutamiento",
                     "puede detener una misión completa."],
         accentHex: "D4A055"),
        (sentences: ["No estás aquí para volar.",
                     "",
                     "Estás aquí para restaurar la red.",
                     "",
                     "Tus habilidades de ingeniería",
                     "decidirán hasta dónde podemos llegar."],
         accentHex: "7EC8E3"),
        (sentences: ["Demuestra tu precisión.",
                     "Gana tu rango.",
                     "",
                     "Desbloquea las rutas que llevarán",
                     "a la humanidad más lejos en el espacio."],
         accentHex: "4B70DD"),
    ] }

    private var panelsFR: [(sentences: [String], accentHex: String)] { [
        (sentences: ["L'humanité peut déjà voyager",
                     "plus loin que jamais.",
                     "",
                     "La distance n'est plus l'obstacle.",
                     "La stabilité, oui."],
         accentHex: "4DB87A"),
        (sentences: ["Chaque station, porte et couloir orbital",
                     "dépend de systèmes énergétiques fragiles.",
                     "",
                     "Une seule défaillance de routage",
                     "peut bloquer une mission entière."],
         accentHex: "D4A055"),
        (sentences: ["Tu n'es pas ici pour piloter.",
                     "",
                     "Tu es ici pour restaurer le réseau.",
                     "",
                     "Tes compétences en ingénierie",
                     "détermineront jusqu'où nous pourrons aller."],
         accentHex: "7EC8E3"),
        (sentences: ["Prouve ta précision.",
                     "Gagne ton rang.",
                     "",
                     "Débloque les routes qui mèneront",
                     "l'humanité plus loin dans l'espace."],
         accentHex: "4B70DD"),
    ] }

    // ── State ─────────────────────────────────────────────────────────────

    @State private var currentPanel:     Int  = 0
    @State private var visibleSentences: Int  = 0
    @State private var showContinue:     Bool = false
    @State private var contentOpacity:   Double = 0

    // Prevent double-advance when tapping fast
    @State private var isTransitioning = false
    // Set true when the user taps to skip mid-reveal, so revealPanel() exits
    // its loop without overwriting the already-complete visibleSentences value.
    @State private var revealSkipped   = false

    private var panel: (sentences: [String], accentHex: String) {
        panels[currentPanel]
    }

    private var accentColor: Color {
        Color(hex: panel.accentHex)
    }

    private var isLastPanel: Bool { currentPanel == panels.count - 1 }
    private var allSentencesVisible: Bool {
        visibleSentences >= panel.sentences.count
    }

    // ── Body ──────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.ignoresSafeArea()

            // Subtle ambient glow
            RadialGradient(
                gradient: Gradient(colors: [accentColor.opacity(0.07), .clear]),
                center: .center, startRadius: 60, endRadius: 320
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.2), value: currentPanel)

            VStack(spacing: 0) {
                // ── Skip button ───────────────────────────────────────────
                HStack {
                    Spacer()
                    Button(action: skip) {
                        Text(S.skip)
                            .font(AppTheme.mono(8, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                            .kerning(1.5)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)   // 44pt minimum touch target
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // ── Panel text ────────────────────────────────────────────
                VStack(alignment: .center, spacing: 6) {
                    ForEach(panel.sentences.indices, id: \.self) { i in
                        let sentence = panel.sentences[i]
                        if sentence.isEmpty {
                            Spacer().frame(height: 8)
                        } else {
                            Text(sentence)
                                .font(AppTheme.mono(14))
                                .foregroundStyle(
                                    i == 0 ? Color.white : Color.white.opacity(0.82)
                                )
                                .multilineTextAlignment(.center)
                                .kerning(0.4)
                                .opacity(i < visibleSentences ? 1 : 0)
                                .animation(.easeIn(duration: 0.5), value: visibleSentences)
                        }
                    }
                }
                .padding(.horizontal, 36)
                .frame(maxWidth: .infinity)
                .opacity(contentOpacity)

                Spacer()

                // ── Bottom bar: dots + continue prompt ────────────────────
                HStack(alignment: .center) {
                    // Panel indicator dots
                    HStack(spacing: 5) {
                        ForEach(panels.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPanel ? accentColor : AppTheme.textSecondary.opacity(0.22))
                                .frame(width: i == currentPanel ? 14 : 5, height: 3)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPanel)
                        }
                    }

                    Spacer()

                    // Continue / Begin prompt
                    if showContinue {
                        HStack(spacing: 4) {
                            Text(isLastPanel ? S.begin : S.continueAction)
                                .font(AppTheme.mono(8, weight: .bold))
                                .foregroundStyle(accentColor)
                                .kerning(1.5)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(accentColor)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 42)
                .frame(height: 64)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .task(id: currentPanel) { await revealPanel() }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) { contentOpacity = 1 }
        }
    }

    // ── Interaction ───────────────────────────────────────────────────────

    private func handleTap() {
        if !allSentencesVisible {
            // Flag first so revealPanel()'s guard fires before it can set
            // visibleSentences back to an intermediate value after its next sleep.
            revealSkipped = true
            withAnimation(.easeIn(duration: 0.25)) {
                visibleSentences = panel.sentences.count
            }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeIn(duration: 0.25)) { showContinue = true }
            }
        } else if showContinue && !isTransitioning {
            advancePanel()
        }
    }

    private func advancePanel() {
        isTransitioning = true
        if isLastPanel {
            withAnimation(.easeOut(duration: 0.4)) { contentOpacity = 0 }
            Task {
                try? await Task.sleep(for: .milliseconds(420))
                onComplete()
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { contentOpacity = 0 }
            Task {
                try? await Task.sleep(for: .milliseconds(320))
                currentPanel     += 1
                visibleSentences  = 0
                showContinue      = false
                revealSkipped     = false   // reset so the next panel reveals normally
                withAnimation(.easeIn(duration: 0.3)) { contentOpacity = 1 }
                isTransitioning   = false
            }
        }
    }

    private func skip() {
        withAnimation(.easeOut(duration: 0.3)) { contentOpacity = 0 }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            onComplete()
        }
    }

    // ── Sequential sentence reveal ────────────────────────────────────────

    @MainActor
    private func revealPanel() async {
        var revealed = 0
        for i in panel.sentences.indices {
            guard !panel.sentences[i].isEmpty else { continue }
            let delay: Duration = revealed == 0 ? .milliseconds(300) : .milliseconds(480)
            try? await Task.sleep(for: delay)
            // Abort if panel changed (task cancelled) or user already tapped to skip.
            // revealSkipped must be checked AFTER the sleep so we don't overwrite the
            // full-reveal that handleTap() set while we were sleeping.
            guard !Task.isCancelled, !revealSkipped else { return }
            revealed += 1
            visibleSentences = i + 1
        }
        // Show continue prompt after a brief pause (only if user hasn't skipped).
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled, !revealSkipped else { return }
        withAnimation(.easeIn(duration: 0.3)) { showContinue = true }
    }
}
