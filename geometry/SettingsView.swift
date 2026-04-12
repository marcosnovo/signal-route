import SwiftUI

// MARK: - SettingsView
/// System configuration panel — sound, music, haptics, motion.
/// Presented as a modal sheet from HomeView.
struct SettingsView: View {

    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                navStrip
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        settingsSection(title: "AUDIO") {
                            settingsRow(icon: "speaker.wave.2.fill",
                                        label: "SOUND FX",
                                        sub: "Game sound effects",
                                        binding: $settings.soundEnabled)
                            TechDivider()
                            settingsRow(icon: "music.note",
                                        label: "AMBIENT MUSIC",
                                        sub: "Background drone",
                                        binding: $settings.musicEnabled)
                        }

                        settingsSection(title: "INTERFACE") {
                            settingsRow(icon: "hand.tap.fill",
                                        label: "HAPTIC FEEDBACK",
                                        sub: "Vibration on actions",
                                        binding: $settings.hapticsEnabled)
                            TechDivider()
                            settingsRow(icon: "waveform.path",
                                        label: "REDUCED MOTION",
                                        sub: "Simplify animations",
                                        binding: $settings.reducedMotion)
                        }

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
                    TechLabel(text: "CLOSE")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            TechLabel(text: "SYSTEM CONFIG", color: AppTheme.sage)
            Spacer()
            // Balance spacer
            HStack(spacing: 5) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                TechLabel(text: "CLOSE")
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

    // MARK: Build info

    private var buildInfo: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(AppTheme.sage.opacity(0.14))
                .frame(height: 0.5)
            HStack {
                TechLabel(text: "SIGNAL ROUTE  ·  v1.0")
                Spacer()
                TechLabel(text: "\(LevelGenerator.levels.count) MISSIONS",
                          color: AppTheme.sage.opacity(0.55))
            }
        }
        .padding(.top, 8)
    }
}
