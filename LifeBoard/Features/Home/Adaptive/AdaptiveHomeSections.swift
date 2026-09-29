import SwiftUI
import LifeBoardDomain

struct HomeSectionHeading: View {
    let title: String
    var state: String?
    let palette: DaypartPalette

    init(
        _ title: String,
        state: String? = nil,
        palette: DaypartPalette
    ) {
        self.title = title
        self.state = state
        self.palette = palette
    }

    // Headings are drawn straight on the scene, so whichever one lands on the
    // night sky takes the fixed inverse ink. Only "Now" used to be flagged,
    // and in light appearance "Start today" rendered cocoa on the night sky at
    // 1.9:1; a forced flag also turned "Now" light when it sat lower, on the
    // paper band, at 2.4:1.
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(Typography.sectionTitle())
                .nightSkyAwareForeground(palette.color(for: .foreground))
            if let state {
                Text(state)
                    .font(.footnote.weight(.medium))
                    .nightSkyAwareForeground(
                        palette.color(for: .foregroundSecondary),
                        inverse: Color(SemanticColorTokens.foundationOnScenicDarkSecondary)
                    )
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The card-building closures a placement section needs from Home. Captured
/// once per `body` so the sections stay free of Home's own state.
struct HomeDashboardCardBuilders {
    let resolvedKind: (DashboardWidgetPlacementValue) -> DashboardWidgetKind
    let effectivePreset: (WidgetSizePreset) -> WidgetSizePreset
    let layoutRevision: (DashboardWidgetPlacementValue, DashboardWidgetKind, WidgetSizePreset) -> DashboardLayoutRevision
    let scrollEntranceIntensity: (DashboardWidgetPlacementValue) -> CGFloat
    let makeWidget: (DashboardWidgetPlacementValue, DashboardWidgetKind, WidgetSizePreset) -> HomeDashboardWidget
}

/// Home's hero region: the Focus Now card or the top context card, plus the
/// receipt for a suppressed suggestion. Its identifier stays on the region.
struct AdaptiveHomeNowSection: View {
    let store: AdaptiveHomeStore
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette
    let showsHeading: Bool
    let state: String?
    @Binding var contextReasonCandidate: HomeContextCandidate?
    @Binding var contextSuppressionReceipt: ActionReceiptPresentation?
    @Binding var suppressedContext: HomeContextCandidate?
    let onPinAfterAction: (HomeContextCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeading {
                HomeSectionHeading("Now", state: state, palette: palette)
            }
            if store.contextSelection.candidates.isEmpty {
                HomeFocusNowWidget(
                    preset: .wide,
                    lifeOSStore: lifeOSStore,
                    projectionAdapter: projectionAdapter,
                    router: router,
                    captureRouter: captureRouter,
                    palette: palette
                )
                .lifeBoardFloatingClayCard(palette: palette)
            } else if let candidate = store.contextSelection.candidates.first {
                HomeContextCard(
                    candidate: candidate,
                    store: store,
                    router: router,
                    palette: palette,
                    accessibilityIdentifier: "home.hero",
                    contextReasonCandidate: $contextReasonCandidate,
                    onPinAfterAction: onPinAfterAction,
                    onSuppressed: { candidate, message in
                        suppressedContext = candidate
                        contextSuppressionReceipt = ActionReceiptPresentation(message: message)
                    }
                )
            }

            // Three of the card's menu items remove a suggestion, and one of
            // them is permanent. `DESIGN.md`: end consequential work with a
            // receipt and Undo where reversal is supported.
            if let receipt = contextSuppressionReceipt {
                ReceiptBar(
                    receipt,
                    undo: {
                        if let candidate = suppressedContext {
                            store.restoreContextSuggestion(candidate)
                        }
                        contextSuppressionReceipt = nil
                        suppressedContext = nil
                    },
                    onDismiss: {
                        contextSuppressionReceipt = nil
                        suppressedContext = nil
                    }
                )
                .accessibilityIdentifier("home.context.suppressionReceipt")
                .lifeBoardMotion(.contentInsertion, value: receipt.id)
            }
        }
        // The whole explainable "Now" region is the canonical Home hero.
        // Its contents can legitimately swap from Focus to a context card as
        // providers hydrate, so the stable identity belongs on the region.
        .accessibilityIdentifier("home.hero")
    }
}

/// Home's spine: what stage the day is in, and the one thing it asks for.
///
/// App-owned and never pinnable — a person cannot reorder or remove the
/// loop, because the loop is what the app *is*. Deliberately outside
/// `HomeSectionBudget`: Low Energy changes which **stages** appear, not
/// whether the spine does.
struct AdaptiveHomeLoopSpine: View {
    let stage: DayLoopStage
    let nowState: String?
    let dayLoopSummary: DayLoopSummary?
    let now: AdaptiveHomeNowSection
    let ritual: HomeDayRitualRow
    let repair: HomeSpineRepairBody

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(HomeSectionCopy.spineTitle(for: stage))
                    .font(Typography.sectionTitle())
                    .nightSkyAwareForeground(Color(SemanticColorTokens.inkPrimary))
                // The count belongs to whichever heading survives. `.act` used
                // to stack the spine's title above `nowSection`'s own, so the
                // screen read "Now" twice and only the lower one carried the
                // number. One row now, and it keeps the number.
                // `.act` is the only stage whose body would otherwise have
                // titled itself: it is `nowSection`, whose heading is
                // suppressed so the spine owns the single row.
                if stage == .act, let state = nowState {
                    Text(state)
                        .font(.footnote.weight(.medium))
                        // On the scene, not a card: grey secondary ink fell
                        // below 4.5:1 on the morning sky, so primary ink here.
                        .nightSkyAwareForeground(
                            Color(SemanticColorTokens.inkPrimary),
                            inverse: Color(SemanticColorTokens.foundationOnScenicDarkSecondary)
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let rhythm = HomeSectionCopy.dayLoopRhythmText(dayLoopSummary) {
                    Text(rhythm)
                        .font(.caption)
                        .nightSkyAwareForeground(
                            Color(SemanticColorTokens.inkPrimary),
                            inverse: Color(SemanticColorTokens.foundationOnScenicDarkSecondary)
                        )
                        // Two lines, never truncation: this once shortened to
                        // "1 of 14 days · 1 day…", hiding one of the two honest
                        // facts. Both numbers carry equal weight
                        // because the anti-guilt mechanism here is arithmetic,
                        // not copy.
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        // No kinetic text here: this line is evidence, and the
                        // kinetic greeting belongs to greetings addressed to
                        // the person, never to numbers they are meant to read.
                }
            }
            .accessibilityElement(children: .combine)

            switch stage {
            case .commit, .close:
                // The ritual is the stage body, not a row buried below one.
                ritual
            case .act:
                now
            case .repair:
                repair
            case .rest:
                HomeSpineRestBody()
            }
        }
        .lifeBoardMotion(.cardReflow, value: stage)
        // A container, not an element: without this the stage identifier is
        // stamped onto every child and hides the body's own
        // `home.loopSpine.repair.body`, so the repair flow is unreachable by
        // identifier even while it is plainly on screen.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.loopSpine.\(stage.rawValue)")
    }
}

