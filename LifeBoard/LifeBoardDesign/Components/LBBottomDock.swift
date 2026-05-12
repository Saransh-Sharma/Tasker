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

    private var items: [DockItem] {
        [
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LBRadiusTokens.dock, style: .continuous))
            .background(Color.white.opacity(0.36), in: RoundedRectangle(cornerRadius: LBRadiusTokens.dock, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LBRadiusTokens.dock, style: .continuous)
                    .stroke(Color.white.opacity(0.58), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)

            LBFloatingAddButton(action: handleCreate)
                .offset(y: -6)
        }
        .padding(.top, 14)
        .scaleEffect(state.isMinimized ? 0.96 : 1, anchor: .bottom)
        .offset(y: state.isMinimized ? 16 : 0)
        .animation(shellPhase == .interactive ? .spring(response: 0.38, dampingFraction: 0.86) : .easeOut(duration: 0.14), value: state.isMinimized)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.bottomBar")
        .accessibilityValue(state.isMinimized ? "minimized" : "expanded")
    }

    private func dockButton(_ item: DockItem) -> some View {
        let selected = state.selectedItem == item.item
        return Button {
            handleTap(item.item)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selected ? item.selectedSystemImage : item.systemImage)
                    .font(.system(size: selected ? 22 : 21, weight: .semibold))
                Text(item.title)
                    .font(LBTypographyTokens.dockLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(selected ? LBColorTokens.violetDeep : Color.gray.opacity(0.82))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if selected {
                    Capsule()
                        .fill(LBColorTokens.violetSoft)
                        .overlay {
                            Capsule().stroke(LBColorTokens.violet.opacity(0.18), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.accessibilityID)
        .accessibilityLabel(item.title)
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
