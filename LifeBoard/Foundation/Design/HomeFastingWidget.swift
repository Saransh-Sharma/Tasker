import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

// The Home card for an active fast.
//
// Fasting is the one surface with three separate presentations — this card, the
// Track module, and its own destination. Splitting this out of the Home gallery
// makes that spread visible in the file list, and keeps the gallery under the
// file-size ratchet.

struct HomeFastingWidget: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let palette: DaypartPalette
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 14) {
                    HomeWidgetTitle("Active fast", symbol: "timer", palette: palette)
                        .accessibilityIdentifier("home.widget.fasting")
                    if let fast = lifeOSStore.activeFast {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let elapsed = fast.elapsed(at: context.date)
                            let progress = fast.targetDuration.map { $0 > 0 ? min(1, elapsed / $0) : 0.25 } ?? 0.25
                            HStack(spacing: 18) {
                                ZStack {
                                    Circle()
                                        .stroke(palette.color(for: .canvasSecondary), lineWidth: 8)
                                    Circle()
                                        .trim(from: 0, to: max(0.025, progress))
                                        .stroke(
                                            palette.color(for: .celestialCore),
                                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .lifeboardFastingEmberRing(
                                            progress: progress,
                                            tint: palette.color(for: .celestialCore)
                                        )
                                }
                                .frame(width: 86, height: 86)
                                .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(HomeSectionCopy.duration(elapsed))
                                        .lifeboardFont(.metric)
                                        .monospacedDigit()
                                    Text(fast.targetDuration.map {
                                        elapsed >= $0
                                            ? "Planned duration reached"
                                            : "\(HomeSectionCopy.duration($0 - elapsed)) until your planned finish"
                                    } ?? "End whenever it feels right")
                                        .font(.caption)
                                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Active fast")
                            .accessibilityValue("\(HomeSectionCopy.duration(elapsed)) elapsed")
                        }
                    } else {
                        HomeEmptyStateRow("No fast is active", symbol: "checkmark.circle", palette: palette)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if lifeOSStore.activeFast != nil {
                HStack(spacing: 10) {
                    Button("End fast") {
                        Task { await lifeOSStore.endActiveFast() }
                    }
                    .buttonStyle(PrimaryActionStyle(fill: palette.color(for: .foreground)))
                    Button("View details", action: onOpen)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                Button("Start a fast", action: onOpen)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette, cornerRadius: Radius.hero)
    }
}
