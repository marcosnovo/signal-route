# SIGNAL VOID — Complete App Design Document

> **Version:** 1.0 · April 2026
> **Platform:** iOS (iPhone + iPad Universal)
> **Bundle ID:** `com.marcosnovo.signalvoidgame`
> **App Store ID:** 6762368239
> **Framework:** SwiftUI (100%)

---

## 1. Concept & Identity

### 1.1 Elevator Pitch
SIGNAL VOID is a sci-fi network-routing puzzle game where the player acts as a space engineer restoring fragile energy systems across the solar system. Rotate conduit tiles to connect sources to targets. Earn ranks, unlock sectors, and prove your precision — from Earth Orbit to Neptune Deep.

### 1.2 Tone & Aesthetic
- **Mission control interface** — the entire UI is styled as a live technical dashboard
- **Dark sci-fi** — deep blacks, monospaced typography, orange + sage accent palette
- **Quiet tension** — subtle ambient animations (drifting grids, twinkling stars, pulsing signal nodes) suggest a living system without competing with gameplay
- **In-universe language** — all copy reads as if written by mission control: "NODE ACTIVE", "SIGNAL ESTABLISHED", "SECTOR COMPLETE"

### 1.3 Name & Logo
- **Name:** SIGNAL VOID
- **Splash text:** "SIGNAL VOID · MISSION CONTROL INTERFACE"
- **Decorative motif:** diamond accent between horizontal rules

---

## 2. Design System (AppTheme)

### 2.1 Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `backgroundPrimary` | `#171717` | App-wide base background |
| `backgroundSecondary` | `#1F1F1F` | Header bars, card backgrounds |
| `surface` | `#222222` | Elevated panels, status bars |
| `surfaceElevated` | `#2B2B2B` | Higher-level cards, overlays |
| `accentPrimary` | `#FF6A3D` | Orange — primary CTA, active states, energy |
| `accentSecondary` | `#D9E7D8` | Sage light — secondary text, powered targets |
| `sage` | `#C7D7C6` | Muted sage — functional labels, data guides |
| `textPrimary` | `#F0EDE8` | Off-white — headings, hero text |
| `textSecondary` | `#9A9A9A` | Technical gray — labels, metadata (AA+ contrast) |
| `stroke` | `white @ 8%` | Default border / divider |
| `strokeBright` | `white @ 15%` | Prominent borders |
| `danger` | `#E84040` | Error states, failure, locked tiles |
| `success` | `#4DB87A` | Completed sectors, passed gates, online |

**Accent gradient:**
```
LinearGradient: #FF6A3D → #FF9550 (leading → trailing)
```

**Difficulty tier colors:**

| Tier | Hex | Label |
|------|-----|-------|
| Easy | `#4DB87A` | Green |
| Medium | `#FFB800` | Amber |
| Hard | `#FF6A3D` | Orange |
| Expert | `#E84040` | Red |

**Planet accent colors (8 planets):**

| Planet | Hex |
|--------|-----|
| Earth Orbit | `#4DB87A` |
| Moon | `#D9E7D8` |
| Mars | `#FF6A3D` |
| Asteroid Belt | `#FFB800` |
| Jupiter | `#D4A055` |
| Saturn | `#E4C87A` |
| Uranus | `#7EC8E3` |
| Neptune | `#4B70DD` |

### 2.2 Typography

All text uses **monospaced system font** for a technical/terminal aesthetic.

| Style | Spec | Usage |
|-------|------|-------|
| Hero title | mono 48 black, tracking -1 | Mission number on Home |
| Section title | mono 18 black, kerning 1 | Sector names, planet names |
| CTA label | mono 15 black, kerning 3 | Primary action buttons |
| Secondary label | mono 12 bold, kerning 2 | Medium-prominence buttons |
| Body text | mono 10 regular, kerning 1 | Objective descriptions |
| Tech label | mono 9 semibold, kerning 1.5 | Metadata, status badges, small labels |
| Micro label | mono 7-8 semibold, kerning 1.5-2 | Subsystem text, footer copy |
| Splash logo | mono 32 black, kerning 5 | "SIGNAL VOID" on splash screen |

**Key rule:** System `.monospaced` design — never use proportional fonts anywhere in the app.

### 2.3 Spacing & Layout

| Token | Value | Usage |
|-------|-------|-------|
| `gap` | 5 pt | Tile grid spacing |
| `tilePadding` | 14 pt | Board outer padding |
| `cornerRadius` | 3 pt | Tiles, small buttons, inputs |
| `cardRadius` | 6 pt | Larger card surfaces |
| `strokeWidth` | 0.5 pt | Default border width |

