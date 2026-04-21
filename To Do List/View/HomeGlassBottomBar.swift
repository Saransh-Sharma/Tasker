//
//  HomeGlassBottomBar.swift
//  Tasker
//

import SwiftUI
import Observation

struct HomeGlassBottomBar: View {
    @Bindable var state: HomeBottomBarState
    let shellPhase: HomeShellPhase

    let onHome: () -> Void
    let onChartsToggle: () -> Void
    let onSearch: () -> Void
    let onChat: () -> Void
    let onCreate: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var prefersReducedMotion: Bool { shellPhase != .interactive }

    var body: some View {
        barContent
    }

    private var barContent: some View {
        HStack(spacing: spacing.s12) {
            BottomToolCluster(
                selectedItem: state.selectedItem,
                shellPhase: shellPhase,
                onTap: handleToolTap
            )
            .opacity(state.isMinimized ? 0 : 1)
            .scaleEffect(state.isMinimized ? 0.96 : 1.0, anchor: .bottomLeading)
            .offset(y: state.isMinimized ? spacing.s20 : 0)
            .allowsHitTesting(!state.isMinimized)
            .accessibilityHidden(state.isMinimized)
            .animation(prefersReducedMotion ? .easeOut(duration: 0.14) : TaskerAnimation.snappy, value: state.isMinimized)

            Spacer(minLength: spacing.s2)

            BottomAddTaskCTA(
                shellPhase: shellPhase,
                onTap: handleCreateTap
            )
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
        .accessibilityIdentifier("home.bottomBar")
        .accessibilityValue(state.isMinimized ? "minimized" : "expanded")
    }

    /// Executes handleToolTap.
    private func handleToolTap(_ item: HomeBottomBarItem) {
        TaskerFeedback.selection()
        withAnimation(prefersReducedMotion ? .easeOut(duration: 0.14) : .spring(response: 0.38, dampingFraction: 0.86)) {
            state.select(item)
        }

        DispatchQueue.main.async {
            switch item {
            case .home:
                onHome()
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

    /// Executes handleCreateTap.
    private func handleCreateTap() {
        withAnimation(prefersReducedMotion ? .easeOut(duration: 0.14) : .spring(response: 0.38, dampingFraction: 0.86)) {
            state.select(.create)
        }
        DispatchQueue.main.async {
            onCreate()
        }
    }
}

private struct BottomToolDescriptor: Identifiable {
    let item: HomeBottomBarItem
    let symbolName: String
    let accessibilityID: String
    let accessibilityLabel: String

    var id: String { accessibilityID }
}

private struct BottomToolCluster: View {
    private static let tools: [BottomToolDescriptor] = [
        BottomToolDescriptor(
            item: .home,
            symbolName: "house.fill",
            accessibilityID: "home.bottomBar.home",
            accessibilityLabel: "Home"
        ),
        BottomToolDescriptor(
            item: .charts,
            symbolName: "chart.bar.xaxis",
            accessibilityID: "home.bottomBar.charts",
            accessibilityLabel: "Analytics"
        ),
        BottomToolDescriptor(
            item: .search,
            symbolName: "magnifyingglass",
            accessibilityID: "home.searchButton",
            accessibilityLabel: "Search"
        ),
        BottomToolDescriptor(
            item: .chat,
            symbolName: "sparkles",
            accessibilityID: "home.chatButton",
            accessibilityLabel: "Chat"
        )
    ]

    let selectedItem: HomeBottomBarItem?
    let shellPhase: HomeShellPhase
    let onTap: (HomeBottomBarItem) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let buttonWidth: CGFloat = 54
    private let buttonHeight: CGFloat = 44
    private let clusterHeight: CGFloat = 56
    private let clusterCornerRadius: CGFloat = 28
    private let clusterSpacing: CGFloat = 4
    private let clusterHorizontalPadding: CGFloat = 8
    private let clusterVerticalPadding: CGFloat = 6
    private var prefersReducedMotion: Bool { shellPhase != .interactive }

    var body: some View {
        toolForeground
            .frame(width: clusterWidth, height: clusterHeight)
            .taskerPremiumSurface(
                cornerRadius: clusterCornerRadius,
                fillColor: Color.tasker.surfacePrimary.opacity(colorScheme == .dark ? 0.76 : 0.70),
                strokeColor: Color.tasker.strokeHairline.opacity(colorScheme == .dark ? 0.70 : 0.62),
                accentColor: Color.tasker.accentSecondary,
                level: .e2,
                useNativeGlass: true
            )
            .frame(height: clusterHeight)
    }

    private var clusterWidth: CGFloat {
        let toolCount = CGFloat(Self.tools.count)
        let gapCount = CGFloat(max(Self.tools.count - 1, 0))
        return (toolCount * buttonWidth) + (gapCount * clusterSpacing) + (clusterHorizontalPadding * 2)
    }

    private var toolForeground: some View {
        HStack(spacing: clusterSpacing) {
            ForEach(Self.tools) { tool in
                ZStack {
                    if selectedItem == tool.item {
                        selectionHighlight
                    }

                    Button {
                        onTap(tool.item)
                    } label: {
                        Image(systemName: tool.symbolName)
                            .font(.system(size: 18, weight: selectedItem == tool.item ? .bold : .semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(selectedItem == tool.item ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BottomToolPressStyle(prefersReducedMotion: prefersReducedMotion))
                    .accessibilityIdentifier(tool.accessibilityID)
                    .accessibilityLabel(tool.accessibilityLabel)
                    .accessibilityValue(selectedItem == tool.item ? "selected" : "unselected")
                }
                .frame(width: buttonWidth, height: buttonHeight)
            }
        }
        .padding(.horizontal, clusterHorizontalPadding)
        .padding(.vertical, clusterVerticalPadding)
        .animation(
            prefersReducedMotion ? .easeOut(duration: 0.14) : .spring(response: 0.22, dampingFraction: 0.88),
            value: selectedItem
        )
    }

    private var selectionHighlight: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.tasker.accentWash.opacity(colorScheme == .dark ? 0.28 : 0.36))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(colorScheme == .dark ? 0.42 : 0.56), lineWidth: 1)
            )
            .frame(width: buttonWidth, height: buttonHeight)
    }
}

private struct BottomAddTaskCTA: View {
    let shellPhase: HomeShellPhase
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var prefersReducedMotion: Bool { shellPhase != .interactive }
    private let ctaCornerRadius: CGFloat = 28

    var body: some View {
        Button {
            TaskerFeedback.medium()
            onTap()
        } label: {
            ctaForeground
                .taskerPremiumSurface(
                    cornerRadius: ctaCornerRadius,
                    fillColor: Color.tasker.surfaceSecondary.opacity(colorScheme == .dark ? 0.78 : 0.72),
                    strokeColor: Color.tasker.strokeHairline.opacity(colorScheme == .dark ? 0.72 : 0.64),
                    accentColor: Color.tasker.accentPrimary,
                    level: .e2,
                    useNativeGlass: true
                )
                .taskerCTABezel(
                    style: .fab,
                    palette: .roseGold,
                    idleMotion: .staticIdle,
                    isEnabled: true,
                    isBusy: false,
                    isPressed: false
                )
        }
        .buttonStyle(BottomCTAPressStyle(prefersReducedMotion: prefersReducedMotion))
        .accessibilityIdentifier("home.addTaskButton")
        .accessibilityLabel("Add Task")
    }

    private var ctaForeground: some View {
        Image(systemName: "plus")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.tasker.textPrimary)
            .frame(width: 56, height: 56)
    }
}

private struct BottomToolPressStyle: ButtonStyle {
    let prefersReducedMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(prefersReducedMotion ? 1.0 : (configuration.isPressed ? 0.96 : 1.0))
            .animation(
                prefersReducedMotion ? .linear(duration: 0.01) : .spring(response: 0.18, dampingFraction: 0.88),
                value: configuration.isPressed
            )
    }
}

private struct BottomCTAPressStyle: ButtonStyle {
    let prefersReducedMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(prefersReducedMotion ? 1.0 : (configuration.isPressed ? 0.975 : 1.0))
            .brightness(prefersReducedMotion ? 0 : (configuration.isPressed ? 0.02 : 0))
            .animation(
                prefersReducedMotion ? .linear(duration: 0.01) : .spring(response: 0.18, dampingFraction: 0.88),
                value: configuration.isPressed
            )
    }
}
