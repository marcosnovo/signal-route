# Signal Void

A sci-fi network-routing puzzle game for iOS. Restore fragile energy systems across the solar system — rotate conduit tiles, connect sources to targets, earn your rank as you journey from Earth Orbit to Neptune Deep.

Built entirely with SwiftUI. Zero external dependencies.

---

## Table of Contents

- [Gameplay](#gameplay)
- [Missions & Sectors](#missions--sectors)
- [Tile Types & Mechanics](#tile-types--mechanics)
- [Objective Types](#objective-types)
- [Scoring System](#scoring-system)
- [Progression & Ranks](#progression--ranks)
- [Planet Pass System](#planet-pass-system)
- [Narrative & Story](#narrative--story)
- [Adaptive Difficulty](#adaptive-difficulty)
- [Audio & Haptics](#audio--haptics)
- [Monetization](#monetization)
- [Multiplayer (Versus Mode)](#multiplayer-versus-mode)
- [Integrations](#integrations)
- [Localization](#localization)
- [Tech Stack](#tech-stack)
- [Running](#running)
- [Project Structure](#project-structure)
- [Design Document](#design-document)

---

## Gameplay

Each mission places **source nodes** and **target nodes** on a grid of conduit tiles. Tap tiles to rotate them 90° clockwise. Energy propagates via BFS (breadth-first search) from sources through connected pipes. Win by powering every target before running out of moves.

The game introduces mechanics progressively — early missions teach the basics on simple 4x4 grids, while later sectors demand mastery of fragile relays, charge gates, interference zones, and time pressure on larger 5x5 boards.

---

## Missions & Sectors

**180 missions** span 8 spatial sectors following a solar system journey. Each sector introduces new difficulty tiers and mechanics as the player progresses outward from Earth.

| Sector | Name | Subtitle | Difficulty | Missions | Grid |
|--------|------|----------|------------|----------|------|
| 1 | Earth Orbit | Training Zone | Easy | 1–22 | 4x4 |
| 2 | Moon | Lunar Approach | Easy | 23–45 | 4x4 |
| 3 | Mars | Red Planet Ops | Medium | 46–67 | 4x4 |
| 4 | Asteroid Belt | Debris Field | Medium | 68–89 | 4x4 |
| 5 | Jupiter | Gas Giant Relay | Hard | 90–110 | 5x5 |
| 6 | Saturn | Ring System Transit | Hard | 111–133 | 5x5 |
| 7 | Uranus | Ice Giant Survey | Expert | 134–156 | 5x5 |
| 8 | Neptune | Deep Space Comms | Expert | 157–180 | 5x5 |

Additionally, a **handcrafted intro mission** (3x3 grid, single tap) teaches the core mechanic before the campaign begins, and a **daily challenge** generates a unique puzzle each day using a deterministic date-based seed.

---

## Tile Types & Mechanics

### Core Tiles

| Tile | Connections | Description |
|------|-------------|-------------|
| Straight | N–S | Two opposite openings |
| Curve | N–E | Right-angle bend |
| T-Shape | N–E–W | Three-way junction |
| Cross | N–E–S–W | Four-way intersection |

### Node Roles

| Role | Description |
|------|-------------|
| Source | Always energized. Emits energy into the network. Orange glow + bolt badge. |
| Target | Must receive energy to win. Sage dashed border when unpowered, solid glow when online. |
| Relay | Standard conduit. Carries energy when connected to the chain. |

### Progressive Mechanics

Mechanics unlock naturally through gameplay progression. Each one is announced with a dedicated overlay the first time it appears.

| Mechanic | Unlock Region | Description |
|----------|---------------|-------------|
| Rotation Cap | Medium missions | Tiles have a limited number of allowed rotations — every move must count |
| Overloaded Relay | Hard missions | Two-tap rotation: first tap arms the tile, second executes the rotation |
| Time Pressure | Hard missions | Mission must complete within a countdown timer |
| Auto Drift | Expert missions | Tiles shift ±1 rotation after a delay if not locked in place |
| One-Way Relay | End-game | Signal accepted from a single direction only (arrow indicator) |
| Fragile Tile | Mission 151+ | Burns out permanently after N energized cycles |
| Charge Gate | Mission 164+ | Only conducts energy after accumulating N charge cycles |
| Interference | Mission 171+ | Visual static overlay obscures tile orientation |

---

## Objective Types

Each mission has one of three objective types that determine the win condition and scoring focus:

| Objective | Win Condition | Scoring Focus |
|-----------|---------------|---------------|
| **Activate Targets** (Normal) | All targets energized | Fewer moves = higher score |
| **Maximize Coverage** | All targets energized AND grid coverage >= 50% | More active nodes = higher score |
| **Energy Saving** | All targets energized using minimal active nodes | Fewer active nodes = higher score (path + 2 tolerance) |

---

## Scoring System

Every mission produces a difficulty-weighted score:

```
Final Score = Base Points x Quality (0.0 – 1.0)
```

**Base Points** = `1000 x Difficulty x Grid x Objective x Time`

| Factor | Values |
|--------|--------|
| Difficulty | Easy: 1.0x — Medium: 1.5x — Hard: 2.25x — Expert: 3.5x |
| Grid Size | 4x4: 1.0x — 5x5: 1.2x |
| Objective | Normal: 1.0x — Max Coverage: 1.15x — Energy Saving: 1.25x |
| Time Pressure | +1.1x when timed |

**Quality** is a 0–1 efficiency rating based on the objective:
- Normal/Max Coverage: `minimumRequiredMoves / movesUsed`
- Energy Saving: proximity to minimum active nodes

**Efficiency Ratings:**

| Rating | Threshold |
|--------|-----------|
| OPTIMAL | >= 95% |
| EFFICIENT | >= 80% |
| ADEQUATE | >= 60% |
| SUBOPTIMAL | < 60% |

The **cumulative leaderboard score** is the sum of each mission's best-ever weighted score.

---

## Progression & Ranks

### Astronaut Ranks

Players earn astronaut ranks by accumulating quality mission completions:

| Rank | Level Range |
|------|-------------|
| Cadet | 1–2 |
| Pilot | 3–4 |
| Navigator | 5–6 |
| Commander | 7–9 |
| Admiral | 10+ |

### Level-Up Requirements

Progression uses an **exponential growth formula**: each rank requires more quality completions at increasing efficiency thresholds.

- **Required missions** = ceil(5 x 1.38^(level-1))
  - L1 -> L2: 5 | L2 -> L3: 7 | L3 -> L4: 10 | L4 -> L5: 14
  - L5 -> L6: 19 | L6 -> L7: 26 | L7 -> L8: 36 | L8 -> L9: 50 | L9 -> L10: 69
- **Required efficiency** = 60% + 2% per level (capped at 86%)
- **Quality weighting**: Easy/Medium = 1 point, Hard = 2 points, Expert = 3 points

The system uses **most-recent scores** (not best-ever) for gating, preventing stat farming on easy missions.

### Dual Efficiency Tracking

- `bestEfficiencyByLevel` — All-time best per mission (display, leaderboard)
- `lastEfficiencyByLevel` — Most recent attempt (rank gating)

---

## Planet Pass System

Completing all missions in a sector earns a **Planet Pass** — a collectible authorization that unlocks the next region.

- One pass per planet, never duplicated
- Rendered as a 720px shareable ticket image (CoreGraphics)
- Metal holographic shader for 3D pass inspection view
- Contains: planet name, astronaut level, efficiency score, mission count, timestamp
- Serial codes: `SR-XXXX-PLA` (earned) or `SR-XXXX-TRN` (training/provisional)
- Shareable via system share sheet

---

## Narrative & Story

Signal Void features a **narrative layer** woven into the progression system. Story beats fire at key milestones, providing context for the journey through the solar system.

### Story Triggers

| Trigger | When |
|---------|------|
| First Launch | App opened for the very first time |
| First Mission Ready | Player cleared to begin Mission 1 |
| First Mission Complete | First regular mission won |
| Onboarding Complete | 8th session won (marks end of free intro) |
| Sector Complete | All missions in a sector finished |
| Pass Unlocked | New Planet Pass issued |
| Rank Up | Astronaut level increases |
| Mechanic Unlocked | New mechanic encountered for the first time |
| Entering New Sector | Player transitions to the next region |

### Intro Sequence

New players experience a multi-step introduction:

1. **Story modal** — Mission control briefing
2. **Cinematic narrative** — 4-panel visual introduction to the universe
3. **Tutorial dialog** — Pre-game explanation of source-to-target mechanics
4. **Intro mission** — Handcrafted 3x3 one-tap puzzle with highlighted hint tile
5. **Clearance confirmation** — "You are cleared for duty" before Mission 1

---

## Adaptive Difficulty

The game adjusts difficulty margins based on player skill — never changing the puzzle itself, only the pressure.

### Skill Score (0.0 – 1.0)

Computed via exponential moving average (alpha = 0.25):

| Component | Weight | Measures |
|-----------|--------|----------|
| Attempts | 40% | How many tries to clear (1 attempt = 1.0, 5+ = 0.0) |
| Efficiency | 35% | Move quality (0–1) |
| Move Economy | 25% | minimum_moves / moves_used |

### Adjustments by Skill Band

| Skill Range | Extra Moves | Timer Factor | Interference | Effect |
|-------------|-------------|--------------|--------------|--------|
| < 0.30 | +3 | x1.35 | x0.45 | Struggling — significant assistance |
| 0.30 – 0.50 | +2 | x1.20 | x0.65 | Below average — moderate help |
| 0.50 – 0.65 | +1 | x1.10 | x0.80 | Average — slight cushion |
| 0.65 – 0.80 | 0 | x1.00 | x1.00 | Proficient — no adjustment |
| > 0.80 | -1 to -3 | x0.90–0.80 | x1.10 | Expert — increased challenge |

**Design contract:** Adjustments are applied once per level on first attempt and remain stable across retries. The puzzle layout and solution never change — only move margins, time limits, and visual noise.

---

## Audio & Haptics

### Music

State-driven audio system with four music contexts:

| State | Source | Description |
|-------|--------|-------------|
| Home Idle | Bundled `home_ambient.m4a` | Calm ambient loop |
| In Mission | PCM synthesis (22050 Hz) | A-minor organ pad + 60 BPM heartbeat pulse |
| Victory | PCM synthesis | Rising triumphant pad |
| Story | PCM synthesis | Ambient narrative underscore |

Music synthesis uses drawbar organ harmonics (8', 16' sub, 4' upper) with slow LFO modulation and stereo micro-detuning for spatial depth. Volume is capped at 35% so sound effects always cut through.

### Sound Effects (18 types)

**Gameplay:** tileRotate, tileLocked, relayEnergized, targetOnline, win, lose, drift, overloadArm, timerTick, mechanicUnlock, sectorComplete

**UI:** tapPrimary, tapSecondary, storyAdvance, uiSuccess

**Sonic Brand:** sonicLogoFull, sonicLogoShort, sonicLogoSubtle

**Reactive:** nearFailurePulse (D2 sub-bass, looped when near failure), comboNote (micro chirp)

**Tickets:** ticketOpen, ticketMove

All players are loaded via `Task.detached(priority: .userInitiated)` to prevent UI blocking.

### Haptics

Three-tier haptic feedback (light / medium / heavy) using singleton `UIImpactFeedbackGenerator` instances for zero-latency response.

---

## Monetization

### Free Access Model

**Phase 1 — Intro (Lifetime):**
- First 8 game sessions are always free (wins and losses both count if player made >= 1 tap)
- Tracks via `EntitlementStore.freeIntroCompleted`

**Phase 2 — Rolling Gate:**
- After 8 free sessions, 3 plays per 24-hour rolling window
- Uses monotonic uptime + wall-clock verification (resistant to clock-forward manipulation)

**Premium — Single Lifetime Purchase:**
- One-time in-app purchase removes all play limits
- Can also be granted via unlock codes

### Paywall Presentation

Paywall moments are selected by `PaywallMomentSelector` based on context:

| Context | Timing | Pressure |
|---------|--------|----------|
| Post-Victory | Just won + limit reached | High (celebratory momentum) |
| Sector Excitement | New sector unlocked but blocked | Medium |
| Next Mission Blocked | Tapped "Next Mission" at limit | Medium |
| Home Soft CTA | Passive upgrade row on Home screen | Low |

### Frustration Guard

The game **never engineers frustration to drive upgrades.** `FrustrationGuard` defers auto-show paywall when the player is struggling:
- >= 3 failures in current session, OR
- Skill score < 0.35

Explicit player taps (intentional navigation to upgrade) override the guard. The guard only reads gameplay metrics — never monetization state.

---

## Multiplayer (Versus Mode)

> Currently behind a feature flag (`VersusFeatureFlag.isEnabled`). Enabled in DEBUG, hardcoded off in RELEASE.

### Architecture

Real-time 1v1 multiplayer via GameKit's `GKMatch`:

1. **Matchmaking** — `GKMatchmakerViewController` or auto-match
2. **Host Election** — Player with lowest `gamePlayerID` becomes host
3. **Seed Exchange** — Host generates `UInt64.random`, sends via `.ready` message
4. **Identical Boards** — Both players run `LevelGenerator.buildBoard(for:)` with the shared seed
5. **Tap/State Sync** — Actions and grid state sync via JSON over `GKMatch.sendData(.reliable)`
6. **Result** — Win/loss reported via `.result` message

### Message Protocol

| Type | Payload | Purpose |
|------|---------|---------|
| `.ready` | Seed + config | Host sends shared puzzle seed |
| `.action` | Tap coordinate | Player tap propagates to opponent view |
| `.state` | Grid snapshot | Full grid state synchronization |
| `.result` | Outcome | Win/loss announcement |

**Isolation:** Versus wins do NOT touch ProgressionStore, PassStore, StoryStore, EntitlementStore, or CloudSave. Completely separate from campaign progression.

---

## Integrations

### Game Center

- **5 Leaderboards:** Total Score + per-tier (Easy, Medium, Hard, Expert)
- **14 Achievements** tied to progression milestones
- **Rank feedback** on victory screen: New Record / Top N% / Raw Rank
- **Non-blocking authentication** — the app works fully without Game Center
- **Auth-time score sync** — catches up any missed submissions on each authentication
- Player avatar loading and caching

### iCloud (CloudSaveManager)

CloudSave payload (schema v4) syncs across devices:

| Field | Content |
|-------|---------|
| `profile` | AstronautProfile (level, scores, efficiency per mission) |
| `passes` | Planet Pass collection |
| `entitlement` | Premium status, intro quota, cooldown state |
| `onboarding` | Intro flow completion flags |
| `mechanicUnlocks` | Set of announced mechanic IDs |
| `storySeenIDs` | Set of dismissed story beat IDs |
| `lastUpdated` | Timestamp for conflict resolution |
| `schemaVersion` | 4 (backward compatible) |

Merge strategy is **monotonic** — never downgrades local progress. Safety checks prevent cloud data from overwriting a more-advanced local profile.

### StoreKit 2

- Single lifetime in-app purchase product
- Transaction listener for purchase restoration
- Unlock code redemption system as alternative activation

### Local Notifications

- Cooldown expiry reminders (when 24h gate lifts)
- Permission requested at appropriate engagement points

---

## Localization

**Three languages:** English, Spanish, French

- `AppLanguage` enum with `.en`, `.es`, `.fr` cases
- `AppStrings` struct provides all localized text via dynamic language selection
- Auto-detects system locale on first launch, persists preference to UserDefaults
- Covers all game surfaces: HUD, overlays, story beats, UI buttons, status messages, failure causes, mechanic descriptions, settings

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | 100% SwiftUI (no UIKit views) |
| Audio | AVAudioPlayer pools + PCM synthesis (MusicSynthesizer) |
| Graphics | Canvas, CoreGraphics (ticket renderer), Metal (holographic shader) |
| Persistence | UserDefaults (primary + backup keys), iCloud KVS via GKSavedGame |
| Monetization | StoreKit 2 |
| Multiplayer | GameKit (GKMatch, GKLeaderboard, GKAchievement) |
| Notifications | UserNotifications |
| Min target | iOS 17+ |
| IDE | Xcode 16+ |
| Dependencies | None (zero external packages) |

---

## Running

1. Clone the repo
2. Open `geometry.xcodeproj` in Xcode 16+
3. Select a simulator or device (iOS 17+)
4. Build and run (`Cmd+R`)

For Game Center features, use a device signed into a sandbox Game Center account. iCloud sync requires iCloud Drive enabled on the test device.

---

## Project Structure

```
geometry/
├── geometry/
│   ├── geometryApp.swift              — App entry, environment injection, splash coordinator
│   ├── ContentView.swift              — Root navigation (intro -> home -> game -> map)
│   ├── HomeView.swift                 — Mission control home screen + subviews
│   ├── GameView.swift                 — Gameplay board, overlays, win/loss sequences
│   ├── GameViewModel.swift            — BFS propagation, move/win/loss logic, state machine
│   ├── TileView.swift                 — Tile rendering, tap animation, mechanic overlays
│   ├── VictoryTelemetryView.swift     — Win screen with bar chart + KPI panel
│   ├── LevelSelectView.swift          — Campaign mission map with sector cards
│   ├── PaywallView.swift              — Premium upgrade paywall UI
│   ├── SettingsView.swift             — Sound, haptics, language preferences
│   ├── DevMenuView.swift              — Debug console (DEBUG builds only)
│   ├── Models.swift                   — Tile, Level, Planet, SpatialRegion, GameResult, etc.
│   ├── LevelGenerator.swift           — Procedural generation for 180 missions
│   ├── LevelSolver.swift              — Puzzle solver for validation
│   ├── Theme.swift                    — AppTheme design tokens + shared components
│   ├── ProgressionStore.swift         — Astronaut profile persistence (primary + backup)
│   ├── EntitlementStore.swift         — Free/premium gating logic
│   ├── CloudSaveManager.swift         — iCloud sync (v4 schema, monotonic merge)
│   ├── PassStore.swift                — Planet Pass collection management
│   ├── MechanicUnlockStore.swift      — Mechanic announcement tracking
│   ├── OnboardingStore.swift          — First-launch flow flags
│   ├── DailyStore.swift               — Daily challenge state
│   ├── SettingsStore.swift            — User preferences singleton
│   ├── GameCenterManager.swift        — GC auth, leaderboards, rank feedback
│   ├── StoreKitManager.swift          — StoreKit 2 transaction handling
│   ├── NotificationManager.swift      — Local notification scheduling
│   ├── MonetizationAnalytics.swift    — Revenue event tracking
│   ├── DiscountStore.swift            — Promotional pricing
│   ├── UnlockCodeStore.swift          — Code redemption system
│   ├── SoundManager.swift             — SFX pool management (18 effects)
│   ├── HapticsManager.swift           — Haptic feedback generators
│   ├── TicketRenderer.swift           — CoreGraphics planet pass renderer
│   ├── PlanetPass3DView.swift         — Metal holographic pass inspection
│   ├── PlanetVisualResolver.swift     — Planet visual asset mapping
│   ├── BackgroundSystem.swift         — Animated background system
│   ├── BackgroundSignalNodes.swift    — Floating signal node particles
│   ├── BackgroundEnergyLine.swift     — Energy line background effect
│   ├── SplashCoordinator.swift        — Launch splash animation
│   ├── SplashView.swift               — Splash screen UI
│   ├── Holographic.metal              — Metal shader for pass holography
│   ├── VersusFeatureFlag.swift        — Multiplayer feature toggle
│   ├── VersusMatchmakingManager.swift — GKMatch coordination
│   ├── VersusViewModel.swift          — Versus game logic
│   ├── VersusView.swift               — Versus gameplay UI
│   ├── VersusMatchState.swift         — Match state management
│   ├── VersusMessage.swift            — Network message protocol
│   ├── VersusLevelFactory.swift       — Shared-seed level generation
│   ├── PlayerSimulationRunner.swift   — Headless playthrough simulation
│   ├── PlayerSimulationView.swift     — Simulation results UI
│   ├── SelfQARunner.swift             — Automated QA checks
│   ├── SelfQAView.swift               — QA results UI
│   ├── LevelValidationRunner.swift    — Level structure verification
│   └── Assets.xcassets                — App icons, colors, images
│
├── L.swift                            — Localized strings (EN/ES/FR)
├── AudioManager.swift                 — State-driven audio coordination
├── MusicSynthesizer.swift             — PCM music generation (22050 Hz)
├── StoryBeat.swift                    — Narrative beat catalog + triggers
├── StoryBeatView.swift                — Story modal overlay UI
├── StoryStore.swift                   — Beat state persistence
├── NarrativeIntroView.swift           — 4-panel cinematic opener
├── MissionClearanceView.swift         — Post-intro clearance screen
├── AchievementManager.swift           — Game Center achievement evaluation
├── AdaptiveDifficultyEngine.swift     — Skill-based margin adjustments
├── PlayerSkillStore.swift             — Skill score computation (0–1 EMA)
├── FrustrationGuard.swift             — Ethical paywall deferral
├── SessionTracker.swift               — Session-level metrics
├── PaywallMomentSelector.swift        — Contextual paywall timing
├── StoryAssetValidator.swift          — Narrative asset integrity checks
├── DeviceMotionManager.swift          — Device motion for 3D effects
├── SignalRoute.storekit               — StoreKit configuration file
│
├── geometryTests/
│   └── geometryTests.swift            — Unit tests (Testing framework)
│
├── geometryUITests/
│   ├── geometryUITests.swift          — UI tests (XCUIAutomation)
│   └── geometryUITestsLaunchTests.swift
│
└── SIGNAL_VOID_Design_Document.md     — Complete design specification
```

---

## Design Document

See [`SIGNAL_VOID_Design_Document.md`](SIGNAL_VOID_Design_Document.md) for the complete design specification including color palette, typography, screen layouts, animation catalog, and architecture details.

---

## License

All rights reserved. This project is proprietary software.