**Horizontal padding:** 20 pt (cards), 28 pt (hero content), 16 pt (nav strips)
**Vertical padding:** 12-18 pt for section separation

### 2.4 Core Components

#### TechLabel
Small uppercase metadata label. Mono 9 semibold, 1.5 kerning, `textSecondary` color by default.

#### TechDivider
Full-width 0.5 pt line in `sage @ 14%` opacity.

#### BreathingCTA (View Modifier)
Gentle scale pulse (1.0 → 1.04) with animated shadow glow (6% → 42% opacity). 1.5s cycle, repeating. Applied to primary action buttons.

#### PulsingGlow (View Modifier)
Slow shadow breathing (6% → 52% opacity). 1.8s cycle. Used on status dots, indicators, and "ONLINE" badges.

#### BackgroundGrid
Subtle technical grid of 28 pt squares. Lines at `white @ 4.5%`, 0.5 pt width. Drifts diagonally at ~1.4 px/s (one cell per 20 s) via linear animation.

---

## 3. Screen Architecture

### 3.1 Navigation Flow

```
geometryApp
  └─ SplashView (full-screen, auto-dismissed after audio + stores ready, max 3s)
      └─ ContentView (root)
          ├─ IntroFlow (first launch only)
          │   ├─ StoryModal (firstLaunch beats)
          │   ├─ NarrativeIntroView (4 cinematic panels)
          │   ├─ GameView (intro mission)
          │   └─ StoryModal (firstMissionReady beat)
          │
          ├─ HomeView (main hub)
          │   ├─ .sheet → SettingsView
          │   ├─ .sheet → PlanetTicketView
          │   └─ .fullScreenCover → DevMenuView (secret, 7-tap sequence)
          │
          ├─ GameView (mission gameplay)
          │   ├─ MechanicUnlockView (overlay)
          │   ├─ VictoryTelemetryView (win overlay)
          │   ├─ MissionOverlay (loss overlay)
          │   ├─ SectorCompleteView (banner)
          │   ├─ MilestoneView ("SIGNAL ESTABLISHED")
          │   └─ StoryBeatView (mechanic narrative)
          │
          ├─ .fullScreenCover → MissionMapView
          │
          ├─ PaywallView (overlay, z-index 100)
          └─ StoryModal (overlay, z-index 50)
```

**Transitions:**
- Home ↔ Game: `.move(edge: .leading)` / `.move(edge: .trailing)`
- Paywall: `.move(edge: .bottom).combined(with: .opacity)`
- Story modals: `.opacity`
- Overlays: `.opacity.combined(with: .scale(scale: 0.90)).combined(with: .offset(y: 24))`

### 3.2 Environment Objects (global injection)

| Object | Purpose |
|--------|---------|
| `GameCenterManager` | Authentication, leaderboards |
| `SettingsStore.shared` | Sound, music, haptics, motion, language |
| `EntitlementStore.shared` | Free/premium state, daily limits |
| `StoreKitManager.shared` | In-app purchase handling |
| `CloudSaveManager.shared` | iCloud save/restore |

---

## 4. Screen Designs

### 4.1 Splash Screen (`SplashView`)

**Layout:** Full-screen, 4 visual layers stacked in ZStack

1. **Base:** `backgroundPrimary`, edge-to-edge
2. **Dot grid:** Canvas, 40 pt spacing, orange dots with center-bright vignette (0.025–0.07 opacity)
3. **Breathing radial glow:** Orange gradient, center origin, radius 20→380, breathing 5%→14% opacity over 3.2s
4. **Perimeter signal nodes:** 8 dots around screen edges, each pulsing independently (0.05→0.52 opacity, 6.8–11s cycles)
5. **Logo block (centered):**
   - Decorative horizontal rule with diamond accent (22 pt lines + diamond.fill icon)
   - "SIGNAL VOID" — mono 32 black, white, kerning 5
   - Orange horizontal rule (190 pt × 1.5 pt)
   - "MISSION CONTROL INTERFACE" — mono 8 semibold, `textSecondary`, kerning 3
6. **Bottom: Signal progress line** — horizontal track with 3 nodes (0%, 50%, 100%), fills left→right as AUDIO and STORES come online. Orange accent.
7. **Status copy** above progress line: "INITIALIZING NETWORK" (localized)

**Animation:** Content fades in (0.5s ease-out, 0.12s delay) from +18 pt offset.

---

### 4.2 Home Screen (`HomeView`)

**Layout:** Full viewport, no scroll when mission available.