/// One budgeted dashboard section ("Today", "Keep steady", "Close the loop").
struct AdaptiveHomePlacementSection: View {
    let title: String
    let placements: [DashboardWidgetPlacementValue]
    let renderPlan: HomeDashboardRenderPlan
    let daypart: ResolvedDaypart
    let palette: DaypartPalette
    let ambientPalette: DaypartPalette
    var showsHeading: Bool = true
    let store: AdaptiveHomeStore
    let builders: HomeDashboardCardBuilders
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if placements.isEmpty == false {
            if showsHeading {
                HomeSectionHeading(title, palette: ambientPalette)
            }
            DashboardFlowLayout(
                isRegular: horizontalSizeClass == .regular,
                usesSingleColumn: dynamicTypeSize.isAccessibilitySize
            ) {
                ForEach(placements) { placement in
                    let kind = renderPlan.resolvedKinds[placement.id]
                        ?? builders.resolvedKind(placement)
                    let preset = renderPlan.effectivePresets[placement.id]
                        ?? builders.effectivePreset(placement.semanticSize)
                    builders.makeWidget(placement, kind, preset)
                        .dashboardPreset(preset)
                            .layoutValue(key: DashboardLayoutRevisionKey.self, value: builders.layoutRevision(placement, kind, preset))
                        // A container, so "Pinned by you" describes the card. On
                        // a plain view SwiftUI stamps the value onto every
                        // control inside: the task checkbox read "Pinned by you"
                        // to VoiceOver instead of "Not complete".
                        .accessibilityElement(children: .contain)
                        .accessibilityValue(placement.ownership.accessibilityDescription)
                        .lifeBoardScrollEntrance(
                            intensity: builders.scrollEntranceIntensity(placement)
                        )
                        .modifier(HomeCardDissolveModifier(
                            isDissolving: store.dissolvingPlacementID == placement.id,
                            tint: palette.color(for: .celestialPrimary),
                            onFinish: { store.finishDissolve(id: placement.id) }
                        ))
                }
            }
        }
    }
}

