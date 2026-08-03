import SwiftUI
import Observation

struct LBBottomDock: View {
    @Bindable var state: HomeBottomBarState
    let shellPhase: HomeShellPhase
    let onHome: () -> Void
    let onCalendar: () -> Void
    let onChartsToggle: () -> Void
    let onSearch: () -> Void
    let onChat: () -> Void
    let onCreate: () -> Void

    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimizedRendering
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var items: [DockItem] {
        return [
            DockItem(item: .home, title: "Home", systemImage: "house", selectedSystemImage: "house.fill", accessibilityID: "home.bottomBar.home"),
            DockItem(item: .calendar, title: "Schedule", systemImage: HomeCalendarBottomBarSymbol.symbolName(for: Date()), selectedSystemImage: HomeCalendarBottomBarSymbol.symbolName(for: Date()), accessibilityID: "home.bottomBar.calendar"),
            DockItem(item: .chat, title: "Eva", systemImage: "sparkles", selectedSystemImage: "sparkles", accessibilityID: "home.chatButton"),
            DockItem(item: .charts, title: "Insights", systemImage: "chart.bar.xaxis", selectedSystemImage: "chart.bar.xaxis", accessibilityID: "home.bottomBar.charts")
        ]
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(items.prefix(2)) { item in
                    dockButton(item)
                }
                Spacer(minLength: 74)
                ForEach(items.suffix(2)) { item in
                    dockButton(item)
                }
            }
            .padding(.horizontal, LBSpacingTokens.sm)
            .frame(height: 68)
            .background {
                RoundedRectangle(cornerRadius: LBRadiusTokens.dock, style: .continuous)
                    .fill(Color.lifeboard(.bgElevated))
                    .modifier(LBBottomDockMaterialModifier(isEnabled: usesMaterialBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: LBRadiusTokens.dock, style: .continuous)
                    .stroke(Color.lifeboard(.borderStrong), lineWidth: 1)
            }
            .shadow(color: Color.lifeboard(.textPrimary).opacity(0.12), radius: 14, x: 0, y: 7)

            LBFloatingAddButton(action: handleCreate)
                .offset(y: -6)
        }
        .padding(.top, 14)
        .animation(nil, value: state.isMinimized)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.bottomBar")
        .accessibilityValue("expanded")
    }

    private var usesMaterialBackground: Bool {
        scrollOptimizedRendering == false && state.isMinimized == false
    }

    private func dockButton(_ item: DockItem) -> some View {
        let selected = state.selectedItem == item.item
        return Button {
            handleTap(item.item)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selected ? item.selectedSystemImage : item.systemImage)
                    .font(.title3.weight(selected ? .semibold : .regular))
                if dynamicTypeSize.isAccessibilitySize == false {
                    Text(item.title)
                        .lifeboardFont(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selected ? Color.lifeboard(.textPrimary) : Color.lifeboard(.textSecondary))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if selected {
                    Capsule()
                        .fill(Color.lifeboard(.surfaceTertiary))
                        .overlay {
                            Capsule().stroke(Color.lifeboard(.borderStrong), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.accessibilityID)
        .accessibilityLabel(item.title)
        .accessibilityValue(selected ? "selected" : "not selected")
    }

    private func handleTap(_ item: HomeBottomBarItem) {
        LifeBoardFeedback.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
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

    private func handleCreate() {
        LifeBoardFeedback.medium()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            state.selectMomentaryCreate()
        }
        DispatchQueue.main.async {
            onCreate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            Task { @MainActor in
                guard state.selectedItem == .create else { return }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    state.restoreAfterMomentaryCreate()
                }
            }
        }
    }
}

private struct DockItem: Identifiable {
    let item: HomeBottomBarItem
    let title: String
    let systemImage: String
    let selectedSystemImage: String
    let accessibilityID: String

    var id: HomeBottomBarItem { item }
}

private struct LBBottomDockMaterialModifier: ViewModifier {
    let isEnabled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if isEnabled == false {
            content
        } else if reduceTransparency {
            content.background(Color.lifeboard(.bgElevated), in: RoundedRectangle(cornerRadius: LBRadiusTokens.dock, style: .continuous))
        } else {
            content.lifeBoardSystemGlass(
                .regular,
                in: RoundedRectangle(cornerRadius: LBRadiusTokens.dock, style: .continuous),
                interactive: true
            )
        }
    }
}
