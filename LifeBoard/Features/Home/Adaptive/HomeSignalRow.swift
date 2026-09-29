import SwiftUI
import LifeBoardDomain

/// What Home shows instead of a row of dashed rings when Health was never shared.
///
/// A `.permissionRequired` ring is correctly modelled — `ringState(for:)` is
/// careful to keep "declined" distinct from "nothing recorded yet" — but three
/// of them side by side is the most prominent band on the first screen of the
/// app, and it reads as a failure rather than as a choice the person made.
private struct HomeSignalConnectHealthTile: View {
    let healthStore: HealthConnectionStore

    @State private var isRequesting = false

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var body: some View {
        Button {
            guard isRequesting == false else { return }
            isRequesting = true
            Task {
                _ = await healthStore.connectReadOnly()
                isRequesting = false
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "heart.text.square")
                    .lifeboardFont(.title2)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .frame(height: 58)
                // The row gives each slot roughly a third of the screen, so this
                // says the one thing it has room to say. The reason lives in the
                // accessibility hint, where it does not cost three wrapped lines
                // and a tile four times the height of the rings beside it.
                Text("Connect\nHealth")
                    .font(.lifeboard(.meta))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .lineLimit(2)
            }
            .frame(maxWidth: layoutClass.isPad ? 140 : .infinity, minHeight: 100)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
        .accessibilityLabel("Connect Health")
        .accessibilityHint("Adds steps and activity from Health")
        .accessibilityIdentifier("home.signal.connectHealth")
    }
}

