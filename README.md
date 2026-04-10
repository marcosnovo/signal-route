# Signal Route

A native iOS puzzle game built with SwiftUI. Route energy from source nodes to target nodes by rotating tiles — close the circuit before you run out of moves.

---

## Gameplay

Each level places a **source node** (orange) and one or more **target nodes** (green) on a grid of pipe tiles. Tap any tile to rotate it 90°. Energy flows via BFS from the source through all correctly matched connections. Win by powering every target node.

- **4×4 grids** — Easy and Medium levels
- **5×5 grids** — Hard and Expert levels
- Move counter limits how many rotations you can make per level
- Score = 1000 + (moves remaining × 50)

---

## Mechanics

| Element | Description |
|---------|-------------|
| Source tile | Emits energy; always lit. Orange glow + bolt badge. |
| Target tile | Must receive energy to complete the level. Sage border + crosshair badge. |
| Relay tile | Standard conduit. Carries energy when connected to the chain. |
| Rotation | Each tap rotates the tile 90° clockwise. |
| Win condition | All target tiles energized within the move limit. |

---

## Running the Project

1. Clone the repo
2. Open `geometry.xcodeproj` in Xcode 15+
3. Select a simulator or device (iOS 17+)
4. Build and run (`⌘R`)

No external dependencies. Pure SwiftUI + UIKit haptics.

---

## Level Types

| Type | Description |
|------|-------------|
| LINEAR | Single path from source to target |
| BRANCH | Path forks at least once |
| MULTI-NODE | Multiple targets, branching paths |
| DENSE | High tile connectivity, many intersections |
| SPARSE | Longer paths with fewer junctions |

---

## Screenshots

_Coming soon._

---

## Project Structure

```
geometry/
├── Models.swift          — Tile, Level, Direction, NodeRole enums
├── LevelGenerator.swift  — Seeded DFS board generation, 50-level catalogue
├── GameViewModel.swift   — BFS energy propagation, move/win logic
├── GameView.swift        — Game screen + HUD
├── TileView.swift        — Tile rendering, tap animation, energy pulse
├── HomeView.swift        — Title screen
├── LevelSelectView.swift — Dev menu with full level info cards
├── Theme.swift           — AppTheme design tokens
├── HapticsManager.swift  — UIKit haptic feedback wrapper
└── ContentView.swift     — Root navigation
```

---

## Roadmap

- [ ] Persistent progress (completed levels, best scores)
- [ ] Sequential level progression from HomeView
- [ ] Animated intro / level transition
- [ ] 6×6 grid levels (Nightmare tier)
- [ ] iCloud sync
- [ ] Demo / tutorial level
- [ ] App Store release
