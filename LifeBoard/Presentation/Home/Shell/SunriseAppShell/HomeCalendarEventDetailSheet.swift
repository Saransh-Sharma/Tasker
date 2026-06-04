//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct HomeCalendarEventDetailSheet: View {
    let selection: HomeCalendarEventDetailSelection
    let onDismiss: () -> Void
    let onHideFromTimeline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Label(String(localized: "Close"), systemImage: "xmark")
                        .labelStyle(.titleAndIcon)
                        .font(.lifeboard(.body).weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.lifeboard.textPrimary)
                .background(Color.lifeboard.surfaceSecondary.opacity(0.82), in: Capsule())
                .accessibilityIdentifier("schedule.detail.close")

                Spacer(minLength: 12)

                if selection.allowsTimelineHide {
                    Button(action: onHideFromTimeline) {
                        Label(String(localized: "Hide"), systemImage: "eye.slash")
                            .labelStyle(.titleAndIcon)
                            .font(.lifeboard(.body).weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lifeboard.statusDanger)
                    .background(Color.lifeboard.statusDanger.opacity(0.12), in: Capsule())
                    .accessibilityLabel(String(localized: "Hide from Timeline"))
                    .accessibilityHint(String(localized: "Hides this event from the Home timeline for this day."))
                    .accessibilityIdentifier("schedule.detail.hideFromTimeline")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color.lifeboard(.bgElevated))

            Divider()

            EventKitEventDetailView(
                eventID: selection.eventID,
                onDismiss: onDismiss,
                showsCloseButton: false,
                onHideFromTimeline: nil
            )
        }
        .background(Color.lifeboard(.bgElevated))
    }
}
