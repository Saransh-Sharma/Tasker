import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The persistent map. Daily Loop at the centre, the five app roots on the inner
/// ring, the user's life areas on the outer ring.
///
/// This view is deliberately *not* replaced between steps. It is the shared
/// geometry the whole flow mutates, which is what makes the payoff legible:
/// the user watches one object accumulate their answers rather than watching
/// nine unrelated screens go by.
struct LifeMapOrbitCanvas: View {
    let scene: LifeMapSceneModel
    let step: LifeMapOnboardingStep
    var selectedRoot: Destination?
    var isInteractive = true
    var onRootTapped: (Destination) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var arrivalTrigger = 0
    @State private var settledRotation: Double = 0
    @GestureState private var dragRotation: Double = 0

    private var reduceMotion: Bool { MotionOverride.resolve(systemReduceMotion) }

    /// Rotation is only offered once the map is complete. Before that the
    /// positions carry meaning the user is still assembling, and letting them
    /// spin reads as decoration rather than as their own structure.
    private var allowsRotation: Bool { isInteractive && step == .reveal }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let innerRadius = side * 0.26
            let outerRadius = side * 0.43
            let rotationRadians = (settledRotation + dragRotation) * .pi / 180

            ZStack {
                LifeMapOrbitRing(radius: innerRadius, canvasSize: proxy.size)
                if scene.lifeAreas.isEmpty == false {
                    LifeMapOrbitRing(radius: outerRadius, canvasSize: proxy.size)
                }
                capacityArc(radius: outerRadius + 7, in: proxy.size)

                LifeMapCenterNode(title: centerTitle)
                    .position(center)

                ForEach(Array(zip(Destination.allCases, scene.roots).enumerated()), id: \.element.1.id) { index, pair in
                    LifeMapOrbitNode(node: pair.1, isSelected: selectedRoot == pair.0)
                        .position(point(
                            index: index,
                            count: scene.roots.count,
                            radius: innerRadius,
                            center: center,
                            phase: -.pi / 2 + rotationRadians
                        ))
                        .onTapGesture { onRootTapped(pair.0) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Preview \(pair.1.title)")
                        .accessibilityIdentifier(LifeMapAccessibilityID.rootNode(pair.0.rawValue))
                }

                ForEach(Array(scene.lifeAreas.enumerated()), id: \.element.id) { index, node in
                    LifeMapOrbitNode(node: node, isSelected: false)
                        .scaleEffect(node.emphasis)
                        .position(point(
                            index: index,
                            count: scene.lifeAreas.count,
                            radius: outerRadius,
                            center: center,
                            phase: -.pi / 2.2 + rotationRadians
                        ))
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.55).combined(with: .opacity))
                }
            }
            .lifeBoardMotion(.cardReflow, value: scene.lifeAreas)
            .lifeboardContextLens(center: .center, trigger: arrivalTrigger)
            .onChange(of: scene.lifeAreas.count) { _, _ in arrivalTrigger += 1 }
            .simultaneousGesture(rotationGesture)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your Life Map")
        .accessibilityValue(accessibilitySummary)
        .accessibilityAction(named: "Rotate clockwise") { rotate(by: 36) }
        .accessibilityAction(named: "Rotate counterclockwise") { rotate(by: -36) }
    }

    private var centerTitle: String {
        step == .welcome ? "Daily Loop" : scene.centerPromise
    }

    /// VoiceOver cannot see an orbit. Stating the contents plainly is the
    /// equivalent experience, not a consolation prize.
    private var accessibilitySummary: String {
        let areas = scene.lifeAreas.map(\.title)
        guard areas.isEmpty == false else {
            return "\(centerTitle) at the centre, with Home, Plan, Track, Insights, and EVA around it."
        }
        return "\(centerTitle) at the centre. Your areas, in priority order: "
            + onboardingNaturalLanguageList(areas, fallback: "none yet") + "."
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragRotation) { value, state, _ in
                guard allowsRotation else { return }
                state = Double(value.translation.width) * 0.32
            }
            .onEnded { value in
                guard allowsRotation else { return }
                // Carrying predicted velocity into the settle is what makes the
                // map feel like an object rather than a diagram.
                let projected = Double(value.predictedEndTranslation.width) * 0.32
                withAnimation(MotionProfile.directManipulation.animation(reduceMotion: reduceMotion)) {
                    settledRotation += projected
                }
                Haptic.settle.play()
            }
    }

    private func rotate(by degrees: Double) {
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            settledRotation += degrees
        }
    }

    private func capacityArc(radius: CGFloat, in size: CGSize) -> some View {
        Circle()
            .trim(from: 0, to: step.rawValue >= LifeMapOnboardingStep.capacity.rawValue ? scene.capacityFraction : 0)
            .stroke(
                Color.lifeboard(.accentPrimary),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: radius * 2, height: radius * 2)
            .position(x: size.width / 2, y: size.height / 2)
            .lifeBoardMotion(.contentInsertion, value: scene.capacityFraction)
            .accessibilityHidden(true)
    }

    private func point(index: Int, count: Int, radius: CGFloat, center: CGPoint, phase: CGFloat) -> CGPoint {
        guard count > 0 else { return center }
        let angle = phase + CGFloat(index) / CGFloat(count) * .pi * 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

// MARK: - Parts

private struct LifeMapOrbitRing: View {
    let radius: CGFloat
    let canvasSize: CGSize

    var body: some View {
        Circle()
            .stroke(
                Color.lifeboard(.strokeHairline),
                style: StrokeStyle(lineWidth: 1, dash: [2, 6])
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
            .accessibilityHidden(true)
    }
}

private struct LifeMapCenterNode: View {
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.lifeboard(.title3))
            Text(title)
                .font(.lifeboard(.caption2))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Color.lifeboard(.accentOnPrimary))
        .padding(8)
        .frame(width: 104, height: 104)
        .background(Color.lifeboard(.accentPrimary), in: Circle())
        .accessibilityHidden(true)
    }
}

private struct LifeMapOrbitNode: View {
    let node: LifeMapSceneNode
    let isSelected: Bool

    private var tint: Color {
        HexColor.color(node.colorHex, fallback: Color.lifeboard(.textPrimary))
    }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: node.symbol)
                .font(.lifeboard(.caption1))
                .foregroundStyle(node.kind == .lifeArea ? tint : Color.lifeboard(.textPrimary))
            Text(node.title)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 6)
        .frame(width: node.kind == .root ? 70 : 78, height: node.kind == .root ? 52 : 50)
        .lifeBoardClaySurface(
            isSelected ? .raised : .resting,
            cornerRadius: Radius.card,
            fill: isSelected ? Color.lifeboard(.accentWash) : nil
        )
    }
}
