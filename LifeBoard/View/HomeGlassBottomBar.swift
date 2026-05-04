//
//  HomeGlassBottomBar.swift
//  LifeBoard
//

import SwiftUI
import Observation

struct HomeGlassBottomBar: View {
    @Bindable var state: HomeBottomBarState
    let shellPhase: HomeShellPhase

    let onHome: () -> Void
    let onCalendar: () -> Void
    let onChartsToggle: () -> Void
    let onSearch: () -> Void
    let onChat: () -> Void
    let onCreate: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var prefersReducedMotion: Bool { shellPhase != .interactive }

    var body: some View {
        HomeAnimatedTabBar(
            selectedItem: state.selectedItem,
            shellPhase: shellPhase,
            items: HomeBottomTabDescriptor.homeTabs,
            onTap: handleItemTap
        )
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s12)
        .padding(.bottom, 0)
        .scaleEffect(state.isMinimized ? 0.96 : 1.0, anchor: .bottom)
        .offset(y: state.isMinimized ? spacing.s20 : 0)
        .animation(prefersReducedMotion ? .easeOut(duration: 0.14) : LifeBoardAnimation.snappy, value: state.isMinimized)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.bottomBar")
        .accessibilityValue(state.isMinimized ? "minimized" : "expanded")
    }

    private func handleItemTap(_ item: HomeBottomBarItem) {
        switch item {
        case .create:
            handleCreateTap()
        default:
            handleToolTap(item)
        }
    }

    private func handleToolTap(_ item: HomeBottomBarItem) {
        LifeBoardFeedback.selection()
        withAnimation(selectionAnimation) {
            state.select(item)
        }

        DispatchQueue.main.async {
            switch item {
            case .home:
                onHome()
            case .calendar:
                onCalendar()
            case .charts:
                onChartsToggle()
            case .search:
                onSearch()
            case .chat:
                onChat()
            case .create:
                break
            }
        }
    }

    private func handleCreateTap() {
        LifeBoardFeedback.medium()
        withAnimation(selectionAnimation) {
            state.selectMomentaryCreate()
        }

        DispatchQueue.main.async {
            onCreate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (prefersReducedMotion ? 0.16 : 0.42)) {
            Task { @MainActor in
                guard state.selectedItem == .create else { return }
                withAnimation(selectionAnimation) {
                    state.restoreAfterMomentaryCreate()
                }
            }
        }
    }

    private var selectionAnimation: Animation {
        prefersReducedMotion
            ? .easeOut(duration: 0.14)
            : .spring(response: 0.38, dampingFraction: 0.86)
    }
}

private struct HomeBottomTabDescriptor: Identifiable {
    let item: HomeBottomBarItem
    let staticSymbolName: String?
    let accessibilityID: String
    let accessibilityLabel: String

    var id: HomeBottomBarItem { item }

    var symbolName: String {
        if item == .calendar {
            return HomeCalendarBottomBarSymbol.symbolName(for: Date())
        }
        return staticSymbolName ?? "circle"
    }

    static let homeTabs: [HomeBottomTabDescriptor] = [
        HomeBottomTabDescriptor(
            item: .home,
            staticSymbolName: "house.fill",
            accessibilityID: "home.bottomBar.home",
            accessibilityLabel: "Home"
        ),
        HomeBottomTabDescriptor(
            item: .calendar,
            staticSymbolName: nil,
            accessibilityID: "home.bottomBar.calendar",
            accessibilityLabel: "Schedule"
        ),
        HomeBottomTabDescriptor(
            item: .chat,
            staticSymbolName: "sparkles",
            accessibilityID: "home.chatButton",
            accessibilityLabel: "Chat"
        ),
        HomeBottomTabDescriptor(
            item: .charts,
            staticSymbolName: "chart.bar.xaxis",
            accessibilityID: "home.bottomBar.charts",
            accessibilityLabel: "Analytics"
        ),
        HomeBottomTabDescriptor(
            item: .search,
            staticSymbolName: "magnifyingglass",
            accessibilityID: "home.searchButton",
            accessibilityLabel: "Search"
        ),
        HomeBottomTabDescriptor(
            item: .create,
            staticSymbolName: "plus",
            accessibilityID: "home.addTaskButton",
            accessibilityLabel: "Add Task"
        )
    ]
}