/// The person's own dashboard: the pinned widgets and the customization entry.
struct AdaptiveHomeUserSpaceSection: View {
    let title: String
    let placements: [DashboardWidgetPlacementValue]
    let renderPlan: HomeDashboardRenderPlan
    let daypart: ResolvedDaypart
    let palette: DaypartPalette
    let ambientPalette: DaypartPalette
    let store: AdaptiveHomeStore
    let builders: HomeDashboardCardBuilders
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Rendered even with nothing in it. This section used to appear only once
        // `supportingPlacements` was non-empty or customization was already
        // running, which made customization unreachable: the only control that
        // starts it lives here, and the only way to get a placement is to start it.
        // A fresh Home therefore had no route into "Add a widget" at all.
        Group {
            HStack(alignment: .center, spacing: 8) {
                // Named "Your dashboard" under the spine: it stops being the
                // leftover bucket below the app's own sections and becomes the
                // one region that is explicitly the person's. The spine leads;
                // this is theirs, and it keeps every widget it had.
                HomeSectionHeading(title, palette: ambientPalette)
                if store.isCustomizing == false {
                    // Layout undo was implemented in the store but its only
                    // button lived in the never-called adaptive header, so a
                    // rearrangement could not be taken back.
                    if store.lastLayoutTransaction != nil {
                        Button("Undo") {
                            Task { await store.undoLastLayoutTransaction() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .fixedSize()
                        .accessibilityHint("Restores the previous Home arrangement")
                        .accessibilityIdentifier("home.layoutUndo")
                    }
                    if V2FeatureFlags.dashboardCustomizationV2Enabled {
                        Button {
                            store.beginCustomization()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // `homeSectionHeading` ends in a greedy `Spacer`, which
                        // compressed this control to 17 x 14 points — well under the
                        // 44-point minimum, and small enough that the hit test
                        // missed it entirely.
                        .fixedSize()
                        .accessibilityLabel("Customize Home")
                        .accessibilityIdentifier("home.customize")
                    }
                }
            }

            if placements.isEmpty, store.isCustomizing == false {
                // Empty is a success state here: one short line, and the
                // customize control beside the heading fills it.
                Text("No cards yet")
                    .font(.subheadline)
                    .foregroundStyle(ambientPalette.color(for: .foregroundSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("home.userSpace.empty")
            } else {
                DashboardFlowLayout(
                    isRegular: horizontalSizeClass == .regular,
                    usesSingleColumn: dynamicTypeSize.isAccessibilitySize
                ) {
                    ForEach(placements) { placement in
                        let kind = renderPlan.resolvedKinds[placement.id]
                            ?? builders.resolvedKind(placement)
                        let preset = renderPlan.effectivePresets[placement.id]
                            ?? builders.effectivePreset(placement.semanticSize)
                        builders.makeWidget(placement, kind, preset)
                            .dashboardPreset(preset)
                            .layoutValue(key: DashboardLayoutRevisionKey.self, value: builders.layoutRevision(placement, kind, preset))
                            // See above: a container keeps the value off the card's controls.
                            .accessibilityElement(children: .contain)
                            .accessibilityValue(placement.ownership.accessibilityDescription)
                            .lifeBoardScrollEntrance(
                                intensity: builders.scrollEntranceIntensity(placement)
                            )
                    }
                }
            }
        }
    }
}
