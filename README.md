# Signal Void

A sci-fi network-routing puzzle game for iOS. Restore fragile energy systems across the solar system — rotate conduit tiles, connect sources to targets, earn your rank.

Built entirely with SwiftUI. No external dependencies.

---

## Gameplay

Each mission places **source nodes** (orange) and **target nodes** on a grid of pipe tiles. Tap tiles to rotate them 90° clockwise. Energy propagates via BFS from sources through connected pipes. Win by powering every target before running out of moves.

- **180 missions** across 8 spatial sectors (Earth Orbit → Neptune Deep)
- **4×4 grids** (Easy/Medium) and **5×5 grids** (Hard/Expert)
- 3 objective types: Activate Targets, Maximize Coverage, Save Energy
- 8 progressive mechanics that unlock as you advance
- Efficiency-based scoring with OPTIMAL / EFFICIENT / ADEQUATE / SUBOPTIMAL ratings

---

## Mechanics

### Core

| Element | Description |
|---------|-------------|
| Source | Emits energy, always energized. Orange glow + bolt badge. |
| Target | Must receive energy to win. Sage dashed border when unpowered, solid glow when online. |
| Relay | Standard conduit. Carries energy when connected to the chain. |
| Rotation | Each tap rotates the tile 90° clockwise. |

### Progressive (unlocked through gameplay)

| Mechanic | Description |
|----------|-------------|
| Rotation Cap | Tiles with limited rotation count — plan every move |
| Overloaded Relay | Two-tap rotation: arm first, then execute |
| Time Pressure | Mission must complete under a countdown |
| Node Drift | Tiles shift back after a delay |
| One-Way Relay | Signal accepted from one direction only |
| Fragile Relay | Burns out after N energized turns |
| Charge Gate | Conducts only after N charge cycles |
| Interference | Visual static overlay obscures tile orientation |

---

## Progression

- **8 sectors** following a solar system journey: Earth Orbit, Lunar Approach, Mars, Asteroid Belt, Jupiter, Saturn, Uranus, Neptune
- **Planet Passes** earned by completing all missions in a sector — unlock the next region
- **Astronaut ranks:** Cadet → Pilot → Navigator → Commander → Admiral
- **Level-up** requires quality completions at increasing efficiency thresholds
- **Dual efficiency tracking:** best-ever (display) + most-recent (gating, prevents farming)

---

## Features

- Synthesized adaptive soundtrack (mission, home, victory, story states)
- 16 custom sound effects
- Haptic feedback (3 tiers)
- Narrative story beats triggered by progression milestones
- Cinematic intro sequence (4 panels + onboarding mission)
- Planet ticket system with shareable 720px rendered passes
- Game Center leaderboards
- iCloud save/restore
- Localized in English, Spanish, and French
- Freemium model: 8 free intro sessions → 3 plays per 24h → single lifetime premium unlock
- Adaptive difficulty hints (near-signal glow, delayed breathing pulse)

---

## Tech Stack

- **UI:** 100% SwiftUI
- **Audio:** AVAudioPlayer pools + PCM synthesis (MusicSynthesizer)
- **Graphics:** Canvas, CoreGraphics (ticket renderer), Metal (holographic shader)
- **Persistence:** UserDefaults, iCloud KVS, Game Center
- **Monetization:** StoreKit 2
- **Min target:** iOS 17+
- **IDE:** Xcode 16+

---

## Running

1. Clone the repo
2. Open `geometry.xcodeproj` in Xcode
3. Select a simulator or device (iOS 17+)
4. Build and run (`Cmd+R`)

---

## Project Structure

```
geometry/
├── geometryApp.swift           — App entry, environment injection, splash
├── ContentView.swift           — Root navigation (intro → home → game → map)
├── HomeView.swift              — Mission control home screen
├── GameView.swift              — Gameplay board + overlays
├── GameViewModel.swift         — BFS propagation, move/win/loss logic
├── TileView.swift              — Tile rendering, tap animation, mechanic overlays
├── VictoryTelemetryView.swift  — Win screen with bar chart + KPI panel
├── LevelSelectView.swift       — Campaign mission map with sector cards
├── PaywallView.swift           — Premium upgrade paywall
├── SettingsView.swift          — Sound, haptics, language preferences
├── Models.swift                — Tile, Level, Planet, SpatialRegion, GameResult
├── LevelGenerator.swift        — Procedural generation for 180 levels
├── Theme.swift                 — AppTheme design tokens + shared components
├── L.swift                     — Localized strings (EN/ES/FR)
├── ProgressionStore.swift      — Astronaut profile persistence
├── EntitlementStore.swift      — Free/premium gating logic
├── AudioManager.swift          — State-driven audio coordination
├── MusicSynthesizer.swift      — PCM music generation
├── SoundManager.swift          — SFX pool management
├── TicketRenderer.swift        — CoreGraphics planet pass renderer
├── StoryBeat.swift             — Narrative beat catalog + triggers
├── StoryBeatView.swift         — Story overlay UI
└── DevMenuView.swift           — Debug console (dev builds only)
```

---

## Design Document

See [`SIGNAL_VOID_Design_Document.md`](SIGNAL_VOID_Design_Document.md) for the complete design specification including color palette, typography, screen layouts, animation catalog, and architecture details.
