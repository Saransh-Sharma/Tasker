import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// Capture chips rise in sequence from the composer's leading control so the
/// tray reads as the "+" unfolding rather than a row appearing at once.
/// Total stagger stays inside the control-morph budget.
/// The root header, lifted out of `FoundationShell`.
///
/// It is drawn on every root, so as a computed member it inlined its whole view
/// value into the shell's own frame every time. See the `-Onone` note on
/// `PlanSectionCopy` in LifeBoardPlanViews.swift for why that matters.
struct ScreenRootHeader: View {
    let destination: Destination
    let atmosphereSnapshot: AtmosphereSnapshot
    let runtime: FoundationCoordinator
    let headerOwnsCapture: Bool
    let title: String
    let context: String
    let homeCardKinds: [DashboardWidgetKind]?
    let primaryCaptureKinds: [CaptureKind]
    let trayTitle: (CaptureKind) -> String
    let onCommitCapture: (CaptureKind) -> Void
    @Binding var captureState: CaptureOrbPresentationState
    @Binding var captureRippleTrigger: Int
    @Binding var showsHomeDisplayPanel: Bool
    @Binding var homeCardPlacementRequest: HomeCardPlacementRequest?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let model = RootHeaderModel(
            title: title,
            context: context,
            captureAvailable: headerOwnsCapture,
            secondaryActionTitle: "More",
            // Only Home's title is a greeting addressed to the person; the
            // other roots name a destination.
            titleRespondsToTouch: destination == .home
        )
        VStack(alignment: .trailing, spacing: 8) {
            AppRootHeader(
                model: model,
                captureExpanded: captureState.isExpanded,
                usesInverseInk: AtmosphereDescriptor.usesInverseHeaderInk(
                    for: atmosphereSnapshot.phase
                ),
                onCapture: {
                    withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                        captureState.isExpanded.toggle()
                        captureState.highlightedKind = nil
                        captureRippleTrigger &+= 1
                    }
                    HapticFeedback.light()
                },
                leadingAccessory: destination == .eva
                    ? AnyView(
                        Button {
                            HapticFeedback.light()
                            runtime.router.select(.home)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.lifeboard(.buttonSmall))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            AtmosphereDescriptor.usesInverseHeaderInk(for: atmosphereSnapshot.phase)
                                ? Color(SemanticColorTokens.foundationOnScenicDark)
                                : Color(SemanticColorTokens.inkPrimary)
                        )
                        .accessibilityLabel("Back to Home")
                        .accessibilityHint("Leaves Eva and returns to the Home screen")
                        .accessibilityIdentifier("eva.chat.back")
                    )
                    : nil,
                secondaryActions: AnyView(
                    // Home's controls outgrew a menu. Atmosphere is a sequence
                    // — a day — and a menu can only list it; SwiftUI menus
                    // render buttons, pickers and toggles, never a slider. So
                    // Home opens a panel, and the other roots keep the menu,
                    // whose two rows do not justify a sheet.
                    Group {
                        if destination == .home {
                            Button {
                                showsHomeDisplayPanel = true
                                HapticFeedback.light()
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 44, height: 44)
                            }
                        } else {
                            Menu {
                                // Add-to-Home was fully built — placement sheet,
                                // receipt and Undo — and nothing ever set the
                                // request, so the whole personalisation loop was
                                // unreachable.
                                if let kinds = homeCardKinds, kinds.isEmpty == false {
                                    Menu("Add to Home", systemImage: "plus.rectangle.on.rectangle") {
                                        ForEach(kinds, id: \.self) { kind in
                                            if let descriptor = DefaultDashboardWidgetRegistry.shared.descriptor(for: kind) {
                                                Button(descriptor.title) {
                                                    homeCardPlacementRequest = .init(kind: kind, destination: destination)
                                                }
                                            }
                                        }
                                    }
                                    .accessibilityIdentifier("home.addToHome.\(destination.rawValue)")
                                    Divider()
                                }
                                Button("Settings", systemImage: "gearshape") {
                                    runtime.router.push(.settings, in: destination)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                    .accessibilityLabel("More")
                    .accessibilityIdentifier("foundation.more.\(destination.rawValue)")
                )
            )

            if captureState.isExpanded, headerOwnsCapture {
                HStack(spacing: 6) {
                    ForEach(primaryCaptureKinds, id: \.self) { kind in
                        Button {
                            onCommitCapture(kind)
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: kind.systemImage)
                                    .lifeboardFont(.headline)
                                Text(trayTitle(kind))
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .accessibilityLabel("Capture \(trayTitle(kind))")
                    }
                }
                .padding(8)
                .frame(maxWidth: 430)
                .lifeBoardGlassSurface(cornerRadius: 22, interactive: true)
                .lifeBoardGlassIdentity(.captureTray)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(SemanticColorTokens.foundationCanvasSoft).opacity(0.44))
                        .lifeboardContextLens(trigger: captureRippleTrigger)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                .accessibilityIdentifier("foundation.capture.palette")
            }
        }
        .zIndex(20)
    }
}