private struct HomeAnimatedTabBar: View {
    let selectedItem: HomeBottomBarItem?
    let shellPhase: HomeShellPhase
    let items: [HomeBottomTabDescriptor]
    let onTap: (HomeBottomBarItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var framesByIndex: [Int: CGRect] = [:]
    @State private var previousSelectedIndex = 0
    @State private var tBall: CGFloat = 1

    private let barHeight: CGFloat = 64
    private let buttonSize: CGFloat = 44
    private let ballSize: CGFloat = 10
    private let coordinateSpaceName = "HomeAnimatedBottomBarSpace"

    private var selectedIndex: Int {
        guard let selectedItem,
              let index = HomeBottomBarItem.visibleAnimatedItems.firstIndex(of: selectedItem) else {
            return HomeBottomBarItem.visibleAnimatedItems.firstIndex(of: .home) ?? 0
        }
        return index
    }

    private var prefersReducedMotion: Bool { shellPhase != .interactive }

    private var ballAnimation: Animation {
        prefersReducedMotion
            ? .linear(duration: 0.01)
            : .easeOut(duration: 0.46)
    }

    private var indentAnimation: Animation {
        prefersReducedMotion
            ? .easeOut(duration: 0.12)
            : .easeOut(duration: 0.30)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background

            buttons

            if hasMeasuredSelectedFrame {
                Circle()
                    .fill(Color.lifeboard.accentPrimary)
                    .frame(width: ballSize, height: ballSize)
                    .modifier(HomeParabolicBallEffect(
                        t: tBall,
                        from: ballCoordinate(for: previousSelectedIndex),
                        to: ballCoordinate(for: selectedIndex),
                        lift: prefersReducedMotion ? 0 : 58
                    ))
                    .shadow(color: Color.lifeboard.accentPrimary.opacity(colorScheme == .dark ? 0.42 : 0.26), radius: 8, y: 3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: barHeight)
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(HomeAnimatedTabFramePreferenceKey.self) { framesByIndex in
            self.framesByIndex = framesByIndex
        }
        .onAppear {
            previousSelectedIndex = selectedIndex
            tBall = 1
        }
        .onChange(of: selectedIndex) { oldValue, newValue in
            previousSelectedIndex = oldValue
            tBall = 0
            withAnimation(ballAnimation) {
                tBall = 1
            }
        }
    }

    private var hasMeasuredSelectedFrame: Bool {
        framesByIndex[selectedIndex] != nil
    }

    private var background: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                backgroundSegment(for: index)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(colorScheme == .dark ? 0.46 : 0.34), lineWidth: 1)
        )
        .background {
            if #available(iOS 26.0, *) {
                Color.clear
            } else {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.lifeboard.surfaceSecondary.opacity(colorScheme == .dark ? 0.36 : 0.30))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.13), radius: 18, y: 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .frame(height: barHeight)
    }

    @ViewBuilder
    private func backgroundSegment(for index: Int) -> some View {
        let shape = HomeAnimatedTabIndent(
            t: selectedIndex == index ? 1 : 0,
            delay: prefersReducedMotion ? 0 : 0.68
        )

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.clear, in: shape)
                .animation(indentAnimation, value: selectedIndex)
        } else {
            shape
                .fill(Color.lifeboard.surfacePrimary.opacity(colorScheme == .dark ? 0.82 : 0.76))
                .animation(indentAnimation, value: selectedIndex)
        }
    }

    private var buttons: some View {
        HomeAnimatedTabLayout {
            ForEach(items.indices, id: \.self) { index in
                let descriptor = items[index]
                let isSelected = selectedIndex == index

                Button {
                    onTap(descriptor.item)
                } label: {
                    if descriptor.item == .chat {
                        EvaMascotView(placement: .homeEntry, size: .custom(isSelected ? 36 : 32))
                            .frame(width: buttonSize, height: buttonSize)
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                            .contentShape(Rectangle())
                    } else {
                        Image(systemName: descriptor.symbolName)
                            .font(.system(size: descriptor.item == .create ? 20 : 18, weight: isSelected ? .bold : .semibold))
                            .frame(width: buttonSize, height: buttonSize)
                            .foregroundStyle(foregroundStyle(isSelected: isSelected, item: descriptor.item))
                            .scaleEffect(isSelected && descriptor.item == .create ? 1.08 : 1.0)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(HomeAnimatedTabPressStyle(prefersReducedMotion: prefersReducedMotion))
                .background(HomeAnimatedTabFrameReader(index: index, coordinateSpaceName: coordinateSpaceName))
                .accessibilityIdentifier(descriptor.accessibilityID)
                .accessibilityLabel(descriptor.accessibilityLabel)
                .accessibilityValue(isSelected ? "selected" : "unselected")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(height: barHeight)
        .animation(prefersReducedMotion ? .easeOut(duration: 0.14) : .spring(response: 0.24, dampingFraction: 0.86), value: selectedIndex)
    }

    private func foregroundStyle(isSelected: Bool, item: HomeBottomBarItem) -> Color {
        if item == .create {
            return isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.textPrimary
        }
        return isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary
    }

    private func ballCoordinate(for index: Int) -> CGPoint {
        guard let frame = framesByIndex[index] else {
            return .zero
        }

        let x = frame.midX - ballSize / 2
        let y = max(frame.minY - ballSize - 3, 0)

        if layoutDirection == .rightToLeft {
            let maxX = (framesByIndex.values.map(\.maxX).max() ?? frame.maxX)
            return CGPoint(x: maxX - x - ballSize, y: y)
        }

        return CGPoint(x: x, y: y)
    }
}

private struct HomeAnimatedTabLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let idealSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let height = idealSizes.reduce(0) { max($0, $1.height) }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.isEmpty == false else { return }

        let widthDelta = bounds.width / CGFloat(subviews.count)
        var x = bounds.minX

        for subview in subviews {
            let idealSize = subview.sizeThatFits(.unspecified)
            let origin = CGPoint(
                x: x + widthDelta / 2 - idealSize.width / 2,
                y: bounds.midY - idealSize.height / 2
            )
            subview.place(at: origin, anchor: .topLeading, proposal: .unspecified)
            x += widthDelta
        }
    }
}

private struct HomeAnimatedTabFrameReader: View {
    let index: Int
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: HomeAnimatedTabFramePreferenceKey.self,
                value: [index: proxy.frame(in: .named(coordinateSpaceName))]
            )
        }
    }
}

