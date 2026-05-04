import SwiftUI

// MARK: - AchievementsCardStackView

struct AchievementsCardStackView: View {
    let achievements: [Achievement]
    let engine: AchievementEngine

    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var motion = DeviceMotionManager.shared

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var dismissPhase: DismissPhase = .idle
    @State private var idleTiltX: Double = 0
    @State private var idleTiltY: Double = 0

    private let visibleCards = 3
    private let swipeThreshold: CGFloat = 80

    enum DismissPhase {
        case idle, dismissing, advancing
    }

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - 48
            ZStack {
                ForEach(Array(visibleIndices.enumerated().reversed()), id: \.element) { stackLevel, achIndex in
                    let ach = achievements[achIndex]
                    let state = engine.state(for: ach)
                    let isFront = stackLevel == 0
                    let reveal: Double = isFront ? 1.0 : 0.0

                    AchievementCardView(
                        achievement: ach,
                        state: state,
                        revealProgress: reveal,
                        gcImage: engine.image(for: ach)
                    )
                    .frame(width: cardWidth)
                    .modifier(CardStackTransform(
                        stackLevel: stackLevel,
                        dragOffset: isFront ? dragOffset : 0,
                        dismissPhase: isFront ? dismissPhase : .idle,
                        reducedMotion: settings.reducedMotion,
                        idleTiltX: isFront ? idleTiltX : 0,
                        idleTiltY: isFront ? idleTiltY : 0,
                        motionX: isFront && motion.isAvailable ? motion.tiltX : 0,
                        motionY: isFront && motion.isAvailable ? motion.tiltY : 0
                    ))
                    .zIndex(Double(visibleCards - stackLevel))
                    .allowsHitTesting(isFront)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if dismissPhase == .idle {
                            isDragging = true
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        handleSwipeEnd(translation: value.translation.width, velocity: value.predictedEndTranslation.width)
                    }
            )
            .onTapGesture {
                if dismissPhase == .idle { navigateCard(forward: true) }
            }
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
        .task { await runIdleMotion() }
    }

    // MARK: - Card indices

    private var visibleIndices: [Int] {
        guard !achievements.isEmpty else { return [] }
        let count = achievements.count
        return (0..<min(visibleCards, count)).map { level in
            (currentIndex + level) % count
        }
    }

    // MARK: - Swipe handling

    private func handleSwipeEnd(translation: CGFloat, velocity: CGFloat) {
        let shouldAct = abs(translation) > swipeThreshold || abs(velocity) > 400

        if shouldAct {
            if translation < 0 {
                navigateCard(forward: true)
            } else {
                navigateCard(forward: false)
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                dragOffset = 0
            }
        }
    }

    private func navigateCard(forward: Bool) {
        guard !achievements.isEmpty else { return }
        let count = achievements.count

        if settings.reducedMotion {
            currentIndex = forward
                ? (currentIndex + 1) % count
                : (currentIndex - 1 + count) % count
            dragOffset = 0
            return
        }

        dismissPhase = .dismissing
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            dragOffset = forward ? -400 : 400
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dismissPhase = .advancing
            dragOffset = 0
            currentIndex = forward
                ? (currentIndex + 1) % count
                : (currentIndex - 1 + count) % count

            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                dismissPhase = .idle
            }
        }
    }

    // MARK: - Idle drift

    private func runIdleMotion() async {
        try? await Task.sleep(nanoseconds: 800_000_000)
        var flip = false
        while !Task.isCancelled {
            if !isDragging {
                let y: Double = flip ? -1.0 : 1.0
                let x: Double = flip ? 0.5 : -0.5
                withAnimation(.easeInOut(duration: 3.0)) { idleTiltY = y }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                if !isDragging {
                    withAnimation(.easeInOut(duration: 4.0)) { idleTiltX = x }
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            flip.toggle()
        }
    }

    // MARK: - Page indicator

    var pageText: String {
        guard !achievements.isEmpty else { return "" }
        return "\(currentIndex + 1) / \(achievements.count)"
    }
}

// MARK: - Card Stack Transform

private struct CardStackTransform: ViewModifier {
    let stackLevel: Int
    let dragOffset: CGFloat
    let dismissPhase: AchievementsCardStackView.DismissPhase
    let reducedMotion: Bool
    let idleTiltX: Double
    let idleTiltY: Double
    let motionX: Double
    let motionY: Double

    private let motionMaxTilt: Double = 5.0

    func body(content: Content) -> some View {
        let level = Double(stackLevel)
        let isDismissing = stackLevel == 0 && dismissPhase == .dismissing
        let isFront = stackLevel == 0

        let tiltYDeg: Double = reducedMotion ? 0 : (isFront ? (-4.0 + idleTiltY + motionX * motionMaxTilt) : 6.0)
        let tiltXDeg: Double = reducedMotion ? 0 : (isFront ? (3.0 + idleTiltX + motionY * motionMaxTilt) : -2.0)

        content
            .offset(
                x: isFront ? dragOffset * 0.6 : 28 * level,
                y: isFront ? (isDismissing ? 120 : 0) : 24 * level
            )
            .scaleEffect(isFront ? 1.0 : 1.0 - 0.05 * level)
            .opacity(isFront ? (isDismissing ? 0.0 : 1.0) : max(0.3, 1.0 - 0.25 * level))
            .rotation3DEffect(.degrees(tiltYDeg), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .rotation3DEffect(.degrees(tiltXDeg), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .rotation3DEffect(
                .degrees(isDismissing && !reducedMotion ? -45 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .shadow(
                color: isFront ? Color.black.opacity(0.35) : Color.clear,
                radius: 20,
                x: reducedMotion ? 4 : 4 + CGFloat(motionX) * 4,
                y: reducedMotion ? 12 : 12 + CGFloat(motionY) * 3
            )
            .animation(
                reducedMotion ? .none : .spring(response: 0.45, dampingFraction: 0.78),
                value: stackLevel
            )
    }
}
