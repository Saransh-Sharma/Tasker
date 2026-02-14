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
            actionButton(
                iconAssetName: "charts",
                item: .charts,
                accessibilityID: "home.bottomBar.charts",
                accessibilityLabel: "Charts",
                action: onChartsToggle
            )

            actionButton(
                iconAssetName: "search",
                item: .search,
                accessibilityID: "home.searchButton",
                accessibilityLabel: "Search",
                action: onSearch
            )

            Spacer(minLength: spacing.s4)

            addButton

            Spacer(minLength: spacing.s4)

            actionButton(
                iconAssetName: "chat",
                item: .chat,
                accessibilityID: "home.chatButton",
                accessibilityLabel: "Chat",
                action: onChat
            )
        }
        .padding(.horizontal, state.isMinimized ? spacing.s12 : spacing.s16)
        .padding(.vertical, state.isMinimized ? spacing.s8 : spacing.s12)
        .background(containerBackground)
        .accessibilityIdentifier("home.bottomBar")
        .accessibilityValue(state.isMinimized ? "minimized" : "expanded")
    }

    private func actionButton(
        iconAssetName: String,
        item: HomeBottomBarItem,
        accessibilityID: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            state.select(item)
            action()
        } label: {
            Image(iconAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: state.isMinimized ? 20 : 22, height: state.isMinimized ? 20 : 22)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            .background(
                Capsule(style: .continuous)
                    .fill(state.selectedItem == item ? Color.tasker.accentPrimary.opacity(0.18) : .clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(accessibilityLabel)
    }

    private var addButton: some View {
        Button {
            state.select(.create)
            onCreate()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: state.isMinimized ? 18 : 20, weight: .bold))
                .frame(width: state.isMinimized ? 44 : 48, height: state.isMinimized ? 44 : 48)
                .foregroundColor(Color.tasker.accentOnPrimary)
                .background(addButtonBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.addTaskButton")
    }

    @ViewBuilder
    private var addButtonBackground: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(Color.tasker.accentPrimary)
                .glassEffect()
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        } else {
            Circle()
                .fill(Color.tasker.accentPrimary)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
    }

    @ViewBuilder
    private var containerBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(Color.tasker.surfacePrimary.opacity(0.88))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.tasker.textPrimary.opacity(0.14), lineWidth: 0.8)
                )
                .glassEffect()
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        }
    }
}
