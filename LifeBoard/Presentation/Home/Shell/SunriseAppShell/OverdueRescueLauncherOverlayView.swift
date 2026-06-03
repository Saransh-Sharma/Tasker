//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct OverdueRescueLauncherOverlayView: View {
    let title: String
    let message: String
    let showsProgress: Bool
    let primaryTitle: String?
    let secondaryTitle: String?
    let onPrimary: (() -> Void)?
    let onSecondary: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.94, blue: 0.82),
                                    Color(red: 0.92, green: 0.88, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)

                    Image(systemName: showsProgress ? "lifepreserver" : "exclamationmark.triangle")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.lifeboard(.title3).weight(.bold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsProgress {
                    ProgressView()
                        .tint(Color.lifeboard.accentPrimary)
                        .accessibilityLabel("Preparing rescue")
                } else if primaryTitle != nil || secondaryTitle != nil {
                    HStack(spacing: 12) {
                        if let secondaryTitle, let onSecondary {
                            Button(action: onSecondary) {
                                Text(secondaryTitle)
                                    .font(.lifeboard(.callout).weight(.semibold))
                                    .foregroundStyle(Color.lifeboard.accentPrimary)
                                    .frame(minWidth: 96, minHeight: 44)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .stroke(Color.lifeboard.accentPrimary.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if let primaryTitle, let onPrimary {
                            Button(action: onPrimary) {
                                Text(primaryTitle)
                                    .font(.lifeboard(.callout).weight(.semibold))
                                    .foregroundStyle(Color.white)
                                    .frame(minWidth: 112, minHeight: 44)
                                    .padding(.horizontal, 14)
                                    .background(
                                        Capsule()
                                            .fill(Color.lifeboard.accentPrimary)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.985, blue: 0.955).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 18)
            )
            .padding(.horizontal, 28)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
            .accessibilityHint(message)
        }
    }
}