**Background layers:**
1. `backgroundPrimary` (edge-to-edge)
2. `BackgroundSystem` — grid + starfield + signal nodes + energy line
3. Radial glow — orange 5.5%→1.5%→clear, centered, radius 0→260
4. Planet pass ghost layer — blurred (18 pt), 7% opacity, slightly rotated (-3°), atmospheric effect
5. "GEO" watermark — 200 pt black, 1.8% opacity, bottom-trailing

**Structure (VStack, spacing: 0):**

#### System Bar (top)
```
[NODE ACTIVE ● pulsing green]  [SIGNAL VOID]  [CONFIG ▫]
```
- Left: status dot (success green, pulsing) + "NODE ACTIVE" tech label
- Center: "SIGNAL VOID" — mono 11 bold, `textPrimary`
- Right: CONFIG button with bordered frame + "CONFIG" tech label

#### Content Area (fills remaining space)

**When next mission exists — System UI layout:**

```
┌──────────────────────────────┐
│  NEXT MISSION       [MEDIUM] │  ← status + difficulty pill
│                              │
│  MISSION 42                  │  ← mono 48 black hero
│  ACTIVATE 3 TARGETS         │  ← objective line
│  ████████░░░░░  42%          │  ← campaign progress bar
│                              │
│       ┌──────────────┐       │
│       │    ▶ PLAY    │       │  ← 260×58 orange CTA with breathing glow
│       └──────────────┘       │
│       ┌──────────────┐       │
│       │ 🏆 RANKING   │       │  ← 260×44 secondary (green if GC auth'd)
│       └──────────────┘       │
│                              │
│  ─────────────────────────── │  ← zone separator (white 5.5%, 0.5 pt)
│                              │
│  ┌─── PASS ────┐  ┌── MAP ──┐│
│  │ EARTH ORBIT │  │  12/180 ││  ← dual square HUD modules
│  │ 85% EFF     │  │ MISSIONS││
│  │ ● ACTIVE    │  │  ▶ MAP  ││
│  └─────────────┘  └─────────┘│
└──────────────────────────────┘
```

