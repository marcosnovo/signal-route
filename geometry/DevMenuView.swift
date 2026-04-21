import SwiftUI
import StoreKit
import GameKit

// MARK: - DevMenuView
/// Hidden QA / testing console. Accessible via 5-tap logo on the Home screen.
///
/// ## Tabs
///   STATE    — astronaut progression, level jump, sector/pass grid.
///   MISSIONS — full level browser with difficulty / objective / completion filters.
///   TOOLS    — onboarding reset, validation runner, mechanic message inspector.
///   RESET    — danger-zone reset actions.
struct DevMenuView: View {
    let onSelect: (Level) -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var settings:   SettingsStore
    @EnvironmentObject private var storeKit:   StoreKitManager
    @EnvironmentObject private var gcManager:  GameCenterManager
    @EnvironmentObject private var cloudSave:  CloudSaveManager

    // ── Tab ───────────────────────────────────────────────────────────────
    enum DevTab { case overview, missions, story, tools, money, reset, qa, sim, versus }
    @State private var activeTab: DevTab = .overview

    // ── QA tab ────────────────────────────────────────────────────────────
    @StateObject private var qaRunner  = SelfQARunner()

    // ── SIM tab ───────────────────────────────────────────────────────────
    @StateObject private var simRunner = PlayerSimulationRunner()

    // ── Filter state (MISSIONS tab) ───────────────────────────────────────
    @State private var filterDifficulty: DifficultyTier?    = nil
    @State private var filterObjective: LevelObjectiveType? = nil
    @State private var filterStatus: CompletionFilter       = .all

    enum CompletionFilter { case all, open, done }

    // ── STATE tab ─────────────────────────────────────────────────────────
    @State private var devLevel: Int   = 1
    @State private var refreshID: UUID = UUID()

    // ── STORY tab ─────────────────────────────────────────────────────────
    enum StorySeenFilter { case all, seen, unseen }
    @State private var storySeenFilter:    StorySeenFilter = .all
    @State private var storyTriggerFilter: StoryTrigger?   = nil
    /// Set to show a StoryBeatView preview overlay inside DevMenuView.
    @State private var previewingBeat:     StoryBeat?      = nil
    /// Queue of beats waiting to be shown after `previewingBeat` is dismissed.
    @State private var previewBeatQueue:   [StoryBeat]     = []
    /// Bumped after any seen/unseen toggle to force list recomputation.
    @State private var storyRefreshID:     UUID            = UUID()
    /// Result of the last StoryAssetValidator run (nil = not yet run).
    @State private var assetValidation:    StoryAssetValidator.Result? = nil
    @State private var storySearch:        String = ""
    /// Beat IDs marked as reviewed in the Story Assets Preview section (session-only).
    @State private var reviewedBeatIDs:    Set<String> = []
    /// Whether the Story Assets Preview section is expanded.
    @State private var showAssetPreview:   Bool = false
    /// Whether the Story Sequence Tester section is expanded.
    @State private var showSequenceTester: Bool = false
    /// Lines of the last consistency report run (nil = not yet run).
    @State private var consistencyReport:  [String]? = nil
    /// ID of the last beat fired via simulateBeat (session-only, for live feedback).
    @State private var lastSimulatedID:    String?   = nil
    /// Results from the last Narrative QA catalog check (nil = not yet run).
    @State private var narrativeQAReport:  NarrativeQAReport? = nil
    /// Whether the Narrative QA section is expanded.
    @State private var showNarrativeQA:    Bool = false

    // ── Toast feedback ────────────────────────────────────────────────────
    struct DevToast: Identifiable {
        enum Style { case success, warning, fail, info }
        let id    = UUID()
        let message: String
        let style:   Style
        var icon: String {
            switch style {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .fail:    return "xmark.circle.fill"
            case .info:    return "info.circle.fill"
            }
        }
        var color: Color {
            switch style {
            case .success: return AppTheme.success
            case .warning: return Color.orange
            case .fail:    return AppTheme.danger
            case .info:    return AppTheme.accentPrimary
            }
        }
    }
    @State private var devToast: DevToast? = nil

    // ── Mission search (MISSIONS tab) ──────────────────────────────────────
    @State private var missionIDInput: String = ""

    // ── TOOLS tab ─────────────────────────────────────────────────────────
    /// Language used for inline mechanic message previews (independent of app language).
    @State private var previewLanguage: AppLanguage = .en
    /// When set, shows a full-screen DevMechanicPreviewCard overlay.
    @State private var previewMechanic: MechanicType? = nil
    /// Controls inline expansion of a mechanic's message card.
    @State private var expandedMechanic: MechanicType? = nil

    #if DEBUG
    @State private var validationReports: [LevelValidationReport] = []
    @State private var isValidating = false

    /// Filter applied to the validation results summary.
    enum ValidationResultFilter: String, CaseIterable {
        case all, failed, startsSolved, trivial, warnings, expert
        var label: String { rawValue == "startsSolved" ? "PRE-SOLVED" : rawValue.uppercased() }
    }
    @State private var validationFilter: ValidationResultFilter = .all

    // Starts-solved scan
    @State private var startsSolvedBroken: [Level] = []
    @State private var startsSolvedChecked: Bool = false
    @State private var isCheckingStartsSolved: Bool = false

    // Per-level inspector (MISSIONS tab)
    @State private var inspectLevelID: Int?  = nil
    @State private var inspectCache: [Int: LevelValidationReport] = [:]
    @State private var inspectRunning: Set<Int> = []

    // Auto-scroll: set to make MISSIONS tab jump to a specific level row
    @State private var jumpToLevelID: Int? = nil

    // Difficulty analysis
    @State private var analysisDataset:          [LevelDifficultyMetrics]                  = []
    @State private var analysisIssues:           [LevelIssue]                              = []
    @State private var analysisSuggestions:      [RebalanceSuggestion]                     = []
    @State private var analysisPhases:           [DifficultyCurveAnalyzer.PhaseReport]     = []
    @State private var analysisCurveAnomalies:   [DifficultyCurveAnalyzer.CurveAnomaly]    = []
    @State private var isAnalyzing:              Bool                                       = false
    @State private var analysisIssueFilter:      IssueType?                                = nil
    #endif

    // ── Pass viewer ───────────────────────────────────────────────────────
    /// When set, shows the rendered ticket card for this pass in a full-screen overlay.
    @State private var viewingPass: PlanetPass? = nil

    // ── MONEY section (inside STATE tab) ──────────────────────────────────
    @State private var showingDevPaywall  = false
    @State private var devPaywallContext: PaywallContext = .nextMissionBlocked

    // ── DISCOUNT CODES section ─────────────────────────────────────────────
    @State private var showAddCodeForm:   Bool    = false
    @State private var newCodeText:       String  = ""
    @State private var newCodePct:        Int     = 25
    @State private var newCodeHasExpiry:  Bool    = false
    @State private var newCodeExpiry:     Date    = Date().addingTimeInterval(86400 * 30)
    @State private var newCodeHasLimit:   Bool    = false
    @State private var newCodeLimit:      Int     = 10
    @State private var discountTestInput: String  = ""
    @State private var discountTestResult: String = ""

    // ── UNLOCK CODES section ───────────────────────────────────────────────
    @State private var showAddUnlockCodeForm:  Bool   = false
    @State private var newUnlockCodeText:      String = ""
    @State private var newUnlockCodeNote:      String = ""
    @State private var newUnlockCodeHasExpiry: Bool   = false
    @State private var newUnlockCodeExpiry:    Date   = Date().addingTimeInterval(86400 * 30)
    @State private var newUnlockCodeHasLimit:  Bool   = false
    @State private var newUnlockCodeLimit:     Int    = 10
    @State private var unlockTestInput:        String = ""
    @State private var unlockTestResult:       String = ""

    // ── NOTIFICATIONS section ──────────────────────────────────────────────
    @State private var notifStatusLabel:  String  = "…"
    @State private var notifPendingIDs:   [String] = []

    // ── RESET tab ─────────────────────────────────────────────────────────
    @State private var pendingReset: ResetAction? = nil

    enum ResetAction: Identifiable {
        case all, missions, passes, mechanics, story
        var id: Self { self }
        var title: String {
            switch self {
            case .all:       return "RESET ALL PROGRESS"
            case .missions:  return "RESET MISSION DATA"
            case .passes:    return "RESET PLANET PASSES"
            case .mechanics: return "RESET MECHANIC UNLOCKS"
            case .story:     return "RESET STORY BEATS"
            }
        }
        var message: String {
            switch self {
            case .all:
                return "Deletes level, all missions, passes, mechanic announcements, and story beats. Cannot be undone."
            case .missions:
                return "Clears all completed missions. Level stays the same."
            case .passes:
                return "Removes all collected planet passes and the render cache."
            case .mechanics:
                return "All mechanic unlock messages will re-appear next time they are encountered."
            case .story:
                return "All story beats will be marked unseen and will fire again at their natural triggers."
            }
        }
    }

    // ── Derived ───────────────────────────────────────────────────────────

    private var profile: AstronautProfile {
        _ = refreshID
        return ProgressionStore.profile
    }

