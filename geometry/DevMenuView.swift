import SwiftUI
import StoreKit

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

    @EnvironmentObject private var settings:  SettingsStore
    @EnvironmentObject private var storeKit:  StoreKitManager
    @EnvironmentObject private var gcManager: GameCenterManager

    // ── Tab ───────────────────────────────────────────────────────────────
    enum DevTab { case overview, missions, story, tools, money, reset, qa, sim }
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
    /// Bumped after any seen/unseen toggle to force list recomputation.
    @State private var storyRefreshID:     UUID            = UUID()
    /// Result of the last StoryAssetValidator run (nil = not yet run).
    @State private var assetValidation:    StoryAssetValidator.Result? = nil
    @State private var storySearch:        String = ""

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
        case all, failed, trivial, warnings, expert
        var label: String { rawValue.uppercased() }
    }
    @State private var validationFilter: ValidationResultFilter = .all

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
    @State private var devPaywallContext: PaywallContext = .standard

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

                switch activeTab {
                case .overview:
                    overviewPanel
                case .missions:
                    missionJumpBar
                    filterBar
                    TechDivider()
                    levelList
                case .story:
                    storyPanel
                case .tools:
                    toolsPanel
                case .money:
                    moneyPanel
                case .reset:
                    resetPanel
                case .qa:
                    SelfQAView(runner: qaRunner) { level in
                        onSelect(level)
                        onDismiss()
                    }
                case .sim:
                    PlayerSimulationView(runner: simRunner)
                }
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
                StoryModal(beat: beat, hasNext: false) {
                    withAnimation(.easeOut(duration: 0.22)) { previewingBeat = nil }
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
                miniStat("DAILY",   isPrem ? "∞" : "\(store.dailyCompleted)/\(EntitlementStore.dailyLimit)")
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
        let gcDetail: String  = gcManager.isAuthenticated
                              ? gcManager.displayName.isEmpty ? "AUTHENTICATED" : gcManager.displayName
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
            let issues = validationReports.filter { !$0.isSolvable || !$0.warnings.isEmpty || $0.isTrivial }
            validStat  = issues.isEmpty ? .pass : .warning
            validDetail = issues.isEmpty
                ? "ALL \(validationReports.count) OK"
                : "\(issues.count) ISSUES IN \(validationReports.count)"
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
            monetizationSection
        }
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
        let store     = EntitlementStore.shared
        let isPremium = store.isPremium
        let used      = store.dailyCompleted
        let limit     = EntitlementStore.dailyLimit
        let remaining = store.remainingToday
        let skProduct = storeKit.product
        let skState   = storeKit.purchaseState
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

        return VStack(spacing: 0) {
            sectionHeader("MONETIZATION  ·  STATUS")

            HStack(spacing: 0) {
                miniStat("PLAN",    isPremium ? "PREMIUM" : "FREE")
                statDivider()
                miniStat("USED",    "\(used)/\(limit)")
                statDivider()
                miniStat("REMAIN",  isPremium ? "∞" : "\(remaining)")
                statDivider()
                miniStat("LIMIT",   store.dailyLimitReached ? "HIT" : "OK")
            }
            .padding(.vertical, 10)

            TechDivider()

            HStack(spacing: 0) {
                miniStat("SECTOR",  "\(profile.progression.currentSector.id)")
                statDivider()
                miniStat("MISSION", profile.nextMission?.displayID ?? "—")
                statDivider()
                miniStat("SK",      skLabel)
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
        let limit     = EntitlementStore.dailyLimit

        return VStack(spacing: 0) {
            sectionHeader("CONTROLS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn(
                        isPremium ? "SET FREE" : "SET PREMIUM",
                        icon: isPremium ? "lock.open" : "star.fill",
                        color: isPremium ? AppTheme.danger : AppTheme.accentPrimary
                    ) {
                        store.setPremium(!isPremium)
                        refreshID = UUID()
                        showToast(isPremium ? "Plan → FREE" : "Plan → PREMIUM", style: .info)
                    }
                    scenarioBtn("RESET DAILY", icon: "arrow.counterclockwise", color: AppTheme.sage) {
                        store.resetDailyCount()
                        refreshID = UUID()
                        showToast("Daily count reset")
                    }
                    ForEach(0...limit, id: \.self) { n in
                        scenarioBtn("SET \(n)/\(limit)", icon: "number",
                                    color: n == limit ? AppTheme.danger : AppTheme.textSecondary) {
                            store.resetDailyCount()
                            let lunar = LevelGenerator.levels.first { $0.id > 30 } ?? LevelGenerator.levels[0]
                            for _ in 0..<n { store.recordMissionCompleted(lunar) }
                            refreshID = UUID()
                        }
                    }
                    scenarioBtn("FORCE LIMIT", icon: "hand.raised.fill", color: AppTheme.danger) {
                        store.resetDailyCount()
                        let lunar = LevelGenerator.levels.first { $0.id > 30 } ?? LevelGenerator.levels[0]
                        for _ in 0..<limit { store.recordMissionCompleted(lunar) }
                        refreshID = UUID()
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
        let limit = EntitlementStore.dailyLimit

        return VStack(spacing: 0) {
            sectionHeader("PAYWALL TEST")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn("STANDARD", icon: "lock.fill", color: AppTheme.accentPrimary) {
                        devPaywallContext = .standard
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                    }
                    scenarioBtn("POST-VICTORY", icon: "checkmark.circle.fill", color: AppTheme.success) {
                        devPaywallContext = .postVictory
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                    }
                    scenarioBtn("HARD BLOCK", icon: "xmark.shield.fill", color: AppTheme.danger) {
                        store.resetDailyCount()
                        let lunar = LevelGenerator.levels.first { $0.id > 30 } ?? LevelGenerator.levels[0]
                        for _ in 0..<limit { store.recordMissionCompleted(lunar) }
                        devPaywallContext = .standard
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                        refreshID = UUID()
                    }
                    scenarioBtn("STREAK CTX", icon: "flame.fill", color: .orange) {
                        devPaywallContext = .postVictory
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
        let limit = EntitlementStore.dailyLimit

        return VStack(spacing: 0) {
            sectionHeader("SCENARIO SIMULATION")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scenarioBtn("FREE USER", icon: "person.fill", color: AppTheme.sage) {
                        store.setPremium(false)
                        store.resetDailyCount()
                        refreshID = UUID()
                    }
                    scenarioBtn("PREMIUM USER", icon: "star.fill", color: AppTheme.accentPrimary) {
                        store.setPremium(true)
                        refreshID = UUID()
                    }
                    scenarioBtn("LIMIT REACHED", icon: "hand.raised.fill", color: AppTheme.danger) {
                        store.setPremium(false)
                        store.resetDailyCount()
                        let lunar = LevelGenerator.levels.first { $0.id > 30 } ?? LevelGenerator.levels[0]
                        for _ in 0..<limit { store.recordMissionCompleted(lunar) }
                        refreshID = UUID()
                    }
                    scenarioBtn("FIRST PAYWALL", icon: "eye.fill", color: .orange) {
                        store.setPremium(false)
                        store.resetDailyCount()
                        let lunar = LevelGenerator.levels.first { $0.id > 30 } ?? LevelGenerator.levels[0]
                        for _ in 0..<limit { store.recordMissionCompleted(lunar) }
                        devPaywallContext = .standard
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) { showingDevPaywall = true }
                        refreshID = UUID()
                    }
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
                onboardingSection
                TechDivider()
                #if DEBUG
                difficultyAnalysisSection
                TechDivider()
                validationSection
                TechDivider()
                #endif
                mechanicMessagesSection
            }
        }
    }

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

    #if DEBUG
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
                let failedCt  = validationReports.filter { !$0.isSolvable || $0.solverResult?.isSolvable == false }.count
                let trivialCt = validationReports.filter { $0.isTrivial }.count
                let warnCt    = validationReports.filter { !$0.warnings.isEmpty }.count
                let expertCt  = validationReports.filter { $0.difficulty == .expert }.count
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        validationFilterPill(.all,      count: validationReports.count)
                        validationFilterPill(.failed,   count: failedCt)
                        validationFilterPill(.trivial,  count: trivialCt)
                        validationFilterPill(.warnings, count: warnCt)
                        validationFilterPill(.expert,   count: expertCt)
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

    private func validationFilterPill(_ filter: ValidationResultFilter, count: Int) -> some View {
        let active = validationFilter == filter
        let color: Color = filter == .failed ? AppTheme.danger
                         : filter == .trivial ? Color.orange
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
        let total          = validationReports.count
        let failed         = validationReports.filter { !$0.isSolvable || $0.solverResult?.isSolvable == false }
        let solvable       = total - failed.count
        let trivialLevels  = validationReports.filter { $0.isTrivial }
        let withMechs      = validationReports.filter { $0.hasMechanics }.count
        let solverImproved = validationReports.filter { $0.solverFoundShorterPath }.count
        let avgComplexity  = validationReports.map { $0.complexityScore }.reduce(0, +) / Float(total)
        let hasSolverData  = validationReports.first?.solverResult != nil

        // All level-tagged warnings for the detail section (using IssueItem defined below)
        let levelWarnings: [IssueItem] = validationReports.flatMap { r in
            r.warnings.map { w in IssueItem(levelID: r.levelID, label: "[\(r.levelID)] \(w)") }
        }

        VStack(spacing: 0) {
            // ── Row 1: core health stats ───────────────────────────────────
            HStack(spacing: 0) {
                miniStat("TOTAL",   "\(total)")
                statDivider()
                miniStat("SOLVABLE", "\(solvable)/\(total)")
                statDivider()
                miniStat("FAILED",  "\(failed.count)")
                    // colour the failed cell red when there are failures
                statDivider()
                miniStat("TRIVIAL", "\(trivialLevels.count)")
            }
            .padding(.vertical, 10)
            .background(failed.isEmpty ? Color.clear : AppTheme.danger.opacity(0.04))

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

            // ── CRITICAL: unsolvable levels ────────────────────────────────
            let showFailed   = validationFilter == .all || validationFilter == .failed
            let showTrivial  = validationFilter == .all || validationFilter == .trivial
            let showWarnings = validationFilter == .all || validationFilter == .warnings
            let showExpert   = validationFilter == .expert

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
            if failed.isEmpty && trivialLevels.isEmpty && levelWarnings.isEmpty && validationFilter == .all {
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
                storySimulateSection
                TechDivider()
                storyBeatList
            }
        }
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
                HStack(spacing: 12) {
                    if result.isValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.sage)
                        Text("All \(result.checkedCount) assets present")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(AppTheme.sage)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.danger)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Missing \(result.missingAssets.count) of \(result.checkedCount):")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.danger)
                            ForEach(result.missingAssets, id: \.self) { name in
                                Text("• \(name)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppTheme.danger)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 10)
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
                storySimBtn("LAUNCH 1",    color: AppTheme.sage)          { simulateBeat("story_intro_01")            }
                storySimBtn("LAUNCH 2",    color: AppTheme.sage)          { simulateBeat("story_intro_02")            }
                storySimBtn("LAUNCH 3",    color: AppTheme.sage)          { simulateBeat("story_intro_03")            }
                storySimBtn("LAUNCH 4",    color: AppTheme.sage)          { simulateBeat("story_intro_04")            }
                storySimBtn("POST-INTRO",  color: AppTheme.sage)          { simulateBeat("story_post_onboarding_01")  }
                storySimBtn("READY",       color: AppTheme.sage)          { simulateBeat("story_first_mission_ready") }
                storySimBtn("FIRST WIN",   color: AppTheme.accentPrimary) { simulateBeat("story_first_mission_complete") }
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
        case .postOnboarding:        return "POST-INTRO"
        case .firstMissionReady:     return "READY"
        case .firstMissionComplete:  return "FIRST WIN"
        case .sectorComplete:        return "SECTOR"
        case .passUnlocked:          return "PASS"
        case .rankUp:                return "RANK"
        case .mechanicUnlocked:      return "MECHANIC"
        case .enteringNewSector:     return "NEW SECTOR"
        }
    }

    private func simulateBeat(_ id: String) {
        guard let beat = StoryBeatCatalog.beats.first(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { previewingBeat = beat }
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
