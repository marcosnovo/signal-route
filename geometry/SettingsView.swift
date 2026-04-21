import SwiftUI

// MARK: - SettingsView
/// System configuration panel — sound, music, haptics, motion, language.
/// Presented as a modal sheet from HomeView.
struct SettingsView: View {

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingTerms = false
    @State private var showingPrivacy = false

    private var S: AppStrings { AppStrings(lang: settings.language) }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                navStrip
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        settingsSection(title: S.audio) {
                            settingsRow(icon: "speaker.wave.2.fill",
                                        label: S.soundFX,
                                        sub: S.soundFXSub,
                                        binding: $settings.soundEnabled)
                            TechDivider()
                            settingsRow(icon: "music.note",
                                        label: S.ambientMusic,
                                        sub: S.ambientMusicSub,
                                        binding: $settings.musicEnabled)
                        }

                        settingsSection(title: S.interfaceSection) {
                            settingsRow(icon: "hand.tap.fill",
                                        label: S.hapticFeedback,
                                        sub: S.hapticFeedbackSub,
                                        binding: $settings.hapticsEnabled)
                            TechDivider()
                            settingsRow(icon: "waveform.path",
                                        label: S.reducedMotion,
                                        sub: S.reducedMotionSub,
                                        binding: $settings.reducedMotion)
                        }

                        languageSection

                        legalSection

                        buildInfo
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: Nav strip

    private var navStrip: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    TechLabel(text: S.close)
                }
                .foregroundStyle(AppTheme.textPrimary.opacity(0.65))
            }
            Spacer()
            TechLabel(text: S.systemConfig, color: AppTheme.sage)
            Spacer()
            // Balance spacer
            HStack(spacing: 5) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                TechLabel(text: S.close)
            }.opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: Section container

    private func settingsSection<C: View>(
        title: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TechLabel(text: title, color: AppTheme.sage)
            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(AppTheme.sage.opacity(0.14), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        }
    }

    // MARK: Toggle row

    private func settingsRow(icon: String, label: String,
                              sub: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(binding.wrappedValue
                                 ? AppTheme.accentPrimary
                                 : AppTheme.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTheme.mono(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .kerning(0.5)
                Text(sub)
                    .font(AppTheme.mono(9))
                    .foregroundStyle(AppTheme.sage.opacity(0.55))
            }

            Spacer()

            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .tint(AppTheme.accentPrimary)
                .labelsHidden()
                .scaleEffect(0.85, anchor: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: Language section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TechLabel(text: S.language, color: AppTheme.sage)
            HStack(spacing: 0) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    let isSelected = settings.language == lang
                    Button(action: {
                        settings.language = lang
                        HapticsManager.selection()
                    }) {
                        Text(lang.displayName)
                            .font(AppTheme.mono(11, weight: isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(isSelected ? AppTheme.accentPrimary : Color.clear)
                            .animation(.easeInOut(duration: 0.15), value: settings.language)
                    }
                    if lang != AppLanguage.allCases.last {
                        Rectangle()
                            .fill(AppTheme.stroke.opacity(0.50))
                            .frame(width: 0.5)
                    }
                }
            }
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(AppTheme.sage.opacity(0.14), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        }
    }

    // MARK: Legal section

    private var legalSection: some View {
        settingsSection(title: S.legalSection) {
            legalRow(icon: "doc.text.fill",
                     label: S.termsTitle,
                     sub: S.termsSub) { showingTerms = true }
            TechDivider()
            legalRow(icon: "lock.shield.fill",
                     label: S.privacyTitle,
                     sub: S.privacySub) { showingPrivacy = true }
        }
        .sheet(isPresented: $showingTerms) {
            LegalTextView(title: S.termsTitle, content: S.termsBody)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showingPrivacy) {
            LegalTextView(title: S.privacyTitle, content: S.privacyBody)
                .environmentObject(settings)
        }
    }

    private func legalRow(icon: String, label: String,
                           sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(AppTheme.mono(12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(0.5)
                    Text(sub)
                        .font(AppTheme.mono(9))
                        .foregroundStyle(AppTheme.sage.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }

    // MARK: Build info

    private var buildInfo: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(AppTheme.sage.opacity(0.14))
                .frame(height: 0.5)
            HStack {
                TechLabel(text: "SIGNAL VOID  ·  v1.0.1")
                Spacer()
                TechLabel(text: "\(LevelGenerator.levels.count) \(S.missionsLabel)",
                          color: AppTheme.sage.opacity(0.55))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - LegalTextView

/// Full-screen sheet displaying Terms or Privacy Policy text.
private struct LegalTextView: View {

    let title: String
    let content: String

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    private var S: AppStrings { AppStrings(lang: settings.language) }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav strip
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            TechLabel(text: S.close)
                        }
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.65))
                    }
                    Spacer()
                    TechLabel(text: title, color: AppTheme.sage)
                    Spacer()
                    // Balance spacer
                    HStack(spacing: 5) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        TechLabel(text: S.close)
                    }.opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { TechDivider() }

                ScrollView {
                    Text(content)
                        .font(AppTheme.mono(10))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(5)
                        .padding(20)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}
