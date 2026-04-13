import SwiftUI
import StoreKit

// MARK: - PaywallContext

/// The trigger context that caused the paywall to appear.
enum PaywallContext {
    case standard       // tapped from Home or Mission Map with no prior win
    case postVictory    // tried "Next Mission" immediately after winning
}

// MARK: - PaywallView

/// Full-screen premium paywall shown when a free user hits the daily mission limit.
struct PaywallView: View {

    let context:   PaywallContext
    let onDismiss: () -> Void

    @EnvironmentObject private var entitlement: EntitlementStore
    @EnvironmentObject private var settings:    SettingsStore
    @EnvironmentObject private var storeKit:    StoreKitManager

    @State private var appeared = false

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
            colors: [accent.opacity(0.10), .clear],
            center: .center, startRadius: 80, endRadius: 380
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface.opacity(0.60))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 10) {
            // Context badge
            HStack(spacing: 6) {
                if context == .postVictory {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(accent)
                } else {
                    BlinkingDot(color: accent)
                }
                Text(badgeLabel)
                    .font(AppTheme.mono(7, weight: .bold)).kerning(1.5)
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(accent.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(accent.opacity(0.35), lineWidth: 0.8))
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
            Button(action: onDismiss) {
                Text(dismissLabel)
                    .font(AppTheme.mono(9, weight: .semibold)).kerning(0.8)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    .frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(.plain)

            // ── Reset hint + restore ───────────────────────────────────────
            VStack(spacing: 6) {
                Text(resetLabel)
                    .font(AppTheme.mono(7)).kerning(0.4)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.28))

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

    // MARK: - Localized strings

    private var badgeLabel: String {
        switch (context, settings.language) {
        case (.postVictory, .en): return "MISSION COMPLETE"
        case (.postVictory, .es): return "MISIÓN COMPLETADA"
        case (.postVictory, .fr): return "MISSION ACCOMPLIE"
        case (_, .en):            return "SIGNAL LIMIT"
        case (_, .es):            return "LÍMITE DE SEÑAL"
        case (_, .fr):            return "LIMITE DE SIGNAL"
        }
    }

    private var titleText: String {
        switch (context, settings.language) {
        case (.postVictory, .en): return "GREAT\nRUN!"
        case (.postVictory, .es): return "¡BIEN\nJUGADO!"
        case (.postVictory, .fr): return "BELLE\nSESSION!"
        case (_, .en):            return "ACCESS\nLIMITED"
        case (_, .es):            return "ACCESO\nLIMITADO"
        case (_, .fr):            return "ACCÈS\nLIMITÉ"
        }
    }

    private var subtitleText: String {
        let n     = entitlement.dailyCompleted
        let limit = EntitlementStore.dailyLimit
        switch settings.language {
        case .en:
            return context == .postVictory
                ? "You've completed \(n) of \(limit) free missions today.\nThe network remains active."
                : "The network remains active.\nNew routes are waiting to be restored."
        case .es:
            return context == .postVictory
                ? "Has completado \(n) de \(limit) misiones gratuitas hoy.\nLas rutas siguen abiertas."
                : "Has alcanzado tu límite diario de misiones.\nLas rutas siguen abiertas."
        case .fr:
            return context == .postVictory
                ? "Vous avez complété \(n) sur \(limit) missions aujourd'hui.\nLe réseau reste actif."
                : "Le réseau reste actif.\nDe nouvelles routes attendent d'être restaurées."
        }
    }

    private var benefitUnlimited: String {
        switch settings.language {
        case .en: return "Unlimited missions"
        case .es: return "Misiones ilimitadas"
        case .fr: return "Missions illimitées"
        }
    }

    private var benefitAccess: String {
        switch settings.language {
        case .en: return "Access to all sectors"
        case .es: return "Acceso a todos los sectores"
        case .fr: return "Accès à tous les secteurs"
        }
    }

    private var benefitProgress: String {
        switch settings.language {
        case .en: return "Continuous progression, no waiting"
        case .es: return "Progresión continua sin esperas"
        case .fr: return "Progression continue sans attente"
        }
    }

    private var upgradeLabel: String {
        switch settings.language {
        case .en: return "UNLOCK FULL ACCESS"
        case .es: return "DESBLOQUEAR ACCESO"
        case .fr: return "DÉBLOQUER L'ACCÈS"
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
        switch settings.language {
        case .en: return "CONTINUE TOMORROW"
        case .es: return "CONTINUAR MAÑANA"
        case .fr: return "CONTINUER DEMAIN"
        }
    }

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
            // Pulsing ambient halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.18 + 0.10 * glowPhase), .clear],
                        center: .center, startRadius: 0, endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(1.0 + 0.06 * glowPhase)

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

            // Inner nodes (counter-rotating, orange-lit)
            ForEach(0..<innerCount, id: \.self) { i in
                Circle()
                    .fill(accent.opacity(0.65 + 0.25 * glowPhase))
                    .frame(width: 9, height: 9)
                    .shadow(color: accent.opacity(0.65), radius: 5)
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
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
            withAnimation(.linear(duration: 32).repeatForever(autoreverses: false)) {
                outerDeg = 360
            }
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
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
