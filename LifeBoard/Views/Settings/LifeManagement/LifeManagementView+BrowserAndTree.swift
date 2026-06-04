import SwiftUI
import UIKit

extension LifeManagementView {
    var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var activeComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: {
                if let draft = viewModel.lifeAreaDraft {
                    return .area(draft)
                }
                if let draft = viewModel.projectDraft {
                    return .project(draft)
                }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .area(let draft):
                    viewModel.lifeAreaDraft = draft
                    viewModel.projectDraft = nil
                case .project(let draft):
                    viewModel.projectDraft = draft
                    viewModel.lifeAreaDraft = nil
                case nil:
                    viewModel.dismissLifeAreaDraft()
                    viewModel.dismissProjectDraft()
                }
            }
        )
    }

    var compactComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: { layoutClass == .phone ? activeComposerRoute.wrappedValue : nil },
            set: { activeComposerRoute.wrappedValue = $0 }
        )
    }

    var regularComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: { layoutClass == .phone ? nil : activeComposerRoute.wrappedValue },
            set: { activeComposerRoute.wrappedValue = $0 }
        )
    }

    var isSearching: Bool {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var hasTreeContent: Bool {
        viewModel.treeSections.isEmpty == false
    }

    var activeTreeIsEmpty: Bool {
        viewModel.treeSections.first(where: { $0.kind == .active })?.nodes.isEmpty != false
    }

    var selectedAreaID: UUID? {
        guard case .area(let id) = viewModel.selectedNode else { return nil }
        return id
    }

    var selectedProjectID: UUID? {
        guard case .project(let id) = viewModel.selectedNode else { return nil }
        return id
    }

    var selectedAreaIsArchived: Bool {
        guard let selectedAreaID else { return false }
        return viewModel.areaRow(for: selectedAreaID)?.lifeArea.isArchived == true
    }

    var selectedProjectAllowsChildHabits: Bool {
        guard let selectedProjectID, let row = viewModel.projectRow(for: selectedProjectID) else { return false }
        return row.project.isArchived == false && row.lifeArea?.isArchived != true
    }

    var compactBrowser: some View {
        ScrollView {
            browserContent(interactionMode: .push)
                .lifeboardReadableContent(maxWidth: 980, alignment: .center)
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.vertical, spacing.s16)
        }
        .navigationDestination(for: LifeManagementSelection.self) { selection in
            detailDestination(for: selection)
        }
    }

    var splitBrowser: some View {
        NavigationSplitView {
            ScrollView {
                browserContent(interactionMode: .select)
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.vertical, spacing.s16)
            }
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    func browserContent(interactionMode: LifeManagementTreeInteractionMode) -> some View {
        LazyVStack(spacing: spacing.s16, pinnedViews: []) {
            if let errorMessage = viewModel.errorMessage {
                errorCard(message: errorMessage)
            }

            lifeManagementPrimaryActionCard

            if isSearching && hasTreeContent == false {
                emptyStateCard(
                    title: "No matches",
                    body: "Try a different search across areas, projects, and habits.",
                    actionTitle: nil,
                    action: nil
                )
            } else if hasTreeContent == false && viewModel.isLoading == false {
                emptyStateCard(
                    title: "Start with a life area",
                    body: "Create an area first, then place projects and habits inside it.",
                    actionTitle: "Add Area",
                    action: {
                        viewModel.beginCreateLifeArea()
                    }
                )
            } else {
                ForEach(viewModel.treeSections) { section in
                    treeSection(section, interactionMode: interactionMode)
                }
            }
        }
    }

    var lifeManagementPrimaryActionCard: some View {
        LifeBoardSettingsCard(active: true) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text("Life Areas")
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard(.textPrimary))

                        Text("Create a new area to organize related projects and habits.")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    viewModel.beginCreateLifeArea()
                } label: {
                    Label("Add Area", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isMutating)
                .accessibilityIdentifier("settings.lifeManagement.addAreaButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.lifeManagement.addAreaCard")
    }

    func treeSection(_ section: LifeManagementTreeSection, interactionMode: LifeManagementTreeInteractionMode) -> some View {
        LifeBoardSettingsCard(active: section.kind == .archived && viewModel.isSectionExpanded(section.kind)) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Button {
                    guard section.kind == .archived else { return }
                    withAnimation(accessibilityReduceMotion ? nil : LifeBoardAnimation.quick) {
                        viewModel.toggleSectionExpansion(section.kind)
                    }
                } label: {
                    HStack(spacing: spacing.s8) {
                        Text(section.title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text("\(section.nodes.count)")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                        Spacer()
                        if section.kind == .archived {
                            Image(systemName: viewModel.isSectionExpanded(section.kind) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(section.kind != .archived)

                if viewModel.isSectionExpanded(section.kind) {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        ForEach(section.nodes) { node in
                            treeNode(node, depth: 0, interactionMode: interactionMode)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(section.accessibilityIdentifier)
    }

    func treeNode(
        _ node: LifeManagementTreeNode,
        depth: Int,
        interactionMode: LifeManagementTreeInteractionMode
    ) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(alignment: .top, spacing: spacing.s8) {
                    if node.isExpandable {
                        Button {
                            withAnimation(accessibilityReduceMotion ? nil : LifeBoardAnimation.quick) {
                                viewModel.toggleNodeExpansion(node.selection)
                            }
                        } label: {
                            Image(systemName: viewModel.isNodeExpanded(node.selection) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 24, height: 24)
                    }

                    primaryNodeControl(node, interactionMode: interactionMode)

                    nodeMenu(node)
                }
                .padding(.leading, CGFloat(depth) * spacing.s16)

                if node.isExpandable && viewModel.isNodeExpanded(node.selection) {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        ForEach(node.children) { child in
                            treeNode(child, depth: depth + 1, interactionMode: interactionMode)
                        }
                    }
                }
            }
        )
    }

    @ViewBuilder
    func primaryNodeControl(
        _ node: LifeManagementTreeNode,
        interactionMode: LifeManagementTreeInteractionMode
    ) -> some View {
        let content = nodeRowContent(node)

        switch (interactionMode, node.selection) {
        case (.push, .area), (.push, .project):
            NavigationLink(value: node.selection) {
                content
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                viewModel.selectNode(node.selection)
            })
        case (.select, _):
            Button {
                viewModel.selectNode(node.selection)
                if case .habit(let id) = node.selection, let row = viewModel.habitRow(for: id) {
                    selectedHabitRow = row.row
                }
            } label: {
                content
            }
            .buttonStyle(.plain)
        default:
            Button {
                viewModel.selectNode(node.selection)
                if case .habit(let id) = node.selection, let row = viewModel.habitRow(for: id) {
                    selectedHabitRow = row.row
                }
            } label: {
                content
            }
            .buttonStyle(.plain)
        }
    }

    func nodeRowContent(_ node: LifeManagementTreeNode) -> some View {
        let isSelected = viewModel.selectedNode == node.selection
        return HStack(alignment: .top, spacing: spacing.s12) {
            AccentIconBadge(
                symbolName: node.symbolName,
                accentHex: node.accentHex
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(node.title)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    if let badgeTitle = nodeBadgeTitle(node) {
                        InlineToneBadge(title: badgeTitle)
                    }
                }

                Text(node.subtitle)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.lifeboard(.accentWash) : Color.lifeboard(.surfaceSecondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.strokeHairline), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .accessibilityIdentifier(node.accessibilityIdentifier)
    }

    func nodeBadgeTitle(_ node: LifeManagementTreeNode) -> String? {
        switch node.payload {
        case .area(let row):
            if row.lifeArea.isArchived || node.isArchived { return "Archived" }
            if row.isGeneral { return "Pinned" }
            return nil
        case .project(let row):
            if row.project.isArchived || node.isArchived { return "Archived" }
            if row.isInbox { return "Inbox" }
            return nil
        case .habit(let row):
            if row.row.isArchived || node.isArchived { return "Archived" }
            if row.row.isPaused { return "Paused" }
            return nil
        }
    }
}
