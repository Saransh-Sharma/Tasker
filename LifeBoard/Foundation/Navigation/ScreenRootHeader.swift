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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Home's mode rides its date line. Track's greeting carries the day's
    /// position: `DESIGN.md` wants its daypart reading to differ "two glances
    /// an hour apart", and the scenic sky alone cannot say how much of the day
    /// is left — this can, and it has a VoiceOver description the sky lacks.
    private var contextAccessory: AnyView? {
        switch destination {
        case .home:
            AnyView(HomeModeMenu(router: runtime.router))
        case .track:
            AnyView(
                CelestialDaypartIndicator()
                    .frame(width: 72, height: 40)
                    .accessibilityIdentifier("track.header.daypart")
            )
        default:
            nil
        }
    }

    var body: some View {
        let model = RootHeaderModel(
            title: title,
            context: context.isEmpty ? nil : context,
            captureAvailable: headerOwnsCapture,
            secondaryActionTitle: "More",
            // Home's and Track's titles are greetings addressed to the person;
            // the other roots name a destination.
            titleRespondsToTouch: destination == .home || destination == .track
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
                    Haptic.pick.play()
                },
                // No back arrow on the Eva root: it is a tab, and the dock
                // is how every root is left. A "Back to Home" there implied
                // Eva was pushed on top of Home.
                leadingAccessory: nil,
                contextAccessory: contextAccessory,
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
                                Haptic.pick.play()
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
                                if destination == .plan {
                                    // Starting a session was reachable only from
                                    // a task or a block inside the day.
                                    Button("Focus session", systemImage: "timer") {
                                        runtime.router.push(.focusSession(nil), in: .plan)
                                    }
                                    .accessibilityIdentifier("foundation.plan.focusSession")
                                    Divider()
                                }
                                if destination == .eva {
                                    // The chats list (search, export, applied
                                    // changes) hung off the legacy chat host's
                                    // nav bar and had no entry on this root.
                                    Button("Chats", systemImage: "text.below.folder") {
                                        NotificationCenter.default.post(name: .toggleChatHistory, object: nil)
                                    }
                                    .accessibilityIdentifier("foundation.eva.chats")
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
                    // The control sits where the celestial body does. On clear
                    // glass a secondary glyph read grey-on-sun (dark) and
                    // grey-on-moon (night); a surface backing under the glass
                    // keeps a known ground whatever drifts behind it.
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .background(Color(SemanticColorTokens.foundationSurfaceSolid).opacity(0.72), in: Circle())
                    .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                    .accessibilityLabel("More")
                    .accessibilityIdentifier("foundation.more.\(destination.rawValue)")
                )
            )

            if captureState.isExpanded, headerOwnsCapture {
                // Five columns truncate every title to one letter at
                // accessibility sizes; the tray becomes a list of rows there.
                let usesAccessibilityLayout = dynamicTypeSize.isAccessibilitySize
                let trayLayout = usesAccessibilityLayout
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 8))
                trayLayout {
                    ForEach(primaryCaptureKinds, id: \.self) { kind in
                        Button {
                            onCommitCapture(kind)
                        } label: {
                            if usesAccessibilityLayout {
                                HStack(spacing: 12) {
                                    Image(systemName: kind.systemImage)
                                        .lifeboardFont(.headline)
                                    Text(trayTitle(kind))
                                        .font(.body.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: kind.systemImage)
                                        .lifeboardFont(.headline)
                                    Text(trayTitle(kind))
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .accessibilityLabel("Capture \(trayTitle(kind))")
                    }
                }
                .padding(8)
                .frame(maxWidth: 430)
                .lifeBoardGlassSurface(cornerRadius: Radius.card, interactive: true)
                .lifeBoardGlassIdentity(.captureTray)
                .background {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Color(SemanticColorTokens.foundationCanvasSoft).opacity(0.44))
                        .lifeboardContextLens(trigger: captureRippleTrigger)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                .accessibilityIdentifier("foundation.capture.palette")
            }
        }
        .zIndex(20)
    }
}

/// Home's mode, on the date line: "Wednesday, September 16 · Smart ⌄".
///
/// Smart, Work, Personal, and Low Energy change what Home includes, so the
/// choice belongs where the day is named, not two levels down a display panel
/// or in a second date row repeated beneath the header.
private struct HomeModeMenu: View {
    let router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Menu {
            Picker("Home mode", selection: Binding(
                get: { router.dashboardMode },
                set: { mode in
                    Haptic.pick.play()
                    // Home reflows rather than snaps into the new mode.
                    withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                        router.dashboardMode = mode
                    }
                }
            )) {
                ForEach(DashboardMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("·").accessibilityHidden(true)
                Text(router.dashboardMode.title)
                Image(systemName: "chevron.down")
                    .lifeboardFont(.caption2)
                    .accessibilityHidden(true)
            }
            .lifeboardFont(.buttonSmall)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Home mode, \(router.dashboardMode.title)")
        .accessibilityIdentifier("home.mode")
    }
}