struct HomeSignalRow: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let healthStore: HealthConnectionStore
    let router: AppRouter
    let captureRouter: CaptureRouter
    let hasTrackFoundationRepository: Bool
    let hasPhaseIIRepository: Bool
    let palette: DaypartPalette
    let reduceMotion: Bool
    @Binding var showsFastEndReceipt: Bool
    /// When the fast that was just started began; drives its receipt.
    @Binding var fastStartReceiptAt: Date?
    @Binding var showsFastingError: Bool
    @Binding var fastingStateChangeTrigger: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var body: some View {
        let slots = presentedSlots
        if dynamicTypeSize.isAccessibilitySize {
            // One column, not two. `DESIGN.md`: at large text sizes use one
            // content column — a two-up grid still halves the width each ring's
            // label has to live in.
            VStack(spacing: 12) {
                ForEach(slots) { slot in ring(slot) }
                if collapsesBlockedHealth { HomeSignalConnectHealthTile(healthStore: healthStore) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.signalRow")
        } else {
            HStack(spacing: 8) {
                ForEach(slots) { slot in ring(slot) }
                if collapsesBlockedHealth { HomeSignalConnectHealthTile(healthStore: healthStore) }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.signalRow")
        }
    }

    /// Health signals whose data was never shared with the app.
    private var blockedHealthSlots: [HomeSignalSlot] {
        signalSlots.filter { $0.id != "fasting" && $0.availability == .permissionRequired }
    }

    /// Two or more dashed rings in a row stop reading as "not shared" and start
    /// reading as "broken". Past one, they collapse into a single affordance
    /// that says what it wants and can actually grant it.
    private var collapsesBlockedHealth: Bool { blockedHealthSlots.count >= 2 }

    private var presentedSlots: [HomeSignalSlot] {
        guard collapsesBlockedHealth else { return signalSlots }
        let blocked = Set(blockedHealthSlots.map(\.id))
        return signalSlots.filter { blocked.contains($0.id) == false }
    }

    @ViewBuilder
    private func ring(_ slot: HomeSignalSlot) -> some View {
        if slot.id == "fasting" {
            HomeFastingSignal(
                lifeOSStore: lifeOSStore,
                router: router,
                hasPhaseIIRepository: hasPhaseIIRepository,
                palette: palette,
                reduceMotion: reduceMotion,
                showsFastEndReceipt: $showsFastEndReceipt,
                fastStartReceiptAt: $fastStartReceiptAt,
                showsFastingError: $showsFastingError,
                fastingStateChangeTrigger: $fastingStateChangeTrigger
            )
        } else {
            Button {
                if slot.id == "hydration" {
                    captureRouter.request(kind: .hydration, source: .shell)
                } else if slot.availability == .permissionRequired {
                    // This used to `router.select(.track)`, which dropped a
                    // person onto another root with no explanation and no way
                    // to grant the thing they had just tapped. The ring is the
                    // request, so it asks.
                    Task { _ = await healthStore.connectReadOnly() }
                } else {
                    router.select(.track)
                }
            } label: {
                MetricRing(
                    label: slot.title,
                    state: HomeSectionCopy.ringState(for: slot),
                    diameter: 58,
                    palette: palette,
                    liquidTint: HomeSectionCopy.liquidTint(for: slot, palette: palette)
                )
                // Fixed slots at pad widths: three 58-point rings each alone in
                // a third of a 1000-point row read as scattered, not a group.
                .frame(maxWidth: layoutClass.isPad ? 140 : .infinity, minHeight: 100)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel("\(slot.title), \(slot.valueText ?? HomeSectionCopy.accessibilityAvailability(slot.availability))")
            .accessibilityHint(slot.id == "hydration" && healthStore.aggregates[.water] == nil
                ? lifeOSStore.hydrationRefreshError ?? "" : "")
            .accessibilityIdentifier("home.signal.\(slot.id)")
        }
    }

    private var signalSlots: [HomeSignalSlot] {
        let hydrationAmount = healthStore.aggregates[.water]?.value
            ?? lifeOSStore.trackSnapshot?.hydrationAmountMilliliters
        let hydrationTarget = lifeOSStore.trackSnapshot?.hydrationTargetMilliliters
        let hydrationProgress = hydrationAmount.flatMap { amount in
            hydrationTarget.flatMap { $0 > 0 ? min(1, amount / $0) : nil }
        }
        let hydrationAvailability: HomeSignalState = if lifeOSStore.isLoading && hydrationAmount == nil && lifeOSStore.trackSnapshot == nil {
            .loading
        } else if hasTrackFoundationRepository == false {
            .unavailable
        } else if lifeOSStore.hydrationRefreshError != nil && healthStore.aggregates[.water] == nil {
            hydrationAmount == nil ? .unavailable : .stale
        } else if hydrationAmount == nil {
            .setupRequired
        } else {
            .available
        }
        let steps = healthStore.aggregates[.steps]
        let activeEnergy = healthStore.aggregates[.activeEnergy]
        let candidates = [
            HomeSignalSlot(
                id: "hydration", title: String(localized: "Water"),
                valueText: hydrationAmount.map { amount in String(localized: "\(Int(amount)) ml") }, progress: hydrationProgress,
                systemImage: "drop.fill",
                availability: hydrationAvailability
            ),
            HomeSignalSlot(
                id: "steps",
                title: String(localized: "Steps"),
                valueText: steps.map { $0.value.formatted(.number.precision(.fractionLength(0))) },
                // No ring without a target the person set. A hard-coded 10,000
                // draws a progress arc against a goal nobody chose, which is
                // exactly the "health quality implied by colour and trend"
                // `DESIGN.md` forbids. Hydration keeps its ring because its
                // target is a real, user-set value.
                progress: nil,
                systemImage: "figure.walk",
                availability: HomeSectionCopy.homeAvailability(for: .activity, value: steps, healthStore: healthStore)
            ),
            HomeSignalSlot(
                id: "active",
                title: String(localized: "Active"),
                valueText: activeEnergy.map { energy in String(localized: "\(Int(energy.value)) kcal") },
                progress: nil,
                systemImage: "flame.fill",
                availability: HomeSectionCopy.homeAvailability(for: .energy, value: activeEnergy, healthStore: healthStore)
            ),
            HomeSignalSlot(
                id: "fasting",
                title: "Fasting",
                valueText: nil,
                progress: lifeOSStore.activeFast.flatMap { fast in
                    fast.targetDuration.flatMap { $0 > 0 ? min(1, fast.elapsed() / $0) : nil }
                },
                systemImage: "timer",
                availability: hasPhaseIIRepository ? .available : .unavailable
            )
        ]
        // These are explicitly configured Home signals. The relevance budget
        // still controls every other Home module, but silently dropping a
        // configured timer makes its active state unreachable. Preserve all
        // four and use ranking only to order the three Health facts.
        let healthSlots = candidates
            .filter { $0.id != "fasting" }
            .sorted { HomeSectionCopy.signalRank($0) > HomeSectionCopy.signalRank($1) }
        return healthSlots + candidates.filter { $0.id == "fasting" }
    }

}

private struct HomeFastingSignal: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let hasPhaseIIRepository: Bool
    let palette: DaypartPalette
    let reduceMotion: Bool
    @Binding var showsFastEndReceipt: Bool
    @Binding var fastStartReceiptAt: Date?
    @Binding var showsFastingError: Bool
    @Binding var fastingStateChangeTrigger: Int

    var body: some View {
        ActiveVisibleTimeline(every: 1) { context in
            let activeFast = lifeOSStore.activeFast
            let mealAnchor = HomeFastingAnchorPolicy.recentMealAnchor(
                latestMealAt: lifeOSStore.recentMealAt,
                now: context.date
            )
            let openAnchor = mealAnchor ?? lifeOSStore.latestEndedFast?.endedAt
            let elapsed = activeFast?.elapsed(at: context.date)
                ?? openAnchor.map { max(0, context.date.timeIntervalSince($0)) }
                ?? 0
            let progress = activeFast?.targetDuration.flatMap { target in
                target > 0 ? min(1, elapsed / target) : nil
            } ?? 0
            let isAvailable = hasPhaseIIRepository

            Button {
                guard isAvailable else {
                    router.select(.track)
                    return
                }
                // One haptic, after the save: `commitFastStart` / `commitFastEnd`
                // play commit on success and fail otherwise.
                if activeFast == nil {
                    let startDate = HomeFastingAnchorPolicy.recentMealAnchor(
                        latestMealAt: lifeOSStore.recentMealAt,
                        now: HomeReferenceClock.now
                    ) ?? HomeReferenceClock.now
                    Task { await commitFastStart(at: startDate) }
                } else {
                    Task { await commitFastEnd() }
                }
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(palette.color(for: .canvasSecondary).opacity(0.62))
                        Circle()
                            .stroke(
                                palette.color(for: .foregroundSecondary).opacity(activeFast == nil ? 0.48 : 0.20),
                                style: StrokeStyle(lineWidth: activeFast == nil ? 2.5 : 5, dash: activeFast == nil ? [3, 5] : [])
                            )
                        if activeFast != nil {
                            Circle()
                                .trim(from: 0, to: max(0.025, progress))
                                .stroke(
                                    Color(SemanticColorTokens.foundationSunAccent),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .lifeboardFastingEmberRing(
                                    progress: progress,
                                    tint: Color(SemanticColorTokens.foundationSunAccent)
                                )
                        }
                        VStack(spacing: 0) {
                            Text(HomeSectionCopy.compactHours(elapsed))
                                .lifeboardFont(.eyebrow)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .contentTransition(.numericText())
                            Text(activeFast != nil ? "fast" : (mealAnchor == nil ? "open" : "since meal"))
                                .lifeboardFont(.eyebrow)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                    }
                    .frame(width: 58, height: 58)

                    Text("Fasting")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(isAvailable ? (activeFast == nil ? (mealAnchor == nil ? "Start" : "Start from meal") : "End") : "Unavailable")
                        .lifeboardFont(.eyebrow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .foregroundStyle(
                            isAvailable
                                ? Color(SemanticColorTokens.inkPrimary)
                                : palette.color(for: .foregroundSecondary)
                        )
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .contentShape(Rectangle())
                .lifeboardClayPressBloom(
                    center: .center,
                    trigger: fastingStateChangeTrigger,
                    tint: Color(SemanticColorTokens.foundationSunAccent)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeFast == nil ? "Start fasting timer" : "End fasting timer")
            .accessibilityValue(
                activeFast == nil
                    ? String(localized: "Not fasting, \(HomeSectionCopy.spokenHours(elapsed))")
                    : String(localized: "Fasting, \(HomeSectionCopy.spokenHours(elapsed))")
            )
            .accessibilityHint(
                activeFast == nil
                    ? (mealAnchor == nil ? "Starts now" : "Starts from your last meal")
                    : "Ends the fast"
            )
            .accessibilityIdentifier("home.signal.fasting")
        }
    }

    @MainActor
    private func commitFastStart(at date: Date) async {
        if await lifeOSStore.startFast(targetDuration: nil, at: date) {
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                showsFastEndReceipt = false
                fastStartReceiptAt = date
            }
            fastingStateChangeTrigger &+= 1
            Haptic.commit.play()
        } else {
            showsFastingError = true
            Haptic.fail.play()
        }
    }

    @MainActor
    private func commitFastEnd() async {
        if await lifeOSStore.endActiveFast() {
            withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
                fastStartReceiptAt = nil
                showsFastEndReceipt = true
            }
            fastingStateChangeTrigger &+= 1
            Haptic.commit.play()
        } else {
            showsFastingError = true
            Haptic.fail.play()
        }
    }
}

struct HomeFastingEndReceipt: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let palette: DaypartPalette
    let reduceMotion: Bool
    @Binding var showsFastEndReceipt: Bool
    @Binding var showsFastingError: Bool
    @Binding var fastingStateChangeTrigger: Int

    var body: some View {
        // The shared receipt bar: one silhouette for every receipt in the
        // product, copy that stacks at accessibility sizes, and an Undo that
        // does not sit on a timer.
        ReceiptBar(
            ActionReceiptPresentation(
                message: String(localized: "Fast ended")
            ),
            undo: {
                Task {
                    if await lifeOSStore.undoLastFastEnd() {
                        withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
                            showsFastEndReceipt = false
                        }
                        fastingStateChangeTrigger &+= 1
                        Haptic.decline.play()
                    } else {
                        showsFastingError = true
                    }
                }
            },
            onDismiss: {
                withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
                    showsFastEndReceipt = false
                }
            }
        )
        .accessibilityIdentifier("home.fasting.receipt")
    }
}

/// The receipt for a fast started from Home. The fasting store records a
/// cancelled session rather than removing one, so there is no honest Undo
/// here; the receipt opens Fasting, where the start time can be corrected or
/// the fast ended.
struct HomeFastingStartReceipt: View {
    let startedAt: Date
    let router: AppRouter
    let reduceMotion: Bool
    @Binding var fastStartReceiptAt: Date?

    var body: some View {
        ReceiptBar(
            ActionReceiptPresentation(
                message: String(localized: "Fast started"),
                detail: Calendar.current.isDate(startedAt, equalTo: Date(), toGranularity: .minute)
                    ? nil
                    : String(localized: "Started \(startedAt.formatted(date: .omitted, time: .shortened))")
            ),
            destination: .init(title: "Open") { router.navigate(.fasting, in: .track) },
            onDismiss: {
                withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                    fastStartReceiptAt = nil
                }
            }
        )
        .accessibilityIdentifier("home.fasting.startReceipt")
    }
}