private struct HomeAnimatedTabFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct HomeParabolicBallEffect: GeometryEffect {
    var t: CGFloat
    let from: CGPoint
    let to: CGPoint
    let lift: CGFloat

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let point = point(at: t)
        return ProjectionTransform(CGAffineTransform(translationX: point.x, y: point.y))
    }

    private func point(at t: CGFloat) -> CGPoint {
        let clampedT = min(max(t, 0), 1)
        let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - lift)
        let inverseT = 1 - clampedT
        return CGPoint(
            x: inverseT * inverseT * from.x + 2 * inverseT * clampedT * control.x + clampedT * clampedT * to.x,
            y: inverseT * inverseT * from.y + 2 * inverseT * clampedT * control.y + clampedT * clampedT * to.y
        )
    }
}

private struct HomeAnimatedTabIndent: Shape {
    var t: CGFloat
    var delay: CGFloat = 0

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let normalizedT: CGFloat
        if t < delay {
            normalizedT = 0
        } else {
            normalizedT = (t - delay) / max(1 - delay, 0.001)
        }

        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)

        let indentWidth = min(60, rect.width * 0.86)
        let indentDepth = normalizedT * 14
        let indentPath = HomeAnimatedTranslatedIndentPath(rect: CGRect(
            x: rect.midX - indentWidth / 2,
            y: rect.minY,
            width: indentWidth,
            height: indentDepth
        )).path()

        var path = Path()
        path.move(to: topLeft)
        path.addPath(indentPath)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()
        return path
    }
}

private struct HomeAnimatedTranslatedIndentPath {
    let rect: CGRect

    private let maxX = 55.0
    private let maxY = 17.0

    func path() -> Path {
        let start = translate(x: 0, y: 0)
        let middle = translate(x: 27.5, y: 17)
        let end = translate(x: 55, y: 0)

        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: middle,
            control1: translate(x: 11.5, y: 0),
            control2: translate(x: 19.5, y: 17)
        )
        path.addCurve(
            to: end,
            control1: translate(x: 35.5, y: 17),
            control2: translate(x: 43.5, y: 0)
        )
        return path
    }

    private func translate(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(
            x: x / maxX * rect.width + rect.minX,
            y: y / maxY * rect.height + rect.minY
        )
    }
}

private struct HomeAnimatedTabPressStyle: ButtonStyle {
    let prefersReducedMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(prefersReducedMotion ? 1.0 : (configuration.isPressed ? 0.94 : 1.0))
            .brightness(prefersReducedMotion ? 0 : (configuration.isPressed ? 0.03 : 0))
            .animation(
                prefersReducedMotion ? .linear(duration: 0.01) : .spring(response: 0.18, dampingFraction: 0.88),
                value: configuration.isPressed
            )
    }
}
