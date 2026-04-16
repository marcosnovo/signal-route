import SwiftUI
import StoreKit

// MARK: - PaywallContext

/// The trigger context that caused the paywall to appear.
///
/// Contexts are selected by PaywallMomentSelector, never by failure or frustration paths.
enum PaywallContext {
    case postVictory        // won and daily limit just reached — celebratory momentum
    case sectorExcitement   // new sector/pass unlocked but blocked by limit — expansion
    case nextMissionBlocked // tried "Next Mission" or map level, hit daily limit — continuity
    case homeSoftCTA        // passive upgrade row on Home — low pressure, no urgency
}

// MARK: - PaywallView

/// Full-screen premium paywall shown when a free user hits the daily mission limit.
struct PaywallView: View {

    let context:   PaywallContext
    let onDismiss: () -> Void

    @EnvironmentObject private var entitlement: EntitlementStore
    @EnvironmentObject private var settings:    SettingsStore
    @EnvironmentObject private var storeKit:    StoreKitManager

    @State private var appeared    = false
    @State private var ctaAppeared = false

    private let accent = AppTheme.accentPrimary

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────────
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid(opacity: 0.035)
            ambientGlow

            // ── Content ───────────────────────────────────────────────────
            VStack(spacing: 0) {
                closeButton
                    .padding(.top, 6)

                Spacer(minLength: 0)

                PaywallHeroView()
                    .frame(height: 260)
                    .padding(.bottom, 12)

                titleSection
                    .padding(.horizontal, 28)

                Spacer(minLength: 16)

                benefitsCard
                    .padding(.horizontal, 20)

                Spacer(minLength: 20)

                ctaSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        }
        // Entrance: fade in + subtle scale up
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.82)) {
                appeared = true
            }
            // CTA slides in slightly after the rest of the content — benefits lead, then CTA follows.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    ctaAppeared = true
                }
            }
            MonetizationAnalytics.shared.trackPaywallShown(context: context)
        }
        // Auto-dismiss once premium is activated (purchase or restore)
        .onChange(of: entitlement.isPremium) { _, isPremium in
            if isPremium { onDismiss() }
        }
        // Ensure product is loaded if not yet available
        .task {
            await storeKit.loadProduct()
        }
    }

    // MARK: - Subviews

    private var ambientGlow: some View {
        RadialGradient(
            colors: [accent.opacity(0.06), .clear],
            center: .center, startRadius: 80, endRadius: 380
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Tracks paywall_dismiss before calling the provided onDismiss callback.
    /// Do NOT use this on the purchase-success path — that's handled by StoreKitManager.
    private func handleDismiss() {
        MonetizationAnalytics.shared.trackPaywallDismiss()
        onDismiss()
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                HapticsManager.light()
                handleDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                    // 44×44 minimum tap target with clear circular glass background
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 10) {
            // Context badge
            HStack(spacing: 6) {
                switch context {
                case .postVictory:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(accent)
                case .sectorExcitement:
                    Image(systemName: "star.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(accent)
                case .nextMissionBlocked, .homeSoftCTA:
                    BlinkingDot(color: accent)
                }
                Text(badgeLabel)
                    .font(AppTheme.mono(7, weight: .bold)).kerning(1.5)
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(accent.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(accent.opacity(0.20), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // Title
            Text(titleText)
                .font(AppTheme.mono(30, weight: .black)).kerning(1.0)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            // Subtitle
            Text(subtitleText)
                .font(AppTheme.mono(10)).kerning(0.3)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Progress stat + momentum nudge — positive reinforcement for non-frustrated players.
            // Hidden for homeSoftCTA (no limit hit) and when isFrustrated (empathetic path instead).
            if context != .homeSoftCTA, !isFrustrated {
                // Progress stat chip
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.success.opacity(0.80))
                    Text(progressStatText)
                        .font(AppTheme.mono(8, weight: .semibold)).kerning(0.5)
                        .foregroundStyle(AppTheme.success.opacity(0.80))
                }
                .padding(.top, 4)

                // Momentum nudge
                Text(momentumText)
                    .font(AppTheme.mono(9)).kerning(0.3)
                    .foregroundStyle(accent.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            // Bridge phrase — connects problem to solution, not shown for homeSoftCTA
            if context != .homeSoftCTA {
                Text(bridgeText)
                    .font(AppTheme.mono(9, weight: .semibold)).kerning(0.5)
                    .foregroundStyle(accent.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private var benefitsCard: some View {
        VStack(spacing: 0) {
            benefitRow(icon: "infinity",        label: benefitUnlimited)
            Rectangle().fill(AppTheme.sage.opacity(0.10)).frame(height: 0.5)
            benefitRow(icon: "lock.open.fill",  label: benefitAccess)
            Rectangle().fill(AppTheme.sage.opacity(0.10)).frame(height: 0.5)
            benefitRow(icon: "arrow.up.forward",label: benefitProgress)
        }
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(accent.opacity(0.20), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func benefitRow(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(label)
                .font(AppTheme.mono(10, weight: .semibold)).kerning(0.4)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.success.opacity(0.70))
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    private var ctaSection: some View {
        VStack(spacing: 0) {

            // ── Primary: purchase ──────────────────────────────────────────
            let isBusy = storeKit.purchaseState == .purchasing
                      || storeKit.purchaseState == .loading
            Button {
                HapticsManager.medium()
                MonetizationAnalytics.shared.trackPaywallCTATap()
                Task { await storeKit.purchase() }
            } label: {
                ZStack {
                    // Button content
                    VStack(spacing: 3) {
                        Text(upgradeLabel)
                            .font(AppTheme.mono(13, weight: .black)).kerning(1.0)
                            .foregroundStyle(.black.opacity(isBusy ? 0 : 0.88))
                        if let price = storeKit.product?.displayPrice, !isBusy {
                            Text(price + " · " + unlimitedLabel)
                                .font(AppTheme.mono(8)).kerning(0.4)
                                .foregroundStyle(.black.opacity(0.50))
                        }
                    }
                    // Spinner overlay during purchase
                    if isBusy {
                        ProgressView()
                            .tint(.black.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(accent.opacity(isBusy ? 0.60 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .breathingCTA(color: accent)
            // Entrance: CTA scales up slightly after the benefits card appears
            .scaleEffect(ctaAppeared ? 1.0 : 0.96)
            .opacity(ctaAppeared ? 1.0 : 0)

            // ── CTA subtext ────────────────────────────────────────────────
            Text(ctaSubtext)
                .font(AppTheme.mono(8)).kerning(0.4)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.38))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .opacity(ctaAppeared ? 1.0 : 0)

            // ── Error message ──────────────────────────────────────────────
            if case .failed(let msg) = storeKit.purchaseState {
                Text(msg)
                    .font(AppTheme.mono(8)).kerning(0.3)
                    .foregroundStyle(AppTheme.danger.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8).padding(.top, 8)
                    .transition(.opacity)
            }

            // ── Secondary: dismiss ─────────────────────────────────────────
            // Visible real button — lower contrast than primary but not hidden.
            Button(action: handleDismiss) {
                Text(dismissLabel)
                    .font(AppTheme.mono(10, weight: .semibold)).kerning(0.8)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.65))
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.textSecondary.opacity(0.18), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            // ── Temporal context + restore ─────────────────────────────────
            VStack(spacing: 8) {
                // Reset hint — slightly more visible; gives the player certainty about the limit.
                if showsResetHint {
                    Text(resetLabel)
                        .font(AppTheme.mono(7)).kerning(0.4)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                }

                Button {
                    Task { await storeKit.restorePurchases() }
                } label: {
                    let isRestoring = storeKit.purchaseState == .restoring
                    HStack(spacing: 5) {
                        if isRestoring {
                            ProgressView().scaleEffect(0.65).tint(AppTheme.textSecondary)
                        }
                        Text(restoreLabel)
                            .font(AppTheme.mono(8)).kerning(0.5)
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                    }
                }
                .buttonStyle(.plain)
                .disabled(storeKit.purchaseState == .restoring)
            }
        }
    }

    // MARK: - Frustration state

    /// True when the player is showing signs of struggle this session.
    /// Used to shift copy tone: empathetic and patient instead of promotional and urgent.
    private var isFrustrated: Bool { FrustrationGuard.isFrustrated() }

    // MARK: - Localized strings

    private var badgeLabel: String {
        switch (context, settings.language) {
        case (.postVictory,        .en): return "MISSION COMPLETE"
        case (.postVictory,        .es): return "MISIÓN COMPLETADA"
        case (.postVictory,        .fr): return "MISSION ACCOMPLIE"
        case (.sectorExcitement,   .en): return "SECTOR UNLOCKED"
        case (.sectorExcitement,   .es): return "SECTOR DESBLOQUEADO"
        case (.sectorExcitement,   .fr): return "SECTEUR DÉBLOQUÉ"
        case (.nextMissionBlocked, .en): return "SIGNAL LIMIT"
        case (.nextMissionBlocked, .es): return "LÍMITE DE SEÑAL"
        case (.nextMissionBlocked, .fr): return "LIMITE DE SIGNAL"
        case (.homeSoftCTA,        .en): return "EXPLORE MORE"
        case (.homeSoftCTA,        .es): return "EXPLORA MÁS"
        case (.homeSoftCTA,        .fr): return "EXPLOREZ PLUS"
        }
    }

    private var titleText: String {
        switch (context, settings.language) {
        case (.postVictory,        .en): return "GREAT\nRUN"
        case (.postVictory,        .es): return "GRAN\nMISIÓN"
        case (.postVictory,        .fr): return "BELLE\nMISSION"
        case (.sectorExcitement,   .en): return "NEW\nDESTINATION"
        case (.sectorExcitement,   .es): return "NUEVO\nDESTINO"
        case (.sectorExcitement,   .fr): return "NOUVELLE\nDESTINATION"
        case (.nextMissionBlocked, .en): return "ACCESS\nLIMITED"
        case (.nextMissionBlocked, .es): return "ACCESO\nLIMITADO"
        case (.nextMissionBlocked, .fr): return "ACCÈS\nLIMITÉ"
        case (.homeSoftCTA,        .en): return "THE FULL\nNETWORK"
        case (.homeSoftCTA,        .es): return "LA RED\nCOMPLETA"
        case (.homeSoftCTA,        .fr): return "LE RÉSEAU\nCOMPLET"
        }
    }

    private var subtitleText: String {
        let n     = entitlement.dailyCompleted
        let limit = EntitlementStore.shared.dailyLimit

        // Empathetic variants — used when FrustrationGuard detects a struggling player.
        // Tone: patient, acknowledging effort. No urgency, no pressure.
        if isFrustrated {
            switch (context, settings.language) {
            case (.postVictory, .en):
                return "You pushed through some tough ones.\nTake a break — the route stays open."
            case (.postVictory, .es):
                return "Lo has logrado con esfuerzo.\nDescansa — las rutas siguen abiertas."
            case (.postVictory, .fr):
                return "Vous avez persévéré malgré tout.\nFaites une pause — le réseau reste actif."
            case (.sectorExcitement, .en):
                return "A new sector is waiting whenever you're ready.\nUpgrade to explore at your own pace."
            case (.sectorExcitement, .es):
                return "Un nuevo sector te espera cuando estés listo.\nMejora para explorar a tu ritmo."
            case (.sectorExcitement, .fr):
                return "Un nouveau secteur vous attend quand vous êtes prêt.\nAméliorez pour explorer à votre rythme."
            case (.nextMissionBlocked, .en):
                return "You're putting in the work.\nCome back tomorrow — the signal stays alive."
            case (.nextMissionBlocked, .es):
                return "Estás dando todo de ti.\nVuelve mañana — la señal sigue activa."
            case (.nextMissionBlocked, .fr):
                return "Vous donnez le meilleur de vous-même.\nRevenez demain — le signal reste actif."
            case (.homeSoftCTA, .en):
                return "Unlock all sectors, no daily limits.\nThe full network is yours."
            case (.homeSoftCTA, .es):
                return "Desbloquea todos los sectores, sin límites diarios.\nToda la red es tuya."
            case (.homeSoftCTA, .fr):
                return "Débloquez tous les secteurs, sans limite journalière.\nTout le réseau vous appartient."
            }
        }

        // Standard variants — used when the player is in a positive state.
        switch (context, settings.language) {
        case (.postVictory, .en):
            return "You've reached your daily mission limit."
        case (.postVictory, .es):
            return "Has alcanzado tu límite diario de misiones."
        case (.postVictory, .fr):
            return "Vous avez atteint votre limite de missions journalière."
        case (.sectorExcitement, .en):
            return "A new sector is unlocked — you've reached your daily limit."
        case (.sectorExcitement, .es):
            return "Un nuevo sector te espera — has alcanzado tu límite diario."
        case (.sectorExcitement, .fr):
            return "Un nouveau secteur est prêt — vous avez atteint votre limite."
        case (.nextMissionBlocked, .en):
            return "You've reached your daily mission limit."
        case (.nextMissionBlocked, .es):
            return "Has alcanzado tu límite diario de misiones."
        case (.nextMissionBlocked, .fr):
            return "Vous avez atteint votre limite de missions journalière."
        case (.homeSoftCTA, .en):
            return "Explore without daily limits."
        case (.homeSoftCTA, .es):
            return "Explora sin límites diarios."
        case (.homeSoftCTA, .fr):
            return "Explorez sans limite journalière."
        }
    }

    private var bridgeText: String {
        switch settings.language {
        case .en: return "Continue without interruptions:"
        case .es: return "Continúa ahora sin interrupciones:"
        case .fr: return "Continuez sans interruptions :"
        }
    }

    /// Dynamic progress stat: how many missions completed today.
    private var progressStatText: String {
        let n = entitlement.dailyCompleted
        switch settings.language {
        case .en: return "\(n) mission\(n == 1 ? "" : "s") completed today"
        case .es: return "\(n) misión\(n == 1 ? "" : "es") completada\(n == 1 ? "" : "s") hoy"
        case .fr: return "\(n) mission\(n == 1 ? "" : "s") complétée\(n == 1 ? "" : "s") aujourd'hui"
        }
    }

    /// Context-specific momentum nudge — keeps tone on progress, never on restriction.
    private var momentumText: String {
        switch (context, settings.language) {
        case (.postVictory,        .en): return "You're about to unlock new routes."
        case (.postVictory,        .es): return "Estás a punto de desbloquear nuevas rutas."
        case (.postVictory,        .fr): return "Vous êtes sur le point de débloquer de nouvelles routes."
        case (.sectorExcitement,   .en): return "New routes are ready — keep your momentum."
        case (.sectorExcitement,   .es): return "Nuevas rutas te esperan — mantén el impulso."
        case (.sectorExcitement,   .fr): return "De nouvelles routes vous attendent — gardez l'élan."
        case (.nextMissionBlocked, .en): return "Keep going — more routes are waiting."
        case (.nextMissionBlocked, .es): return "Sigue — más rutas te están esperando."
        case (.nextMissionBlocked, .fr): return "Continuez — d'autres routes vous attendent."
        default:                         return ""
        }
    }

    private var benefitUnlimited: String {
        switch settings.language {
        case .en: return "Play without daily limits"
        case .es: return "Juega sin límites diarios"
        case .fr: return "Jouez sans limites journalières"
        }
    }

    private var benefitAccess: String {
        switch settings.language {
        case .en: return "Access all sectors"
        case .es: return "Accede a todos los sectores"
        case .fr: return "Accédez à tous les secteurs"
        }
    }

    private var benefitProgress: String {
        switch settings.language {
        case .en: return "Progress without interruptions"
        case .es: return "Avanza sin interrupciones"
        case .fr: return "Avancez sans interruptions"
        }
    }

    private var upgradeLabel: String {
        switch settings.language {
        case .en: return "CONTINUE NOW"
        case .es: return "CONTINUAR AHORA"
        case .fr: return "CONTINUER MAINTENANT"
        }
    }

    private var ctaSubtext: String {
        switch settings.language {
        case .en: return "Immediate access · No daily limits"
        case .es: return "Acceso inmediato · Sin límites diarios"
        case .fr: return "Accès immédiat · Sans limite journalière"
        }
    }

    private var unlimitedLabel: String {
        switch settings.language {
        case .en: return "Unlimited missions · No daily limits"
        case .es: return "Misiones ilimitadas · Sin límite diario"
        case .fr: return "Missions illimitées · Sans limite journalière"
        }
    }

    private var dismissLabel: String {
        if context == .homeSoftCTA {
            switch settings.language {
            case .en: return "NOT NOW"
            case .es: return "AHORA NO"
            case .fr: return "PAS MAINTENANT"
            }
        }
        switch settings.language {
        case .en: return "CONTINUE TOMORROW"
        case .es: return "CONTINUAR MAÑANA"
        case .fr: return "CONTINUER DEMAIN"
        }
    }

    /// Whether to show the midnight-reset hint. Hidden for homeSoftCTA since
    /// the player hasn't hit a daily limit — there's nothing to reset.
    private var showsResetHint: Bool { context != .homeSoftCTA }

    private var resetLabel: String {
        switch settings.language {
        case .en: return "Free missions reset at midnight"
        case .es: return "Las misiones gratuitas se reinician a medianoche"
        case .fr: return "Les missions gratuites se réinitialisent à minuit"
        }
    }

    private var restoreLabel: String {
        switch settings.language {
        case .en: return "Restore purchase"
        case .es: return "Restaurar compra"
        case .fr: return "Restaurer l'achat"
        }
    }
}

// MARK: - PaywallHeroView

/// Animated signal-network visualization: rotating rings, pulsing nodes, traveling particle.
private struct PaywallHeroView: View {

    private let accent      = AppTheme.accentPrimary
    private let innerR: CGFloat = 78
    private let outerR: CGFloat = 118
    private let innerCount  = 6
    private let outerCount  = 8

    @State private var glowPhase:    CGFloat = 0   // 0 → 1, ambient pulse
    @State private var outerDeg:     Double  = 0   // outer ring rotation
    @State private var innerDeg:     Double  = 0   // inner ring rotation (opposite)
    @State private var particleDeg:  Double  = 0   // traveling particle angle

    var body: some View {
        ZStack {
            // Pulsing ambient halo — kept subtle; focal glow lives on central node only
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.08 + 0.04 * glowPhase), .clear],
                        center: .center, startRadius: 0, endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(1.0 + 0.03 * glowPhase)

            // Static concentric rings
            Circle()
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                .frame(width: innerR * 2, height: innerR * 2)
            Circle()
                .strokeBorder(.white.opacity(0.04), lineWidth: 0.5)
                .frame(width: outerR * 2, height: outerR * 2)

            // Spoke lines: center → inner node positions (static canvas, no animation)
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                for i in 0..<6 {
                    let angle = Double(i) * .pi * 2 / 6
                    let ex = cx + CGFloat(sin(angle)) * 78
                    let ey = cy - CGFloat(cos(angle)) * 78
                    var p = Path()
                    p.move(to: CGPoint(x: cx, y: cy))
                    p.addLine(to: CGPoint(x: ex, y: ey))
                    ctx.stroke(p, with: .color(.white.opacity(0.08)), lineWidth: 0.6)
                }
            }
            .frame(width: 260, height: 260)
            .allowsHitTesting(false)

            // Outer nodes (rotating slowly, unlit gray)
            ForEach(0..<outerCount, id: \.self) { i in
                Circle()
                    .fill(AppTheme.backgroundSecondary)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.8))
                    .offset(y: -outerR)
                    .rotationEffect(.degrees(Double(i) * 360.0 / Double(outerCount) + outerDeg))
            }

            // Inner nodes (counter-rotating, dimmed — glow reserved for central node)
            ForEach(0..<innerCount, id: \.self) { i in
                Circle()
                    .fill(accent.opacity(0.40 + 0.12 * glowPhase))
                    .frame(width: 9, height: 9)
                    .shadow(color: accent.opacity(0.22), radius: 4)
                    .offset(y: -innerR)
                    .rotationEffect(.degrees(Double(i) * 360.0 / Double(innerCount) - innerDeg))
            }

            // Traveling particle along outer ring
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .shadow(color: accent, radius: 7)
                .offset(y: -outerR)
                .rotationEffect(.degrees(particleDeg))

            // Central node — three-layer glow
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12 + 0.10 * glowPhase))
                    .frame(width: 62, height: 62)
                    .scaleEffect(1.0 + 0.05 * glowPhase)
                Circle()
                    .fill(accent.opacity(0.38 + 0.12 * glowPhase))
                    .frame(width: 38, height: 38)
                Circle()
                    .fill(accent)
                    .frame(width: 20, height: 20)
                    .shadow(color: accent.opacity(0.88 + 0.10 * glowPhase), radius: 14)
            }
        }
        .frame(width: 260, height: 260)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
            // Very slow orbital drift — barely perceptible, gives life without distraction
            withAnimation(.linear(duration: 72).repeatForever(autoreverses: false)) {
                outerDeg = 360
            }
            withAnimation(.linear(duration: 52).repeatForever(autoreverses: false)) {
                innerDeg = 360
            }
            withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                particleDeg = 360
            }
        }
    }
}

#Preview {
    PaywallView(context: .postVictory) { }
        .environmentObject(EntitlementStore.shared)
        .environmentObject(SettingsStore.shared)
        .environmentObject(StoreKitManager.shared)
}
