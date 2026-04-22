import SwiftUI
import StoreKit

// MARK: - DiscountState (paywall-local enum)

private enum DiscountState: Equatable {
    case idle
    case valid(DiscountCode)
    case unlocked    // full premium granted via unlock code
    case invalid
    case inactive
    case expired
    case exhausted
}

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
/// No-scroll layout — all content fits on a 6.1" iPhone screen.
struct PaywallView: View {

    let context:   PaywallContext
    let onDismiss: () -> Void

    @EnvironmentObject private var entitlement: EntitlementStore
    @EnvironmentObject private var settings:    SettingsStore
    @EnvironmentObject private var storeKit:    StoreKitManager

    @State private var appeared    = false
    @State private var ctaAppeared = false

    // ── Discount ───────────────────────────────────────────────────────────
    @State private var codeInput:     String        = ""
    @State private var discountState: DiscountState = .idle
    @FocusState private var codeFieldFocused: Bool

    private var S: AppStrings { AppStrings(lang: settings.language) }

    private let accent = AppTheme.accentPrimary
    private let sage   = AppTheme.sage

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────────
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid(opacity: 0.030)
            ambientGlow

            // ── Content ───────────────────────────────────────────────────
            VStack(spacing: 0) {
                closeButton
                    .padding(.top, 6)

                Spacer(minLength: 8)

                CompactOrbitView()
                    .frame(width: 80, height: 80)
                    .padding(.bottom, 8)

                titleSection
                    .padding(.horizontal, 28)

                Spacer(minLength: 12)

                benefitsCard
                    .padding(.horizontal, 20)

                Spacer(minLength: 10)

                discountSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 10)

                ctaSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.82)) {
                appeared = true
            }
            // CTA slides in slightly after the rest of the content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    ctaAppeared = true
                }
            }
            MonetizationAnalytics.shared.trackPaywallShown(context: context)
        }
        // Auto-dismiss once premium is activated (purchase or restore)
        .onChange(of: entitlement.isPremium) { _, isPremium in
            if isPremium {
                SoundManager.play(.sonicLogoFull)   // full logo — premium purchase milestone
                onDismiss()
            }
        }
        .task {
            await storeKit.loadProduct()
        }
    }

    // MARK: - Subviews

    private var ambientGlow: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.07), .clear],
                center: .top, startRadius: 40, endRadius: 320
            )
            RadialGradient(
                colors: [AppTheme.success.opacity(0.04), .clear],
                center: .bottom, startRadius: 60, endRadius: 280
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Tracks paywall_dismiss before calling the provided onDismiss callback.
    private func handleDismiss() {
        MonetizationAnalytics.shared.trackPaywallDismiss()
        onDismiss()
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                HapticsManager.light()
                SoundManager.play(.tapSecondary)
                handleDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.65))
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
        VStack(spacing: 8) {
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
                .font(AppTheme.mono(26, weight: .black)).kerning(0.8)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            // Subtitle — single-line summary, no momentum/bridge copy
            Text(subtitleText)
                .font(AppTheme.mono(10)).kerning(0.3)
                .foregroundStyle(sage.opacity(0.80))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(2)
        }
    }

    private var benefitsCard: some View {
        VStack(spacing: 0) {
            benefitRow(icon: "lock.open.fill",   label: S.paywallFeatureLevels)
            Rectangle().fill(sage.opacity(0.10)).frame(height: 0.5)
            benefitRow(icon: "infinity",         label: S.paywallFeatureNoLimit)
            Rectangle().fill(sage.opacity(0.10)).frame(height: 0.5)
            benefitRow(icon: "creditcard",       label: S.paywallFeatureOneTime)
            Rectangle().fill(sage.opacity(0.10)).frame(height: 0.5)
            benefitRow(icon: "person.2.fill",    label: S.paywallFeatureFamily)
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
                .foregroundStyle(AppTheme.success.opacity(0.75))
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
    }

    // MARK: - Discount section

    private var discountSection: some View {
        VStack(spacing: 6) {
            // Input row
            HStack(spacing: 0) {
                TextField(discountPlaceholderLabel, text: $codeInput)
                    .font(AppTheme.mono(11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .focused($codeFieldFocused)
                    .padding(.leading, 14)
                    .padding(.vertical, 11)

                Button(action: applyDiscount) {
                    Text(applyLabel)
                        .font(AppTheme.mono(9, weight: .black)).kerning(1)
                        .foregroundStyle(codeInput.isEmpty ? AppTheme.textSecondary : .black)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(codeInput.isEmpty ? AppTheme.backgroundSecondary : accent)
                }
                .buttonStyle(.plain)
                .disabled(codeInput.isEmpty)
                .animation(.easeOut(duration: 0.15), value: codeInput.isEmpty)
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(discountBorderColor, lineWidth: 0.8)
            )

            // Feedback row
            if discountState != .idle {
                HStack(spacing: 6) {
                    Image(systemName: discountFeedbackIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(discountFeedbackColor)
                    Text(discountFeedbackText)
                        .font(AppTheme.mono(8, weight: .semibold)).kerning(0.5)
                        .foregroundStyle(discountFeedbackColor)
                    Spacer()
                    if case .valid(let code) = discountState {
                        Text(discountOffLabel(code.percentageOff))
                            .font(AppTheme.mono(8, weight: .black)).kerning(1)
                            .foregroundStyle(AppTheme.success)
                    }
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.80), value: discountState)
    }

    private func applyDiscount() {
        codeFieldFocused = false

        // 1. Check unlock codes first — they take priority over discount codes.
        switch UnlockCodeStore.shared.validate(codeInput) {
        case .valid:
            // Redeem triggers EntitlementStore.activateByCode → isPremium = true.
            // The .onChange(of: entitlement.isPremium) handler plays the sound + dismisses.
            UnlockCodeStore.shared.redeem(codeInput)
            discountState = .unlocked
            HapticsManager.success()
            return
        case .inactive:
            discountState = .inactive;  HapticsManager.light(); return
        case .expired:
            discountState = .expired;   HapticsManager.light(); return
        case .exhausted:
            discountState = .exhausted; HapticsManager.light(); return
        case .invalid:
            break   // not an unlock code — fall through to discount code check
        }

        // 2. Check discount codes (price display only, no access change).
        switch DiscountStore.shared.validate(codeInput) {
        case .valid(let code):
            discountState = .valid(code)
            DiscountStore.shared.redeem(codeInput)
            HapticsManager.light()
        case .invalid:   discountState = .invalid;   HapticsManager.light()
        case .inactive:  discountState = .inactive;  HapticsManager.light()
        case .expired:   discountState = .expired;   HapticsManager.light()
        case .exhausted: discountState = .exhausted; HapticsManager.light()
        }
    }

    // ── Discount display helpers ──────────────────────────────────────────

    private var discountBorderColor: Color {
        switch discountState {
        case .idle:                                      return sage.opacity(0.20)
        case .valid, .unlocked:                          return AppTheme.success.opacity(0.55)
        case .invalid, .inactive, .expired, .exhausted: return AppTheme.danger.opacity(0.45)
        }
    }

    private var discountFeedbackIcon: String {
        switch discountState {
        case .idle:              return "tag"
        case .valid, .unlocked:  return "checkmark.circle.fill"
        default:                 return "xmark.circle.fill"
        }
    }

    private var discountFeedbackColor: Color {
        switch discountState {
        case .valid, .unlocked: return AppTheme.success
        default:                return AppTheme.danger
        }
    }

    private var discountFeedbackText: String {
        switch (discountState, settings.language) {
        case (.idle, _):           return ""
        case (.unlocked,  .en):    return "Full access unlocked"
        case (.unlocked,  .es):    return "Acceso completo desbloqueado"
        case (.unlocked,  .fr):    return "Accès complet débloqué"
        case (.valid(let c), .en): return "\(c.code) — Code applied"
        case (.valid(let c), .es): return "\(c.code) — Código aplicado"
        case (.valid(let c), .fr): return "\(c.code) — Code appliqué"
        case (.invalid,   .en):    return "Invalid code"
        case (.invalid,   .es):    return "Código inválido"
        case (.invalid,   .fr):    return "Code invalide"
        case (.inactive,  .en):    return "Code not active"
        case (.inactive,  .es):    return "Código inactivo"
        case (.inactive,  .fr):    return "Code inactif"
        case (.expired,   .en):    return "Code expired"
        case (.expired,   .es):    return "Código expirado"
        case (.expired,   .fr):    return "Code expiré"
        case (.exhausted, .en):    return "Usage limit reached"
        case (.exhausted, .es):    return "Límite de usos alcanzado"
        case (.exhausted, .fr):    return "Limite d'utilisations atteinte"
        }
    }

    private func discountOffLabel(_ pct: Int) -> String {
        switch settings.language {
        case .en: return "\(pct)% OFF"
        case .es: return "\(pct)% DTO."
        case .fr: return "\(pct)% RÉD."
        }
    }

    /// Formatted discounted price string, or nil when no discount is active.
    private var discountedPriceString: String? {
        guard case .valid(let code) = discountState,
              let product = storeKit.product else { return nil }
        let factor = Decimal(1) - Decimal(code.percentageOff) / Decimal(100)
        let discounted = (product.price * factor as NSDecimalNumber).rounding(accordingToBehavior: nil)
        return (discounted as Decimal).formatted(product.priceFormatStyle)
    }

    // MARK: - CTA section

    private var ctaSection: some View {
        VStack(spacing: 0) {

            // ── Primary: purchase ──────────────────────────────────────────
            let isBusy = storeKit.purchaseState == .purchasing
                      || storeKit.purchaseState == .loading
            Button {
                HapticsManager.medium()
                SoundManager.play(.tapPrimary)
                MonetizationAnalytics.shared.trackPaywallCTATap()
                Task { await storeKit.purchase() }
            } label: {
                ZStack {
                    VStack(spacing: 3) {
                        Text(upgradeLabel)
                            .font(AppTheme.mono(13, weight: .black)).kerning(1.0)
                            .foregroundStyle(.black.opacity(isBusy ? 0 : 0.88))
                        if !isBusy {
                            priceSubtext
                        }
                    }
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
            .scaleEffect(ctaAppeared ? 1.0 : 0.96)
            .opacity(ctaAppeared ? 1.0 : 0)

            // ── CTA subtext ────────────────────────────────────────────────
            Text(ctaSubtext)
                .font(AppTheme.mono(8)).kerning(0.4)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
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

            // ── Secondary: dismiss (ghost style matching Home's secondary buttons) ──
            Button(action: { SoundManager.play(.tapSecondary); handleDismiss() }) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(dismissLabel)
                        .font(AppTheme.mono(11, weight: .bold)).kerning(1.4)
                        .foregroundStyle(sage.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(.white.opacity(0.030))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            // ── Temporal context + restore ─────────────────────────────────
            VStack(spacing: 8) {
                if showsResetHint {
                    Text(resetLabel)
                        .font(AppTheme.mono(7)).kerning(0.4)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
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
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    }
                }
                .buttonStyle(.plain)
                .disabled(storeKit.purchaseState == .restoring)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Price sub-label (inside CTA button)

    @ViewBuilder
    private var priceSubtext: some View {
        if let discounted = discountedPriceString,
           let original = storeKit.product?.displayPrice {
            // Discount active — show strikethrough original + discounted price
            HStack(spacing: 6) {
                Text(original)
                    .strikethrough(true, color: .black.opacity(0.50))
                    .font(AppTheme.mono(8)).kerning(0.4)
                    .foregroundStyle(.black.opacity(0.40))
                Image(systemName: "arrow.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.black.opacity(0.55))
                Text(discounted + " · " + unlimitedLabel)
                    .font(AppTheme.mono(8, weight: .bold)).kerning(0.4)
                    .foregroundStyle(.black.opacity(0.70))
            }
        } else if let price = storeKit.product?.displayPrice {
            Text(price + " · " + unlimitedLabel)
                .font(AppTheme.mono(8)).kerning(0.4)
                .foregroundStyle(.black.opacity(0.50))
        }
    }

    // MARK: - Frustration state

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

    /// Condensed single-line subtitle — replaces the prior multi-block copy
    /// (progress stat, momentum nudge, bridge phrase) for a cleaner no-scroll layout.
    private var subtitleText: String {
        if isFrustrated {
            switch (context, settings.language) {
            case (.postVictory,        .en): return "You pushed through. The route stays open."
            case (.postVictory,        .es): return "Lo has logrado. Las rutas siguen abiertas."
            case (.postVictory,        .fr): return "Vous avez persévéré. Le réseau reste actif."
            case (.sectorExcitement,   .en): return "A new sector waits. Upgrade to explore at your pace."
            case (.sectorExcitement,   .es): return "Un sector te espera. Mejora a tu ritmo."
            case (.sectorExcitement,   .fr): return "Un secteur vous attend. Améliorez à votre rythme."
            case (.nextMissionBlocked, .en): return "You're putting in the work. Come back tomorrow."
            case (.nextMissionBlocked, .es): return "Estás dando todo. Vuelve mañana."
            case (.nextMissionBlocked, .fr): return "Vous donnez le meilleur. Revenez demain."
            case (.homeSoftCTA,        .en): return "Unlock all sectors. No daily limits."
            case (.homeSoftCTA,        .es): return "Desbloquea todos los sectores. Sin límites."
            case (.homeSoftCTA,        .fr): return "Débloquez tous les secteurs. Sans limites."
            }
        }
        switch (context, settings.language) {
        case (.postVictory,        .en): return "Daily limit reached. Upgrade to keep going."
        case (.postVictory,        .es): return "Límite diario alcanzado. Mejora para continuar."
        case (.postVictory,        .fr): return "Limite atteinte. Améliorez pour continuer."
        case (.sectorExcitement,   .en): return "New sector unlocked — daily limit reached."
        case (.sectorExcitement,   .es): return "Sector desbloqueado — límite diario alcanzado."
        case (.sectorExcitement,   .fr): return "Secteur débloqué — limite journalière atteinte."
        case (.nextMissionBlocked, .en): return "Daily limit reached. Upgrade to continue."
        case (.nextMissionBlocked, .es): return "Límite diario alcanzado. Mejora para continuar."
        case (.nextMissionBlocked, .fr): return "Limite atteinte. Améliorez pour continuer."
        case (.homeSoftCTA,        .en): return "Explore without daily limits."
        case (.homeSoftCTA,        .es): return "Explora sin límites diarios."
        case (.homeSoftCTA,        .fr): return "Explorez sans limite journalière."
        }
    }

    private var upgradeLabel: String {
        switch settings.language {
        case .en: return "CONTINUE NOW"
        case .es: return "CONTINUAR AHORA"
        case .fr: return "CONTINUER MAINTENANT"
        }
    }

    private var ctaSubtext: String { S.paywallLegal }

    private var unlimitedLabel: String {
        switch settings.language {
        case .en: return "Unlimited"
        case .es: return "Ilimitado"
        case .fr: return "Illimité"
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

    /// Whether to show the 24h reset hint.
    /// Hidden for homeSoftCTA — player hasn't hit a daily limit yet.
    private var showsResetHint: Bool { context != .homeSoftCTA }

    private var resetLabel: String {
        switch settings.language {
        case .en: return "Free missions reset in 24 hours"
        case .es: return "Las misiones gratuitas se reinician en 24 horas"
        case .fr: return "Les missions gratuites se réinitialisent dans 24 heures"
        }
    }

    private var restoreLabel: String { S.paywallCtaRestore }

    private var discountPlaceholderLabel: String {
        switch settings.language {
        case .en: return "Code"
        case .es: return "Código"
        case .fr: return "Code"
        }
    }

    private var applyLabel: String {
        switch settings.language {
        case .en: return "APPLY"
        case .es: return "APLICAR"
        case .fr: return "APPLIQUER"
        }
    }
}

// MARK: - CompactOrbitView

/// Compact animated signal-network visualization.
/// 80×80pt — two orbiting rings, counter-rotating inner nodes, and a traveling particle.
private struct CompactOrbitView: View {

    private let accent     = AppTheme.accentPrimary
    private let innerR: CGFloat = 22
    private let outerR: CGFloat = 34

    @State private var glowPhase:   CGFloat = 0
    @State private var outerDeg:    Double  = 0
    @State private var innerDeg:    Double  = 0
    @State private var particleDeg: Double  = 0

    var body: some View {
        ZStack {
            // Ambient halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.10 + 0.06 * glowPhase), .clear],
                        center: .center, startRadius: 0, endRadius: 44
                    )
                )
                .scaleEffect(1.0 + 0.04 * glowPhase)

            // Static rings
            Circle()
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                .frame(width: innerR * 2, height: innerR * 2)
            Circle()
                .strokeBorder(.white.opacity(0.05), lineWidth: 0.5)
                .frame(width: outerR * 2, height: outerR * 2)

            // Outer nodes (slow clockwise rotation)
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(AppTheme.backgroundSecondary)
                    .frame(width: 4, height: 4)
                    .overlay(Circle().strokeBorder(.white.opacity(0.20), lineWidth: 0.6))
                    .offset(y: -outerR)
                    .rotationEffect(.degrees(Double(i) * 72.0 + outerDeg))
            }

            // Inner nodes (counter-clockwise)
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(accent.opacity(0.45 + 0.15 * glowPhase))
                    .frame(width: 6, height: 6)
                    .shadow(color: accent.opacity(0.25), radius: 3)
                    .offset(y: -innerR)
                    .rotationEffect(.degrees(Double(i) * 90.0 - innerDeg))
            }

            // Traveling particle
            Circle()
                .fill(accent)
                .frame(width: 4, height: 4)
                .shadow(color: accent, radius: 5)
                .offset(y: -outerR)
                .rotationEffect(.degrees(particleDeg))

            // Central node — three-layer glow
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14 + 0.10 * glowPhase))
                    .frame(width: 22, height: 22)
                    .scaleEffect(1.0 + 0.06 * glowPhase)
                Circle()
                    .fill(accent.opacity(0.45 + 0.12 * glowPhase))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                    .shadow(color: accent.opacity(0.90), radius: 6)
            }
        }
        .frame(width: 80, height: 80)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                outerDeg = 360
            }
            withAnimation(.linear(duration: 44).repeatForever(autoreverses: false)) {
                innerDeg = 360
            }
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
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
