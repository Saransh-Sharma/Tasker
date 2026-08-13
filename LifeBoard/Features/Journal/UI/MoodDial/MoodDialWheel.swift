import SwiftUI

public struct MoodDialWheel: View {
    @Binding var selectedMood: Mood
    @Binding var isDragging: Bool
    let metrics: MoodDialWheelMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.moodDialTheme) private var theme
    @Environment(\.journalHaptics) private var haptics

    @State private var rotationDegrees = 0.0
    @State private var dragStartRotationDegrees = 0.0
    @State private var dragStartAngleDegrees: Double?
    @State private var pointerBounce = false

    public init(selectedMood: Binding<Mood>, isDragging: Binding<Bool>, metrics: MoodDialWheelMetrics) {
        _selectedMood = selectedMood
        _isDragging = isDragging
        self.metrics = metrics
    }

    public var body: some View {
        ZStack {
            dialSegments
                .rotationEffect(
                    .degrees(rotationDegrees),
                    anchor: UnitPoint(
                        x: metrics.center.x / max(metrics.size.width, 1),
                        y: metrics.center.y / max(metrics.size.height, 1)
                    )
                )
                .animation(isDragging || reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.78), value: rotationDegrees)
                .zIndex(1)

            MoodDialPointer()
                .position(x: metrics.center.x, y: metrics.pointerCenterY + (pointerBounce ? -5 : 0))
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62), value: pointerBounce)
                .zIndex(2)

            Color.clear
                .frame(width: metrics.size.width, height: metrics.gestureHeight)
                .contentShape(Rectangle())
                .position(x: metrics.center.x, y: metrics.gestureCenterY)
                .gesture(dragGesture(center: metrics.center))
                .zIndex(3)
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .accessibilityElement()
        .accessibilityLabel("Mood dial")
        .accessibilityValue(selectedMood.displayName)
        .accessibilityHint("Swipe up or down to change mood.")
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
        .accessibilityIdentifier("moodDial.wheel")
        .onAppear {
            rotationDegrees = MoodDialMath.rotationDegrees(for: selectedMood)
        }
    }

    private var dialSegments: some View {
        let geometry = MoodDialWheelGeometryCache.geometry(for: metrics)

        return ZStack {
            ForEach(geometry.segments) { segment in
                segment.path
                    .fill(theme.segmentColor(segment.mood).opacity(0.78))

                segment.mood.dialFaceImage
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(segment.iconPreRotationDegrees))
                    .opacity(0.56)
                    .position(segment.iconPosition)
                    .accessibilityHidden(true)
            }

            if let selectedSegment = geometry.segment(for: selectedMood) {
                selectedSegment.selectedPath
                    .fill(theme.segmentColor(selectedMood))
                    .overlay(
                        selectedSegment.selectedPath
                            .fill(Color.white.opacity(0.08))
                            .blendMode(.softLight)
                    )

                selectedMood.dialFaceImage
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(selectedSegment.iconPreRotationDegrees))
                    .opacity(0.88)
                    .position(selectedSegment.iconPosition)
                    .accessibilityHidden(true)
            }
        }
    }

    private func dragGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                if dragStartAngleDegrees == nil {
                    MoodDialSignposts.event("MoodDialDragStarted")
                    isDragging = true
                    dragStartAngleDegrees = MoodDialMath.angleDegrees(for: value.startLocation, around: center)
                    dragStartRotationDegrees = rotationDegrees
                }

                let startAngle = dragStartAngleDegrees ?? MoodDialMath.angleDegrees(for: value.startLocation, around: center)
                let currentAngle = MoodDialMath.angleDegrees(for: value.location, around: center)
                let delta = MoodDialMath.normalizedDeltaDegrees(from: startAngle, to: currentAngle)
                let nextRotation = MoodDialMath.resistedRotationDegrees(dragStartRotationDegrees + delta)
                updateSelection(forRotation: nextRotation, animated: false)
            }
            .onEnded { _ in
                MoodDialSignposts.event("MoodDialDragEnded")
                dragStartAngleDegrees = nil
                isDragging = false
                snapToCurrentMood()
            }
    }

    private func updateSelection(forRotation nextRotation: Double, animated: Bool) {
        let nextMood = MoodDialMath.mood(forRotationDegrees: nextRotation)
        let apply = {
            rotationDegrees = nextRotation
            if nextMood != selectedMood {
                selectedMood = nextMood
                haptics.selectionChanged()
            }
        }

        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                apply()
            }
        } else {
            apply()
        }
    }

    private func snapToCurrentMood() {
        let nearestIndex = MoodDialMath.nearestIndex(forRotationDegrees: rotationDegrees)
        let snappedRotation = MoodDialMath.rotationDegrees(for: nearestIndex)
        selectedMood = Mood.dialMoods[nearestIndex]
        updateSelection(forRotation: snappedRotation, animated: true)
        bouncePointer()
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let currentIndex = MoodDialMath.index(for: selectedMood)
        let nextIndex: Int
        switch direction {
        case .increment:
            nextIndex = min(currentIndex + 1, Mood.dialMoods.count - 1)
        case .decrement:
            nextIndex = max(currentIndex - 1, 0)
        @unknown default:
            return
        }

        selectedMood = Mood.dialMoods[nextIndex]
        updateSelection(forRotation: MoodDialMath.rotationDegrees(for: nextIndex), animated: true)
        bouncePointer()
    }

    private func bouncePointer() {
        guard !reduceMotion else { return }
        pointerBounce = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            pointerBounce = false
        }
    }
}

