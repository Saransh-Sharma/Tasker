import SwiftUI
import UIKit

extension AddHabitSheetView {
    var appearanceCard: some View {
        CalmInlineReveal(
            title: String(localized: "Appearance"),
            collapsedHint: appearanceSummary,
            isExpanded: $showAppearance,
            accessibilityID: "addHabit.appearanceDisclosure",
            onToggle: toggleAppearance
        ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    TextField("Search icons", text: $viewModel.iconSearchQuery, prompt: Text("Search icons").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .textFieldStyle(TokenTextFieldStyle())
                        .accessibilityIdentifier("addHabit.iconSearchField")

                    ScrollView(.horizontal) {
                        HStack(spacing: spacing.s8) {
                            ForEach(viewModel.availableIconOptions.prefix(18)) { option in
                                Button {
                                    viewModel.selectedIconSymbolName = option.symbolName
                                } label: {
                                    Image(systemName: option.symbolName)
                                        .font(ClayTypography.bodyStrong)
                                        .foregroundStyle(viewModel.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                                        .frame(width: CreationChipMetrics.compactSwatchSize, height: CreationChipMetrics.compactSwatchSize)
                                        .background(viewModel.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: CreationChipMetrics.compactCornerRadius, style: .continuous))
                                    .minimumHitTarget(CreationChipMetrics.hitHeight)
                                }
                                .frame(width: CreationChipMetrics.hitHeight, height: CreationChipMetrics.hitHeight)
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.displayName)
                                .accessibilityAddTraits(viewModel.selectedIconSymbolName == option.symbolName ? .isSelected : [])
                            }
                        }
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: spacing.s8) {
                            ForEach(HabitColorFamily.allCases, id: \.rawValue) { family in
                                Button {
                                    viewModel.selectedColorHex = family.canonicalHex
                                } label: {
                                    RoundedRectangle(cornerRadius: CreationChipMetrics.compactCornerRadius, style: .continuous)
                                        .fill(Color(lifeboardHex: family.canonicalHex))
                                        .frame(width: CreationChipMetrics.compactSwatchSize, height: CreationChipMetrics.compactSwatchSize)
                                        .overlay {
                                            if HabitColorFamily.family(for: viewModel.selectedColorHex) == family {
                                                RoundedRectangle(cornerRadius: CreationChipMetrics.compactCornerRadius, style: .continuous)
                                                    .stroke(Color.lifeboard.accentOnPrimary, lineWidth: 2)
                                                    .padding(3)
                                            }
                                        }
                                        .minimumHitTarget(CreationChipMetrics.hitHeight)
                                }
                                .frame(width: CreationChipMetrics.hitHeight, height: CreationChipMetrics.hitHeight)
                                .buttonStyle(.plain)
                                .accessibilityLabel(family.title)
                                .accessibilityAddTraits(HabitColorFamily.family(for: viewModel.selectedColorHex) == family ? .isSelected : [])
                            }
                        }
                    }
                }
        }
    }

    var validationText: String? {
        if let error = viewModel.errorMessage {
            return error
        }
        if viewModel.habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Add a name.")
        }
        if viewModel.selectedLifeAreaID == nil {
            return String(localized: "Choose an area.")
        }
        return viewModel.reminderWindowValidationError
    }

    private var appearanceSummary: String {
        let icon = viewModel.selectedIconOption?.displayName ?? String(localized: "Icon")
        let color = HabitColorFamily.family(for: viewModel.selectedColorHex).title
        return "\(icon) · \(color)"
    }

    private func toggleAppearance() {
        withAnimation(MotionProfile.localState.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
            showAppearance.toggle()
            if showAppearance {
                selectedDetent = .large
            }
        }
    }

    /// Open-only entry point for the title-field icon so tapping it never collapses an
    /// already-open Appearance panel.
    func openAppearance() {
        guard showAppearance == false else { return }
        withAnimation(MotionProfile.localState.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
            showAppearance = true
            selectedDetent = .large
        }
    }
}

struct HabitInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .lifeboardFont(.headline)
                .foregroundStyle(Color.lifeboard.statusWarning)
            Text(message)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.lifeboard.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.lifeboard.statusWarning.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("addHabit.validationMessage")
    }
}
