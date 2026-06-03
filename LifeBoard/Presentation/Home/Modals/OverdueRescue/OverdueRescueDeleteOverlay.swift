//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueDeleteOverlay: View {
    let taskTitle: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(OverdueRescuePalette.deleteForeground)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(OverdueRescuePalette.deleteFill))

                    Text("Delete this task?")
                        .font(.lifeboard(.title3))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This removes it from your board. You can undo right after deleting.")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Delete task")
                            .font(.lifeboard(.button))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.lifeboard.statusDanger)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .accessibilityIdentifier("home.rescue.delete.confirm")

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.lifeboard(.button))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.lifeboard.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .accessibilityIdentifier("home.rescue.delete.cancel")
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.lifeboard.bgCanvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 30, y: 16)
            )
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(deleteAccessibilityLabel)
        .accessibilityIdentifier("home.rescue.delete.overlay")
    }

    var deleteAccessibilityLabel: String {
        if let taskTitle, taskTitle.isEmpty == false {
            return "Delete \(taskTitle)? This removes it from your board. You can undo right after deleting."
        }
        return "Delete this task? This removes it from your board. You can undo right after deleting."
    }
}