public struct MoodDialWheelGeometry {
    public let segments: [Segment]

    public struct Segment: Identifiable {
        public let id: Mood.ID
        public let mood: Mood
        public let path: Path
        public let selectedPath: Path
        public let iconPosition: CGPoint
        public let iconPreRotationDegrees: Double
    }

    public func segment(for mood: Mood) -> Segment? {
        segments.first { $0.mood == mood }
    }
}

public enum MoodDialWheelGeometryCache {
    private struct Key: Hashable {
        let width: Int
        let height: Int
        let topInset: Int
        let bottomInset: Int

        init(metrics: MoodDialWheelMetrics) {
            width = Int((metrics.size.width * 2).rounded())
            height = Int((metrics.size.height * 2).rounded())
            topInset = Int((metrics.safeAreaInsets.top * 2).rounded())
            bottomInset = Int((metrics.safeAreaInsets.bottom * 2).rounded())
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [Key: MoodDialWheelGeometry] = [:]

    public static func geometry(for metrics: MoodDialWheelMetrics) -> MoodDialWheelGeometry {
        let key = Key(metrics: metrics)

        lock.lock()
        if let geometry = cache[key] {
            lock.unlock()
            return geometry
        }
        lock.unlock()

        let geometry = makeGeometry(for: metrics)

        lock.lock()
        cache[key] = geometry
        lock.unlock()
        return geometry
    }

    public static func clear() {
        lock.lock()
        cache = [:]
        lock.unlock()
    }

    #if DEBUG
    public static func resetForTesting() {
        clear()
    }

    public static var cachedGeometryCount: Int {
        lock.lock()
        let count = cache.count
        lock.unlock()
        return count
    }
    #endif

    private static func makeGeometry(for metrics: MoodDialWheelMetrics) -> MoodDialWheelGeometry {
        MoodDialSignposts.event("MoodDialGeometryCacheMiss")
        let sweep = MoodDialMath.segmentSweepDegrees()
        let segments = Mood.dialMoods.enumerated().map { index, mood in
            let startAngle = MoodDialMath.arcStartDegrees + Double(index) * sweep
            let endAngle = MoodDialMath.arcStartDegrees + Double(index + 1) * sweep
            let iconAngle = MoodDialMath.centerAngleDegrees(for: index)
            let iconRadians = iconAngle * .pi / 180
            let iconRadius = (metrics.innerRadius + metrics.outerRadius) / 2
            let iconPosition = CGPoint(
                x: metrics.center.x + CGFloat(cos(iconRadians)) * iconRadius,
                y: metrics.center.y + CGFloat(sin(iconRadians)) * iconRadius
            )

            return MoodDialWheelGeometry.Segment(
                id: mood.id,
                mood: mood,
                path: segmentPath(
                    center: metrics.center,
                    innerRadius: metrics.innerRadius,
                    outerRadius: metrics.outerRadius,
                    startAngleDegrees: startAngle,
                    endAngleDegrees: endAngle
                ),
                selectedPath: segmentPath(
                    center: metrics.center,
                    innerRadius: metrics.innerRadius,
                    outerRadius: metrics.outerRadius + 10,
                    startAngleDegrees: startAngle,
                    endAngleDegrees: endAngle
                ),
                iconPosition: iconPosition,
                iconPreRotationDegrees: iconAngle - MoodDialMath.pointerAngleDegrees
            )
        }

        return MoodDialWheelGeometry(segments: segments)
    }

    private static func segmentPath(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngleDegrees: Double,
        endAngleDegrees: Double
    ) -> Path {
        var path = Path()
        let outerPoints = points(radius: outerRadius, center: center, from: startAngleDegrees, to: endAngleDegrees)
        let innerPoints = points(radius: innerRadius, center: center, from: endAngleDegrees, to: startAngleDegrees)

        guard let first = outerPoints.first else { return path }
        path.move(to: first)
        outerPoints.dropFirst().forEach { path.addLine(to: $0) }
        innerPoints.forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    private static func points(radius: CGFloat, center: CGPoint, from startAngle: Double, to endAngle: Double) -> [CGPoint] {
        let steps = max(6, Int(abs(endAngle - startAngle) / 2))
        return (0...steps).map { step in
            let progress = Double(step) / Double(steps)
            let angle = startAngle + (endAngle - startAngle) * progress
            let radians = angle * .pi / 180
            return CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
        }
    }
}
