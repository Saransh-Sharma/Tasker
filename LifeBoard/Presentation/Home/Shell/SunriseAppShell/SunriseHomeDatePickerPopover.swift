//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct SunriseHomeDatePickerPopover: View {
    @Binding var draftDate: Date
    let selectedDate: Date
    let onToday: () -> Void
    let onCancel: () -> Void
    let onApply: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            HStack(spacing: LBSpacingTokens.md) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .frame(width: 38, height: 38)
                    .background(LBColorTokens.violetSoft.opacity(0.86), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose day")
                        .font(LBTypographyTokens.cardTitle)
                        .foregroundStyle(LBColorTokens.navy)
                    Text(Self.relativeDateText(for: draftDate, selectedDate: selectedDate))
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.navyMuted)
                }

                Spacer(minLength: LBSpacingTokens.sm)

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .frame(width: 32, height: 32)
                        .background(LBColorTokens.glassStrong, in: Circle())
                        .overlay { Circle().stroke(LBColorTokens.glassBorder, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close date picker")
            }

            DatePicker(
                "Select date",
                selection: $draftDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(LBColorTokens.violetDeep)
            .accessibilityIdentifier("home.datePicker.calendar")

            HStack(spacing: LBSpacingTokens.sm) {
                dateActionButton(
                    title: "Today",
                    systemImage: "sun.max",
                    isPrimary: false,
                    action: onToday
                )
                dateActionButton(
                    title: "Cancel",
                    systemImage: "xmark",
                    isPrimary: false,
                    action: onCancel
                )
                dateActionButton(
                    title: "Apply",
                    systemImage: "checkmark",
                    isPrimary: true,
                    action: onApply
                )
            }
        }
        .padding(LBSpacingTokens.lg)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 420 : 366)
        .background { popoverSurface }
        .shadow(color: LBColorTokens.navy.opacity(0.16), radius: 28, x: 0, y: 16)
        .accessibilityIdentifier("home.datePicker")
    }

    var popoverSurface: some View {
        let shape = RoundedRectangle(cornerRadius: LBRadiusTokens.largeCard, style: .continuous)
        return shape
            .fill(.ultraThinMaterial)
            .overlay { shape.fill(LBColorTokens.glassStrong.opacity(0.88)) }
            .overlay { shape.stroke(LBColorTokens.glassBorder, lineWidth: 1) }
    }

    func dateActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(LBTypographyTokens.meta.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .foregroundStyle(isPrimary ? Color.lifeboard(.accentOnPrimary) : LBColorTokens.navy)
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, LBSpacingTokens.sm)
                .background {
                    Capsule()
                        .fill(isPrimary ? LBColorTokens.violetDeep : LBColorTokens.glass)
                        .overlay {
                            Capsule()
                                .stroke(isPrimary ? LBColorTokens.violet.opacity(0.35) : LBColorTokens.glassBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    static func relativeDateText(for draftDate: Date, selectedDate: Date) -> String {
        let calendar = Calendar.current
        let selectedPrefix = calendar.isDate(draftDate, inSameDayAs: selectedDate) ? "Selected" : "Preview"
        if calendar.isDateInToday(draftDate) {
            return "\(selectedPrefix) today"
        }
        let formatted = draftDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return "\(selectedPrefix) \(formatted)"
    }
}