    private var filteredLevels: [Level] {
        LevelGenerator.levels.filter { level in
            // ID search: exact match when a number is typed
            if !missionIDInput.isEmpty {
                if let id = Int(missionIDInput) { if level.id != id { return false } }
                else { return false }
            }
            if let d = filterDifficulty, level.difficulty != d { return false }
            if let o = filterObjective,  level.objectiveType != o { return false }
            switch filterStatus {
            case .open: if  profile.hasCompleted(levelId: level.id) { return false }
            case .done: if !profile.hasCompleted(levelId: level.id) { return false }
            case .all:  break
            }
            return true
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────

    /// Type-erased tab content. `AnyView` breaks the deep opaque-type chain that
    /// causes a stack overflow in SwiftUI's layout engine on complex view hierarchies.
    private var tabContent: some View {
        switch activeTab {
        case .overview:
            return AnyView(overviewPanel)
        case .missions:
            return AnyView(Group {
                missionJumpBar
                filterBar
                TechDivider()
                levelList
            })
        case .story:
            return AnyView(storyPanel)
        case .tools:
            return AnyView(toolsPanel)
        case .money:
            return AnyView(moneyPanel)
        case .reset:
            return AnyView(resetPanel)
        case .qa:
            return AnyView(SelfQAView(runner: qaRunner) { level in
                onSelect(level)
                onDismiss()
            })
        case .sim:
            return AnyView(PlayerSimulationView(runner: simRunner))
        case .versus:
            return AnyView(versusPanel)
        }
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()
            BackgroundGrid()

            VStack(spacing: 0) {
                navStrip
                globalStatusBar
                quickActionsStrip
                tabBar
                TechDivider()

                tabContent
            }

            // ── Dev toast ─────────────────────────────────────────────────
            if let toast = devToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: toast.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(toast.message)
                            .font(AppTheme.mono(10, weight: .bold))
                            .kerning(0.5)
                    }
                    .foregroundStyle(toast.color)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(AppTheme.backgroundPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(toast.color.opacity(0.60), lineWidth: 0.75)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .shadow(color: toast.color.opacity(0.25), radius: 16, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(400)
            }

            // ── Full-screen mechanic preview overlay ──────────────────────
            if let mechanic = previewMechanic {
                DevMechanicPreviewCard(mechanic: mechanic, language: previewLanguage) {
                    withAnimation(.easeOut(duration: 0.22)) { previewMechanic = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // ── Full-screen pass card viewer ───────────────────────────────
            if let pass = viewingPass {
                DevPassViewerOverlay(pass: pass) {
                    withAnimation(.easeOut(duration: 0.22)) { viewingPass = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // ── Story beat preview overlay (full StoryModal for visual fidelity) ──
            if let beat = previewingBeat {
                StoryModal(beat: beat, hasNext: !previewBeatQueue.isEmpty) {
                    withAnimation(.easeOut(duration: 0.22)) { advancePreviewBeatQueue() }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(300)
            }

            // ── Dev paywall test overlay ───────────────────────────────────────
            if showingDevPaywall {
                PaywallView(context: devPaywallContext) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.90)) {
                        showingDevPaywall = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal:   .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(250)
            }
        }
        .onAppear {
            devLevel        = profile.level
            previewLanguage = settings.language
        }
        .confirmationDialog(
            pendingReset?.title ?? "",
            isPresented: Binding(
                get: { pendingReset != nil },
                set: { if !$0 { pendingReset = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingReset {
                Button("CONFIRM — \(action.title)", role: .destructive) {
                    executeReset(action)
                }
                Button("CANCEL", role: .cancel) { pendingReset = nil }
            }
        } message: {
            if let action = pendingReset { Text(action.message) }
        }
    }

    // MARK: - Global status bar

    private var globalStatusBar: some View {
        _ = refreshID
        let prog    = profile.progression
        let store   = EntitlementStore.shared
        let isPrem  = store.isPremium
        let unseen  = StoryBeatCatalog.beats.filter { !StoryStore.seenIDs.contains($0.id) }.count

        let missingPasses = SpatialRegion.catalog.filter { s in
            !PassStore.hasPass(for: s.id - 1) && s.levels.allSatisfy { profile.hasCompleted(levelId: $0.id) }
        }
        let devGranted = SpatialRegion.catalog.filter { s in
            PassStore.hasPass(for: s.id - 1) && !s.levels.allSatisfy { profile.hasCompleted(levelId: $0.id) }
        }
        let (cohLabel, cohColor): (String, Color) = {
            if !missingPasses.isEmpty { return ("INVALID", AppTheme.danger) }
            if !devGranted.isEmpty    { return ("WARNING", Color.orange) }
            return ("OK", AppTheme.success)
        }()

        return VStack(spacing: 0) {
            // Row 1 — progression
            HStack(spacing: 0) {
                miniStat("LVL",     "\(prog.playerLevel) · \(rankLabel(for: prog.playerLevel))")
                statDivider()
                miniStat("SECTOR",  prog.currentSector.name.components(separatedBy: " ").first ?? "—")
                statDivider()
                miniStat("PLANET",  prog.currentPlanet.name)
                statDivider()
                miniStat("NEXT",    prog.nextPlanet?.name ?? "—")
                statDivider()
                miniStat("MISSION", prog.activeMission.map { "#\($0.id)" } ?? "DONE")
            }
            .padding(.vertical, 8)

            TechDivider()

            // Row 2 — meta state
            HStack(spacing: 0) {
                miniStatC("PLAN",    isPrem ? "PREMIUM" : "FREE",
                          isPrem ? AppTheme.accentPrimary : AppTheme.sage)
                statDivider()
                miniStatC("GATE",
                          isPrem ? "∞" : store.isInIntroPhase
                              ? "INTRO \(store.freeIntroCompleted)/\(EntitlementStore.freeIntroLimit)"
                              : store.canPlayNow ? "OPEN" : "LOCKED",
                          isPrem ? AppTheme.accentPrimary
                              : store.isInIntroPhase ? AppTheme.sage
                              : store.canPlayNow ? AppTheme.success : AppTheme.danger)
                statDivider()
                miniStatC("STORY",  unseen > 0 ? "\(unseen) UNSEEN" : "ALL SEEN",
                          unseen > 0 ? Color.orange : AppTheme.success)
                statDivider()
                miniStatC("STATE",   cohLabel, cohColor)
            }
            .padding(.vertical, 8)
        }
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private func miniStatC(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            TechLabel(text: label, color: AppTheme.textSecondary)
            Text(value)
                .font(AppTheme.mono(9, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Nav strip

    private var navStrip: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    TechLabel(text: "CLOSE")
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            TechLabel(text: "DEV CONSOLE", color: AppTheme.accentPrimary)

            Spacer()

            // Contextual action for the MISSIONS tab; invisible placeholder otherwise
            if activeTab == .missions {
                Button(action: resetFilters) {
                    TechLabel(text: "FILTERS", color: AppTheme.sage.opacity(0.60))
                }
            } else {
                Color.clear.frame(width: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.backgroundPrimary.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // MARK: - Quick actions strip

    private var quickActionsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // RESET ALL
                quickBtn("RESET ALL", icon: "trash.fill", color: AppTheme.danger, isDanger: true) {
                    pendingReset = .all
                }
                // REPLAY ONBOARDING
                quickBtn("ONBOARDING", icon: "play.fill", color: AppTheme.accentPrimary) {
                    OnboardingStore.resetAll()
                    NotificationCenter.default.post(name: .devReplayOnboarding, object: nil)
                    onDismiss()
                }
                // OPEN CURRENT MISSION
                quickBtn("CUR MISSION", icon: "bolt.fill", color: AppTheme.sage) {
                    if let m = profile.progression.activeMission { onSelect(m) }
                }
                // OPEN CURRENT PASS
                quickBtn("CUR PASS", icon: "creditcard.fill", color: AppTheme.accentPrimary) {
                    viewingPass = PassStore.all.last
                }
                // JUMP TO ACTIVE SECTOR
                quickBtn("SECTOR", icon: "map.fill", color: AppTheme.sage) {
                    activeTab = .overview
                }
                // STORY PANEL
                quickBtn("STORY", icon: "text.bubble", color: Color(hex: "7EC8E3")) {
                    activeTab = .story
                }
                // MONETIZATION PANEL
                quickBtn("MONEY", icon: "infinity", color: AppTheme.accentPrimary) {
                    activeTab = .money
                }
                // SELF QA
                quickBtn("SELF QA", icon: "checkmark.seal.fill", color: Color(hex: "4DB87A")) {
                    activeTab = .qa
                    Task { await qaRunner.runQuick() }
                }
                // PLAYER SIM
                quickBtn("PLAYER SIM", icon: "figure.run", color: Color(hex: "7EC8E3")) {
                    activeTab = .sim
                    Task { await simRunner.run() }
                }
                #if DEBUG
                // VALIDATE ALL
                quickBtn("VALIDATE ALL", icon: "checkmark.seal.fill", color: AppTheme.sage) {
                    activeTab = .tools
                    runValidation(useSolver: false)
                }
                // DIFFICULTY ANALYSIS
                quickBtn("ANALYSIS", icon: "chart.bar.xaxis", color: AppTheme.accentPrimary) {
                    activeTab = .tools
                    runDifficultyAnalysis()
                }
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .background(AppTheme.backgroundPrimary)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private func quickBtn(
        _ label: String,
        icon: String,
        color: Color,
        isDanger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 8, weight: .bold))
                Text(label).font(AppTheme.mono(8, weight: .bold)).kerning(0.6)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(color.opacity(isDanger ? 0.13 : 0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(color.opacity(isDanger ? 0.55 : 0.32),
                                  lineWidth: isDanger ? 1.0 : 0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("OVERVIEW", icon: "square.grid.2x2",          tab: .overview)
            tabSeparator()
            tabButton("MISSIONS", icon: "list.bullet",              tab: .missions)
            tabSeparator()
            tabButton("STORY",    icon: "text.bubble",              tab: .story)
            tabSeparator()
            tabButton("TOOLS",    icon: "wrench.and.screwdriver",   tab: .tools)
            tabSeparator()
            tabButton("MONEY",    icon: "infinity",                 tab: .money)
            tabSeparator()
            tabButton("RESET",    icon: "exclamationmark.triangle", tab: .reset)
            tabSeparator()
            tabButton("VERSUS",   icon: "person.2",                 tab: .versus)
        }
        .frame(height: 42)
        .background(AppTheme.backgroundSecondary)
    }

    private func tabSeparator() -> some View {
        Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5)
    }

    private func tabButton(_ label: String, icon: String, tab: DevTab) -> some View {
        let isActive = activeTab == tab
        let isReset  = tab == .reset
        let fgColor: Color = isActive
            ? (isReset ? AppTheme.danger : AppTheme.accentPrimary)
            : AppTheme.textSecondary.opacity(0.50)
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.14)) { activeTab = tab }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isActive ? .bold : .regular))
                Text(label)
                    .font(AppTheme.mono(6, weight: isActive ? .bold : .regular))
                    .kerning(0.5)
            }
            .foregroundStyle(fgColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isActive
                ? (isReset ? AppTheme.danger.opacity(0.06) : AppTheme.accentPrimary.opacity(0.07))
                : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? fgColor : Color.clear)
                    .frame(height: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - OVERVIEW tab

    private var overviewPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                systemHealthSection
                TechDivider()
                gameCenterSection
                TechDivider()
                progressionSection
                TechDivider()
                coherenceSection
                TechDivider()
                qaScenarioSection
                TechDivider()
                sectorPassGrid
            }
        }
    }

    // MARK: - System Health

    private var systemHealthSection: some View {
        _ = refreshID
        let prog = profile.progression

        // ── Progression coherence ──────────────────────────────────────────────
        let missingPasses = SpatialRegion.catalog.filter { s in
            !PassStore.hasPass(for: s.id - 1) && s.levels.allSatisfy { profile.hasCompleted(levelId: $0.id) }
        }
        let devGranted = SpatialRegion.catalog.filter { s in
            PassStore.hasPass(for: s.id - 1) && !s.levels.allSatisfy { profile.hasCompleted(levelId: $0.id) }
        }
        let cohStatus: QAStatus = missingPasses.isEmpty && devGranted.isEmpty ? .pass
                                : !missingPasses.isEmpty ? .fail : .warning
        let cohDetail: String   = missingPasses.isEmpty && devGranted.isEmpty
                                ? "LVL \(prog.playerLevel) · S\(prog.currentSector.id)"
                                : (!missingPasses.isEmpty ? "\(missingPasses.count) PASS MISSING" : "\(devGranted.count) DEV-GRANTED")

        // ── Story assets ───────────────────────────────────────────────────────
        let assetStat: QAStatus
        let assetDetail: String
        if let r = assetValidation {
            assetStat  = r.isValid ? .pass : .fail
            assetDetail = r.isValid ? "ALL \(r.checkedCount) OK" : "\(r.missingAssets.count)/\(r.checkedCount) MISSING"
        } else {
            assetStat  = .warning
            assetDetail = "NOT CHECKED"
        }

        // ── Game Center ────────────────────────────────────────────────────────
        let gcStat: QAStatus  = gcManager.isAuthenticated ? .pass : .warning
        let avatarLoaded      = gcManager.playerAvatar != nil
        let cloudSynced       = cloudSave.lastSyncedAt != nil
        let gcDetail: String  = gcManager.isAuthenticated
                              ? "\(gcManager.displayName.isEmpty ? "AUTHENTICATED" : gcManager.displayName) · AVATAR \(avatarLoaded ? "✓" : "…") · CLOUD \(cloudSynced ? "✓" : "—")"
                              : "NOT AUTHENTICATED"

        // ── StoreKit ───────────────────────────────────────────────────────────
        let skStat: QAStatus
        let skDetail: String
        switch storeKit.purchaseState {
        case .idle:       skStat = storeKit.product != nil ? .pass : .warning
                          skDetail = storeKit.product.map { $0.displayPrice } ?? "NO PRODUCT"
        case .failed:     skStat = .fail;    skDetail = "PURCHASE FAILED"
        case .success:    skStat = .pass;    skDetail = "PURCHASE OK"
        default:          skStat = .warning; skDetail = "LOADING…"
        }

        // ── Validation (DEBUG only) ────────────────────────────────────────────
        #if DEBUG
        let validStat: QAStatus
        let validDetail: String
        if isValidating {
            validStat  = .warning; validDetail = "RUNNING…"
        } else if validationReports.isEmpty {
            validStat  = .warning; validDetail = "NOT RUN"
        } else {
            let criticals = validationReports.filter { !$0.isSolvable || $0.startsSolved }
            let issues    = validationReports.filter { !$0.isSolvable || !$0.warnings.isEmpty || $0.isTrivial || $0.startsSolved }
            validStat  = !criticals.isEmpty ? .fail : (issues.isEmpty ? .pass : .warning)
            validDetail = !criticals.isEmpty
                ? "\(criticals.count) CRITICAL IN \(validationReports.count)"
                : (issues.isEmpty ? "ALL \(validationReports.count) OK" : "\(issues.count) ISSUES IN \(validationReports.count)")
        }
        #else
        let validStat  = QAStatus.warning
        let validDetail = "DEBUG ONLY"
        #endif

        // ── Last QA ────────────────────────────────────────────────────────────
        let qaStat: QAStatus
        let qaDetail: String
        if qaRunner.isRunning {
            qaStat  = .warning; qaDetail = "RUNNING…"
        } else if let s = qaRunner.summary {
            qaStat  = s.overallStatus
            qaDetail = "\(s.passes)/\(s.total) · \(s.failures)F \(s.warnings)W"
        } else {
            qaStat  = .warning; qaDetail = "NOT RUN"
        }

        return VStack(spacing: 0) {
            sectionHeader("SYSTEM HEALTH")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 0
            ) {
                healthCell("PROGRESSION",  status: cohStatus,   detail: cohDetail)
                healthCell("STORY ASSETS", status: assetStat,   detail: assetDetail)
                healthCell("GAME CENTER",  status: gcStat,       detail: gcDetail)
                healthCell("STOREKIT",     status: skStat,       detail: skDetail)
                healthCell("VALIDATION",   status: validStat,    detail: validDetail)
                healthCell("LAST QA",      status: qaStat,       detail: qaDetail)
            }
            .padding(.vertical, 4)

            // Run QA shortcut
            HStack(spacing: 8) {
                scenarioBtn("RUN QUICK QA", icon: "checkmark.seal.fill",
                            color: qaStat == .fail ? AppTheme.danger : AppTheme.sage) {
                    activeTab = .qa
                    Task { await qaRunner.runQuick() }
                }
                scenarioBtn("VALIDATE ASSETS", icon: "checklist", color: AppTheme.accentPrimary) {
                    assetValidation = StoryAssetValidator.validate()
                    showToast(
                        assetValidation!.isValid
                            ? "✓ All \(assetValidation!.checkedCount) assets present"
                            : "✗ \(assetValidation!.missingAssets.count) missing",
                        style: assetValidation!.isValid ? .success : .fail
                    )
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(AppTheme.surface)
    }

    private func healthCell(_ label: String, status: QAStatus, detail: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: status.systemIcon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(status.color)
            VStack(alignment: .leading, spacing: 3) {
                TechLabel(text: label, color: AppTheme.textSecondary.opacity(0.55))
                Text(detail)
                    .font(AppTheme.mono(8, weight: .bold))
                    .foregroundStyle(status.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(status == .fail    ? AppTheme.danger.opacity(0.05)
                  : status == .warning ? Color.orange.opacity(0.04)
                  : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.sage.opacity(0.08)).frame(height: 0.5)
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppTheme.sage.opacity(0.08)).frame(width: 0.5)
        }
    }

    // MARK: - MONEY tab

    private var moneyPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                monetizationSection
                TechDivider()
                unlockCodesSection
                TechDivider()
                discountCodesSection
                TechDivider()
                notificationsSection
                TechDivider()
                cloudSaveSection
            }
        }
    }

    // ── Game Center ─────────────────────────────────────────────────────────

    private var gameCenterSection: some View {
        _ = refreshID
        let auth       = gcManager.isAuthenticated
        let name       = gcManager.displayName
        let hasAvatar  = gcManager.playerAvatar != nil
        let lastScore  = gcManager.lastSubmittedScore
        let lbID       = GameCenterManager.leaderboardID
        let rankLabel: String = {
            guard let fb = gcManager.rankFeedback else { return "—" }
            switch fb {
            case .newRecord:        return "#1 ★"
            case .topPercent(let p): return "TOP \(p)%"
            case .ranked(let r):    return "#\(r)"
            }
        }()

        return VStack(spacing: 0) {
            sectionHeader("GAME CENTER")

            // Row 1 — auth + player
            HStack(spacing: 0) {
                miniStatC("AUTH",   auth ? "YES" : "NO",
                          auth ? AppTheme.success : AppTheme.danger)
                statDivider()
                miniStat("PLAYER",  name.isEmpty ? "—" : String(name.prefix(12)).uppercased())
                statDivider()
                miniStatC("AVATAR", hasAvatar ? "LOADED" : "—",
                          hasAvatar ? AppTheme.success : AppTheme.textSecondary)
            }
            .padding(.vertical, 10)

            TechDivider()

            // Row 2 — leaderboard + last score + rank
            HStack(spacing: 0) {
                miniStat("LAST SCORE", lastScore.map { "\($0)" } ?? "—")
                statDivider()
                miniStatC("RANK FB", rankLabel,
                          gcManager.rankFeedback != nil ? AppTheme.accentPrimary : AppTheme.textSecondary)
            }
            .padding(.vertical, 10)

            // Leaderboard ID row
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.50))
                Text("LB ID: \(lbID)")
                    .font(AppTheme.mono(7))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            TechDivider()

            // Controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn("LEADERBOARD", icon: "chart.bar.fill", color: AppTheme.accentPrimary) {
                        gcManager.openLeaderboards()
                        showToast("Opening leaderboard…", style: .info)
                    }
                    scenarioBtn("DASHBOARD", icon: "gamecontroller.fill", color: AppTheme.sage) {
                        gcManager.openDashboard()
                        showToast("Opening GC dashboard…", style: .info)
                    }
                    if !auth {
                        scenarioBtn("AUTHENTICATE", icon: "person.crop.circle.badge.checkmark",
                                    color: AppTheme.success) {
                            gcManager.authenticate()
                            showToast("GC auth triggered…", style: .info)
                        }
                    }
                    scenarioBtn("CLEAR RANK", icon: "xmark.circle", color: AppTheme.textSecondary) {
                        gcManager.clearRankFeedback()
                        refreshID = UUID()
                        showToast("Rank feedback cleared")
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
    }

    // ── Progression ────────────────────────────────────────────────────────

    private var progressionSection: some View {
        VStack(spacing: 0) {
            sectionHeader("PROGRESSION")

            // Level stepper row
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    TechLabel(text: "ASTRONAUT LEVEL", color: AppTheme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(devLevel)")
                            .font(AppTheme.mono(40, weight: .black))
                            .foregroundStyle(AppTheme.textPrimary)
                            .monospacedDigit()
                        Text(rankLabel(for: devLevel))
                            .font(AppTheme.mono(9, weight: .semibold))
                            .foregroundStyle(AppTheme.accentPrimary)
                            .kerning(1)
                    }
                }
                .padding(.leading, 16)

                Spacer()

                HStack(spacing: 0) {
                    stepperBtn("minus", enabled: devLevel > 1)  { devLevel = max(1,  devLevel - 1) }
                    Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 32)
                    stepperBtn("plus",  enabled: devLevel < 20) { devLevel = min(20, devLevel + 1) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.sage.opacity(0.22), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .padding(.trailing, 16)
            }
            .padding(.vertical, 14)

            // Apply button
            Button(action: applyLevelJump) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                    Text("APPLY LEVEL JUMP  →  LVL \(devLevel)")
                        .font(AppTheme.mono(10, weight: .bold))
                        .kerning(1.2)
                }
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(devLevel == profile.level
                            ? AppTheme.backgroundSecondary
                            : AppTheme.accentPrimary)
                .foregroundStyle(devLevel == profile.level
                                 ? AppTheme.textSecondary
                                 : .black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .disabled(devLevel == profile.level)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Live stats bar
            HStack(spacing: 0) {
                miniStat("LEVEL",    "\(profile.level)")
                statDivider()
                miniStat("MISSIONS", "\(profile.uniqueCompletions)")
                statDivider()
                miniStat("AVG EFF",  "\(profile.averageEfficiencyPercent)%")
                statDivider()
                miniStat("PASSES",   "\(PassStore.all.count)/\(Planet.catalog.count)")
            }
            .padding(.bottom, 4)

            TechDivider()

            // Current position summary
            let prog = profile.progression
            HStack(spacing: 0) {
                miniStat("SECTOR",  prog.currentSector.name.components(separatedBy: " ").first ?? prog.currentSector.name)
                statDivider()
                miniStat("PLANET",  prog.currentPlanet.name)
                statDivider()
                miniStat("NEXT",    prog.nextPlanet?.name ?? "—")
                statDivider()
                miniStat("MISSION", prog.activeMission.map { "#\($0.id)" } ?? "ALL DONE")
            }
            .padding(.bottom, 16)
        }
        .background(AppTheme.surface)
    }

    // ── Monetization panel (expanded entitlement + paywall testing) ────────

    private var monetizationSection: some View {
        VStack(spacing: 0) {
            moneyStatusSection
            TechDivider()
            moneyControlsSection
            TechDivider()
            paywallTestSection
            TechDivider()
            ctaPreviewSection
            TechDivider()
            moneyScenarioSection
            TechDivider()
            skMockSection
        }
    }

    // MARK: Money sub-sections

    private var moneyStatusSection: some View {
        _ = refreshID
        let store      = EntitlementStore.shared
        let isPremium  = store.isPremium
        let intro      = store.freeIntroCompleted
        let remaining  = store.remainingToday
        let canPlay    = store.canPlay(LevelGenerator.levels.first ?? LevelGenerator.levels[0])
        let blocked    = store.reasonBlocked
        let skProduct  = storeKit.product
        let skState    = storeKit.purchaseState
        let skill      = PlayerSkillTracker.shared.skillScore
        let session    = SessionTracker.shared
        let frustrated = FrustrationGuard.isFrustrated()
        let lastCtx    = MonetizationAnalytics.shared.lastShownContext
        let lastShownAt = MonetizationAnalytics.shared.lastShownAt
        let lastShownLabel: String = {
            guard let t = lastShownAt else { return "—" }
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm:ss"
            return fmt.string(from: t)
        }()
        let skLabel: String = {
            switch skState {
            case .idle:       return skProduct != nil ? "LOADED" : "—"
            case .loading:    return "LOADING"
            case .purchasing: return "BUYING"
            case .restoring:  return "RESTORE"
            case .success:    return "SUCCESS"
            case .failed:     return "FAILED"
            }
        }()

        let cooldownRemaining = store.remainingCooldown
        let cooldownLabel: String = {
            guard !store.canPlayNow else { return "—" }
            let total = Int(cooldownRemaining)
            let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
            return String(format: "%02d:%02d:%02d", h, m, s)
        }()
        let nextDateLabel: String = {
            guard let d = store.nextPlayableDate else { return "—" }
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss 'on' dd/MM"
            return fmt.string(from: d)
        }()

        return VStack(spacing: 0) {
            sectionHeader("MONETIZATION  ·  STATUS")

            // Row 1 — plan + intro counter + gate state
            HStack(spacing: 0) {
                miniStatC("PLAN",     isPremium ? "PREMIUM" : "FREE",
                          isPremium ? AppTheme.accentPrimary : AppTheme.sage)
                statDivider()
                miniStat("INTRO",     "\(intro)/\(EntitlementStore.freeIntroLimit)")
                statDivider()
                miniStatC("GATE",
                          isPremium ? "∞" : store.isInIntroPhase ? "INTRO"
                              : store.canPlayNow ? "OPEN" : "LOCKED",
                          isPremium ? AppTheme.accentPrimary
                              : store.isInIntroPhase ? AppTheme.sage
                              : store.canPlayNow ? AppTheme.success : AppTheme.danger)
                statDivider()
                miniStat("REMAIN",    isPremium ? "∞" : "\(remaining)")
            }
            .padding(.vertical, 10)

            TechDivider()

            // Row 2 — daily counter + cooldown + phase
            HStack(spacing: 0) {
                miniStatC("CAN PLAY", canPlay ? "YES" : "NO",
                          canPlay ? AppTheme.success : AppTheme.danger)
                statDivider()
                miniStatC("PHASE",    store.isInIntroPhase ? "INTRO" : "PHASE 2",
                          store.isInIntroPhase ? AppTheme.accentSecondary : AppTheme.sage)
                statDivider()
                miniStatC("DAILY",
                          store.isPremium ? "∞" : store.isInIntroPhase ? "—"
                              : "\(store.dailyPlaysUsed)/\(EntitlementStore.dailyLimit)",
                          store.dailyPlaysUsed >= EntitlementStore.dailyLimit ? AppTheme.danger
                              : store.dailyPlaysUsed > 0 ? Color.orange : AppTheme.textSecondary)
                statDivider()
                miniStatC("COOLDOWN", cooldownLabel,
                          store.canPlayNow ? AppTheme.textSecondary : AppTheme.danger)
            }
            .padding(.vertical, 10)

            // nextPlayableDate row
            if store.nextPlayableDate != nil {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.danger)
                    Text("NEXT PLAYABLE: \(nextDateLabel)")
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.danger.opacity(0.80))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
            }

            if let reason = blocked {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.danger)
                    Text(reason)
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.danger.opacity(0.80))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
            }

            // Clock-hardening diagnostics
            #if DEBUG
            if store.nextPlayableDate != nil {
                let diag = store.clockDiagnostics
                VStack(spacing: 2) {
                    if diag.clockManipulationSuspected {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.yellow)
                            Text("CLOCK MANIPULATION SUSPECTED")
                                .font(AppTheme.mono(7))
                                .foregroundStyle(.yellow)
                            Spacer()
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                        let uptimeH = diag.uptimeElapsed.map { String(format: "%.0fs (%.1fh)", $0, $0 / 3600) } ?? "—"
                        Text("UPTIME ELAPSED: \(uptimeH)  WALL:\(diag.wallClockSaysExpired ? "EXP" : "ACT")  UP:\(diag.uptimeSaysExpired ? "EXP" : "ACT")")
                            .font(AppTheme.mono(7))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.70))
                        Spacer()
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
            }
            #endif

            TechDivider()

            // Row 3 — skill & frustration
            HStack(spacing: 0) {
                miniStatC("SKILL",   String(format: "%.2f", skill),
                          skill < 0.35 ? AppTheme.danger : AppTheme.success)
                statDivider()
                miniStatC("FRUSTRD", frustrated ? "YES" : "NO",
                          frustrated ? AppTheme.danger : AppTheme.textSecondary)
                statDivider()
                miniStat("STREAK",  "\(session.streakCount)")
                statDivider()
                miniStatC("FAILS",  "\(session.failuresInSession)",
                          session.failuresInSession >= 3 ? AppTheme.danger : AppTheme.textSecondary)
            }
            .padding(.vertical, 10)

            TechDivider()

            // Row 4 — StoreKit, last paywall context + timestamp
            HStack(spacing: 0) {
                miniStat("SK",        skLabel)
                statDivider()
                miniStat("LAST CTX",  lastCtx.map { $0.analyticsName.uppercased() } ?? "—")
                statDivider()
                miniStat("SHOWN AT",  lastShownLabel)
            }
            .padding(.vertical, 10)

            if let p = skProduct {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.success)
                    Text("\(p.id)  ·  \(p.displayPrice)")
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
            }
        }
        .background(AppTheme.surface)
    }

