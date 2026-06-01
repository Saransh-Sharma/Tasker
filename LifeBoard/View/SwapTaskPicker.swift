import SwiftUI

struct SwapTaskPicker: View {
    let slotIndex: Int
    let currentTask: DailyPlanTaskOption?
    let planningDate: Date
    let options: [DailyPlanTaskOption]
    let onUse: (DailyPlanTaskOption) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ReflectPlanStyle.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                        header
                        searchField

                        if filteredOptions.isEmpty {
                            emptyState
                        } else {
                            ForEach(sections) { section in
                                if section.options.isEmpty == false {
                                    VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                                        Text(section.title)
                                            .font(.lifeboard(.caption1).weight(.semibold))
                                            .foregroundStyle(LBColorTokens.navyMuted)
                                            .padding(.horizontal, 2)

                                        VStack(spacing: LBSpacingTokens.sm) {
                                            ForEach(section.options) { option in
                                                swapOptionRow(option)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(LBSpacingTokens.lg)
                    .padding(.bottom, LBSpacingTokens.lg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Swap task")
                .font(.lifeboard(.title2).weight(.bold))
                .foregroundStyle(LBColorTokens.navy)
            Text("Choose a better fit for today.")
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private var searchField: some View {
        HStack(spacing: LBSpacingTokens.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LBColorTokens.navyMuted)
                .accessibilityHidden(true)
            TextField("Search tasks", text: $searchText)
                .font(.lifeboard(.callout))
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ReflectPlanStyle.peachBorder.opacity(0.48), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
            Text("No matches")
                .font(.lifeboard(.headline))
                .foregroundStyle(LBColorTokens.navy)
            Text("Try a different title or project.")
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LBSpacingTokens.lg)
        .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func swapOptionRow(_ option: DailyPlanTaskOption) -> some View {
        HStack(alignment: .top, spacing: LBSpacingTokens.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                    .fixedSize(horizontal: false, vertical: true)
                if let projectName = option.projectName, projectName.isEmpty == false {
                    Text(projectName)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
                }
                if option.isCarryover || option.isQuickStabilizer {
                    Text(optionBadge(option))
                        .font(.lifeboard(.caption2).weight(.semibold))
                        .foregroundStyle(LBColorTokens.role(.warning).deep)
                }
            }

            Spacer(minLength: LBSpacingTokens.sm)

            Button("Use this") {
                onUse(option)
                dismiss()
            }
            .font(.lifeboard(.caption1).weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(LBColorTokens.role(.focus).deep)
            .frame(minWidth: 70, minHeight: 44, alignment: .trailing)
        }
        .padding(LBSpacingTokens.md)
        .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ReflectPlanStyle.blueBorder.opacity(0.48), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Use \(option.title). \(option.projectName ?? "").")
    }

    private var filteredOptions: [DailyPlanTaskOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return options }
        return options.filter { option in
            option.title.localizedCaseInsensitiveContains(query)
                || (option.projectName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var sections: [SwapTaskPickerSection] {
        var used = Set<UUID>()

        func unique(_ candidates: [DailyPlanTaskOption]) -> [DailyPlanTaskOption] {
            candidates.filter { used.insert($0.id).inserted }
        }

        let quickWins = unique(filteredOptions.filter(\.isQuickStabilizer))
        let carryover = unique(filteredOptions.filter { option in
            option.isCarryover || isOverdue(option)
        })
        let projectName = currentTask?.projectName
        let projectMatched = unique(filteredOptions.filter { option in
            guard let projectName, projectName.isEmpty == false else { return false }
            return option.projectName == projectName
        })
        let suggested = unique(filteredOptions)

        return [
            SwapTaskPickerSection(title: "Suggested alternatives", options: suggested),
            SwapTaskPickerSection(title: "Quick wins", options: quickWins),
            SwapTaskPickerSection(title: "Overdue carryover", options: carryover),
            SwapTaskPickerSection(title: "Project-matched tasks", options: projectMatched)
        ]
    }

    private func isOverdue(_ option: DailyPlanTaskOption) -> Bool {
        guard let dueDate = option.dueDate else { return false }
        return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: planningDate)
    }

    private func optionBadge(_ option: DailyPlanTaskOption) -> String {
        if option.isQuickStabilizer {
            return "Quick win"
        }
        if option.isCarryover || isOverdue(option) {
            return "Carryover"
        }
        return ""
    }
}

private struct SwapTaskPickerSection: Identifiable {
    let id = UUID()
    let title: String
    let options: [DailyPlanTaskOption]
}
