//
//  HomeGlassBottomBar.swift
//  Tasker
//

import SwiftUI
import Observation

struct HomeGlassBottomBar: View {
    @Bindable var state: HomeBottomBarState

    let onChartsToggle: () -> Void
    let onSearch: () -> Void
    let onChat: () -> Void
    let onCreate: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: state.isMinimized ? spacing.s8 : spacing.s12) {
            LiquidToolCluster(
                selectedItem: state.selectedItem,
                isMinimized: state.isMinimized,
                onTap: handleToolTap
            )

            Spacer(minLength: spacing.s2)

            LiquidAddTaskCTA(
                isMinimized: state.isMinimized,
                onTap: handleCreateTap
            )
        }
        .padding(.horizontal, state.isMinimized ? spacing.s12 : spacing.s16)
        .padding(.vertical, state.isMinimized ? spacing.s8 : spacing.s12)
        .accessibilityIdentifier("home.bottomBar")
        .accessibilityValue(state.isMinimized ? "minimized" : "expanded")
    }

    private func handleToolTap(_ item: HomeBottomBarItem) {
        TaskerFeedback.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            state.select(item)
        }

        switch item {
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

    private func handleCreateTap() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            state.select(.create)
        }
        onCreate()
    }
}

private struct BottomToolDescriptor: Identifiable {
    let item: HomeBottomBarItem
    let symbolName: String
    let accessibilityID: String
    let accessibilityLabel: String

    var id: String { accessibilityID }
}

private struct LiquidToolCluster: View {
    private static let tools: [BottomToolDescriptor] = [
        BottomToolDescriptor(
            item: .search,
            symbolName: "magnifyingglass",
            accessibilityID: "home.searchButton",
            accessibilityLabel: "Search"
        ),
        BottomToolDescriptor(
            item: .charts,
            symbolName: "chart.bar.xaxis",
            accessibilityID: "home.bottomBar.charts",
            accessibilityLabel: "Analytics"
        ),
        BottomToolDescriptor(
            item: .chat,
            symbolName: "sparkles",
            accessibilityID: "home.chatButton",
            accessibilityLabel: "Chat"
        )
    ]

    let selectedItem: HomeBottomBarItem?
    let isMinimized: Bool
    let onTap: (HomeBottomBarItem) -> Void

    @Namespace private var selectionNamespace
    @State private var pressedItem: HomeBottomBarItem?
    @Environment(\.colorScheme) private var colorScheme

    private var buttonWidth: CGFloat { isMinimized ? 46 : 54 }
    private var buttonHeight: CGFloat { isMinimized ? 42 : 44 }
    private var clusterHeight: CGFloat { isMinimized ? 52 : 56 }

    var body: some View {
        LiquidGlassSurface(shape: Capsule(style: .continuous), emphasis: .normal) {
            HStack(spacing: isMinimized ? 2 : 4) {
                ForEach(Self.tools) { tool in
                    ZStack {
                        if selectedItem == tool.item {
                            selectionHighlight
                                .matchedGeometryEffect(id: "home.bottomBar.selection", in: selectionNamespace)
                        }

                        Button {
                            onTap(tool.item)
                        } label: {
                            Image(systemName: tool.symbolName)
                                .font(.system(size: isMinimized ? 16 : 18, weight: selectedItem == tool.item ? .bold : .semibold))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(selectedItem == tool.item ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(tool.accessibilityID)
                        .accessibilityLabel(tool.accessibilityLabel)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if pressedItem != tool.item {
                                        pressedItem = tool.item
                                    }
                                }
                                .onEnded { _ in
                                    pressedItem = nil
                                }
                        )
                    }
                    .frame(width: buttonWidth, height: buttonHeight)
                    .scaleEffect(pressedItem == tool.item ? 0.96 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.85), value: pressedItem == tool.item)
                }
            }
            .padding(.horizontal, isMinimized ? 6 : 8)
            .padding(.vertical, isMinimized ? 5 : 6)
        }
        .frame(height: clusterHeight)
    }

    private var selectionHighlight: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.tasker.textPrimary.opacity(colorScheme == .dark ? 0.14 : 0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.08), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.10),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
            )
            .frame(width: buttonWidth, height: buttonHeight)
    }
}

private struct LiquidAddTaskCTA: View {
    let isMinimized: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPressed = false
    @State private var sheenOffset: CGFloat = -1.0
    @State private var showSheen = false

    var body: some View {
        Button {
            TaskerFeedback.medium()
            triggerSheenIfNeeded()
            onTap()
        } label: {
            LiquidGlassSurface(shape: Capsule(style: .continuous), emphasis: .strong) {
                Image(systemName: "plus")
                    .font(.system(size: isMinimized ? 17 : 18, weight: .bold))
                .foregroundStyle(Color.tasker.textPrimary)
                .frame(width: isMinimized ? 48 : 56)
                .frame(height: isMinimized ? 48 : 56)
                .overlay(
                    sheenOverlay
                )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.975 : 1.0)
        .brightness(isPressed ? 0.03 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityIdentifier("home.addTaskButton")
        .accessibilityLabel("Add Task")
    }

    @ViewBuilder
    private var sheenOverlay: some View {
        if showSheen && !reduceMotion {
            GeometryReader { proxy in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.10),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * 0.70)
                    .offset(x: sheenOffset * proxy.size.width)
                    .blendMode(.screen)
            }
            .clipShape(Capsule(style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private func triggerSheenIfNeeded() {
        guard !reduceMotion else { return }

        showSheen = true
        sheenOffset = -0.8

        withAnimation(.easeInOut(duration: 0.35)) {
            sheenOffset = 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSheen = false
        }
    }
}