**Pass tile:** Ticket-dark background (#0A0C0F), planet orb glow, left accent stripe (4 pt, planet color), planet name, efficiency bar (5 segments), status dot.

**Map tile:** Surface background, orange radial glow (bottom-trailing), mission count (hero number), progress bar, "VIEW MAP" link.

**When intro not completed — Training layout:**
- Training card with "SYSTEM CALIBRATION" header
- "INITIALIZE TRAINING →" orange CTA button

**When all missions complete:**
- AllClearCard congratulation
- Map preview block

#### Status Strip (bottom, 32 pt padding)
```
SIGNAL · ACTIVE    ●    42 / 180 MISSIONS
```
Orange breathing dot center, progress label right.

---

### 4.3 Game Screen (`GameView`)

**Layout:** Full screen, VStack with header → moves → timer → objective → board → status → hint

#### Header Strip
```
[← HOME]                    MISSION 42  [MEDIUM]
```
Chevron.left + "HOME" tech label | level displayName centered | difficulty badge right

#### Moves Bar
Orange accent gradient bar showing remaining moves vs total. Fractional fill animation.

#### Timer Bar (optional)
Only for timed missions. Similar bar treatment with countdown display.

#### Objective Section
```
ACTIVATE 3 TARGETS    ● 1/3 ONLINE
```
Icon + objective label | progress counter with colored status dots

#### Board Section
N×N grid (4×4 or 5×5) of `TileView` components. 5 pt gap between tiles. 14 pt outer padding.

**Tile Visual States:**
- **Source (●):** Warm orange background, bolt badge, outer ring (1.5 pt, 55% opacity). Always energized.
- **Target (◎ unpowered):** Dashed outline (sage 40%, dash 4/3), awaiting energy
- **Target (◉ powered):** Solid glowing border (sage 85%, 1.5 pt), green shadow (6 pt radius)
- **Relay (default):** Standard conduit, glows when energized from source
- **Energized relay:** Tinted sage/green, pipe lines glow

**Pipe rendering:** Lines drawn from center to tile edges for each connected direction. Outer pipe = 24% of tile size, inner = 10%. Node at center = 22% of tile size.

**Mechanic overlays on tiles:**
- **Rotation cap:** Bottom-left badge with remaining count; lock icon when exhausted
- **Overloaded:** Double-ring junction; orange ring when armed
- **Auto-drift:** Pulsing amber outer ring
- **One-way relay:** Directional arrow badge (blue `#5BA4CF`)
- **Fragile tile:** Top-left badge with charges; red pulsing ring; burned = dark + X mark
- **Charge gate:** Cyan border `#5BE8C8` (closed) or teal (open); bottom-right charge badge
- **Interference zone:** Flickering static overlay (Canvas noise)

**Mechanic indicator colors:**
- Amber `#FFB800` — rotation cap, auto-drift, overloaded
- Blue `#5BA4CF` — one-way relay
- Red `#E84040` — fragile tile
- Cyan `#5BE8C8` — charge gate

#### Status Panel
KPI readout below the board — nodes activated, moves used, efficiency indicator.

#### Hint
Contextual hint text for the current state.

#### Win Sequence
1. Signal sweep animation — bright flash travels tile-by-tile through the solution path
2. Board success opacity flash (green ring)
3. Win pulse (synchronized scale pulse on all energized tiles)
4. **Missions 1–7:** Auto-advance to next mission after 500ms pause (no overlay)
5. **Mission 8 (first time):** "SIGNAL ESTABLISHED" milestone (2.2s) → VictoryTelemetryView
6. **Mission 8+:** VictoryTelemetryView overlay

#### Loss Sequence
- MissionOverlay with failure state
- Red ring/flash on culprit tiles
- Retry or dismiss options

---

### 4.4 Victory Telemetry View (`VictoryTelemetryView`)

**Layout:** Full-screen split panel — left dark (chart), right sage (KPIs)

```
┌──────────────────────┬──────────────────────┐
│    ← HOME   M-42     │                      │
├──────────────────────┤                      │
│                      │    EFFICIENCY         │
│   ▓ ░ ▓ ░ ▓ ░ ▓ █   │       87%            │
│   ▓ ░ ▓ ░ ▓ ░ ▓ █   │    EFFICIENT          │
│   ▓ ░ ▓ ░ ▓ ░ ▓ █   │                      │
│   ▓ ░ ▓ ░ ▓ ░ ▓ █   │  ── MOVES ──  12     │
│   bar chart (8 bars) │  ── ENERGY ── 95%    │
│   last bar = orange  │  ── TIME ──   100%   │
│                      │                      │
├──────────────────────┴──────────────────────┤
│  [RESTART]  [HOME]  [MISSIONS]  [NEXT →]    │
└─────────────────────────────────────────────┘
```

**Left panel:** Dark background. 8-bar vertical chart (240 pt height). 7 mock bars + 1 real bar (player's efficiency, orange highlighted).

**Right panel:** Sage background (`#D9E7D8`)
- Sage-ink text `#131B13` — primary
- Sage-mid `#415041` — secondary
- Sage-faint `#8FA88F` — tertiary
- Large count-up percentage animation
- Route rating label: OPTIMAL (≥95%), EFFICIENT (≥80%), ADEQUATE (≥60%), SUBOPTIMAL (<60%)
- 3 metric rows: Move rating, Energy rating, Time rating (each 0–100%)

**CTA strip:** Full-width bottom bar with action buttons.

---

### 4.5 Mission Map (`MissionMapView`)

**Background:** `backgroundPrimary` + `BackgroundGrid` + `StarMapBackground` (50 twinkling stars at 8 fps)

**Header:**
```
[← BACK]    MISSION MAP    [missions count]
             42/180 ✓
```

**Content:** Vertical ScrollView with LazyVStack of SectorCards connected by RouteConnectors.

#### Sector Card
Three display states:

**Active:**
- Orange accent bar (left edge, 3 pt)
- Pulsing orange status dot + "ACTIVE SECTOR"
- Sector name (mono 18 black) + zone brief subtitle
- Progress: "12/30" large count + progress bar
- Expanded level grid showing all missions

**Completed:**
- Green accent bar
- "SECTOR COMPLETE" badge (success green)
- Checkmark icon + total count
- Average efficiency percentage
- Collapsed by default with expand toggle

**Locked:**
- Gray accent bar (45% opacity)
- Lock icon + "LOCKED" badge
- Mission count visible but dimmed
- Unlock requirement: "REQUIRES LEVEL 3"
- Upgrade nudge button for free users

#### MissionCell
Individual level entry in the grid:
- Completed: checkmark, efficiency bar
- Current: pulsing orange dot
- Locked: lock icon, dimmed

#### RouteConnector
Between sectors: dashed vertical line with traveling pulse dot. Dimmed if next sector is locked.

---

### 4.6 Settings View (`SettingsView`)

**Presentation:** `.sheet` modal from Home

**Layout:** ZStack (backgroundPrimary + BackgroundGrid) → VStack (navStrip + ScrollView)

**Sections:**
1. **Audio:** Sound FX toggle, Ambient Music toggle
2. **Interface:** Haptic Feedback toggle, Reduced Motion toggle
3. **Language:** EN / ES / FR picker (3 bordered buttons)
4. **Legal:** Terms & Conditions, Privacy Policy
5. **Build info:** Version + build number footer

**Toggle style:** Custom tech-styled rows with icon + label + sublabel + toggle.

---

### 4.7 Paywall View (`PaywallView`)

**Presentation:** Overlay (z-index 100), enters from bottom

**Background:** `backgroundPrimary` + BackgroundGrid (3% opacity) + ambient orange glow

**Layout:**
```
                    [× Close]

                  ○ orbital anim

          UNLOCK UNLIMITED ACCESS
          Play without restrictions.

          ┌──────────────────────┐
          │ ✓ Unlimited missions │
          │ ✓ All 8 sectors      │
          │ ✓ Full progression   │
          └──────────────────────┘

          [DISCOUNT CODE ______]

          ┌──────────────────────┐
          │  BUY — $X.XX         │
          └──────────────────────┘

          Restore Purchases
```

**Contexts (4 emotional framings):**
- `postVictory` — celebratory momentum after a win
- `sectorExcitement` — new sector unlocked but gate hit
- `nextMissionBlocked` — tried to play, hit daily limit
- `homeSoftCTA` — passive nudge on Home screen

---

### 4.8 Narrative Views

#### NarrativeIntroView
4 cinematic inter-title panels with sequential sentence fade-in (0.45s apart). Each panel has a unique accent color. "TAP TO CONTINUE" prompt after all sentences visible. Tap-to-skip accelerates reveal.

**Panel accent colors:** `#4DB87A`, `#D4A055`, `#7EC8E3`, `#4B70DD`

#### StoryModal
Full-screen story beat overlay. Dark backdrop (92% black) + accent radial glow. Card with optional header image, title, body text (typewriter animation), acknowledge button.

#### StoryBeatView
Compact floating-card for lightweight beats (mechanic unlocks, confirmations). Same backdrop pattern, smaller card.

#### MilestoneView
"SIGNAL ESTABLISHED" — shown after mission 8 completion (first time). Auto-dismissed after 2.2s, then transitions to VictoryTelemetryView. Shows completed count / total count.

#### MechanicUnlockView
Shown on first encounter with each new game mechanic. Icon + title + description explaining the new rule.

---

### 4.9 Planet Ticket System

#### PlanetTicketView (sheet modal)
Scan-reveal animation (0.25s linear scan, 0.28s post-delay), then chrome appears (0.22s ease-out). Share button exports via UIActivityViewController.

#### TicketRenderer (720×720 bitmap)
CoreGraphics-rendered shareable ticket image. All coordinates in 1080 design space, rendered at 720×720 with CTM scale (0.667×). Content: planet visual, efficiency bar, serial code, player stats.

---

## 5. Background Atmosphere System

### 5.1 BackgroundSystem (HomeView)
4 layers composited in ZStack, all `allowsHitTesting(false)`:

1. **BackgroundGrid** — 28 pt square grid, white lines @ 4.5%, drifts diagonally
2. **BackgroundStarfield** — 40 static stars, twinkling via `sin()` at 4 fps, 1-2 pt dots
3. **BackgroundSignalNodes** — async pulsing dots + traveling particles along lines
4. **BackgroundEnergyLine** — occasional sweeping horizontal signal line

**Design rules:**
- Base opacity ≤ 0.08 (nearly invisible at rest)
- Peak opacity ≤ 0.55 (never competing with UI)
- Palette: orange (accent), sage (secondary), white (neutral)

### 5.2 StarMapBackground (MissionMapView)
50 deterministic stars via LCG seeded random. Canvas at 8 fps. Opacity oscillates 0.05–0.095 via `sin()`.

---

## 6. Animation Catalog

### 6.1 Springs & Easing

| Animation | Spec |
|-----------|------|
| Content entrance | `.spring(response: 0.55, dampingFraction: 0.82)` |
| Overlay appear | `.spring(response: 0.44, dampingFraction: 0.80)` |
| Paywall spring | `.spring(response: 0.40, dampingFraction: 0.88)` |
| Sector card stagger | `.easeOut(duration: 0.42).delay(idx * 0.055)` |
| Root level transition | `.spring(response: 0.38, dampingFraction: 0.88)` |
| Intro step transition | `.spring(response: 0.44, dampingFraction: 0.88)` |
| Splash content | `.easeOut(duration: 0.5).delay(0.12)` |
| Splash glow breathing | `.easeInOut(duration: 3.2).repeatForever` |

### 6.2 Interactive Feedback
- **Tile tap:** Scale bounce (1.0 → 0.92 → 1.0)
- **Tile energize:** Connection snap flash
- **Win pulse:** Synchronized scale pulse on all energized tiles
- **Signal sweep:** Bright flash traveling tile-by-tile through solution path
- **Circuit error:** Red ring flash on broken connections
- **Wrong tap:** Subtle red flash on non-helpful rotation

### 6.3 Breathing / Pulsing
- CTA button: scale 1.0 → 1.04, shadow 6% → 42%, 1.5s
- Status dots: shadow 6% → 52%, 1.8s (configurable)
- FAB pulsing: shadow opacity 10% → 28%, 2.2s
- Rank button: scale 1.0 → 1.007, 3.6s (very subtle)

---

## 7. Audio Design

### 7.1 Audio States
Managed by `AudioManager`, transitions reactively based on app state:

| State | Context |
|-------|---------|
| `homeIdle` | Home screen, mission map browsing |
| `inMission` | Active gameplay |
| `victory` | Win overlay shown |
| `story` | Story beat/modal visible |
| `cooldown` | Paywall displayed (silence, SFX only) |

### 7.2 Music
Synthesized via `MusicSynthesizer` (PCM stereo, 22050 Hz WAV):
- **Home ambient:** Gentle pad, auto-looping
- **Mission active:** A-minor drawbar organ pad (A2·E3·A3·C4), 60 BPM heartbeat at 55 Hz, 10s loop
- **Victory:** Celebratory synth
- **Story:** Ambient narrative pad

**Reactive intensity:** Mission music intensity ramps as targets connect.

### 7.3 Sound Effects (16 bundled MP3s, 44.1 kHz/128 kbps)

| SFX | File | Context |
|-----|------|---------|
| Tile rotate | `sfx_tileRotate.mp3` | Player taps a tile |
| Tile locked | `sfx_tileLocked.mp3` | Tap on locked tile, gate denied |
| Relay energized | `sfx_relayEnergized.mp3` | Relay first receives energy |
| Target online | `sfx_targetOnline.mp3` | Target node energized |
| Win | `sfx_win.mp3` | Mission victory |
| Lose | `sfx_lose.mp3` | Mission failure |
| Overload arm | `sfx_overloadArm.mp3` | Overloaded tile armed |
| Mechanic unlock | `sfx_mechanicUnlock.mp3` | New mechanic discovered |
| Sector complete | `sfx_sectorComplete.mp3` | All missions in sector done |
| Tap primary | `sfx_tapPrimary.mp3` | Primary button press |
| UI success | `sfx_uiSuccess.mp3` | Confirmation action |
| Near failure pulse | `sfx_nearFailurePulse.mp3` | Low moves warning |
| Sonic logo (full) | `sfx_sonicLogoFull.mp3` | App launch |
| Sonic logo (short) | `sfx_sonicLogoShort.mp3` | Sector complete beat |
| Ticket open | `sfx_ticketOpen.mp3` | Planet ticket reveal |
| Ticket move | `sfx_ticketMove.mp3` | Ticket interaction |

### 7.4 Haptics (3 tiers)
- **Light:** Tile rotation
- **Medium:** CTA press, ticket reveal, share action
- **Error:** Gate denied, failure

---

## 8. Game Mechanics

### 8.1 Core Gameplay
- **Grid:** 4×4 or 5×5 tile grid
- **Tiles:** 4 types — Straight (N-S), Curve (N-E), T-Shape (N-E-W), Cross (all 4)
- **Roles:** Source (always energized), Target (must receive energy to win), Relay (conduit)
- **Action:** Tap to rotate 90° clockwise
- **Goal:** Route energy from source(s) to all targets within the move limit

### 8.2 Objective Types

| Type | Win Condition | Scoring |
|------|--------------|---------|
| Normal | Energize all targets | Score by moves remaining |
| Max Coverage | Energize all targets | Bonus for total active nodes |
| Energy Saving | Energize all targets | Within solution path + 2 active nodes |

### 8.3 Progressive Mechanics (unlocked through gameplay)

| ID | Mechanic | Unlock | Description |
|----|----------|--------|-------------|
| B | Rotation Cap | Medium+ | Tiles with limited rotation count |
| D | Overloaded Relay | Hard+ | Two-tap rotation (arm → execute) |
| A | Time Limit | Hard+ | Mission must complete under time pressure |
| C | Auto-Drift | Expert | Tiles drift back after delay |
| E | One-Way Relay | End-game | Signal accepted from one direction only |
| F | Fragile Tile | Level ≥151 | Burns out after N energized turns |
| G | Charge Gate | Level ≥164 | Conducts only after N charge cycles |
| H | Interference Zone | Level ≥171 | Visual static overlay on tiles |

### 8.4 Difficulty Tiers

| Tier | Grid | Move Budget | Mechanics |
|------|------|-------------|-----------|
| Easy | 4×4 | Generous | None |
| Medium | 4×4-5×5 | Moderate | Rotation cap |
| Hard | 5×5 | Tight | + Overloaded, Time limit |
| Expert | 5×5 | Minimal | + Auto-drift, One-way, Fragile, Gate, Interference |

---

## 9. Progression System

### 9.1 Campaign Structure
**180 missions** across **8 spatial regions** (sectors), following a solar system journey:

| Sector | Region | Levels | Required Level | Difficulty |
|--------|--------|--------|----------------|------------|
| 1 | Earth Orbit | 1–30 | 1 | Easy |
| 2 | Lunar Approach | 31–50 | 2 | Easy-Medium |
| 3 | Mars Sector | 51–70 | 3 | Medium |
| 4 | Asteroid Belt | 71–90 | 5 | Medium-Hard |
| 5 | Jupiter Relay | 91–110 | 7 | Hard |
| 6 | Saturn Ring | 111–130 | 10 | Hard |
| 7 | Uranus Void | 131–150 | 14 | Expert |
| 8 | Neptune Deep | 151–180 | 18 | Expert |

### 9.2 Level-Up System
- **Quality missions:** Completions meeting efficiency threshold count toward level-up
- **Exponential curve:** Required missions = ⌈5 × 1.38^(level−1)⌉
- **Efficiency ramp:** 60% + 2% per level, capped at 86%
- **Difficulty weighting:** Easy/Medium = 1 point, Hard = 2, Expert = 3

**Level progression example:**
```
L1→L2:  5 quality missions @ ≥60%
L2→L3:  7 quality missions @ ≥62%
L3→L4: 10 quality missions @ ≥64%
L4→L5: 14 quality missions @ ≥66%
...practical ceiling: L11-L12 (requires nearly all levels at high efficiency)
```

### 9.3 Rank Titles

| Level | Rank |
|-------|------|
| 1–2 | CADET |
| 3–4 | PILOT |
| 5–6 | NAVIGATOR |
| 7–9 | COMMANDER |
| 10+ | ADMIRAL |

### 9.4 Sector Unlock
Completing all missions in a sector awards a **PlanetPass**. The pass unlocks the next sector. Sector 1 (Earth Orbit) is always open.

### 9.5 Efficiency Rating

| Range | Label |
|-------|-------|
| ≥95% | OPTIMAL |
| ≥80% | EFFICIENT |
| ≥60% | ADEQUATE |
| <60% | SUBOPTIMAL |

5-block efficiency bar (Wordle-style): filled blocks = round(efficiency × 5)

### 9.6 Dual Efficiency Tracking
- **Best per level** (`bestEfficiencyByLevel`): All-time high score, used for display (tickets, stats)
- **Last per level** (`lastEfficiencyByLevel`): Most recent score, used for level-up gating (prevents farming)

---

## 10. Monetization

### 10.1 Product
**Single lifetime purchase:** `com.signalroute.fullaccess` (premium unlock)

### 10.2 Free-User Access Model

**Phase 1 — Intro (lifetime):**
- First 8 game sessions always free (win or loss with ≥1 tap)
- Missions 1–7 auto-advance (no overlay friction)
- Mission 8: "SIGNAL ESTABLISHED" milestone → VictoryTelemetryView

**Phase 2 — 24h Rolling Gate:**
- 3 plays per 24h window
- Cooldown countdown displayed on Home FAB
- Both wins and losses (with interaction) count

**Premium:**
- Unlimited missions, no gates
- All 8 sectors accessible (still requires progression unlock)

### 10.3 Paywall Moments
Selected by `PaywallMomentSelector` based on context:
- **Post-victory:** Celebratory after a win when limit reached
- **Sector excitement:** New sector unlocked but gate hit
- **Next mission blocked:** Explicit tap denied by limit
- **Home soft CTA:** Passive "unlock unlimited" nudge

**Frustration guard:** Auto-show paywall deferred if `FrustrationGuard` detects player struggling.

### 10.4 Discount System
Text input field on paywall for discount/unlock codes. States: idle, valid, unlocked, invalid, inactive, expired, exhausted.

---

## 11. Localization

### 11.1 Supported Languages
- **English (en)** — default
- **Spanish (es)**
- **French (fr)**

### 11.2 Architecture
- `AppStrings` struct in `L.swift` — all strings as computed properties
- Language selection persists to UserDefaults key `"language"`
- Auto-detects system locale on first launch
- Pattern: `@EnvironmentObject private var settings: SettingsStore` → `private var S: AppStrings { AppStrings(lang: settings.language) }`
- Planet names, region names, zone briefs all localized via `S.planetName()`, `S.regionName()`, `S.zoneBrief()`

---

## 12. Story / Narrative System

### 12.1 Story Beats
Contextual narrative moments triggered by gameplay milestones:

| Trigger | Timing | Content |
|---------|--------|---------|
| `firstLaunch` | App first opened | Introduction to the universe |
| `firstMissionReady` | After intro completion | Briefing before Mission 1 |
| `firstMissionComplete` | First ever win | Acknowledgment |
| `sectorComplete` | All missions in sector done | Retrospective |
| `passUnlocked` | Planet pass earned | Authorization |
| `enteringNewSector` | New sector opened | Destination briefing |
| `rankUp` | Level milestone (2, 5, 10) | Personal recognition |
| `mechanicUnlocked` | New mechanic first seen | Explanation |
| `onboardingComplete` | Free intro quota exhausted | Gate context |

### 12.2 Beat Sequence (sector-completing win)
Beats play in this order, all positive moments before gate:
1. `firstMissionComplete` (if applicable)
2. `sectorComplete`
3. `passUnlocked`
4. `enteringNewSector`
5. `rankUp`
6. `onboardingComplete` (gate last)

---

## 13. Persistence & Cloud

### 13.1 Local Storage (UserDefaults)
- `AstronautProfile` (via ProgressionStore)
- `SettingsStore` preferences
- `EntitlementStore` state
- `OnboardingStore` flags
- `PassStore` earned passes
- `StoryStore` seen beat IDs
- `MechanicUnlockStore` announced mechanics

### 13.2 Cloud Save
- `CloudSaveManager` — iCloud key-value save
- Slot: `signal_route_progress`
- Auto-saves on every win

### 13.3 Game Center
- Leaderboard: `signal_route_efficiency`
- Authentication via `GameCenterManager`

---

## 14. Adaptive Systems

### 14.1 Adaptive Difficulty
`AdaptiveDifficultyEngine` adjusts parameters based on player skill (completely independent of monetization):
- Near-signal hint layer (faint glow on tiles adjacent to energy)
- Delayed hint pulse (12s inactivity → breathing glow on suggested tile)
- Interference scale reduction for struggling players

### 14.2 Session Tracking
`SessionTracker` records play patterns, abandons, and session duration for intelligent pacing.

### 14.3 Player Skill
`PlayerSkillStore` tracks win/loss ratio, average efficiency, and adjusts the adaptive layer accordingly.

---

## 15. Dev Tools (Debug Only)

### 15.1 Dev Console (`DevMenuView`)
Accessed via 7-tap secret sequence on Home. Full-screen modal with tabs:

- **Missions:** Level browser with filters, jump-to-level
- **Progression:** Level override, pass grants, resets
- **Story:** Beat preview, trigger replay
- **Simulation:** Player simulation runner
- **Self QA:** Automated validation runs

### 15.2 Audit Tools
`LevelValidationRunner` — validates all 180 levels (solvability, difficulty rating accuracy)
`SelfQARunner` — automated UI and logic checks

---

## 16. Technical Notes

### 16.1 Performance
- TicketRenderer: 720×720 (not 1080) with CTM scale for ~56% fewer pixels
- SoundManager: Pool-based AVAudioPlayer with anti-spam debounce
- Audio creation: `Task.detached(priority: .userInitiated)` to prevent input blocking
- BackgroundGrid: Canvas-based, minimal GPU cost
- Starfield: Single Canvas at 4-8 fps, not per-star views
- `.id(level.id)` on GameView forces VM recreation (prevents stale state)

### 16.2 Architecture Patterns
- `@MainActor` for all ViewModels and stores
- `@EnvironmentObject` for global state injection
- `ProgressionState` struct as single source of truth for all progression display
- Sequential mission unlock (level N requires level N-1 completed)
- Next mission uses catalog index+1 (not ProgressionStore.nextMission)
- No Combine — uses async/await throughout

---

*Document generated from source code analysis — April 2026*
