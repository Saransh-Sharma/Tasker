//
//  NeedsReplanTrayView.swift
//  LifeBoard
//

import SwiftUI

struct NeedsReplanTrayView: View {
    let title: String
    let subtitle: String
    let callToAction: String
    let accessibilityHint: String
    let accessibilityIdentifier: String
    let isProminent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.lifeboard.accentWash.opacity(0.72), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text(subtitle)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(callToAction)
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.lifeboard.surfacePrimary.opacity(0.82), in: Capsule())
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.lifeboard.accentWash.opacity(isProminent ? 0.34 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.lifeboard.accentPrimary.opacity(isProminent ? 0.12 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
