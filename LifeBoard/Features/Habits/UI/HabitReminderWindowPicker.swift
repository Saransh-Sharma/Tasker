import SwiftUI
import UIKit

struct HabitReminderWindowPicker: View {
    let isEnabled: Bool
    let startDate: Binding<Date>
    let endDate: Binding<Date>
    let onEnable: () -> Void
    let onClear: () -> Void
    var accessibilityIdentifierPrefix: String

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text("Reminder (optional)")
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                }
                Spacer(minLength: 0)
                if isEnabled {
                    Button("Clear", systemImage: "xmark.circle", action: onClear)
                        .font(ClayTypography.meta)
                        .foregroundStyle(ClayColorTokens.textTertiary)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).clear")
                }
            }

            if isEnabled {
                ViewThatFits(in: .horizontal) {
                    pickerRow
                    pickerColumn
                }
            } else {
                Button(action: onEnable) {
                    HStack(spacing: spacing.s8) {
                        Image(systemName: "bell.badge")
                        Text("Add reminder")
                        Spacer(minLength: 0)
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.lifeboard.accentPrimary)
                    }
                    .font(ClayTypography.meta)
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .padding(.horizontal, spacing.s12)
                    .frame(minHeight: 44)
                    .background(Color.lifeboard.surfaceSecondary, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.lifeboard.strokeHairline.opacity(0.7), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(accessibilityIdentifierPrefix).add")
            }
        }
        .accessibilityIdentifier(accessibilityIdentifierPrefix)
    }

    private var pickerRow: some View {
        HStack(spacing: spacing.s8) {
            timePicker(title: "Start", selection: startDate, accessibilityID: "\(accessibilityIdentifierPrefix).start")
            timePicker(title: "End", selection: endDate, accessibilityID: "\(accessibilityIdentifierPrefix).end")
        }
    }

    private var pickerColumn: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            timePicker(title: "Start", selection: startDate, accessibilityID: "\(accessibilityIdentifierPrefix).start")
            timePicker(title: "End", selection: endDate, accessibilityID: "\(accessibilityIdentifierPrefix).end")
        }
    }

    private func timePicker(title: String, selection: Binding<Date>, accessibilityID: String) -> some View {
        DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(.horizontal, spacing.s12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textTertiary)
                    .padding(.horizontal, spacing.s8)
                    .background(Color.lifeboard.surfaceSecondary)
                    .offset(x: spacing.s8, y: -7)
            }
            .accessibilityLabel("Reminder \(title.lowercased()) time")
            .accessibilityIdentifier(accessibilityID)
    }
}