    private var moneyControlsSection: some View {
        let store     = EntitlementStore.shared
        let isPremium = store.isPremium

        return VStack(spacing: 0) {
            sectionHeader("CONTROLS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Toggle plan
                    scenarioBtn(
                        isPremium ? "SET FREE" : "SET PREMIUM",
                        icon: isPremium ? "lock.open" : "star.fill",
                        color: isPremium ? AppTheme.danger : AppTheme.accentPrimary
                    ) {
                        store.setPremium(!isPremium)
                        refreshID = UUID()
                        showToast(isPremium ? "Plan → FREE" : "Plan → PREMIUM", style: .info)
                    }
                    // Reset counters
                    scenarioBtn("RESET INTRO", icon: "arrow.counterclockwise", color: AppTheme.sage) {
                        store.resetIntroCount()
                        refreshID = UUID()
                        showToast("Intro count → 0")
                    }
                    scenarioBtn("CLEAR COOLDOWN", icon: "arrow.counterclockwise", color: AppTheme.sage) {
                        store.clearCooldown()
                        refreshID = UUID()
                        showToast("Cooldown cleared → can play")
                    }
                    scenarioBtn("FORCE COOLDOWN", icon: "lock.fill", color: AppTheme.danger) {
                        store.forceCooldown()
                        refreshID = UUID()
                        showToast("24h cooldown armed", style: .warning)
                    }
                    // Set daily plays count explicitly (0–dailyLimit)
                    ForEach(0...EntitlementStore.dailyLimit, id: \.self) { n in
                        scenarioBtn("DAY \(n)/\(EntitlementStore.dailyLimit)",
                                    icon: n == 0 ? "arrow.counterclockwise"
                                        : n < EntitlementStore.dailyLimit ? "circle.fill"
                                        : "lock.fill",
                                    color: n == EntitlementStore.dailyLimit ? AppTheme.danger
                                        : n > 0 ? Color.orange : AppTheme.sage) {
                            store.setDailyAttemptsUsed(n)
                            refreshID = UUID()
                            showToast("Daily → \(n)/\(EntitlementStore.dailyLimit)",
                                      style: n == EntitlementStore.dailyLimit ? .warning : .info)
                        }
                    }
                    // Set intro counter explicitly
                    ForEach(0...EntitlementStore.freeIntroLimit, id: \.self) { n in
                        scenarioBtn("INTRO \(n)/\(EntitlementStore.freeIntroLimit)", icon: "number",
                                    color: n == EntitlementStore.freeIntroLimit ? AppTheme.danger : AppTheme.textSecondary) {
                            store.setFreeIntroCompleted(n)
                            if n < EntitlementStore.freeIntroLimit { store.clearCooldown() }
                            refreshID = UUID()
                            showToast("Intro → \(n)/\(EntitlementStore.freeIntroLimit)")
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
    }

    private var paywallTestSection: some View {
        let store = EntitlementStore.shared

        return VStack(spacing: 0) {
            sectionHeader("PAYWALL TEST")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn("POST-VICTORY", icon: "checkmark.circle.fill", color: AppTheme.success) {
                        devPaywallContext = .postVictory
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                    }
                    scenarioBtn("SECTOR", icon: "star.fill", color: AppTheme.accentPrimary) {
                        devPaywallContext = .sectorExcitement
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                    }
                    scenarioBtn("NEXT BLOCKED", icon: "lock.fill", color: AppTheme.danger) {
                        // Force Phase 2 + 24h cooldown active
                        store.forceCooldown()
                        devPaywallContext = .nextMissionBlocked
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                        refreshID = UUID()
                    }
                    scenarioBtn("HOME CTA", icon: "house.fill", color: AppTheme.sage) {
                        devPaywallContext = .homeSoftCTA
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
    }

    private var ctaPreviewSection: some View {
        VStack(spacing: 0) {
            sectionHeader("CTA PREVIEW")

            VStack(spacing: 12) {
                // Home upgrade pill
                VStack(alignment: .leading, spacing: 4) {
                    TechLabel(text: "HOME CTA", color: AppTheme.textSecondary)
                    HStack(spacing: 8) {
                        Image(systemName: "infinity").font(.system(size: 10, weight: .bold))
                        Text("UNLIMITED ACCESS").font(AppTheme.mono(9, weight: .bold)).kerning(1.5)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 34).padding(.horizontal, 14)
                    .background(AppTheme.accentPrimary.opacity(0.07))
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.80))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.accentPrimary.opacity(0.20), lineWidth: 0.5))
                }

                // Post-mission banner
                VStack(alignment: .leading, spacing: 4) {
                    TechLabel(text: "POST-MISSION BANNER", color: AppTheme.textSecondary)
                    HStack(spacing: 8) {
                        Image(systemName: "infinity").font(.system(size: 10, weight: .bold))
                        Text("CONTINUE WITHOUT LIMITS").font(AppTheme.mono(9, weight: .bold)).kerning(1.5)
                        Spacer()
                        Text("UPGRADE").font(AppTheme.mono(8))
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 36).padding(.horizontal, 16)
                    .background(AppTheme.accentPrimary.opacity(0.09))
                    .foregroundStyle(AppTheme.accentPrimary)
                }

                // Locked sector nudge
                VStack(alignment: .leading, spacing: 4) {
                    TechLabel(text: "LOCKED SECTOR CTA", color: AppTheme.textSecondary)
                    HStack(spacing: 6) {
                        Image(systemName: "infinity").font(.system(size: 9, weight: .bold))
                        Text("UNLIMITED ACCESS").font(AppTheme.mono(8, weight: .bold)).kerning(1.5)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).padding(.horizontal, 28).padding(.vertical, 10)
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.65))
                    .background(AppTheme.accentPrimary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
    }

    private var moneyScenarioSection: some View {
        let store = EntitlementStore.shared

        return VStack(spacing: 0) {
            sectionHeader("SCENARIO SIMULATION")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 1. Brand-new player — Phase 1, 0 intro used
                    scenarioBtn("FIRST-TIME USER", icon: "person.fill", color: AppTheme.sage) {
                        store.setPremium(false)
                        store.resetIntroCount()
                        store.resetDailyCount()
                        refreshID = UUID()
                        showToast("Intro 0/\(EntitlementStore.freeIntroLimit) · Phase 1")
                    }
                    // 2. Phase 1, 2 intro missions used (1 remaining)
                    scenarioBtn("2 INTRO USED", icon: "2.circle.fill", color: AppTheme.sage) {
                        store.setPremium(false)
                        store.setFreeIntroCompleted(2)
                        store.clearCooldown()
                        refreshID = UUID()
                        showToast("Intro 2/\(EntitlementStore.freeIntroLimit) · 1 slot left")
                    }
                    // 3. Phase 2 — just entered, cooldown NOT yet armed (can play once more)
                    scenarioBtn("JUST FINISHED 3rd", icon: "3.circle.fill", color: .orange) {
                        store.setPremium(false)
                        store.setFreeIntroCompleted(EntitlementStore.freeIntroLimit)
                        store.clearCooldown()
                        StoryStore.markUnseen("story_onboarding_complete")
                        refreshID = UUID()
                        showToast("3rd mission done · story pending · gate active")
                    }
                    // 3b. Phase 2 — 1 play used (2 remaining today)
                    scenarioBtn("DAY: 1/3 USED", icon: "1.circle.fill", color: Color.orange.opacity(0.7)) {
                        store.setPremium(false)
                        store.setDailyAttemptsUsed(1)
                        refreshID = UUID()
                        showToast("Phase 2 · 1/3 plays used · 2 remaining")
                    }
                    // 3c. Phase 2 — 2 plays used (1 remaining today)
                    scenarioBtn("DAY: 2/3 USED", icon: "2.circle.fill", color: Color.orange) {
                        store.setPremium(false)
                        store.setDailyAttemptsUsed(2)
                        refreshID = UUID()
                        showToast("Phase 2 · 2/3 plays used · 1 remaining")
                    }
                    // 3d. Phase 2 — cooldown just expired (fresh window, can play again)
                    scenarioBtn("COOLDOWN EXPIRED", icon: "checkmark.circle", color: AppTheme.success) {
                        store.setPremium(false)
                        store.setFreeIntroCompleted(EntitlementStore.freeIntroLimit)
                        store.clearCooldown()
                        refreshID = UUID()
                        showToast("Cooldown expired · gate OPEN", style: .success)
                    }
                    // 4. Phase 2 — cooldown active (hard blocked)
                    scenarioBtn("BLOCKED (24H)", icon: "hand.raised.fill", color: AppTheme.danger) {
                        store.setPremium(false)
                        store.forceCooldown()
                        refreshID = UUID()
                        showToast("24h cooldown armed · BLOCKED", style: .warning)
                    }
                    // 5. Premium
                    scenarioBtn("PREMIUM", icon: "star.fill", color: AppTheme.accentPrimary) {
                        store.setPremium(true)
                        refreshID = UUID()
                        showToast("Plan → PREMIUM", style: .info)
                    }
                    #if DEBUG
                    scenarioBtn("STRUGGLING FREE", icon: "exclamationmark.triangle.fill", color: AppTheme.danger) {
                        // Simulate a frustrated free player with active cooldown
                        store.forceCooldown()
                        PlayerSkillTracker.shared.overrideSkillScore(0.12)
                        SessionTracker.shared.overrideFailuresInSession(4)
                        SessionTracker.shared.overrideStreakCount(0)
                        devPaywallContext = .nextMissionBlocked
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                        refreshID = UUID()
                        showToast("Skill → 0.12 · Failures → 4 · Frustrated = YES", style: .warning)
                    }
                    scenarioBtn("HIGH-SKILL FREE", icon: "bolt.fill", color: AppTheme.success) {
                        // Simulate a skilled free player mid-session
                        store.setPremium(false)
                        store.setFreeIntroCompleted(EntitlementStore.freeIntroLimit)
                        store.resetDailyCount()
                        PlayerSkillTracker.shared.overrideSkillScore(0.88)
                        SessionTracker.shared.overrideFailuresInSession(0)
                        SessionTracker.shared.overrideStreakCount(5)
                        refreshID = UUID()
                        showToast("Skill → 0.88 · Streak → 5 · Frustrated = NO", style: .success)
                    }
                    #endif
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
    }

    private var skMockSection: some View {
        VStack(spacing: 0) {
            sectionHeader("STOREKIT MOCK")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    #if DEBUG
                    scenarioBtn("SIM SUCCESS", icon: "checkmark.circle.fill", color: AppTheme.success) {
                        storeKit.simulatePurchaseSuccess()
                        refreshID = UUID()
                    }
                    scenarioBtn("SIM FAIL", icon: "xmark.circle.fill", color: AppTheme.danger) {
                        storeKit.simulatePurchaseFailed()
                    }
                    #endif
                    scenarioBtn("LOAD PRODUCT", icon: "arrow.down.circle", color: AppTheme.textSecondary) {
                        Task { await storeKit.loadProduct() }
                    }
                    scenarioBtn("RESTORE SK", icon: "arrow.clockwise", color: AppTheme.sage) {
                        Task { await storeKit.restorePurchases() }
                    }
                    scenarioBtn("CLEAR STATE", icon: "xmark", color: AppTheme.textSecondary) {
                        storeKit.clearState()
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
    }

    // ── Unlock Codes ────────────────────────────────────────────────────────

    private var unlockCodesSection: some View {
        let store      = UnlockCodeStore.shared
        let entitle    = EntitlementStore.shared
        return VStack(spacing: 0) {
            sectionHeader("UNLOCK CODES  ·  GRANT FULL ACCESS")

            // Active code badge
            if entitle.premiumByCode, let codeID = entitle.activeCodeID {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.success)
                    Text("ACTIVE: \(codeID)")
                        .font(AppTheme.mono(9, weight: .black))
                        .foregroundStyle(AppTheme.success)
                    Spacer()
                    Button("REVOKE") {
                        entitle.revokeCodePremium()
                        refreshID = UUID()
                        showToast("Code premium revoked", style: .warning)
                    }
                    .font(AppTheme.mono(7, weight: .bold))
                    .foregroundStyle(AppTheme.danger)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(AppTheme.danger.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(AppTheme.success.opacity(0.06))
                TechDivider()
            }

            // Code list
            if store.codes.isEmpty {
                HStack {
                    Text("No unlock codes — add one below")
                        .font(AppTheme.mono(8))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.codes) { code in
                        unlockCodeRow(code)
                        if code.id != store.codes.last?.id {
                            Rectangle().fill(AppTheme.sage.opacity(0.10)).frame(height: 0.5)
                        }
                    }
                }
            }

            TechDivider()

            // Test / simulate row
            HStack(spacing: 8) {
                TextField("Test code…", text: $unlockTestInput)
                    .font(AppTheme.mono(10))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(.leading, 12).padding(.vertical, 8)
                    .background(AppTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                Button("VALIDATE") {
                    switch store.validate(unlockTestInput) {
                    case .valid(let c):  unlockTestResult = "✓ \(c.code) — \(c.type.label)"
                    case .invalid:       unlockTestResult = "✗ Invalid"
                    case .inactive:      unlockTestResult = "✗ Inactive"
                    case .expired:       unlockTestResult = "✗ Expired"
                    case .exhausted:     unlockTestResult = "✗ Exhausted"
                    }
                }
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(AppTheme.accentPrimary)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(AppTheme.accentPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                Button("APPLY") {
                    switch store.validate(unlockTestInput) {
                    case .valid:
                        store.redeem(unlockTestInput)
                        refreshID = UUID()
                        showToast("Unlock code applied — premium granted", style: .success)
                    case .invalid:   showToast("Invalid code", style: .fail)
                    case .inactive:  showToast("Code inactive", style: .fail)
                    case .expired:   showToast("Code expired", style: .fail)
                    case .exhausted: showToast("Usage limit reached", style: .fail)
                    }
                }
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(AppTheme.success)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(AppTheme.success.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if !unlockTestResult.isEmpty {
                HStack {
                    Text(unlockTestResult)
                        .font(AppTheme.mono(8))
                        .foregroundStyle(unlockTestResult.hasPrefix("✓") ? AppTheme.success : AppTheme.danger)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }

            TechDivider()

            // Controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn(showAddUnlockCodeForm ? "CANCEL" : "ADD CODE",
                                icon: showAddUnlockCodeForm ? "xmark" : "plus",
                                color: showAddUnlockCodeForm ? AppTheme.danger : AppTheme.success) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            showAddUnlockCodeForm.toggle()
                        }
                    }
                    if !store.codes.isEmpty {
                        scenarioBtn("DELETE ALL", icon: "trash.fill", color: AppTheme.danger) {
                            store.deleteAll()
                            showToast("All unlock codes deleted", style: .warning)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)

            if showAddUnlockCodeForm {
                addUnlockCodeForm
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.surface)
        .animation(.spring(response: 0.30, dampingFraction: 0.80), value: showAddUnlockCodeForm)
    }

    private func unlockCodeRow(_ code: UnlockCode) -> some View {
        let store = UnlockCodeStore.shared
        return HStack(spacing: 8) {
            Circle()
                .fill(code.isActive && !code.isExpired && !code.isExhausted
                      ? AppTheme.success : AppTheme.danger)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(code.code)
                    .font(AppTheme.mono(10, weight: .black))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    Text(code.type.label)
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary)
                    if let exp = code.expiresAt {
                        let fmt: DateFormatter = {
                            let f = DateFormatter(); f.dateFormat = "dd/MM/yy"; return f
                        }()
                        Text("EXP \(fmt.string(from: exp))")
                            .font(AppTheme.mono(7))
                            .foregroundStyle(code.isExpired ? AppTheme.danger : AppTheme.textSecondary.opacity(0.55))
                    }
                    if let max = code.maxUses {
                        Text("USES \(code.usesCount)/\(max)")
                            .font(AppTheme.mono(7))
                            .foregroundStyle(code.isExhausted ? AppTheme.danger : AppTheme.textSecondary.opacity(0.55))
                    }
                    if let note = code.note, !note.isEmpty {
                        Text("· \(note)")
                            .font(AppTheme.mono(7))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button(code.isActive ? "OFF" : "ON") {
                    store.toggleActive(code)
                    refreshID = UUID()
                }
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(code.isActive ? AppTheme.sage : AppTheme.success)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background((code.isActive ? AppTheme.sage : AppTheme.success).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button("RESET") {
                    store.resetUsage(code)
                    refreshID = UUID()
                }
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(AppTheme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button(action: { store.delete(code); refreshID = UUID() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.danger)
                        .padding(6)
                        .background(AppTheme.danger.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var addUnlockCodeForm: some View {
        let store = UnlockCodeStore.shared
        return VStack(alignment: .leading, spacing: 0) {
            TechDivider()
            sectionHeader("NEW UNLOCK CODE")

            VStack(spacing: 12) {
                // Code text
                HStack(spacing: 0) {
                    Text("CODE")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("PRESS2024", text: $newUnlockCodeText)
                        .font(AppTheme.mono(11, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
                .padding(.horizontal, 16)

                // Dev note
                HStack(spacing: 0) {
                    Text("NOTE")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("Press copy, reviewer, etc.", text: $newUnlockCodeNote)
                        .font(AppTheme.mono(10))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.70))
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16)

                // Expiry toggle
                Toggle(isOn: $newUnlockCodeHasExpiry) {
                    Text("EXPIRY")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .tint(AppTheme.accentPrimary)
                .padding(.horizontal, 16)

                if newUnlockCodeHasExpiry {
                    DatePicker("", selection: $newUnlockCodeExpiry, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(AppTheme.accentPrimary)
                        .padding(.horizontal, 16)
                        .labelsHidden()
                }

                // Usage limit toggle
                Toggle(isOn: $newUnlockCodeHasLimit) {
                    Text("USAGE LIMIT")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .tint(AppTheme.accentPrimary)
                .padding(.horizontal, 16)

                if newUnlockCodeHasLimit {
                    Stepper(value: $newUnlockCodeLimit, in: 1...999) {
                        Text("Max uses: \(newUnlockCodeLimit)")
                            .font(AppTheme.mono(9))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                }

                // Create button
                Button(action: {
                    let trimmed = newUnlockCodeText.trimmingCharacters(in: .whitespaces).uppercased()
                    guard !trimmed.isEmpty else {
                        showToast("Code text is empty", style: .fail); return
                    }
                    let code = UnlockCode(
                        code:      trimmed,
                        type:      .fullUnlock,
                        isActive:  true,
                        expiresAt: newUnlockCodeHasExpiry ? newUnlockCodeExpiry : nil,
                        maxUses:   newUnlockCodeHasLimit  ? newUnlockCodeLimit  : nil,
                        usesCount: 0,
                        note:      newUnlockCodeNote.isEmpty ? nil : newUnlockCodeNote
                    )
                    store.add(code)
                    refreshID = UUID()
                    newUnlockCodeText = ""
                    newUnlockCodeNote = ""
                    withAnimation { showAddUnlockCodeForm = false }
                    showToast("\(trimmed) created (FULL UNLOCK)", style: .success)
                }) {
                    Text("CREATE UNLOCK CODE")
                        .font(AppTheme.mono(10, weight: .black)).kerning(1)
                        .foregroundStyle(newUnlockCodeText.isEmpty ? AppTheme.textSecondary : .black)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(newUnlockCodeText.isEmpty ? AppTheme.backgroundSecondary : AppTheme.success)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .disabled(newUnlockCodeText.isEmpty)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
    }

    // ── Discount Codes ──────────────────────────────────────────────────────

    private var discountCodesSection: some View {
        let store = DiscountStore.shared
        return VStack(spacing: 0) {
            sectionHeader("DISCOUNT CODES  ·  APP-LAYER SIMULATION")

            // Code list
            if store.codes.isEmpty {
                HStack {
                    Text("No codes — add one below")
                        .font(AppTheme.mono(8))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.codes) { code in
                        discountCodeRow(code)
                        if code.id != store.codes.last?.id {
                            Rectangle().fill(AppTheme.sage.opacity(0.10)).frame(height: 0.5)
                        }
                    }
                }
            }

            TechDivider()

            // Test row
            HStack(spacing: 8) {
                TextField("Test code…", text: $discountTestInput)
                    .font(AppTheme.mono(10))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(.leading, 12).padding(.vertical, 8)
                    .background(AppTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                Button("VALIDATE") {
                    let result = store.validate(discountTestInput)
                    switch result {
                    case .valid(let c):  discountTestResult = "✓ \(c.code) — \(c.percentageOff)% off"
                                         showToast("\(c.percentageOff)% off")
                    case .invalid:       discountTestResult = "✗ Invalid"
                    case .inactive:      discountTestResult = "✗ Inactive"
                    case .expired:       discountTestResult = "✗ Expired"
                    case .exhausted:     discountTestResult = "✗ Exhausted"
                    }
                }
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(AppTheme.accentPrimary)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(AppTheme.accentPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if !discountTestResult.isEmpty {
                HStack {
                    Text(discountTestResult)
                        .font(AppTheme.mono(8))
                        .foregroundStyle(discountTestResult.hasPrefix("✓") ? AppTheme.success : AppTheme.danger)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }

            TechDivider()

            // Add / delete-all controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn(showAddCodeForm ? "CANCEL" : "ADD CODE",
                                icon: showAddCodeForm ? "xmark" : "plus",
                                color: showAddCodeForm ? AppTheme.danger : AppTheme.success) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            showAddCodeForm.toggle()
                        }
                    }
                    if !store.codes.isEmpty {
                        scenarioBtn("DELETE ALL", icon: "trash.fill", color: AppTheme.danger) {
                            store.deleteAll()
                            showToast("All codes deleted", style: .warning)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)

            // Add-code form (collapsible)
            if showAddCodeForm {
                addCodeForm
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.surface)
        .animation(.spring(response: 0.30, dampingFraction: 0.80), value: showAddCodeForm)
    }

    private func discountCodeRow(_ code: DiscountCode) -> some View {
        let store = DiscountStore.shared
        return HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(code.isActive && !code.isExpired && !code.isExhausted
                      ? AppTheme.success : AppTheme.danger)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(code.code)
                    .font(AppTheme.mono(10, weight: .black))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 6) {
                    Text("\(code.percentageOff)% OFF")
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary)
                    if let exp = code.expiresAt {
                        let fmt: DateFormatter = {
                            let f = DateFormatter(); f.dateFormat = "dd/MM/yy"; return f
                        }()
                        Text("EXP \(fmt.string(from: exp))")
                            .font(AppTheme.mono(7))
                            .foregroundStyle(code.isExpired ? AppTheme.danger : AppTheme.textSecondary.opacity(0.55))
                    }
                    if let limit = code.usageLimit {
                        Text("USES \(code.usageCount)/\(limit)")
                            .font(AppTheme.mono(7))
                            .foregroundStyle(code.isExhausted ? AppTheme.danger : AppTheme.textSecondary.opacity(0.55))
                    }
                }
            }

            Spacer()

            // Per-code actions
            HStack(spacing: 4) {
                Button(code.isActive ? "OFF" : "ON") {
                    store.toggleActive(code)
                    refreshID = UUID()
                }
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(code.isActive ? AppTheme.sage : AppTheme.success)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background((code.isActive ? AppTheme.sage : AppTheme.success).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button("RESET") {
                    store.resetUsage(code)
                    refreshID = UUID()
                }
                .font(AppTheme.mono(7, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(AppTheme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button(action: { store.delete(code); refreshID = UUID() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.danger)
                        .padding(6)
                        .background(AppTheme.danger.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var addCodeForm: some View {
        let store = DiscountStore.shared
        return VStack(alignment: .leading, spacing: 0) {
            TechDivider()
            sectionHeader("NEW CODE")

            VStack(spacing: 12) {
                // Code text
                HStack(spacing: 0) {
                    Text("CODE")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("SIGNAL25", text: $newCodeText)
                        .font(AppTheme.mono(11, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
                .padding(.horizontal, 16)

                // Percentage
                HStack(spacing: 8) {
                    Text("% OFF")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    Slider(value: Binding(
                        get: { Double(newCodePct) },
                        set: { newCodePct = Int($0) }
                    ), in: 1...100, step: 1)
                    .tint(AppTheme.accentPrimary)
                    Text("\(newCodePct)%")
                        .font(AppTheme.mono(11, weight: .black))
                        .foregroundStyle(AppTheme.accentPrimary)
                        .frame(width: 36, alignment: .trailing)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)

                // Expiry toggle
                HStack(spacing: 8) {
                    Toggle(isOn: $newCodeHasExpiry) {
                        Text("EXPIRY")
                            .font(AppTheme.mono(8, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .tint(AppTheme.accentPrimary)
                    .padding(.horizontal, 16)
                }
                if newCodeHasExpiry {
                    DatePicker("", selection: $newCodeExpiry, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(AppTheme.accentPrimary)
                        .padding(.horizontal, 16)
                        .labelsHidden()
                }

                // Usage limit toggle
                HStack(spacing: 8) {
                    Toggle(isOn: $newCodeHasLimit) {
                        Text("USAGE LIMIT")
                            .font(AppTheme.mono(8, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .tint(AppTheme.accentPrimary)
                    .padding(.horizontal, 16)
                }
                if newCodeHasLimit {
                    Stepper(value: $newCodeLimit, in: 1...999) {
                        Text("Max uses: \(newCodeLimit)")
                            .font(AppTheme.mono(9))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                }

                // Create button
                Button(action: {
                    let trimmed = newCodeText.trimmingCharacters(in: .whitespaces).uppercased()
                    guard !trimmed.isEmpty else {
                        showToast("Code text is empty", style: .fail); return
                    }
                    let code = DiscountCode(
                        code:          trimmed,
                        percentageOff: newCodePct,
                        isActive:      true,
                        expiresAt:     newCodeHasExpiry ? newCodeExpiry : nil,
                        usageLimit:    newCodeHasLimit  ? newCodeLimit  : nil,
                        usageCount:    0
                    )
                    store.add(code)
                    refreshID = UUID()
                    newCodeText = ""
                    withAnimation { showAddCodeForm = false }
                    showToast("\(trimmed) created (\(newCodePct)% off)", style: .success)
                }) {
                    Text("CREATE CODE")
                        .font(AppTheme.mono(10, weight: .black)).kerning(1)
                        .foregroundStyle(newCodeText.isEmpty ? AppTheme.textSecondary : .black)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(newCodeText.isEmpty ? AppTheme.backgroundSecondary : AppTheme.success)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .disabled(newCodeText.isEmpty)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
    }

    // ── Notifications ───────────────────────────────────────────────────────

    private var notificationsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("NOTIFICATIONS")

            // Status row
            HStack(spacing: 0) {
                miniStatC("PERMISSION", notifStatusLabel,
                          notifStatusLabel == "AUTHORIZED" ? AppTheme.success
                              : notifStatusLabel == "DENIED" ? AppTheme.danger
                              : AppTheme.textSecondary)
                statDivider()
                miniStat("PENDING", "\(notifPendingIDs.count)")
            }
            .padding(.vertical, 10)

            // Pending IDs list
            if !notifPendingIDs.isEmpty {
                ForEach(notifPendingIDs, id: \.self) { id in
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AppTheme.accentPrimary.opacity(0.70))
                        Text(id)
                            .font(AppTheme.mono(7))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.65))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }
            }

            TechDivider()

            // Controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn("REQUEST PERMISSION", icon: "bell.badge", color: AppTheme.accentPrimary) {
                        Task {
                            let granted = await NotificationManager.shared.requestPermissionIfNeeded()
                            showToast(granted ? "Permission granted" : "Permission denied",
                                      style: granted ? .success : .fail)
                            await refreshNotifState()
                        }
                    }
                    scenarioBtn("TEST (10s)", icon: "bell.and.waves.left.and.right", color: AppTheme.sage) {
                        NotificationManager.shared.scheduleTest(
                            after: 10,
                            language: settings.language
                        )
                        showToast("Test notification in 10s", style: .info)
                        Task { await refreshNotifState() }
                    }
                    scenarioBtn("CANCEL ALL", icon: "bell.slash.fill", color: AppTheme.danger) {
                        NotificationManager.shared.cancelAll()
                        showToast("All notifications cancelled", style: .warning)
                        Task { await refreshNotifState() }
                    }
                    scenarioBtn("REFRESH", icon: "arrow.clockwise", color: AppTheme.textSecondary) {
                        Task { await refreshNotifState() }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
        .task { await refreshNotifState() }
    }

    private func refreshNotifState() async {
        let status = await NotificationManager.shared.currentStatus()
        notifStatusLabel = switch status {
            case .authorized:   "AUTHORIZED"
            case .denied:       "DENIED"
            case .provisional:  "PROVISIONAL"
            case .notDetermined: "NOT SET"
            default:            "UNKNOWN"
        }
        notifPendingIDs = await NotificationManager.shared.pendingIDs()
    }

    // ── Cloud save ─────────────────────────────────────────────────────────

    private var cloudSaveSection: some View {
        let syncing  = cloudSave.isSyncing
        let syncDate = cloudSave.lastSyncedAt
        let gcAuth   = gcManager.isAuthenticated
        let syncLabel: String = {
            guard let d = syncDate else { return "NEVER" }
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm:ss"
            return fmt.string(from: d)
        }()

        return VStack(spacing: 0) {
            sectionHeader("CLOUD SAVE  ·  GKSavedGame")

            // Status row
            HStack(spacing: 0) {
                miniStatC("GC AUTH",   gcAuth ? "YES" : "NO",
                          gcAuth ? AppTheme.success : AppTheme.danger)
                statDivider()
                miniStatC("STATUS",    syncing ? "SYNCING…" : "IDLE",
                          syncing ? Color.orange : AppTheme.textSecondary)
                statDivider()
                miniStat("LAST SYNC",  syncLabel)
            }
            .padding(.vertical, 10)

            TechDivider()

            // Action buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    #if DEBUG
                    scenarioBtn("FORCE SAVE", icon: "icloud.and.arrow.up", color: AppTheme.accentPrimary) {
                        cloudSave.devForceSave()
                    }
                    scenarioBtn("LOAD CLOUD", icon: "icloud.and.arrow.down", color: AppTheme.sage) {
                        cloudSave.devForceLoad()
                    }
                    #endif
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
    }

    // ── Coherence report ───────────────────────────────────────────────────

    private var coherenceSection: some View {
        let prog         = profile.progression
        let allPasses    = PassStore.all
        let unlockedIDs  = prog.unlockedSectorIDs

        // Coherence analysis
        // devGrant: has pass but sector not complete
        let devGrantedPasses = SpatialRegion.catalog.filter { sector in
            let idx = sector.id - 1
            return PassStore.hasPass(for: idx) && !sector.levels.allSatisfy { profile.hasCompleted(levelId: $0.id) }
        }
        // missingPasses: sector complete but no pass
        let missingPasses = SpatialRegion.catalog.filter { sector in
            let idx = sector.id - 1
            return !PassStore.hasPass(for: idx) && sector.levels.allSatisfy { profile.hasCompleted(levelId: $0.id) }
        }
        let status: (label: String, color: Color, icon: String) = {
            if !missingPasses.isEmpty {
                return ("INVALID", AppTheme.danger, "xmark.circle.fill")
            } else if !devGrantedPasses.isEmpty {
                return ("WARNING", Color.orange, "exclamationmark.triangle.fill")
            } else {
                return ("COHERENT", AppTheme.success, "checkmark.seal.fill")
            }
        }()

        return VStack(spacing: 0) {
            sectionHeader("SYSTEM COHERENCE")

            // Status banner
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(status.color)
                Text(status.label)
                    .font(AppTheme.mono(12, weight: .black))
                    .foregroundStyle(status.color)
                    .kerning(1.5)
                Spacer()
                // Counts
                TechLabel(
                    text: "\(allPasses.count) PASS · \(unlockedIDs.count) SECTOR · LVL \(prog.playerLevel)",
                    color: AppTheme.textSecondary.opacity(0.60)
                )
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(status.color.opacity(0.05))

            TechDivider()

            // Field grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                coherenceField("PLAYER LEVEL",   "\(prog.playerLevel)")
                coherenceField("CURRENT SECTOR", prog.currentSector.name)
                coherenceField("CURRENT PLANET", prog.currentPlanet.name)
                coherenceField("NEXT TARGET",    prog.nextTargetSector?.name ?? "—")
                coherenceField("NEXT PLANET",    prog.nextPlanet?.name ?? "—")
                coherenceField("ACTIVE MISSION", prog.activeMission.map { "#\($0.id)" } ?? "ALL DONE")
                coherenceField("UNLOCKED SECTORS", "\(unlockedIDs.sorted().map { "S\($0)" }.joined(separator: " "))")
                coherenceField("PASSES HELD",    allPasses.map { $0.planetName.prefix(3) }.joined(separator: " "))
            }
            .padding(.vertical, 4)

            // Issue annotations
            if !missingPasses.isEmpty || !devGrantedPasses.isEmpty {
                TechDivider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(missingPasses, id: \.id) { sector in
                        issueAnnotation("⚠ S\(sector.id) \(sector.name): all levels done but no pass", color: AppTheme.danger)
                    }
                    ForEach(devGrantedPasses, id: \.id) { sector in
                        issueAnnotation("🔧 S\(sector.id) \(sector.name): pass dev-granted (incomplete sector)", color: Color.orange)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(AppTheme.danger.opacity(0.03))
            }
        }
        .background(AppTheme.surface)
    }

    private func coherenceField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TechLabel(text: label, color: AppTheme.textSecondary.opacity(0.60))
            Text(value)
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.sage.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func issueAnnotation(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AppTheme.mono(7))
            .foregroundStyle(color.opacity(0.80))
            .lineLimit(2)
    }

    // ── QA scenarios ───────────────────────────────────────────────────────

    private var qaScenarioSection: some View {
        VStack(spacing: 0) {
            sectionHeader("QA SCENARIOS")

            // Simulate sector complete buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SpatialRegion.catalog) { sector in
                        let planetIdx = sector.id - 1
                        let done      = PassStore.hasPass(for: planetIdx)
                        Button(action: {
                            ProgressionStore.devSimulateSectorComplete(sector.id)
                            devLevel  = ProgressionStore.profile.level
                            refreshID = UUID()
                        }) {
                            VStack(spacing: 2) {
                                Text("S\(sector.id)")
                                    .font(AppTheme.mono(8, weight: .black))
                                Text(sector.name.components(separatedBy: " ").first ?? "")
                                    .font(AppTheme.mono(6))
                            }
                            .foregroundStyle(done ? AppTheme.success : AppTheme.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(done ? AppTheme.success.opacity(0.08) : AppTheme.backgroundSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(done ? AppTheme.success.opacity(0.35) : AppTheme.sage.opacity(0.20), lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)

            TechDivider()

            // Bulk actions
            HStack(spacing: 8) {
                scenarioBtn("SYNC PASSES", icon: "arrow.triangle.2.circlepath", color: AppTheme.accentPrimary) {
                    ProgressionStore.devSyncPasses()
                    refreshID = UUID()
                    showToast("Passes synced")
                }
                scenarioBtn("REMOVE LATEST PASS", icon: "minus.circle", color: AppTheme.danger) {
                    if let last = PassStore.all.last {
                        let passes = PassStore.all.filter { $0.id != last.id }
                        PassStore.reset()
                        let p = ProgressionStore.profile
                        for pass in passes {
                            if let planet = Planet.catalog.first(where: { $0.id == pass.planetIndex }) {
                                PassStore.issue(planet: planet, profile: p)
                            }
                        }
                        TicketCache.shared.invalidateAll()
                        refreshID = UUID()
                        showToast("Pass removed: \(last.planetName)", style: .warning)
                    } else {
                        showToast("No pass to remove", style: .info)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(AppTheme.surface)
    }

    private func scenarioBtn(
        _ label: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
                Text(label).font(AppTheme.mono(8, weight: .bold)).kerning(0.6)
            }
            .frame(maxWidth: .infinity).frame(height: 36)
            .foregroundStyle(color)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(color.opacity(0.32), lineWidth: 0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    // ── Sector / pass grid ─────────────────────────────────────────────────

    private var sectorPassGrid: some View {
        VStack(spacing: 0) {
            sectionHeader("SECTORS  ·  PASSES")
            ForEach(Array(SpatialRegion.catalog.enumerated()), id: \.offset) { idx, sector in
                sectorRow(sector: sector)
                if idx < SpatialRegion.catalog.count - 1 { TechDivider() }
            }
        }
    }

    private func sectorRow(sector: SpatialRegion) -> some View {
        let planetIdx  = sector.id - 1
        let planet     = planetIdx < Planet.catalog.count ? Planet.catalog[planetIdx] : Planet.catalog[0]
        let hasPass    = PassStore.hasPass(for: planetIdx)
        let pass       = PassStore.all.first { $0.planetIndex == planetIdx }
        let unlocked   = profile.level >= sector.requiredPlayerLevel
        let completed  = sector.levels.allSatisfy { profile.hasCompleted(levelId: $0.id) }
        // Coherence: completed+pass ✅  incomplete+devGrant 🛠  done+missing ⚠️
        let coherenceIcon: String? = completed && !hasPass ? "exclamationmark.triangle.fill"
                                   : !completed && hasPass ? "wrench.fill"
                                   : nil
        let coherenceColor: Color  = completed && !hasPass ? .orange : AppTheme.sage.opacity(0.55)

        return HStack(spacing: 10) {
            // Sector badge
            Text("S\(sector.id)")
                .font(AppTheme.mono(9, weight: .black))
                .foregroundStyle(planet.color.opacity(unlocked ? 0.90 : 0.25))
                .frame(width: 22, alignment: .leading)

            // Name + range
            VStack(alignment: .leading, spacing: 2) {
                TechLabel(
                    text: sector.name,
                    color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.35)
                )
                TechLabel(
                    text: "LVL \(sector.levelRange.lowerBound)–\(sector.levelRange.upperBound)  ·  \(sector.levels.count) MISSIONS",
                    color: AppTheme.textSecondary.opacity(0.50)
                )
            }

            Spacer()

            // Coherence indicator
            if let icon = coherenceIcon {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(coherenceColor)
            }

            // Completion check
            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.success.opacity(0.70))
            }

            // Pass status — tappable to view rendered ticket; or grant button if absent
            if hasPass, let pass {
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        viewingPass = pass
                    }
                }) {
                    passGrantedBadge(color: planet.color)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    PassStore.issue(planet: planet, profile: profile)
                    refreshID = UUID()
                }) {
                    Text("GRANT PASS")
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(planet.color.opacity(unlocked ? 1.0 : 0.40))
                        .kerning(0.6)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(planet.color.opacity(unlocked ? 0.35 : 0.15), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.backgroundPrimary)
    }

    private func passGrantedBadge(color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark")
                .font(.system(size: 6, weight: .bold))
            Text("PASS")
                .font(AppTheme.mono(7, weight: .bold))
                .kerning(0.5)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(color.opacity(0.30), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: - MISSIONS tab

    private var missionJumpBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(missionIDInput.isEmpty ? AppTheme.textSecondary : AppTheme.accentPrimary)
            TextField("JUMP TO MISSION #", text: $missionIDInput)
                .font(AppTheme.mono(10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .keyboardType(.numberPad)
                .autocorrectionDisabled()
            if !missionIDInput.isEmpty {
                #if DEBUG
                Button(action: {
                    if let id = Int(missionIDInput) {
                        filterDifficulty = nil
                        filterObjective  = nil
                        filterStatus     = .all
                        jumpToLevelID    = id
                    }
                }) {
                    Text("GO")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.accentPrimary.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.30), lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                #endif
                Button(action: { missionIDInput = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(AppTheme.backgroundSecondary)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill("ALL", active: filterDifficulty == nil, color: AppTheme.sage) {
                    filterDifficulty = nil
                }
                ForEach(DifficultyTier.allCases) { tier in
                    filterPill(tier.label, active: filterDifficulty == tier, color: tier.color) {
                        filterDifficulty = filterDifficulty == tier ? nil : tier
                    }
                }

                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 14)

                filterPill("NRM", active: filterObjective == .normal,
                           color: LevelObjectiveType.normal.accentColor) {
                    filterObjective = filterObjective == .normal ? nil : .normal
                }
                filterPill("CVR", active: filterObjective == .maxCoverage,
                           color: LevelObjectiveType.maxCoverage.accentColor) {
                    filterObjective = filterObjective == .maxCoverage ? nil : .maxCoverage
                }
                filterPill("SAV", active: filterObjective == .energySaving,
                           color: LevelObjectiveType.energySaving.accentColor) {
                    filterObjective = filterObjective == .energySaving ? nil : .energySaving
                }

                Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 14)

                filterPill("OPEN", active: filterStatus == .open,
                           color: AppTheme.accentPrimary) {
                    filterStatus = filterStatus == .open ? .all : .open
                }
                filterPill("DONE", active: filterStatus == .done,
                           color: AppTheme.success) {
                    filterStatus = filterStatus == .done ? .all : .done
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .background(AppTheme.backgroundSecondary)
    }

    @ViewBuilder
    private func filterPill(
        _ label: String,
        active: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(active ? .black : AppTheme.textSecondary)
                .kerning(0.8)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(active ? color : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(active ? color : AppTheme.sage.opacity(0.20), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    private var levelList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredLevels) { level in
                        Button(action: { onSelect(level) }) { levelRow(level) }
                            .buttonStyle(.plain)
                            .id(level.id)
                        TechDivider()
                    }
                }
            }
            #if DEBUG
            .onChange(of: jumpToLevelID) { _, id in
                guard let id else { return }
                withAnimation(.spring(response: 0.44, dampingFraction: 0.85)) {
                    proxy.scrollTo(id, anchor: .center)
                }
                jumpToLevelID = nil
            }
            #endif
        }
    }

    private func levelRow(_ level: Level) -> some View {
        let completed = profile.hasCompleted(levelId: level.id)
        let bestEff   = profile.bestEfficiencyByLevel[String(level.id)]
        #if DEBUG
        let isExpanded = inspectLevelID == level.id
        #endif

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(String(format: "%03d", level.id))
                    .font(AppTheme.mono(11, weight: .bold))
                    .foregroundStyle(AppTheme.sage.opacity(0.80))
                    .frame(width: 30, alignment: .leading)

                Text("\(level.gridSize)×\(level.gridSize)")
                    .font(AppTheme.mono(9))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 26)

                Text(level.difficulty.label)
                    .font(AppTheme.mono(7, weight: .bold))
                    .foregroundStyle(level.difficulty.color)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(level.difficulty.color.opacity(0.40), lineWidth: 0.5)
                    )

                Image(systemName: level.objectiveType.iconName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(level.objectiveType.accentColor.opacity(0.85))

                if level.timeLimit != nil {
                    Image(systemName: "timer")
                        .font(.system(size: 8))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Text("\(level.minimumRequiredMoves)/\(level.maxMoves)")
                    .font(AppTheme.mono(8))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 38, alignment: .trailing)

                if let eff = bestEff {
                    Text("\(Int(eff * 100))%")
                        .font(AppTheme.mono(9, weight: .bold))
                        .foregroundStyle(AppTheme.success.opacity(0.80))
                        .frame(width: 32, alignment: .trailing)
                        .monospacedDigit()
                } else {
                    Color.clear.frame(width: 32)
                }

                Circle()
                    .fill(completed ? AppTheme.success : AppTheme.stroke)
                    .frame(width: 6, height: 6)

                #if DEBUG
                // Inspect toggle — opens per-level solver panel
                Button(action: {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        inspectLevelID = isExpanded ? nil : level.id
                    }
                    if !isExpanded && !inspectCache.keys.contains(level.id) {
                        runInspect(level: level, useSolver: false)
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "magnifyingglass")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(isExpanded
                                         ? AppTheme.accentPrimary
                                         : AppTheme.textSecondary.opacity(0.45))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                #endif
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.backgroundPrimary)
            .contentShape(Rectangle())

            #if DEBUG
            if isExpanded {
                inspectorPanel(for: level)
            }
            #endif
        }
    }

    // MARK: - Level inspector (MISSIONS tab, DEBUG only)

    #if DEBUG
    @ViewBuilder
    private func inspectorPanel(for level: Level) -> some View {
        if inspectRunning.contains(level.id) {
            HStack(spacing: 8) {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.65)
                TechLabel(text: "ANALYZING LEVEL \(level.id)...", color: AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.surface)
        } else if let report = inspectCache[level.id] {
            inspectorReport(report, level: level)
        }
    }

    @ViewBuilder
    private func inspectorReport(_ r: LevelValidationReport, level: Level) -> some View {
        VStack(spacing: 0) {
            // ── Solvability banner ─────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: r.isSolvable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(r.isSolvable ? "SOLVABLE" : "NOT SOLVABLE")
                    .font(AppTheme.mono(11, weight: .black))
                    .kerning(1.2)
                if r.isTrivial {
                    Text("TRIVIAL")
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Spacer()
                TechLabel(text: "LVL \(r.levelID)", color: AppTheme.textSecondary.opacity(0.50))
            }
            .foregroundStyle(r.isSolvable ? AppTheme.success : AppTheme.danger)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(r.isSolvable ? AppTheme.success.opacity(0.06) : AppTheme.danger.opacity(0.06))

            TechDivider()

            // ── Level type / objective row ─────────────────────────────────
            if let level = LevelGenerator.levels.first(where: { $0.id == r.levelID }) {
                HStack(spacing: 8) {
                    // Difficulty badge
                    Text(level.difficulty.label)
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(level.difficulty.color)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(level.difficulty.color.opacity(0.40), lineWidth: 0.5))

                    // Objective badge
                    HStack(spacing: 3) {
                        Image(systemName: level.objectiveType.iconName).font(.system(size: 7))
                        Text(level.objectiveType.rawValue.uppercased()).font(AppTheme.mono(7, weight: .bold)).kerning(0.4)
                    }
                    .foregroundStyle(level.objectiveType.accentColor)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(level.objectiveType.accentColor.opacity(0.40), lineWidth: 0.5))

                    // Grid size
                    TechLabel(text: "\(r.gridSize)×\(r.gridSize)", color: AppTheme.textSecondary)

                    Spacer()

                    // Callout alerts
                    if r.buffer > 8 {
                        calloutBadge("HIGH BUFFER", color: Color.orange)
                    }
                    if r.isTrivial {
                        calloutBadge("TRIVIAL", color: AppTheme.danger)
                    }
                    // Difficulty mismatch heuristic
                    if level.difficulty == .expert && r.complexityScore < 6 {
                        calloutBadge("EASY FOR EXPERT", color: Color.orange)
                    } else if level.difficulty == .easy && r.complexityScore > 12 {
                        calloutBadge("HARD FOR EASY", color: AppTheme.danger)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)

                TechDivider()
            }

            // ── Core stats ─────────────────────────────────────────────────
            HStack(spacing: 0) {
                miniStat("MIN MOVES", "\(r.confirmedMinMoves)")
                statDivider()
                miniStat("LIMIT", "\(r.moveLimit)")
                statDivider()
                miniStat("BUFFER", r.buffer > 8 ? "⚠ \(r.buffer)" : "\(r.buffer)")
                statDivider()
                miniStat("CPLX", String(format: "%.1f", r.complexityScore))
            }
            .padding(.vertical, 8)
            .background(AppTheme.surface)

            // ── Solver result or "run solver" button ───────────────────────
            TechDivider()
            if let sr = r.solverResult {
                HStack(spacing: 6) {
                    Image(systemName: "cpu").font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.sage)
                    TechLabel(
                        text: sr.isExact
                            ? "SOLVER: EXACT \(sr.minimumMoves) MOVES\(r.solverFoundShorterPath ? " — IMPROVED BY \(sr.improvement)" : "")"
                            : "SOLVER: BUDGET HIT — ESTIMATE \(sr.minimumMoves) (NOT EXACT)",
                        color: AppTheme.sage
                    )
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.backgroundSecondary)
            } else {
                Button(action: { runInspect(level: level, useSolver: true) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu").font(.system(size: 9, weight: .semibold))
                        Text("RUN DIJKSTRA SOLVER")
                            .font(AppTheme.mono(8, weight: .bold))
                            .kerning(0.8)
                    }
                    .frame(maxWidth: .infinity).frame(height: 32)
                    .background(AppTheme.accentPrimary.opacity(0.08))
                    .foregroundStyle(AppTheme.accentPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.accentPrimary.opacity(0.22), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(AppTheme.backgroundSecondary)
            }

            // ── Warnings ───────────────────────────────────────────────────
            if !r.warnings.isEmpty {
                TechDivider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(r.warnings.enumerated()), id: \.offset) { _, w in
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(AppTheme.danger.opacity(0.75))
                                .padding(.top, 1)
                            Text(w)
                                .font(AppTheme.mono(7))
                                .foregroundStyle(AppTheme.danger.opacity(0.65))
                                .lineLimit(3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppTheme.danger.opacity(0.04))
            }

            // ── Mechanics ──────────────────────────────────────────────────
            if r.hasMechanics {
                TechDivider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        if r.hasRotationCap      { mechBadge("rotation.3d",                         "ROT CAP")   }
                        if r.hasOverloaded       { mechBadge("bolt.fill",                           "OVERLOAD")  }
                        if r.hasAutoDrift        { mechBadge("wind",                                "DRIFT")     }
                        if r.hasOneWayRelay      { mechBadge("arrow.right",                         "ONE-WAY")   }
                        if r.hasFragileTile      { mechBadge("bolt.slash",                          "FRAGILE")   }
                        if r.hasChargeGate       { mechBadge("lock.fill",                           "GATE")      }
                        if r.hasInterferenceZone { mechBadge("antenna.radiowaves.left.and.right",   "INTERFERE") }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.vertical, 8)
                .background(AppTheme.surface)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func calloutBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(AppTheme.mono(6, weight: .bold))
            .foregroundStyle(.black)
            .kerning(0.3)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func mechBadge(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7))
            Text(label).font(AppTheme.mono(6, weight: .bold)).kerning(0.4)
        }
        .foregroundStyle(AppTheme.sage)
        .padding(.horizontal, 5).padding(.vertical, 3)
        .background(AppTheme.sage.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(AppTheme.sage.opacity(0.25), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func runInspect(level: Level, useSolver: Bool) {
        inspectRunning.insert(level.id)
        Task {
            let report = LevelValidationRunner.validate(level: level, useSolver: useSolver)
            inspectCache[level.id] = report
            inspectRunning.remove(level.id)
        }
    }
    #endif

    // MARK: - TOOLS tab

    private var toolsPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                #if DEBUG
                audioSection
                TechDivider()
                #endif
                onboardingSection
                TechDivider()
                #if DEBUG
                difficultyAnalysisSection
                TechDivider()
                validationSection
                TechDivider()
                startsSolvedSection
                TechDivider()
                #endif
                mechanicMessagesSection
            }
        }
    }

    // ── Audio Debug ────────────────────────────────────────────────────────

    #if DEBUG
    @State private var audioToast: String? = nil

    private var audioSection: some View {
        let am = AudioManager.shared
        return VStack(spacing: 0) {
            sectionHeader("AUDIO DEBUG")

            // ── Live status ──────────────────────────────────────────────
            TimelineView(.periodic(from: Date(), by: 1)) { _ in
                VStack(spacing: 4) {
                    HStack {
                        audioStatusRow("STATE",  am.currentState.debugLabel)
                        Spacer()
                        audioStatusRow("TRACK",  am.currentTrackLabel)
                    }
                    HStack {
                        audioStatusRow("MUSIC",  am.musicEnabled ? "ON"  : "OFF")
                        Spacer()
                        audioStatusRow("SFX",    am.sfxEnabled   ? "ON"  : "OFF")
                        Spacer()
                        audioStatusRow("DUCK",   am.isDucked     ? "YES" : "NO")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            TechDivider().padding(.horizontal, 16)

            // ── Simulate state ───────────────────────────────────────────
            simulateGroup("SIMULATE STATE") {
                storySimBtn("HOME",    color: AppTheme.textSecondary) { AudioManager.shared.transition(to: .homeIdle)  }
                storySimBtn("MISSION", color: AppTheme.accentPrimary) { AudioManager.shared.transition(to: .inMission) }
                storySimBtn("VICTORY", color: AppTheme.sage)          { AudioManager.shared.transition(to: .victory)   }
                storySimBtn("STORY",   color: AppTheme.sage)          { AudioManager.shared.transition(to: .story)     }
                storySimBtn("PAYWALL", color: Color.orange)            { AudioManager.shared.transition(to: .paywall)   }
                storySimBtn("STOP",    color: AppTheme.textSecondary) { AudioManager.shared.stopMusic()                }
            }

            TechDivider().padding(.horizontal, 16)

            // ── Duck test ────────────────────────────────────────────────
            simulateGroup("DUCK TEST") {
                storySimBtn("DUCK ▼",   color: Color.yellow) { AudioManager.shared.duck()   }
                storySimBtn("UNDUCK ▲", color: Color.yellow) { AudioManager.shared.unduck() }
            }

            TechDivider().padding(.horizontal, 16)

            // ── SFX library ──────────────────────────────────────────────
            simulateGroup("SFX — UI") {
                audioSFXBtn("TAP.P",   .tapPrimary)
                audioSFXBtn("TAP.S",   .tapSecondary)
                audioSFXBtn("STORY",   .storyAdvance)
                audioSFXBtn("SUCCESS", .uiSuccess)
            }
            simulateGroup("SFX — MISSION") {
                audioSFXBtn("ROTATE",  .tileRotate)
                audioSFXBtn("RELAY",   .relayEnergized)
                audioSFXBtn("TARGET",  .targetOnline)
                audioSFXBtn("LOCKED",  .tileLocked)
                audioSFXBtn("DRIFT",   .drift)
                audioSFXBtn("OVERLOAD",.overloadArm)
            }
            simulateGroup("SFX — RESULT") {
                audioSFXBtn("WIN",     .win)
                audioSFXBtn("TICK",    .timerTick)
            }

            // ── Toast ─────────────────────────────────────────────────────
            if let toast = audioToast {
                Text(toast)
                    .font(AppTheme.mono(9))
                    .foregroundStyle(AppTheme.accentPrimary)
                    .padding(.vertical, 6)
                    .transition(.opacity)
            }
        }
    }

    private func audioStatusRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            TechLabel(text: label, color: AppTheme.textSecondary.opacity(0.7))
            TechLabel(text: value, color: AppTheme.textPrimary)
        }
    }

    private func audioSFXBtn(_ label: String, _ sfx: SoundManager.SFX) -> some View {
        storySimBtn(label, color: AppTheme.accentPrimary) {
            SoundManager.debugPlay(sfx)
            withAnimation(.easeIn(duration: 0.15)) { audioToast = "▶ \(label)" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.3)) { audioToast = nil }
            }
        }
    }
    #endif

    // ── Onboarding ─────────────────────────────────────────────────────────

    private var onboardingSection: some View {
        let done = OnboardingStore.hasCompletedIntro
        return VStack(spacing: 0) {
            sectionHeader("ONBOARDING")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    TechLabel(text: "INTRO MISSION STATUS", color: AppTheme.textPrimary)
                    TechLabel(
                        text: done
                            ? "COMPLETED — player goes to Home on launch"
                            : "PENDING — intro mission will show on next launch",
                        color: AppTheme.textSecondary
                    )
                }
                Spacer()
                Text(done ? "DONE" : "ACTIVE")
                    .font(AppTheme.mono(7, weight: .bold))
                    .foregroundStyle(done ? AppTheme.success : AppTheme.accentPrimary)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(
                                (done ? AppTheme.success : AppTheme.accentPrimary).opacity(0.45),
                                lineWidth: 0.5
                            )
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // REPLAY NOW — resets flag + posts notification → ContentView shows intro immediately
            Button(action: {
                OnboardingStore.resetAll()
                NotificationCenter.default.post(name: .devReplayOnboarding, object: nil)
                onDismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 9, weight: .bold))
                    Text("REPLAY ONBOARDING NOW")
                        .font(AppTheme.mono(9, weight: .bold))
                        .kerning(0.8)
                }
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(AppTheme.accentPrimary)
                .foregroundStyle(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // RESET FLAG ONLY — clears the flag; intro appears on next cold launch
            if done {
                Button(action: {
                    OnboardingStore.resetAll()
                    refreshID = UUID()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.slash").font(.system(size: 8, weight: .semibold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("RESET FLAG ONLY")
                                .font(AppTheme.mono(8, weight: .bold))
                                .kerning(0.8)
                            Text("intro appears on next cold launch")
                                .font(AppTheme.mono(7))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .padding(.horizontal, 10)
                    .background(AppTheme.backgroundSecondary)
                    .foregroundStyle(AppTheme.textSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(AppTheme.sage.opacity(0.20), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .background(AppTheme.surface)
    }

    // ── Validation & Solver ────────────────────────────────────────────────

    #if DEBUG
    // MARK: - Difficulty Analysis section

    private var difficultyAnalysisSection: some View {
        VStack(spacing: 0) {
            sectionHeader("DIFFICULTY ANALYSIS")

            // ── Action buttons ────────────────────────────────────────────
            HStack(spacing: 8) {
                validationButton(
                    isAnalyzing ? "RUNNING..." : "RUN ANALYSIS",
                    subtitle: "\(LevelGenerator.levels.count) levels · full pipeline",
                    icon: "chart.bar.xaxis"
                ) { runDifficultyAnalysis() }

                validationButton(
                    "LOG PATCH",
                    subtitle: "rebalance → console",
                    icon: "printer"
                ) { logRebalancePatch() }

                validationButton(
                    "RESET",
                    subtitle: "clear results",
                    icon: "xmark.circle"
                ) { resetAnalysis() }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
                    TechLabel(
                        text: "ANALYSING \(LevelGenerator.levels.count) LEVELS...",
                        color: AppTheme.textSecondary
                    )
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)

            } else if !analysisDataset.isEmpty {
                analysisDistributionView
                TechDivider()
                analysisIssuesView
                TechDivider()
                analysisCurveView
                TechDivider()
                analysisRebalanceView
            } else {
                TechLabel(
                    text: "NO DATA — RUN ANALYSIS TO SEE RESULTS",
                    color: AppTheme.textSecondary.opacity(0.45)
                )
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .background(AppTheme.surface)
    }

    // ── Distribution ────────────────────────────────────────────────────────

    @ViewBuilder
    private var analysisDistributionView: some View {
        let total     = max(1, analysisDataset.count)
        let mismatches = analysisDataset.filter { $0.tierMismatch }.count

        VStack(spacing: 0) {
            HStack {
                TechLabel(text: "DISTRIBUTION  D=DECLARED · C=COMPUTED", color: AppTheme.textSecondary)
                Spacer()
                if mismatches > 0 {
                    TechLabel(text: "\(mismatches) MISMATCHES", color: Color.orange)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            ForEach(DifficultyTier.allCases, id: \.self) { tier in
                let declCount = analysisDataset.filter { $0.difficultyTier == tier }.count
                let compCount = analysisDataset.filter { $0.computedTier  == tier }.count
                let color     = analysisТierColor(tier)

                HStack(spacing: 10) {
                    Text(tier.fullLabel)
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 52, alignment: .leading)

                    VStack(spacing: 3) {
                        analysisBar(label: "D", count: declCount, total: total, color: color.opacity(0.80))
                        analysisBar(label: "C", count: compCount, total: total, color: color.opacity(0.42))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 5)
            }
        }
        .padding(.bottom, 6)
    }

    private func analysisBar(label: String, count: Int, total: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(label).font(AppTheme.mono(7)).foregroundStyle(AppTheme.textSecondary).frame(width: 8)
            GeometryReader { g in
                HStack(spacing: 0) {
                    Rectangle().fill(color)
                        .frame(width: g.size.width * CGFloat(count) / CGFloat(max(1, total)))
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 6).background(AppTheme.sage.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 1))
            Text("\(count)").font(AppTheme.mono(7)).foregroundStyle(AppTheme.textSecondary).frame(width: 26, alignment: .trailing)
        }
    }

    // ── Issues ──────────────────────────────────────────────────────────────

    @ViewBuilder
    private var analysisIssuesView: some View {
        let criticals = analysisIssues.filter { $0.severity == .critical }.count
        let filtered  = analysisIssueFilter == nil
            ? analysisIssues
            : analysisIssues.filter { $0.issueType == analysisIssueFilter }

        VStack(spacing: 0) {
            HStack {
                TechLabel(text: "BALANCE ISSUES", color: AppTheme.textSecondary)
                Spacer()
                if criticals > 0 {
                    TechLabel(text: "\(criticals) CRITICAL", color: AppTheme.danger)
                        .padding(.trailing, 6)
                }
                TechLabel(text: "\(analysisIssues.count) TOTAL", color: AppTheme.textSecondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    analysisIssuePill(nil,                  label: "ALL",       count: analysisIssues.count)
                    analysisIssuePill(.impossible,           label: "IMPOSSIBLE", count: analysisIssues.filter { $0.issueType == .impossible }.count)
                    analysisIssuePill(.trivial,              label: "TRIVIAL",    count: analysisIssues.filter { $0.issueType == .trivial }.count)
                    analysisIssuePill(.overPermissive,       label: "PERMISSIVE", count: analysisIssues.filter { $0.issueType == .overPermissive }.count)
                    analysisIssuePill(.fakeHard,             label: "FAKE HARD",  count: analysisIssues.filter { $0.issueType == .fakeHard }.count)
                    analysisIssuePill(.misalignedProgression, label: "MISALIGNED", count: analysisIssues.filter { $0.issueType == .misalignedProgression }.count)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .background(AppTheme.backgroundSecondary)
            .overlay(alignment: .bottom) { TechDivider() }

            if filtered.isEmpty {
                TechLabel(text: "NO ISSUES IN THIS CATEGORY ✓", color: AppTheme.sage.opacity(0.55))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                let items = Array(filtered.prefix(25).enumerated())
                ForEach(items, id: \.offset) { item in
                    analysisIssueRow(item.element)
                }
                if filtered.count > 25 {
                    TechLabel(text: "+ \(filtered.count - 25) MORE ISSUES", color: AppTheme.textSecondary.opacity(0.45))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
        }
    }

    private func analysisIssuePill(_ type: IssueType?, label: String, count: Int) -> some View {
        let active = analysisIssueFilter == type
        let color: Color = type == .impossible ? AppTheme.danger
                         : (type == .fakeHard || type == .trivial) ? Color.orange
                         : AppTheme.accentPrimary
        return Button(action: { analysisIssueFilter = type }) {
            HStack(spacing: 4) {
                Text(label).font(AppTheme.mono(8, weight: .bold)).kerning(0.5)
                Text("(\(count))").font(AppTheme.mono(7))
            }
            .foregroundStyle(active ? .black : (count > 0 && type != nil ? color : AppTheme.textSecondary))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(active ? color : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(active ? color : (count > 0 ? color.opacity(0.35) : AppTheme.sage.opacity(0.18)), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    private func analysisIssueRow(_ issue: LevelIssue) -> some View {
        let isCritical = issue.severity == .critical
        return HStack(alignment: .top, spacing: 8) {
            Text(isCritical ? "●" : "◦")
                .font(AppTheme.mono(9, weight: .bold))
                .foregroundStyle(isCritical ? AppTheme.danger : Color.orange)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("L\(String(format: "%03d", issue.levelID))")
                        .font(AppTheme.mono(8, weight: .bold))
                        .foregroundStyle(AppTheme.accentPrimary)
                    Text(issue.issueType.displayLabel)
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(analysisIssueTypeColor(issue.issueType))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(analysisIssueTypeColor(issue.issueType).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Text(issue.description)
                    .font(AppTheme.mono(7))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: {
                activeTab    = .missions
                jumpToLevelID = issue.levelID
            }) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private func analysisIssueTypeColor(_ type: IssueType) -> Color {
        switch type {
        case .impossible:            return AppTheme.danger
        case .trivial:               return Color.orange
        case .overPermissive:        return AppTheme.accentPrimary
        case .fakeHard:              return Color.orange
        case .misalignedProgression: return AppTheme.sage
        }
    }

    // ── Curve health ────────────────────────────────────────────────────────

    @ViewBuilder
    private var analysisCurveView: some View {
        let curveAnomalyCount = analysisCurveAnomalies.count

        VStack(spacing: 0) {
            HStack {
                TechLabel(text: "DIFFICULTY CURVE", color: AppTheme.textSecondary)
                Spacer()
                if curveAnomalyCount > 0 {
                    TechLabel(text: "\(curveAnomalyCount) ANOMALIES", color: Color.orange)
                } else {
                    TechLabel(text: "SMOOTH ✓", color: AppTheme.sage)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            // Phase rows
            ForEach(analysisPhases, id: \.phase.rawValue) { r in
                analysisCurvePhaseRow(r)
            }

            // Sparkline
            if !analysisDataset.isEmpty {
                let sorted  = analysisDataset.filter { $0.levelID >= 1 }.sorted { $0.levelID < $1.levelID }
                let buckets = stride(from: 0, to: sorted.count, by: 5).map { i -> Double in
                    let slice = sorted[i..<min(i + 5, sorted.count)]
                    return Double(slice.map { $0.computedDifficultyScore }.reduce(0, +)) / Double(slice.count)
                }
                let spark = buckets.map { DifficultyCurveAnalyzer.sparkChar($0) }.joined()

                VStack(spacing: 4) {
                    Text(spark)
                        .font(AppTheme.mono(12))
                        .foregroundStyle(AppTheme.sage)
                        .lineLimit(1).minimumScaleFactor(0.4)
                    TechLabel(
                        text: "▁<13 · ▄≈50 · █≥88  —  5-level avg",
                        color: AppTheme.textSecondary.opacity(0.50)
                    )
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(AppTheme.backgroundSecondary)
            }
        }
    }

    private func analysisCurvePhaseRow(_ r: DifficultyCurveAnalyzer.PhaseReport) -> some View {
        HStack(spacing: 10) {
            Text(r.phase.rawValue)
                .font(AppTheme.mono(8, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(String(format: "avg %.0f", r.avgScore))
                    Text(r.avgOnTarget ? "✓" : "✗").foregroundStyle(r.avgOnTarget ? AppTheme.sage : AppTheme.danger)
                    Text(String(format: "trend %+.0f", r.trend))
                    Text(r.isRising ? "↑" : "↓").foregroundStyle(r.isRising ? AppTheme.sage : AppTheme.danger)
                }
                .font(AppTheme.mono(8)).foregroundStyle(AppTheme.textSecondary)

                if r.anomalyCount > 0 {
                    Text("\(r.anomalyCount) anomalies")
                        .font(AppTheme.mono(7)).foregroundStyle(Color.orange)
                }
            }

            Spacer()
            Text("[\(r.minScore)–\(r.maxScore)]")
                .font(AppTheme.mono(7)).foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    // ── Rebalance summary ───────────────────────────────────────────────────

    @ViewBuilder
    private var analysisRebalanceView: some View {
        let tighten = analysisSuggestions.filter { $0.action == .tighten }.count
        let loosen  = analysisSuggestions.filter { $0.action == .loosen  }.count
        let ok      = analysisSuggestions.filter { $0.action == .ok      }.count
        let netDelta = analysisSuggestions.map { $0.delta }.reduce(0, +)

        VStack(spacing: 0) {
            HStack {
                TechLabel(text: "AUTO REBALANCE", color: AppTheme.textSecondary)
                Spacer()
                let changes = tighten + loosen
                TechLabel(
                    text: changes > 0 ? "\(changes) LEVELS NEED CHANGE" : "ALL BALANCED ✓",
                    color: changes > 0 ? Color.orange : AppTheme.sage
                )
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            HStack(spacing: 0) {
                miniStat("TIGHTEN ▼", "\(tighten)")
                statDivider()
                miniStat("LOOSEN  ▲", "\(loosen)")
                statDivider()
                miniStat("OK  ·", "\(ok)")
                statDivider()
                miniStat("NET Δ", String(format: "%+d", netDelta))
            }
            .padding(.vertical, 10)

            Button(action: logRebalancePatch) {
                HStack(spacing: 6) {
                    Image(systemName: "printer").font(.system(size: 9, weight: .bold))
                    Text("LOG FULL PATCH TO CONSOLE")
                        .font(AppTheme.mono(9, weight: .bold)).kerning(0.8)
                }
                .foregroundStyle(AppTheme.sage)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(AppTheme.sage.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.sage.opacity(0.22), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16).padding(.bottom, 14)
        }
    }

    // ── Tier color helper ───────────────────────────────────────────────────

    private func analysisТierColor(_ tier: DifficultyTier) -> Color {
        switch tier {
        case .easy:   return AppTheme.sage
        case .medium: return AppTheme.accentPrimary
        case .hard:   return Color.orange
        case .expert: return AppTheme.danger
        }
    }

    private var validationSection: some View {
        VStack(spacing: 0) {
            sectionHeader("VALIDATION & SOLVER")

            HStack(spacing: 8) {
                validationButton(
                    "RUN QUICK",
                    subtitle: "heuristic only",
                    icon: "checkmark.seal"
                ) { runValidation(useSolver: false) }

                validationButton(
                    "RUN + SOLVER",
                    subtitle: "dijkstra · ~300 ms",
                    icon: "cpu"
                ) { runValidation(useSolver: true) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if isValidating {
                HStack(spacing: 8) {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
                    TechLabel(
                        text: "VALIDATING \(LevelGenerator.levels.count) LEVELS...",
                        color: AppTheme.textSecondary
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !validationReports.isEmpty {
                // Filter pills
                let startsSolvedCt = validationReports.filter { $0.startsSolved }.count
                let failedCt  = validationReports.filter { !$0.isSolvable || $0.solverResult?.isSolvable == false }.count
                let trivialCt = validationReports.filter { $0.isTrivial }.count
                let warnCt    = validationReports.filter { !$0.warnings.isEmpty }.count
                let expertCt  = validationReports.filter { $0.difficulty == .expert }.count
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        validationFilterPill(.all,          count: validationReports.count)
                        validationFilterPill(.failed,       count: failedCt)
                        validationFilterPill(.startsSolved, count: startsSolvedCt)
                        validationFilterPill(.trivial,      count: trivialCt)
                        validationFilterPill(.warnings,     count: warnCt)
                        validationFilterPill(.expert,       count: expertCt)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .background(AppTheme.backgroundSecondary)
                .overlay(alignment: .bottom) { TechDivider() }

                validationSummary
            } else {
                TechLabel(
                    text: "NO DATA — RUN VALIDATION TO SEE RESULTS",
                    color: AppTheme.textSecondary.opacity(0.45)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .background(AppTheme.surface)
    }

    // ── Starts-solved scanner ──────────────────────────────────────────────

    private var startsSolvedSection: some View {
        VStack(spacing: 0) {
            sectionHeader("BUG DETECTION — STARTS SOLVED")

            // Scan button
            Button(action: runStartsSolvedCheck) {
                HStack(spacing: 6) {
                    if isCheckingStartsSolved {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.65)
                        Text("SCANNING \(LevelGenerator.levels.count) LEVELS...")
                    } else {
                        Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold))
                        Text("CHECK STARTS-SOLVED LEVELS")
                    }
                }
                .font(AppTheme.mono(9, weight: .bold))
                .kerning(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(isCheckingStartsSolved ? AppTheme.textSecondary : AppTheme.danger)
                .background(AppTheme.danger.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.danger.opacity(0.22), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(isCheckingStartsSolved)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Results
            if startsSolvedChecked {
                if startsSolvedBroken.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                        TechLabel(
                            text: "ALL \(LevelGenerator.levels.count) LEVELS OK — NO PRE-SOLVED BOARDS",
                            color: AppTheme.success
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                } else {
                    // Summary bar
                    HStack(spacing: 0) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.danger)
                            .padding(.trailing, 6)
                        TechLabel(
                            text: "\(startsSolvedBroken.count) PRE-SOLVED LEVEL\(startsSolvedBroken.count == 1 ? "" : "S") DETECTED",
                            color: AppTheme.danger
                        )
                        Spacer()
                        Text("OF \(LevelGenerator.levels.count)")
                            .font(AppTheme.mono(7))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.danger.opacity(0.06))
                    .overlay(alignment: .bottom) { TechDivider() }

                    // Level rows
                    ForEach(startsSolvedBroken) { level in
                        let sector = SpatialRegion.catalog
                            .last(where: { $0.levelRange.contains(level.id) })?.name ?? "UNKNOWN"
                        HStack(spacing: 0) {
                            // ID badge
                            Text(String(format: "L%03d", level.id))
                                .font(AppTheme.mono(9, weight: .bold))
                                .foregroundStyle(AppTheme.danger)
                                .frame(width: 44, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(sector.uppercased())
                                    .font(AppTheme.mono(8, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                HStack(spacing: 6) {
                                    Text(level.difficulty.fullLabel.uppercased())
                                        .font(AppTheme.mono(7))
                                        .foregroundStyle(level.difficulty.color)
                                    Text("·")
                                        .font(AppTheme.mono(7))
                                        .foregroundStyle(AppTheme.textSecondary.opacity(0.35))
                                    Text(level.objectiveType.hudLabel.uppercased())
                                        .font(AppTheme.mono(7))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text("·")
                                        .font(AppTheme.mono(7))
                                        .foregroundStyle(AppTheme.textSecondary.opacity(0.35))
                                    Text("\(level.gridSize)×\(level.gridSize)")
                                        .font(AppTheme.mono(7))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)

                            // Jump button
                            Button(action: {
                                jumpToLevelID = level.id
                                withAnimation(.easeInOut(duration: 0.14)) { activeTab = .missions }
                            }) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.accentPrimary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.backgroundPrimary)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(AppTheme.sage.opacity(0.07)).frame(height: 0.5)
                        }
                    }
                }
            } else if !isCheckingStartsSolved {
                TechLabel(
                    text: "NOT SCANNED — TAP BUTTON TO CHECK ALL LEVELS",
                    color: AppTheme.textSecondary.opacity(0.45)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .background(AppTheme.surface)
    }

    private func validationFilterPill(_ filter: ValidationResultFilter, count: Int) -> some View {
        let active = validationFilter == filter
        let color: Color = filter == .failed       ? AppTheme.danger
                         : filter == .startsSolved ? AppTheme.danger
                         : filter == .trivial      ? Color.orange
                         : AppTheme.accentPrimary
        return Button(action: { validationFilter = filter }) {
            HStack(spacing: 4) {
                Text(filter.label)
                    .font(AppTheme.mono(8, weight: .bold))
                    .kerning(0.6)
                Text("(\(count))")
                    .font(AppTheme.mono(7))
            }
            .foregroundStyle(active ? .black : (count > 0 && filter != .all ? color : AppTheme.textSecondary))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(active ? color : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(active ? color : AppTheme.sage.opacity(0.22), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .buttonStyle(.plain)
    }

    private func validationButton(
        _ label: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.system(size: 9, weight: .semibold))
                    Text(label).font(AppTheme.mono(9, weight: .bold)).kerning(0.8)
                }
                Text(subtitle)
                    .font(AppTheme.mono(7))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(AppTheme.accentPrimary.opacity(0.08))
            .foregroundStyle(isValidating ? AppTheme.textSecondary : AppTheme.accentPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.accentPrimary.opacity(0.22), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(isValidating)
    }

    @ViewBuilder
    private var validationSummary: some View {
        let total              = validationReports.count
        let failed             = validationReports.filter { !$0.isSolvable || $0.solverResult?.isSolvable == false }
        let startsSolvedLevels = validationReports.filter { $0.startsSolved }
        let solvable           = total - failed.count
        let trivialLevels      = validationReports.filter { $0.isTrivial }
        let withMechs          = validationReports.filter { $0.hasMechanics }.count
        let solverImproved     = validationReports.filter { $0.solverFoundShorterPath }.count
        let avgComplexity      = validationReports.map { $0.complexityScore }.reduce(0, +) / Float(total)
        let hasSolverData      = validationReports.first?.solverResult != nil
        let anyCritical        = !failed.isEmpty || !startsSolvedLevels.isEmpty

        // All level-tagged warnings for the detail section (using IssueItem defined below)
        let levelWarnings: [IssueItem] = validationReports.flatMap { r in
            r.warnings.map { w in IssueItem(levelID: r.levelID, label: "[\(r.levelID)] \(w)") }
        }

        VStack(spacing: 0) {
            // ── Row 1: core health stats ───────────────────────────────────
            HStack(spacing: 0) {
                miniStat("TOTAL",     "\(total)")
                statDivider()
                miniStat("SOLVABLE",  "\(solvable)/\(total)")
                statDivider()
                miniStatC("FAILED",   "\(failed.count)",
                          failed.isEmpty ? AppTheme.textPrimary : AppTheme.danger)
                statDivider()
                miniStatC("PRE-SOLVED", "\(startsSolvedLevels.count)",
                          startsSolvedLevels.isEmpty ? AppTheme.textPrimary : AppTheme.danger)
            }
            .padding(.vertical, 10)
            .background(anyCritical ? AppTheme.danger.opacity(0.04) : Color.clear)

            TechDivider()

            // ── Row 2: secondary stats ─────────────────────────────────────
            HStack(spacing: 0) {
                miniStat("WARNINGS", "\(levelWarnings.count)")
                statDivider()
                miniStat("AVG CPLX", String(format: "%.1f", avgComplexity))
                statDivider()
                miniStat("W/MECHS",  "\(withMechs)")
                if hasSolverData {
                    statDivider()
                    miniStat("SOLVER↓", "\(solverImproved)")
                }
            }
            .padding(.vertical, 10)

            // ── CRITICAL sections ──────────────────────────────────────────
            let showFailed      = validationFilter == .all || validationFilter == .failed
            let showStartsSolved = validationFilter == .all || validationFilter == .startsSolved
            let showTrivial     = validationFilter == .all || validationFilter == .trivial
            let showWarnings    = validationFilter == .all || validationFilter == .warnings
            let showExpert      = validationFilter == .expert

            // CRITICAL: board starts already solved
            if !startsSolvedLevels.isEmpty && showStartsSolved {
                TechDivider()
                issueSection(
                    title: "CRITICAL — STARTS SOLVED (\(startsSolvedLevels.count))",
                    color: AppTheme.danger,
                    icon: "bolt.circle.fill",
                    items: startsSolvedLevels.map { r in
                        IssueItem(
                            levelID: r.levelID,
                            label: "LVL \(r.levelID) · \(r.difficulty.label) · \(r.objectiveType.hudLabel) · \(r.gridSize)×\(r.gridSize) — WIN BEFORE FIRST TAP"
                        )
                    }
                )
            }

            // CRITICAL: unsolvable levels
            if !failed.isEmpty && showFailed {
                TechDivider()
                issueSection(
                    title: "CRITICAL — UNSOLVABLE (\(failed.count))",
                    color: AppTheme.danger,
                    icon: "xmark.circle.fill",
                    items: failed.map { r in
                        IssueItem(
                            levelID: r.levelID,
                            label: "LVL \(r.levelID) · \(r.difficulty.label) · \(r.gridSize)×\(r.gridSize)"
                                + (r.solverResult?.isSolvable == false ? " [SOLVER CONFIRMED]" : "")
                        )
                    }
                )
            }

            // ── EXPERT-ONLY view ───────────────────────────────────────────
            if showExpert {
                let expertLevels = validationReports.filter { $0.difficulty == .expert }
                TechDivider()
                issueSection(
                    title: "EXPERT LEVELS (\(expertLevels.count))",
                    color: AppTheme.sage,
                    icon: "star.fill",
                    items: expertLevels.map { r in
                        IssueItem(levelID: r.levelID,
                                  label: "LVL \(r.levelID) · \(r.gridSize)×\(r.gridSize) · minMoves=\(r.confirmedMinMoves) buf=\(r.buffer)")
                    }
                )
            }

            // ── TRIVIAL: too-easy levels ───────────────────────────────────
            if !trivialLevels.isEmpty && showTrivial {
                TechDivider()
                issueSection(
                    title: "TRIVIAL — ≤1 TAP TO SOLVE (\(trivialLevels.count))",
                    color: Color.orange,
                    icon: "exclamationmark.triangle.fill",
                    items: trivialLevels.map { r in
                        IssueItem(
                            levelID: r.levelID,
                            label: "LVL \(r.levelID) · \(r.difficulty.label) · minMoves=\(r.confirmedMinMoves)"
                        )
                    }
                )
            }

            // ── WARNINGS ──────────────────────────────────────────────────
            if !levelWarnings.isEmpty && showWarnings {
                TechDivider()
                issueSection(
                    title: "WARNINGS (\(levelWarnings.count))",
                    color: AppTheme.danger.opacity(0.75),
                    icon: "exclamationmark.triangle",
                    items: levelWarnings
                )
            }

            // ── All-clear message ──────────────────────────────────────────
            if failed.isEmpty && startsSolvedLevels.isEmpty && trivialLevels.isEmpty && levelWarnings.isEmpty && validationFilter == .all {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.success)
                    TechLabel(text: "ALL \(total) LEVELS PASSED — NO ISSUES FOUND", color: AppTheme.success)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.success.opacity(0.05))
            }
        }
        .padding(.bottom, 4)
    }

    // Helper model for issue rows (local to the view body above but defined at file scope)
    private struct IssueItem {
        let levelID: Int
        let label: String
    }

    /// Renders a collapsible issue section (CRITICAL / TRIVIAL / WARNINGS).
    /// Tapping any row navigates the MISSIONS tab to that level with inspector open.
    @ViewBuilder
    private func issueSection(title: String, color: Color, icon: String, items: [IssueItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color)
                TechLabel(text: title, color: color)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)

            // Item rows (capped at 20; show overflow notice)
            ForEach(Array(items.prefix(20).enumerated()), id: \.offset) { _, item in
                Button(action: { jumpToLevel(item.levelID) }) {
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(AppTheme.mono(7))
                            .foregroundStyle(color.opacity(0.75))
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(color.opacity(0.45))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if items.count > 20 {
                TechLabel(
                    text: "  … \(items.count - 20) MORE — see console log",
                    color: AppTheme.textSecondary.opacity(0.40)
                )
                .padding(.horizontal, 16).padding(.bottom, 4)
            } else {
                Color.clear.frame(height: 6)
            }
        }
        .background(color.opacity(0.03))
    }

    /// Switches to MISSIONS tab, clears filters, opens the inspector for the given level,
    /// and schedules a scroll to that row.
    private func jumpToLevel(_ id: Int) {
        filterDifficulty = nil
        filterObjective  = nil
        filterStatus     = .all
        activeTab        = .missions
        inspectLevelID   = id
        if !inspectCache.keys.contains(id),
           let level = LevelGenerator.levels.first(where: { $0.id == id }) {
            runInspect(level: level, useSolver: false)
        }
        // Slight delay so the tab switch + layout settle before scrolling
        Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            jumpToLevelID = id
        }
    }
    #endif

    // ── Mechanic messages ──────────────────────────────────────────────────

    private var mechanicMessagesSection: some View {
        VStack(spacing: 0) {
            sectionHeader("MECHANIC UNLOCK MESSAGES  ·  \(MechanicType.allCases.count) TOTAL")

            // Language picker — controls both inline preview and full-screen launch
            HStack(spacing: 6) {
                TechLabel(text: "PREVIEW LANG:", color: AppTheme.textSecondary)
                ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                    Button(action: { previewLanguage = lang }) {
                        Text(lang.rawValue.uppercased())
                            .font(AppTheme.mono(8, weight: .bold))
                            .foregroundStyle(previewLanguage == lang ? .black : AppTheme.textSecondary)
                            .kerning(0.6)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(previewLanguage == lang ? AppTheme.accentPrimary : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(
                                        previewLanguage == lang
                                            ? AppTheme.accentPrimary
                                            : AppTheme.sage.opacity(0.25),
                                        lineWidth: 0.5
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.backgroundSecondary)
            .overlay(alignment: .bottom) { TechDivider() }

            ForEach(MechanicType.allCases, id: \.rawValue) { mechanic in
                mechanicRow(mechanic)
                TechDivider()
            }
        }
    }

    private func mechanicRow(_ mechanic: MechanicType) -> some View {
        let seen     = MechanicUnlockStore.hasAnnounced(mechanic)
        let S        = AppStrings(lang: previewLanguage)
        let expanded = expandedMechanic == mechanic
        let amber    = Color(hex: "FFB800")

        return VStack(alignment: .leading, spacing: 0) {

            // ── Header row ────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: mechanic.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(seen ? AppTheme.success : amber)
                    .frame(width: 16)

                TechLabel(text: S.mechanicTitle(mechanic), color: AppTheme.textPrimary)

                Spacer()

                // Seen / unseen badge — tappable toggle
                Button(action: {
                    if seen {
                        MechanicUnlockStore.markUnannounced(mechanic)
                    } else {
                        MechanicUnlockStore.markAnnounced(mechanic)
                    }
                    refreshID = UUID()
                }) {
                    Text(seen ? "SEEN" : "UNSEEN")
                        .font(AppTheme.mono(7, weight: .bold))
                        .foregroundStyle(seen ? AppTheme.success : amber)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(
                                    (seen ? AppTheme.success : amber).opacity(0.50),
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)

                // Launch full-screen preview
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        previewMechanic = mechanic
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill").font(.system(size: 7, weight: .bold))
                        Text("LAUNCH")
                            .font(AppTheme.mono(7, weight: .bold))
                            .kerning(0.5)
                    }
                    .foregroundStyle(amber)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(amber.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(amber.opacity(0.35), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .buttonStyle(.plain)

                // Expand/collapse inline preview
                Button(action: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                        expandedMechanic = expanded ? nil : mechanic
                    }
                }) {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // ── Inline preview card ───────────────────────────────────────
            if expanded {
                VStack(spacing: 0) {
                    // Card header
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: mechanic.iconName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(amber)
                            Text(S.newMechanicUnlocked)
                                .font(AppTheme.mono(8, weight: .bold))
                                .foregroundStyle(amber)
                                .kerning(1)
                        }
                        Text(S.mechanicTitle(mechanic))
                            .font(AppTheme.mono(14, weight: .black))
                            .foregroundStyle(AppTheme.textPrimary)
                            .kerning(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.surface)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(amber.opacity(0.35)).frame(height: 0.5)
                    }

                    // Message body
                    Text(S.mechanicMessage(mechanic))
                        .font(AppTheme.mono(10))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.backgroundSecondary)

                    // CTA bar (non-interactive in preview)
                    Text(S.understood)
                        .font(AppTheme.mono(10, weight: .bold))
                        .kerning(2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(amber.opacity(0.20))
                        .foregroundStyle(amber)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .strokeBorder(amber.opacity(0.40), lineWidth: 0.8)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.backgroundPrimary)
    }

    // MARK: - STORY tab

    private var storyPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                storyHeaderSection
                TechDivider()
                storyAssetSection
                TechDivider()
                narrativeQASection
                TechDivider()
                storyAssetPreviewSection
                TechDivider()
                storySimulateSection
                TechDivider()
                storySequenceTesterSection
                TechDivider()
                storyBeatList
            }
        }
    }

    // ── Pending queue inspector ────────────────────────────────────────────

    private var storyPendingQueueSection: some View {
        let pendingIDs = UserDefaults.standard.stringArray(forKey: "storyQueue.pendingBeatIDs") ?? []

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("PENDING QUEUE")
                            .font(AppTheme.mono(8, weight: .black)).kerning(1.0)
                            .foregroundStyle(pendingIDs.isEmpty
                                             ? AppTheme.textSecondary.opacity(0.40)
                                             : AppTheme.accentPrimary)
                        if !pendingIDs.isEmpty {
                            Text("\(pendingIDs.count)")
                                .font(AppTheme.mono(7, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(AppTheme.accentPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    if pendingIDs.isEmpty {
                        Text("no beats waiting")
                            .font(AppTheme.mono(8))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.30))
                    } else {
                        ForEach(pendingIDs, id: \.self) { beatID in
                            Text("• \(beatID)")
                                .font(AppTheme.mono(8))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                if !pendingIDs.isEmpty {
                    scenarioBtn("CLEAR", icon: "xmark.circle", color: AppTheme.danger) {
                        UserDefaults.standard.removeObject(forKey: "storyQueue.pendingBeatIDs")
                        storyRefreshID = UUID()
                        showToast("Pending queue cleared", style: .warning)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if let lastID = lastSimulatedID {
                TechDivider()
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.50))
                    Text("LAST SIMULATED")
                        .font(AppTheme.mono(7, weight: .bold)).kerning(0.8)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.50))
                    Text(lastID)
                        .font(AppTheme.mono(8, weight: .semibold))
                        .foregroundStyle(AppTheme.accentPrimary.opacity(0.70))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 7)
            }
        }
        .background(AppTheme.backgroundSecondary.opacity(0.50))
        .id(storyRefreshID)  // re-evaluates UserDefaults read when refresh fires
    }

    // ── Narrative QA ──────────────────────────────────────────────────────

    /// Lightweight catalog-only check — no UIImage calls, runs synchronously.
    struct NarrativeQAReport {
        struct Issue { let severity: Severity; let message: String
            enum Severity { case error, warning }
        }
        let issues: [Issue]
        var errorCount:   Int { issues.filter { $0.severity == .error   }.count }
        var warningCount: Int { issues.filter { $0.severity == .warning }.count }
        var isClean: Bool { errorCount == 0 }
    }

    private func runNarrativeQA() -> NarrativeQAReport {
        var issues: [NarrativeQAReport.Issue] = []
        let beats = StoryBeatCatalog.beats

        // 1. Unique IDs
        let ids = beats.map(\.id)
        let duplicateIDs = Set(ids.filter { id in ids.filter { $0 == id }.count > 1 })
        for id in duplicateIDs.sorted() {
            issues.append(.init(severity: .error, message: "Duplicate beat ID: \(id)"))
        }

        // 2. Non-empty required fields
        for beat in beats {
            if beat.title.isEmpty  { issues.append(.init(severity: .error,   message: "'\(beat.id)' empty title"))  }
            if beat.body.isEmpty   { issues.append(.init(severity: .error,   message: "'\(beat.id)' empty body"))   }
            if beat.source.isEmpty { issues.append(.init(severity: .error,   message: "'\(beat.id)' empty source")) }
        }

        // 3. Locale strings non-empty
        for beat in beats {
            if let lt = beat.localizedTitle {
                if lt.es.isEmpty { issues.append(.init(severity: .error, message: "'\(beat.id)' localizedTitle.es empty")) }
                if lt.fr.isEmpty { issues.append(.init(severity: .error, message: "'\(beat.id)' localizedTitle.fr empty")) }
            }
            if let lb = beat.localizedBody {
                if lb.es.isEmpty { issues.append(.init(severity: .error, message: "'\(beat.id)' localizedBody.es empty")) }
                if lb.fr.isEmpty { issues.append(.init(severity: .error, message: "'\(beat.id)' localizedBody.fr empty")) }
            }
        }

        // 4. Locale strings distinct per language
        for beat in beats {
            if beat.localizedTitle != nil {
                let en = beat.displayTitle(for: .en)
                if beat.displayTitle(for: .es) == en { issues.append(.init(severity: .warning, message: "'\(beat.id)' ES title == EN")) }
                if beat.displayTitle(for: .fr) == en { issues.append(.init(severity: .warning, message: "'\(beat.id)' FR title == EN")) }
            }
            if beat.localizedBody != nil {
                let en = beat.displayBody(for: .en)
                if beat.displayBody(for: .es) == en { issues.append(.init(severity: .warning, message: "'\(beat.id)' ES body == EN")) }
                if beat.displayBody(for: .fr) == en { issues.append(.init(severity: .warning, message: "'\(beat.id)' FR body == EN")) }
            }
        }

        // 5. Beats with no imageName
        let noImage = beats.filter { $0.imageName == nil }
        if !noImage.isEmpty {
            issues.append(.init(severity: .warning,
                                message: "\(noImage.count) beat(s) have no imageName: \(noImage.map(\.id).joined(separator: ", "))"))
        }

        return NarrativeQAReport(issues: issues)
    }

    private var narrativeQASection: some View {
        VStack(spacing: 0) {
            // ── Collapsible header ────────────────────────────────────────
            Button(action: {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                    showNarrativeQA.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.accentPrimary)
                    Text("NARRATIVE QA")
                        .font(AppTheme.mono(9, weight: .black)).kerning(1.2)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    if let r = narrativeQAReport {
                        Text(r.isClean ? "PASS" : "\(r.errorCount)E \(r.warningCount)W")
                            .font(AppTheme.mono(7, weight: .bold)).kerning(0.6)
                            .foregroundStyle(r.isClean ? AppTheme.sage : AppTheme.danger)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((r.isClean ? AppTheme.sage : AppTheme.danger).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Image(systemName: showNarrativeQA ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.50))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showNarrativeQA {
                TechDivider()

                // ── Run button + summary ──────────────────────────────────
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        scenarioBtn("RUN CATALOG CHECK", icon: "doc.badge.gearshape", color: AppTheme.accentPrimary) {
                            let r = runNarrativeQA()
                            narrativeQAReport = r
                            showToast(r.isClean
                                      ? "✓ Catalog clean — \(StoryBeatCatalog.beats.count) beats"
                                      : "✗ \(r.errorCount) error(s), \(r.warningCount) warning(s)",
                                      style: r.isClean ? .success : .fail)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // ── Issue list ────────────────────────────────────────
                    if let r = narrativeQAReport {
                        if r.issues.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.sage)
                                Text("All \(StoryBeatCatalog.beats.count) beats passed catalog checks")
                                    .font(AppTheme.mono(8))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(r.issues.enumerated()), id: \.offset) { _, issue in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(issue.severity == .error ? "✗" : "⚠")
                                            .font(AppTheme.mono(8, weight: .bold))
                                            .foregroundStyle(issue.severity == .error
                                                             ? AppTheme.danger : Color(hex: "FFB800"))
                                        Text(issue.message)
                                            .font(AppTheme.mono(7))
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .lineLimit(2)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    TechDivider()

                    // ── Preview shortcuts ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        TechLabel(text: "PREVIEW BY CATEGORY", color: AppTheme.textSecondary.opacity(0.70))
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(StoryTrigger.allCases, id: \.self) { trigger in
                                    let beats = StoryBeatCatalog.beats.filter { $0.trigger == trigger }
                                    if !beats.isEmpty {
                                        storySimBtn(trigger.rawValue.uppercased().replacingOccurrences(of: "_", with: " "),
                                                    color: AppTheme.textSecondary) {
                                            let sorted = beats.sorted { $0.priority < $1.priority }
                                            if !sorted.isEmpty {
                                                previewBeatQueue = Array(sorted.dropFirst())
                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                    previewingBeat = sorted[0]
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 10)

                    TechDivider()

                    // ── Conflict simulations ──────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        TechLabel(text: "CONFLICT SCENARIOS", color: AppTheme.textSecondary.opacity(0.70))
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                // Preview the first beat that would fire at onboardingComplete
                                // while a paywall would normally appear — verifies beat takes priority.
                                storySimBtn("PAYWALL CONFLICT", color: Color(hex: "FF6B6B")) {
                                    simulateBeat("story_onboarding_complete")
                                    showToast("Beat shown — paywall suppressed during story beat", style: .warning)
                                }
                                // Preview a beat during simulated cooldown — confirms beat still surfaces.
                                storySimBtn("COOLDOWN CONFLICT", color: Color(hex: "FFB800")) {
                                    simulateBeat("story_first_mission_complete")
                                    showToast("Beat shown — cooldown gate yields to story beat", style: .warning)
                                }
                                // Preview all unseen beats in queue order.
                                storySimBtn("QUEUE: ALL UNSEEN", color: AppTheme.accentPrimary) {
                                    playUnseenSequence()
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .background(AppTheme.backgroundSecondary.opacity(0.40))
            }
        }
        .background(AppTheme.surface)
    }

    // ── Asset validation ───────────────────────────────────────────────────

    private var storyAssetSection: some View {
        VStack(spacing: 0) {
            sectionHeader("ASSET VALIDATION")

            HStack(spacing: 8) {
                scenarioBtn("VALIDATE STORY ASSETS", icon: "checklist", color: AppTheme.accent) {
                    assetValidation = StoryAssetValidator.validate()
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if let result = assetValidation {
                VStack(alignment: .leading, spacing: 10) {

                    // ── Summary bar ───────────────────────────────────────
                    HStack(spacing: 0) {
                        miniStat("ERRORS",   "\(result.errorCount)")
                        statDivider()
                        miniStat("WARNINGS", "\(result.warningCount)")
                        statDivider()
                        miniStat("CHECKED",  "\(result.checkedCount)")
                        statDivider()
                        miniStat("ORPHANS",  "\(result.orphanAssets.count)")
                    }
                    .padding(.vertical, 6)
                    .background(result.isValid ? AppTheme.sage.opacity(0.06) : AppTheme.danger.opacity(0.06))

                    // ── 1. Missing assets (ERROR) ─────────────────────────
                    assetResultGroup(
                        icon:  result.missingAssets.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill",
                        color: result.missingAssets.isEmpty ? AppTheme.sage : AppTheme.danger,
                        title: result.missingAssets.isEmpty
                            ? "All \(result.checkedCount) image assets present"
                            : "\(result.missingAssets.count) missing asset(s)",
                        items: result.missingAssets
                    )

                    // ── 2. Beats with no image (WARNING) ──────────────────
                    assetResultGroup(
                        icon:  result.beatsWithNoImage.isEmpty ? "photo.fill" : "exclamationmark.triangle.fill",
                        color: result.beatsWithNoImage.isEmpty ? AppTheme.sage : Color.orange,
                        title: result.beatsWithNoImage.isEmpty
                            ? "All beats have images assigned"
                            : "\(result.beatsWithNoImage.count) beat(s) have no image",
                        items: result.beatsWithNoImage
                    )

                    // ── 3. Placeholder images (ERROR) ─────────────────────
                    if !result.placeholderImages.isEmpty {
                        assetResultGroup(
                            icon:  "exclamationmark.octagon.fill",
                            color: AppTheme.danger,
                            title: "\(result.placeholderImages.count) placeholder image(s) in production beats",
                            items: result.placeholderImages
                        )
                    }

                    // ── 4. Duplicate mappings (WARNING) ───────────────────
                    if !result.duplicateMappings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.orange)
                                Text("\(result.duplicateMappings.count) duplicate image mapping(s) — may be intentional")
                                    .font(AppTheme.mono(10, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            }
                            ForEach(result.duplicateMappings) { dup in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("• \(dup.imageName)")
                                        .font(AppTheme.mono(9, weight: .semibold))
                                        .foregroundStyle(Color.orange.opacity(0.90))
                                    ForEach(dup.beatIDs, id: \.self) { id in
                                        Text("    ↳ \(id)")
                                            .font(AppTheme.mono(8))
                                            .foregroundStyle(AppTheme.textSecondary.opacity(0.70))
                                    }
                                }
                            }
                        }
                    }

                    // ── 5. Orphan assets (WARNING) ────────────────────────
                    assetResultGroup(
                        icon:  result.orphanAssets.isEmpty ? "square.stack.fill" : "questionmark.square.dashed",
                        color: result.orphanAssets.isEmpty ? AppTheme.sage : AppTheme.textSecondary,
                        title: result.orphanAssets.isEmpty
                            ? "No orphan assets in manifest"
                            : "\(result.orphanAssets.count) manifest asset(s) unused by any beat",
                        items: result.orphanAssets
                    )
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
    }

    // ── Summary + global actions + filter pills ────────────────────────────

    private var storyHeaderSection: some View {
        let total    = StoryBeatCatalog.beats.count
        let seenSet  = { _ = storyRefreshID; return StoryStore.seenIDs }()
        let seenCount = StoryBeatCatalog.beats.filter { seenSet.contains($0.id) }.count

        return VStack(spacing: 0) {
            sectionHeader("STORY BEATS")

            // Summary bar
            HStack(spacing: 0) {
                miniStat("TOTAL",  "\(total)")
                statDivider()
                miniStat("SEEN",   "\(seenCount)")
                statDivider()
                miniStat("UNSEEN", "\(total - seenCount)")
            }
            .padding(.vertical, 10)

            TechDivider()

            // Global actions
            HStack(spacing: 8) {
                scenarioBtn("MARK ALL SEEN", icon: "checkmark.circle", color: AppTheme.sage) {
                    StoryStore.markAllSeen()
                    storyRefreshID = UUID()
                    showToast("\(StoryBeatCatalog.beats.count) beats marked seen")
                }
                scenarioBtn("REPLAY LAST", icon: "backward.end.fill", color: Color(hex: "7EC8E3")) {
                    let seenSet = StoryStore.seenIDs
                    if let beat = StoryBeatCatalog.beats.last(where: { seenSet.contains($0.id) }) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            previewingBeat = beat
                        }
                    } else {
                        showToast("No beats seen yet", style: .info)
                    }
                }
                scenarioBtn("RESET ALL", icon: "arrow.counterclockwise", color: AppTheme.danger) {
                    StoryStore.reset()
                    storyRefreshID = UUID()
                    showToast("Story beats reset", style: .warning)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            TechDivider()

            // ── Pending queue inspector ───────────────────────────────────
            // Reads the UserDefaults persistence key written by StoryBeatQueue.
            // Shows beats staged after a win but not yet dispatched (e.g., app was killed).
            storyPendingQueueSection

            TechDivider()

            // Language switcher — changes app language so previews render in selected locale
            HStack(spacing: 0) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Button(action: { settings.language = lang }) {
                        VStack(spacing: 2) {
                            Text(lang.rawValue.uppercased())
                                .font(AppTheme.mono(9, weight: .black)).kerning(1.2)
                                .foregroundStyle(settings.language == lang
                                                 ? AppTheme.accentPrimary
                                                 : AppTheme.textSecondary.opacity(0.50))
                            Text(lang.displayName)
                                .font(AppTheme.mono(6)).kerning(0.4)
                                .foregroundStyle(settings.language == lang
                                                 ? AppTheme.accentPrimary.opacity(0.70)
                                                 : AppTheme.textSecondary.opacity(0.28))
                        }
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(settings.language == lang
                                    ? AppTheme.accentPrimary.opacity(0.08)
                                    : Color.clear)
                    }
                    .buttonStyle(.plain)
                    if lang != AppLanguage.allCases.last {
                        Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(AppTheme.sage.opacity(0.18), lineWidth: 0.5)
            )

            TechDivider()

            // Seen + trigger filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterPill("ALL",    active: storySeenFilter == .all,    color: AppTheme.sage)    { storySeenFilter = .all }
                    filterPill("SEEN",   active: storySeenFilter == .seen,   color: AppTheme.success) { storySeenFilter = storySeenFilter == .seen   ? .all : .seen }
                    filterPill("UNSEEN", active: storySeenFilter == .unseen, color: AppTheme.accentPrimary) { storySeenFilter = storySeenFilter == .unseen ? .all : .unseen }

                    Rectangle().fill(AppTheme.sage.opacity(0.18)).frame(width: 0.5, height: 14)

                    filterPill("TRIGGERS", active: storyTriggerFilter == nil, color: AppTheme.textSecondary) {
                        storyTriggerFilter = nil
                    }
                    ForEach(StoryTrigger.allCases, id: \.self) { trigger in
                        filterPill(storyTriggerLabel(trigger),
                                   active: storyTriggerFilter == trigger,
                                   color: Color(hex: "7EC8E3")) {
                            storyTriggerFilter = storyTriggerFilter == trigger ? nil : trigger
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
            }
            .background(AppTheme.backgroundSecondary)
        }
        .background(AppTheme.surface)
    }

    // ── Story Assets Preview ───────────────────────────────────────────────

    private var storyAssetPreviewSection: some View {
        let beatsWithNoImg = StoryBeatCatalog.beats.filter { $0.imageName == nil }.count
        let reviewed       = reviewedBeatIDs.count
        let total          = StoryBeatCatalog.beats.count

        return VStack(spacing: 0) {
            // Collapsible header
            Button(action: {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                    showAssetPreview.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Text("STORY ASSETS PREVIEW")
                        .font(AppTheme.mono(9, weight: .black)).kerning(1.2)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    // Warning badge if any beats have no image
                    if beatsWithNoImg > 0 {
                        Text("\(beatsWithNoImg) NO IMG")
                            .font(AppTheme.mono(6, weight: .bold)).kerning(0.6)
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Text("\(reviewed)/\(total)")
                        .font(AppTheme.mono(8, weight: .bold)).kerning(0.8)
                        .foregroundStyle(reviewed == total ? AppTheme.sage : AppTheme.textSecondary.opacity(0.50))

                    Image(systemName: showAssetPreview ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showAssetPreview {
                TechDivider()

                // Quick-action bar
                HStack(spacing: 8) {
                    scenarioBtn("MARK ALL REVIEWED", icon: "checkmark.circle", color: AppTheme.sage) {
                        reviewedBeatIDs = Set(StoryBeatCatalog.beats.map(\.id))
                    }
                    scenarioBtn("CLEAR REVIEWED", icon: "xmark.circle", color: AppTheme.textSecondary) {
                        reviewedBeatIDs.removeAll()
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)

                TechDivider()

                ForEach(Array(StoryBeatCatalog.beats.enumerated()), id: \.element.id) { idx, beat in
                    storyAssetPreviewRow(beat)
                    if idx < StoryBeatCatalog.beats.count - 1 { TechDivider() }
                }
            }
        }
        .background(AppTheme.surface)
    }

    @ViewBuilder
    private func storyAssetPreviewRow(_ beat: StoryBeat) -> some View {
        let accent     = beat.accentHex.map { Color(hex: $0) } ?? AppTheme.accentPrimary
        let isReviewed = reviewedBeatIDs.contains(beat.id)
        let assetStatus: StoryAssetValidator.BeatAssetStatus = assetValidation.map {
            StoryAssetValidator.status(for: beat, in: $0)
        } ?? .ok

        HStack(alignment: .top, spacing: 10) {

            // Image thumbnail
            Group {
                if let name = beat.imageName, let uiImg = UIImage(named: name) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 45)
                        .clipped()
                } else {
                    ZStack {
                        AppTheme.backgroundPrimary
                        VStack(spacing: 3) {
                            Image(systemName: "photo.slash")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.orange)
                            Text("NO IMAGE")
                                .font(AppTheme.mono(5, weight: .bold)).kerning(0.5)
                                .foregroundStyle(Color.orange)
                        }
                    }
                    .frame(width: 80, height: 45)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(
                        storyAssetStatusColor(assetStatus).opacity(0.55),
                        lineWidth: assetStatus == .ok ? 0.5 : 1.2
                    )
            )

            // Text block — beat ID, status badge, title, trilingual body
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(beat.id)
                        .font(AppTheme.mono(6))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    // Status badge — only shown after a validation run
                    if assetValidation != nil {
                        storyAssetStatusBadge(assetStatus)
                    }
                }

                Text(beat.displayTitle(for: settings.language))
                    .font(AppTheme.mono(9, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Divider()
                    .background(accent.opacity(0.20))

                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    HStack(alignment: .top, spacing: 4) {
                        Text(lang.rawValue.uppercased())
                            .font(AppTheme.mono(6, weight: .bold)).kerning(0.4)
                            .foregroundStyle(accent.opacity(0.55))
                            .frame(width: 14, alignment: .leading)
                        Text(beat.displayBody(for: lang))
                            .font(AppTheme.mono(7))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Reviewed toggle
            Button(action: {
                if isReviewed {
                    reviewedBeatIDs.remove(beat.id)
                } else {
                    reviewedBeatIDs.insert(beat.id)
                }
            }) {
                Image(systemName: isReviewed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isReviewed ? AppTheme.sage : AppTheme.textSecondary.opacity(0.28))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isReviewed ? AppTheme.sage.opacity(0.04) : Color.clear)
    }

    // ── Asset result group helper ──────────────────────────────────────────

    @ViewBuilder
    private func assetResultGroup(icon: String, color: Color, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(AppTheme.mono(10, weight: .bold))
                    .foregroundStyle(color)
            }
            if !items.isEmpty {
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .font(AppTheme.mono(9))
                        .foregroundStyle(color.opacity(0.75))
                }
            }
        }
    }

    // ── Asset status badge helpers ─────────────────────────────────────────

    private func storyAssetStatusColor(_ status: StoryAssetValidator.BeatAssetStatus) -> Color {
        switch status {
        case .ok:          return AppTheme.sage
        case .noImage:     return Color.orange
        case .missing:     return AppTheme.danger
        case .placeholder: return AppTheme.danger
        case .duplicate:   return Color(hex: "FFB800")
        }
    }

    @ViewBuilder
    private func storyAssetStatusBadge(_ status: StoryAssetValidator.BeatAssetStatus) -> some View {
        let (label, icon): (String, String) = {
            switch status {
            case .ok:          return ("OK",          "checkmark.circle.fill")
            case .noImage:     return ("NO IMG",      "exclamationmark.triangle.fill")
            case .missing:     return ("MISSING",     "xmark.circle.fill")
            case .placeholder: return ("PLACEHOLDER", "exclamationmark.octagon.fill")
            case .duplicate:   return ("DUPLICATE",   "doc.on.doc.fill")
            }
        }()
        let color = storyAssetStatusColor(status)
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .bold))
            Text(label)
                .font(AppTheme.mono(5, weight: .black)).kerning(0.4)
        }
        .foregroundStyle(status == .ok ? color.opacity(0.50) : color)
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(color.opacity(status == .ok ? 0.05 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // ── Simulate triggers ─────────────────────────────────────────────────

    private var storySimulateSection: some View {
        VStack(spacing: 0) {
            sectionHeader("SIMULATE TRIGGERS")

            simulateGroup("SECTOR COMPLETE") {
                ForEach(SpatialRegion.catalog) { sector in
                    storySimBtn("S\(sector.id)", color: sector.accentColor) {
                        simulateBeat(sectorClearID(sector.id))
                    }
                }
            }
            TechDivider()
            simulateGroup("PASS UNLOCKED") {
                ForEach(1...7, id: \.self) { n in
                    storySimBtn("S\(n)", color: AppTheme.accentPrimary) { simulateBeat(passUnlockID(n)) }
                }
            }
            TechDivider()
            simulateGroup("ENTER SECTOR") {
                ForEach(2...8, id: \.self) { n in
                    storySimBtn("S\(n)", color: AppTheme.sage) { simulateBeat(enterSectorID(n)) }
                }
            }
            TechDivider()
            simulateGroup("RANK UP") {
                storySimBtn("LVL 2",  color: AppTheme.accentPrimary) { simulateBeat("rank_up_2")  }
                storySimBtn("LVL 5",  color: AppTheme.accentPrimary) { simulateBeat("rank_up_5")  }
                storySimBtn("LVL 10", color: AppTheme.accentPrimary) { simulateBeat("rank_up_10") }
            }
            TechDivider()
            simulateGroup("MECHANIC UNLOCKED") {
                ForEach(MechanicType.allCases, id: \.self) { m in
                    storySimBtn(m.unlockTitle.components(separatedBy: " ").first ?? m.rawValue,
                                color: Color(hex: "FFB800")) {
                        simulateBeat("mechanic_\(m.rawValue)")
                    }
                }
            }
            TechDivider()
            simulateGroup("OTHER") {
                storySimBtn("LAUNCH 1",    color: AppTheme.sage)          { simulateBeat("story_intro_01")             }
                storySimBtn("LAUNCH 3",    color: AppTheme.sage)          { simulateBeat("story_intro_03")             }
                storySimBtn("POST-INTRO",  color: AppTheme.sage)          { simulateBeat("story_onboarding_complete")  }
                storySimBtn("READY",       color: AppTheme.sage)          { simulateBeat("story_first_mission_ready")  }
                storySimBtn("FIRST WIN",   color: AppTheme.accentPrimary) { simulateBeat("story_first_mission_complete") }
            }
            TechDivider()
            simulateGroup("SEQUENCE") {
                storySimBtn("PLAY INTRO",   color: AppTheme.sage)         { playIntroSequence()  }
                storySimBtn("PLAY UNSEEN",  color: AppTheme.sage)         { playUnseenSequence() }
            }
        }
        .background(AppTheme.surface)
    }

    @ViewBuilder
    private func simulateGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TechLabel(text: label, color: AppTheme.textSecondary.opacity(0.70))
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { content() }
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
    }

    private func storySimBtn(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.mono(7, weight: .bold)).kerning(0.5)
                .foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(color.opacity(0.09))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(color.opacity(0.28), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .buttonStyle(.plain)
    }

    // ── Story Sequence Tester ─────────────────────────────────────────────

    private var storySequenceTesterSection: some View {
        VStack(spacing: 0) {
            // Collapsible header
            Button(action: {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                    showSequenceTester.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Text("STORY SEQUENCE TESTER")
                        .font(AppTheme.mono(9, weight: .black)).kerning(1.2)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("SCENARIO · REPORT")
                        .font(AppTheme.mono(6, weight: .bold)).kerning(0.8)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                    Image(systemName: showSequenceTester ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showSequenceTester {
                TechDivider()

                // ── SECTOR COMPLETE SEQUENCES ──────────────────────────────
                simulateGroup("SECTOR COMPLETE SEQUENCE") {
                    storySimBtn("S1", color: Color(hex: "4DB87A")) {
                        playBeatSequence(["story_earth_complete",
                                         "story_lunar_pass_granted", "story_lunar_intro"])
                    }
                    storySimBtn("S2", color: Color(hex: "D9E7D8")) {
                        playBeatSequence(["sector_2_clear",
                                         "story_mars_unlock", "enter_sector_3"])
                    }
                    storySimBtn("S3", color: Color(hex: "FF6A3D")) {
                        playBeatSequence(["sector_3_clear",
                                         "pass_sector_3", "enter_sector_4"])
                    }
                    storySimBtn("S4", color: Color(hex: "FFB800")) {
                        playBeatSequence(["sector_4_clear",
                                         "pass_sector_4", "enter_sector_5"])
                    }
                    storySimBtn("S5", color: Color(hex: "D4A055")) {
                        playBeatSequence(["sector_5_clear",
                                         "pass_sector_5", "enter_sector_6"])
                    }
                    storySimBtn("S6", color: Color(hex: "E4C87A")) {
                        playBeatSequence(["sector_6_clear",
                                         "pass_sector_6", "enter_sector_7"])
                    }
                    storySimBtn("S7", color: Color(hex: "7EC8E3")) {
                        playBeatSequence(["sector_7_clear",
                                         "pass_sector_7", "enter_sector_8"])
                    }
                    storySimBtn("S8", color: Color(hex: "4B70DD")) {
                        playBeatSequence(["sector_8_clear"])
                    }
                }

                TechDivider()

                // ── RANK UP ────────────────────────────────────────────────
                simulateGroup("RANK UP") {
                    storySimBtn("LVL 2",  color: AppTheme.accentPrimary) {
                        playBeatSequence(["rank_up_2"])
                    }
                    storySimBtn("LVL 5",  color: AppTheme.accentPrimary) {
                        playBeatSequence(["rank_up_5"])
                    }
                    storySimBtn("LVL 10", color: Color(hex: "4B70DD")) {
                        playBeatSequence(["rank_up_10"])
                    }
                }

                TechDivider()

                // ── NARRATIVE MOMENTS ──────────────────────────────────────
                simulateGroup("NARRATIVE MOMENTS") {
                    storySimBtn("FIRST WIN",  color: AppTheme.sage) {
                        playBeatSequence(["story_first_mission_complete"])
                    }
                    storySimBtn("GATE",       color: AppTheme.accentPrimary) {
                        playBeatSequence(["story_onboarding_complete"])
                    }
                    storySimBtn("FULL INTRO", color: AppTheme.sage) {
                        playBeatSequence(["story_intro_01", "story_intro_03",
                                          "story_first_mission_ready",
                                          "story_first_mission_complete",
                                          "story_onboarding_complete"])
                    }
                    storySimBtn("FULL S1",    color: Color(hex: "4DB87A")) {
                        playBeatSequence(["story_intro_01", "story_intro_03",
                                          "story_first_mission_ready",
                                          "story_first_mission_complete",
                                          "story_onboarding_complete",
                                          "story_earth_complete",
                                          "story_lunar_pass_granted",
                                          "story_lunar_intro"])
                    }
                }

                TechDivider()

                // ── CONSISTENCY REPORT ─────────────────────────────────────
                sectionHeader("CONSISTENCY REPORT")

                HStack(spacing: 8) {
                    scenarioBtn("RUN REPORT", icon: "doc.text.magnifyingglass",
                                color: AppTheme.textSecondary) {
                        consistencyReport = buildConsistencyReport()
                        showToast("Report generated", style: .info)
                    }
                    if consistencyReport != nil {
                        scenarioBtn("CLEAR", icon: "xmark.circle", color: AppTheme.danger) {
                            consistencyReport = nil
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)

                if let lines = consistencyReport {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(AppTheme.mono(8))
                                    .foregroundStyle(
                                        line.hasPrefix("──") ? AppTheme.accentPrimary.opacity(0.80) :
                                        line.hasPrefix("⚠️") ? Color.orange :
                                        line.hasPrefix("✓")  ? AppTheme.sage :
                                        line.hasPrefix("  ") ? AppTheme.textSecondary.opacity(0.70) :
                                        AppTheme.textPrimary
                                    )
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 14)
                    }
                }
            }
        }
        .background(AppTheme.surface)
    }

    // ── Helpers: sequence playback ─────────────────────────────────────────

    /// Preview a specific list of beat IDs in sequence via the StoryModal overlay.
    /// Ignores seen status — always shows all specified beats.
    private func playBeatSequence(_ ids: [String]) {
        let queue = ids.compactMap { id in StoryBeatCatalog.beats.first(where: { $0.id == id }) }
        guard !queue.isEmpty else {
            showToast("No beats found for sequence", style: .info)
            return
        }
        previewBeatQueue = Array(queue.dropFirst())
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            previewingBeat = queue[0]
        }
    }

    // ── Consistency report generator ───────────────────────────────────────

    private func buildConsistencyReport() -> [String] {
        let beats   = StoryBeatCatalog.beats
        let seenSet = StoryStore.seenIDs
        var lines   = [String]()

        lines.append("── BEAT CATALOG  (\(beats.count) total) ─────────────────────")
        for trigger in StoryTrigger.allCases {
            let group = beats.filter { $0.trigger == trigger }.sorted { $0.priority < $1.priority }
            guard !group.isEmpty else { continue }
            lines.append("\(storyTriggerLabel(trigger).padding(toLength: 14, withPad: " ", startingAt: 0)): \(group.count) beat(s)")
            for b in group {
                let img  = b.imageName != nil ? "🖼" : "⚠️"
                let seen = seenSet.contains(b.id) ? "✓" : "○"
                let once = b.onceOnly ? "" : " ↻"
                lines.append("  [\(String(b.priority).padding(toLength: 2, withPad: " ", startingAt: 0))] \(seen)\(img)\(once) \(b.id)")
            }
        }

        lines.append("")
        lines.append("── IMAGES ────────────────────────────────────────────")
        let noImg = beats.filter { $0.imageName == nil }
        if noImg.isEmpty {
            lines.append("✓ All \(beats.count) beats have images assigned")
        } else {
            lines.append("⚠️ \(noImg.count) beat(s) have no image:")
            for b in noImg { lines.append("  \(b.id)") }
        }

        lines.append("")
        lines.append("── REPEATABILITY ─────────────────────────────────────")
        let repeatable = beats.filter { !$0.onceOnly }
        lines.append("Once-only: \(beats.count - repeatable.count)  Repeatable: \(repeatable.count)")
        for b in repeatable { lines.append("  ↻ \(b.id)") }

        lines.append("")
        lines.append("── SEQUENCE GROUPS ───────────────────────────────────")
        let grouped = Dictionary(grouping: beats.filter { $0.sequenceGroup != nil },
                                 by: { $0.sequenceGroup! })
        if grouped.isEmpty {
            lines.append("  (none)")
        } else {
            for key in grouped.keys.sorted() {
                let members = grouped[key]!.sorted { $0.orderInSequence < $1.orderInSequence }
                lines.append("  [\(key)] \(members.count) beats:")
                for b in members { lines.append("    [\(b.orderInSequence)] \(b.id)") }
            }
        }

        lines.append("")
        lines.append("── PRIORITY CONFLICTS ────────────────────────────────")
        var conflicts = false
        for trigger in StoryTrigger.allCases {
            let group = beats.filter { $0.trigger == trigger }
            let priorityCounts = Dictionary(grouping: group, by: { $0.priority })
            for (priority, dupes) in priorityCounts where dupes.count > 1 {
                conflicts = true
                lines.append("⚠️ Trigger \(storyTriggerLabel(trigger)) has \(dupes.count) beats at priority \(priority):")
                for b in dupes { lines.append("  \(b.id)") }
            }
        }
        if !conflicts { lines.append("✓ No priority conflicts") }

        lines.append("")
        lines.append("── PROGRESS ──────────────────────────────────────────")
        let seenCount = beats.filter { seenSet.contains($0.id) }.count
        lines.append("Seen:   \(seenCount) / \(beats.count)")
        lines.append("Unseen: \(beats.count - seenCount)")

        return lines
    }

    // ── Beat catalog list ─────────────────────────────────────────────────

    private var storyBeatList: some View {
        let seenSet = { _ = storyRefreshID; return StoryStore.seenIDs }()
        let beats   = filteredStoryBeats

        return VStack(spacing: 0) {
            // ── Search field ──────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(storySearch.isEmpty ? AppTheme.textSecondary : AppTheme.accentPrimary)
                TextField("SEARCH TITLE · ID · BODY", text: $storySearch)
                    .font(AppTheme.mono(10, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                if !storySearch.isEmpty {
                    Button(action: { storySearch = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(AppTheme.backgroundSecondary)
            .overlay(alignment: .bottom) { TechDivider() }

            sectionHeader("BEAT CATALOG  ·  \(beats.count) / \(StoryBeatCatalog.beats.count)")

            if beats.isEmpty {
                TechLabel(text: "NO BEATS MATCH CURRENT FILTER", color: AppTheme.textSecondary.opacity(0.40))
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ForEach(Array(beats.enumerated()), id: \.element.id) { idx, beat in
                    storyBeatRow(beat, isSeen: seenSet.contains(beat.id))
                    if idx < beats.count - 1 { TechDivider() }
                }
            }
        }
    }

    private func storyBeatRow(_ beat: StoryBeat, isSeen: Bool) -> some View {
        let accent = beat.accentHex.map { Color(hex: $0) } ?? AppTheme.accentPrimary

        return VStack(alignment: .leading, spacing: 0) {

            // ── Header row ────────────────────────────────────────────────
            HStack(spacing: 7) {
                Circle()
                    .fill(isSeen ? AppTheme.textSecondary.opacity(0.22) : accent)
                    .frame(width: 5, height: 5)

                Text(storyTriggerLabel(beat.trigger))
                    .font(AppTheme.mono(6, weight: .bold)).kerning(0.8)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(accent.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(accent.opacity(0.30), lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                Text(beat.id)
                    .font(AppTheme.mono(6)).foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                    .lineLimit(1)

                Spacer()

                // Image asset indicator
                Image(systemName: beat.imageName != nil ? "photo.fill" : "photo")
                    .font(.system(size: 7))
                    .foregroundStyle(beat.imageName != nil
                        ? accent.opacity(isSeen ? 0.35 : 0.65)
                        : AppTheme.textSecondary.opacity(0.25))

                Text(isSeen ? "SEEN" : "UNSEEN")
                    .font(AppTheme.mono(6, weight: .bold)).kerning(0.5)
                    .foregroundStyle(isSeen ? AppTheme.textSecondary.opacity(0.35) : accent.opacity(0.75))
            }
            .padding(.horizontal, 14).padding(.top, 10)

            // ── Title + source ─────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(beat.title)
                    .font(AppTheme.mono(11, weight: .black)).kerning(1)
                    .foregroundStyle(isSeen ? AppTheme.textSecondary : AppTheme.textPrimary)
                Text("· \(beat.source)")
                    .font(AppTheme.mono(7)).foregroundStyle(AppTheme.textSecondary.opacity(0.50))
            }
            .padding(.horizontal, 14).padding(.top, 4)

            // ── Body ───────────────────────────────────────────────────────
            Text(beat.body)
                .font(AppTheme.mono(9))
                .foregroundStyle(AppTheme.textSecondary.opacity(isSeen ? 0.40 : 0.70))
                .lineSpacing(3).lineLimit(3)
                .padding(.horizontal, 14).padding(.top, 3)

            // ── Footer hint ────────────────────────────────────────────────
            if let hint = beat.footerHint {
                Text(hint)
                    .font(AppTheme.mono(7, weight: .bold)).kerning(0.8)
                    .foregroundStyle(accent.opacity(isSeen ? 0.35 : 0.60))
                    .padding(.horizontal, 14).padding(.top, 3)
            }

            // ── Actions ────────────────────────────────────────────────────
            HStack(spacing: 6) {
                // Preview — shows the real StoryBeatView overlay, no side effects
                storyActionBtn("eye", "PREVIEW", color: AppTheme.accentPrimary) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        previewingBeat = beat
                    }
                }
                // Replay — marks unseen so it fires naturally; also shows preview
                storyActionBtn("arrow.counterclockwise", "REPLAY", color: Color(hex: "7EC8E3")) {
                    StoryStore.markUnseen(beat)
                    storyRefreshID = UUID()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        previewingBeat = beat
                    }
                }
                // Toggle seen / unseen
                storyActionBtn(isSeen ? "eye.slash" : "checkmark.circle",
                               isSeen ? "MARK UNSEEN" : "MARK SEEN",
                               color: isSeen ? AppTheme.textSecondary : AppTheme.success) {
                    if isSeen { StoryStore.markUnseen(beat) } else { StoryStore.markSeen(beat) }
                    storyRefreshID = UUID()
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .background(isSeen ? AppTheme.backgroundPrimary : AppTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSeen ? AppTheme.sage.opacity(0.12) : accent)
                .frame(width: 2)
        }
    }

    private func storyActionBtn(_ icon: String, _ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 7, weight: .bold))
                Text(label).font(AppTheme.mono(7, weight: .bold)).kerning(0.4)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(color.opacity(0.09))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(0.32), lineWidth: 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    // ── Story helpers ──────────────────────────────────────────────────────

    private var filteredStoryBeats: [StoryBeat] {
        _ = storyRefreshID
        let seenSet = StoryStore.seenIDs
        let q = storySearch.lowercased().trimmingCharacters(in: .whitespaces)
        return StoryBeatCatalog.beats.filter { beat in
            if !q.isEmpty {
                let hit = beat.title.lowercased().contains(q)
                       || beat.id.lowercased().contains(q)
                       || beat.body.lowercased().contains(q)
                if !hit { return false }
            }
            switch storySeenFilter {
            case .all:    break
            case .seen:   if !seenSet.contains(beat.id) { return false }
            case .unseen: if  seenSet.contains(beat.id) { return false }
            }
            if let t = storyTriggerFilter, beat.trigger != t { return false }
            return true
        }
    }

    private func storyTriggerLabel(_ trigger: StoryTrigger) -> String {
        switch trigger {
        case .firstLaunch:           return "LAUNCH"
        case .firstMissionReady:     return "READY"
        case .firstMissionComplete:  return "FIRST WIN"
        case .onboardingComplete:    return "GATE"
        case .sectorComplete:        return "SECTOR"
        case .passUnlocked:          return "PASS"
        case .rankUp:                return "RANK"
        case .mechanicUnlocked:      return "MECHANIC"
        case .enteringNewSector:     return "NEW SECTOR"
        }
    }

    private func simulateBeat(_ id: String) {
        guard let beat = StoryBeatCatalog.beats.first(where: { $0.id == id }) else { return }
        lastSimulatedID = id
        previewBeatQueue = []
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { previewingBeat = beat }
    }

    private func advancePreviewBeatQueue() {
        if previewBeatQueue.isEmpty {
            previewingBeat = nil
        } else {
            previewingBeat = previewBeatQueue.removeFirst()
        }
    }

    private func playIntroSequence() {
        let ids = ["story_intro_01", "story_intro_03", "story_first_mission_ready",
                   "story_first_mission_complete", "story_onboarding_complete"]
        let queue = ids.compactMap { id in StoryBeatCatalog.beats.first(where: { $0.id == id }) }
        guard !queue.isEmpty else { return }
        previewBeatQueue = Array(queue.dropFirst())
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { previewingBeat = queue[0] }
    }

    private func playUnseenSequence() {
        let seen  = StoryStore.seenIDs
        let queue = StoryBeatCatalog.beats.filter { !seen.contains($0.id) }
        guard !queue.isEmpty else { return }
        previewBeatQueue = Array(queue.dropFirst())
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { previewingBeat = queue[0] }
    }

    /// Returns the catalog beat ID for a given sector-complete event.
    private func sectorClearID(_ sectorID: Int) -> String {
        switch sectorID {
        case 1:  return "story_earth_complete"
        default: return "sector_\(sectorID)_clear"
        }
    }

    /// Returns the catalog beat ID for a given pass-unlocked event.
    private func passUnlockID(_ sectorID: Int) -> String {
        switch sectorID {
        case 1:  return "story_lunar_pass_granted"
        case 2:  return "story_mars_unlock"
        default: return "pass_sector_\(sectorID)"
        }
    }

    /// Returns the catalog beat ID for entering a given sector.
    private func enterSectorID(_ sectorID: Int) -> String {
        switch sectorID {
        case 2:  return "story_lunar_intro"
        default: return "enter_sector_\(sectorID)"
        }
    }

    // MARK: - RESET tab

    private var resetPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Danger banner ─────────────────────────────────────────
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.danger)
                        Text("DANGER ZONE")
                            .font(AppTheme.mono(13, weight: .black))
                            .foregroundStyle(AppTheme.danger)
                            .kerning(2)
                    }
                    Text("All actions are permanent and cannot be undone.\nA confirmation dialog will appear before any action executes.")
                        .font(AppTheme.mono(8))
                        .foregroundStyle(AppTheme.danger.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16).padding(.vertical, 16)
                .background(AppTheme.danger.opacity(0.07))
                .overlay(alignment: .bottom) { TechDivider() }

                // ── NUCLEAR — full wipe ───────────────────────────────────
                sectionHeaderDanger("NUCLEAR — FULL WIPE")

                VStack(spacing: 8) {
                    resetRow(
                        "RESET ALL PROGRESS",
                        sub: "level · missions · passes · mechanics · story · onboarding",
                        color: AppTheme.danger
                    ) { pendingReset = .all }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                TechDivider()

                // ── SELECTIVE — partial resets ────────────────────────────
                sectionHeader("SELECTIVE")

                VStack(spacing: 8) {
                    resetRow(
                        "RESET MISSION DATA",
                        sub: "clears completions, keeps level",
                        color: AppTheme.accentPrimary
                    ) { pendingReset = .missions }

                    resetRow(
                        "RESET PLANET PASSES",
                        sub: "removes passes + image cache",
                        color: AppTheme.sage
                    ) { pendingReset = .passes }

                    resetRow(
                        "RESET MECHANIC UNLOCKS",
                        sub: "all 8 unlock messages will show again",
                        color: AppTheme.sage
                    ) { pendingReset = .mechanics }

                    resetRow(
                        "RESET STORY BEATS",
                        sub: "all \(StoryBeatCatalog.beats.count) beats fire again from their triggers",
                        color: Color(hex: "7EC8E3")
                    ) { pendingReset = .story }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }

    // MARK: - Versus panel

    private var versusPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                sectionHeader("FEATURE FLAG")

                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("VERSUS MODE")
                                .font(AppTheme.mono(11, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Toggle to show Versus CTA on Home")
                                .font(AppTheme.mono(8))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { VersusFeatureFlag.isEnabled },
                            set: { VersusFeatureFlag.setEnabled($0) }
                        ))
                        .labelsHidden()
                        .tint(AppTheme.accentPrimary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                TechDivider()
                sectionHeader("GAME CENTER")

                VStack(spacing: 8) {
                    HStack {
                        Text("GC AUTH")
                            .font(AppTheme.mono(9, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(gcManager.isAuthenticated ? AppTheme.success : AppTheme.danger)
                                .frame(width: 6, height: 6)
                            Text(gcManager.isAuthenticated ? gcManager.displayName : "NOT CONNECTED")
                                .font(AppTheme.mono(9, weight: .bold))
                                .foregroundStyle(gcManager.isAuthenticated ? AppTheme.success : AppTheme.danger)
                        }
                    }

                    HStack {
                        Text("LOCAL PLAYER ID")
                            .font(AppTheme.mono(9, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text(GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.gamePlayerID.prefix(12) + "…" : "—")
                            .font(AppTheme.mono(8))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                TechDivider()
                sectionHeader("MATCH STATE")

                VStack(spacing: 8) {
                    let state = VersusMatchmakingManager.shared.matchState
                    devRow("PHASE", "\(state.phase)")
                    devRow("IS HOST", state.isHost ? "YES" : "NO")
                    devRow("SEED", state.sharedSeed == 0 ? "—" : "\(state.sharedSeed)")
                    devRow("OPPONENT", state.opponentDisplayName)
                    devRow("LOCAL STATUS", state.localSnapshot.status.uppercased())
                    devRow("REMOTE STATUS", state.remoteSnapshot.status.uppercased())
                    devRow("LOCAL OUTCOME", state.localOutcome?.rawValue.uppercased() ?? "—")
                    devRow("REMOTE OUTCOME", state.remoteOutcome?.rawValue.uppercased() ?? "—")
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                TechDivider()
                sectionHeader("ACTIONS")

                VStack(spacing: 8) {
                    Button(action: { VersusMatchmakingManager.shared.findMatch() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("FIND MATCH")
                                .font(AppTheme.mono(10, weight: .bold))
                                .kerning(0.8)
                        }
                        .foregroundStyle(gcManager.isAuthenticated ? AppTheme.accentPrimary : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentPrimary.opacity(gcManager.isAuthenticated ? 0.12 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(AppTheme.accentPrimary.opacity(gcManager.isAuthenticated ? 0.4 : 0.15), lineWidth: 0.6)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .disabled(!gcManager.isAuthenticated)

                    Button(action: { VersusMatchmakingManager.shared.disconnect() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 10, weight: .bold))
                            Text("DISCONNECT")
                                .font(AppTheme.mono(10, weight: .bold))
                                .kerning(0.8)
                        }
                        .foregroundStyle(AppTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.danger.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(AppTheme.danger.opacity(0.35), lineWidth: 0.6)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }

    private func devRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.mono(9, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.mono(9, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    // MARK: - Layout helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Rectangle().fill(AppTheme.accentPrimary).frame(width: 2, height: 10)
            TechLabel(text: title, color: AppTheme.accentPrimary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(AppTheme.backgroundSecondary)
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private func sectionHeaderDanger(_ title: String) -> some View {
        HStack(spacing: 7) {
            Rectangle().fill(AppTheme.danger).frame(width: 2, height: 10)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(AppTheme.danger)
            TechLabel(text: title, color: AppTheme.danger)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(AppTheme.danger.opacity(0.06))
        .overlay(alignment: .bottom) { TechDivider() }
    }

    private func stepperBtn(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(enabled ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.35))
                .frame(width: 44, height: 36)
        }
        .disabled(!enabled)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            TechLabel(text: label, color: AppTheme.textSecondary.opacity(0.55))
            Text(value)
                .font(AppTheme.mono(9, weight: .bold))
                .foregroundStyle(AppTheme.sage)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func statDivider() -> some View {
        Rectangle().fill(AppTheme.sage.opacity(0.14)).frame(width: 0.5, height: 28)
    }

    private func resetRow(
        _ title: String,
        sub: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppTheme.mono(9, weight: .bold))
                        .foregroundStyle(color)
                        .kerning(0.8)
                    Text(sub)
                        .font(AppTheme.mono(7))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(color.opacity(0.45))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(color.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func showToast(_ message: String, style: DevToast.Style = .success) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            devToast = DevToast(message: message, style: style)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(2400))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) { devToast = nil }
            }
        }
    }

    private func applyLevelJump() {
        ProgressionStore.devSetLevel(devLevel)
        TicketCache.shared.invalidateAll()
        refreshID = UUID()
        showToast("LVL \(devLevel) · \(rankLabel(for: devLevel))")
    }

    private func executeReset(_ action: ResetAction) {
        switch action {
        case .all:
            ProgressionStore.devResetAll()
            StoryStore.reset()
            OnboardingStore.resetAll()
            EntitlementStore.shared.setPremium(false)
            EntitlementStore.shared.resetIntroCount()
            EntitlementStore.shared.resetDailyCount()
            TicketCache.shared.invalidateAll()
            showToast("All progress cleared", style: .warning)
        case .missions:
            ProgressionStore.devResetMissions()
            TicketCache.shared.invalidateAll()
            showToast("Mission data cleared")
        case .passes:
            PassStore.reset()
            TicketCache.shared.invalidateAll()
            showToast("Planet passes cleared")
        case .mechanics:
            MechanicUnlockStore.reset()
            showToast("Mechanic unlocks cleared")
        case .story:
            StoryStore.reset()
            storyRefreshID = UUID()
            showToast("Story beats reset")
        }
        devLevel     = ProgressionStore.profile.level
        refreshID    = UUID()
        pendingReset = nil
    }

    private func resetFilters() {
        filterDifficulty = nil
        filterObjective  = nil
        filterStatus     = .all
    }

    #if DEBUG
    private func runDifficultyAnalysis() {
        guard !isAnalyzing else { return }
        isAnalyzing            = true
        analysisDataset        = []
        analysisIssues         = []
        analysisSuggestions    = []
        analysisPhases         = []
        analysisCurveAnomalies = []
        Task.detached(priority: .userInitiated) {
            let ds          = DifficultyDataset.build()
            let issues      = LevelIssueDetector.detect(from: ds)
            let suggestions = RebalancingEngine.suggest(from: ds)
            let (phases, curveAnomalies) = DifficultyCurveAnalyzer.analyze(ds)

            // Always print to console for detailed dev inspection
            DifficultyCurveAnalyzer.printReport(phases: phases, anomalies: curveAnomalies)

            await MainActor.run {
                analysisDataset        = ds
                analysisIssues         = issues
                analysisSuggestions    = suggestions
                analysisPhases         = phases
                analysisCurveAnomalies = curveAnomalies
                isAnalyzing            = false
            }
        }
    }

    private func logRebalancePatch() {
        guard !analysisSuggestions.isEmpty else { return }
        RebalancingEngine.printPatch(analysisSuggestions)
    }

    private func resetAnalysis() {
        analysisDataset        = []
        analysisIssues         = []
        analysisSuggestions    = []
        analysisPhases         = []
        analysisCurveAnomalies = []
        analysisIssueFilter    = nil
        isAnalyzing            = false
    }

    private func runValidation(useSolver: Bool) {
        isValidating      = true
        validationReports = []
        Task.detached(priority: .userInitiated) {
            let reports = LevelValidationRunner.validateAll(useSolver: useSolver)
            LevelValidationRunner.printReport(reports)
            await MainActor.run {
                validationReports = reports
                isValidating      = false
            }
        }
    }

    private func runStartsSolvedCheck() {
        isCheckingStartsSolved = true
        startsSolvedBroken     = []
        startsSolvedChecked    = false
        let totalCount = LevelGenerator.levels.count
        Task.detached(priority: .userInitiated) {
            let broken = LevelValidationRunner.findStartsSolvedLevels()
            if broken.isEmpty {
                print("✅ [StartsSolved] All \(totalCount) levels OK — no pre-solved boards")
            } else {
                print("❌ [StartsSolved] \(broken.count) pre-solved level(s) detected:")
                for level in broken {
                    print(String(format: "   L%03d  %@  %@  %dx%d",
                        level.id,
                        level.difficulty.fullLabel,
                        level.objectiveType.hudLabel,
                        level.gridSize, level.gridSize))
                }
            }
            await MainActor.run {
                startsSolvedBroken     = broken
                startsSolvedChecked    = true
                isCheckingStartsSolved = false
                let msg = broken.isEmpty
                    ? "ALL \(totalCount) OK — NO PRE-SOLVED LEVELS"
                    : "\(broken.count) PRE-SOLVED LEVEL\(broken.count == 1 ? "" : "S") FOUND"
                showToast(msg, style: broken.isEmpty ? .success : .fail)
            }
        }
    }
    #endif

    private func rankLabel(for level: Int) -> String {
        switch level {
        case 1...2:  return "CADET"
        case 3...4:  return "PILOT"
        case 5...6:  return "NAVIGATOR"
        case 7...9:  return "COMMANDER"
        default:     return "ADMIRAL"
        }
    }
}

// MARK: - DevPassViewerOverlay
/// Full-screen overlay showing a rendered PlanetPass ticket card and its metadata.
/// Tap anywhere to dismiss.
private struct DevPassViewerOverlay: View {
    let pass: PlanetPass
    let onDismiss: () -> Void

    private var planet: Planet {
        Planet.catalog[min(pass.planetIndex, Planet.catalog.count - 1)]
    }

    @State private var ticketImage: UIImage? = nil
    @State private var cardAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.90).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Spacer()

                // ── Planet header ──────────────────────────────────────────
                VStack(spacing: 6) {
                    Text(pass.planetName)
                        .font(AppTheme.mono(13, weight: .black))
                        .foregroundStyle(planet.color)
                        .kerning(3)
                    TechLabel(text: "PLANET PASS  ·  \(pass.serialCode)", color: planet.color.opacity(0.60))
                }
                .padding(.bottom, 24)

                // ── Rendered ticket card ───────────────────────────────────
                Group {
                    if let img = ticketImage {
                        Image(uiImage: img)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: planet.color.opacity(0.45), radius: 32, y: 8)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(planet.color.opacity(0.07))
                            .frame(width: 280, height: 158)
                            .overlay {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(planet.color.opacity(0.60))
                            }
                    }
                }
                .opacity(cardAppeared ? 1 : 0)
                .scaleEffect(cardAppeared ? 1 : 0.82)
                .rotation3DEffect(.degrees(cardAppeared ? 0 : -6), axis: (x: 1, y: 0, z: 0))
                .padding(.bottom, 28)

                // ── Metadata grid ──────────────────────────────────────────
                HStack(spacing: 0) {
                    passMetaStat("LEVEL",     "\(pass.levelReached)")
                    passMetaDivider()
                    passMetaStat("EFF",       "\(Int(pass.efficiencyScore * 100))%")
                    passMetaDivider()
                    passMetaStat("MISSIONS",  "\(pass.missionCount)")
                    passMetaDivider()
                    passMetaStat("ISSUED",    issuedLabel)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

                // ── Dev footer ─────────────────────────────────────────────
                HStack(spacing: 4) {
                    Image(systemName: "info.circle").font(.system(size: 8))
                    Text("DEV PASS VIEWER  ·  TAP TO DISMISS")
                        .font(AppTheme.mono(7)).kerning(0.4)
                }
                .foregroundStyle(AppTheme.textSecondary.opacity(0.35))

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.10)) {
                cardAppeared = true
            }
            let p = pass; let profile = ProgressionStore.profile
            Task.detached(priority: .userInitiated) {
                let img = TicketRenderer.render(pass: p, profile: profile)
                await MainActor.run { ticketImage = img }
            }
        }
    }

    private static let issuedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var issuedLabel: String {
        Self.issuedFormatter.string(from: pass.timestamp)
    }

    private func passMetaStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            TechLabel(text: label, color: planet.color.opacity(0.55))
            Text(value)
                .font(AppTheme.mono(10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func passMetaDivider() -> some View {
        Rectangle().fill(planet.color.opacity(0.18)).frame(width: 0.5, height: 28)
    }
}

// MARK: - DevMechanicPreviewCard
/// Full-screen reproduction of MechanicUnlockView that takes a language parameter directly,
/// so the dev menu can preview any mechanic in any language without touching SettingsStore.
private struct DevMechanicPreviewCard: View {
    let mechanic: MechanicType
    let language: AppLanguage
    let onDismiss: () -> Void

    private var S: AppStrings { AppStrings(lang: language) }
    private let amber = Color(hex: "FFB800")

    @State private var bodyRevealed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────
                VStack(spacing: 10) {
                    Image(systemName: mechanic.iconName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(amber)
                        .pulsingGlow(color: amber, duration: 1.3)

                    TechLabel(text: S.newMechanicUnlocked, color: amber)

                    Text(S.mechanicTitle(mechanic))
                        .font(AppTheme.mono(20, weight: .black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .kerning(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(AppTheme.surface)

                TechDivider()

                // ── Message ───────────────────────────────────────────────
                Text(S.mechanicMessage(mechanic))
                    .font(AppTheme.mono(11))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.backgroundSecondary)
                    .opacity(bodyRevealed ? 1 : 0)
                    .offset(y: bodyRevealed ? 0 : 8)

                TechDivider()

                // ── CTA ───────────────────────────────────────────────────
                Button(action: onDismiss) {
                    Text(S.understood)
                        .font(AppTheme.mono(12, weight: .bold))
                        .kerning(2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(amber)
                        .foregroundStyle(Color.black)
                }

                // ── Dev footer ────────────────────────────────────────────
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 8))
                    Text("DEV PREVIEW  ·  \(language.rawValue.uppercased())")
                        .font(AppTheme.mono(7))
                        .kerning(0.5)
                }
                .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(AppTheme.backgroundPrimary)
            }
            .background(AppTheme.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(amber.opacity(0.55), lineWidth: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82).delay(0.20)) {
                bodyRevealed = true
            }
        }
    }
}
