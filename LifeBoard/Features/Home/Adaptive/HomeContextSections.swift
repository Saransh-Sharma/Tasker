import SwiftUI
import LifeBoardDomain

struct HomeNeedsAttentionSection: View {
    let store: AdaptiveHomeStore
    let router: AppRouter
    let palette: DaypartPalette
    let onPinAfterAction: (HomeContextCandidate) -> Void

    var body: some View {
        let candidates = Array(store.contextSelection.candidates.dropFirst().prefix(3))
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeading(
                "Suggestions",
                state: "\(candidates.count)",
                palette: palette
            )
            ForEach(candidates) { candidate in
                Button {
                    onPinAfterAction(candidate)
                    // Open the thing the row names, the same way the lead
                    // context card does; only a candidate with no typed route
                    // falls back to its root.
                    if let route = candidate.route {
                        router.navigate(route, in: candidate.destination)
                    } else {
                        router.select(candidate.destination)
                    }
                    Haptic.pick.play()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: HomeSectionCopy.symbol(for: candidate.widgetKind, store: store))
                            .frame(width: 30, height: 30)
                            .background(palette.color(for: .canvasSecondary), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.title)
                                .font(.subheadline.weight(.semibold))
                            Text(candidate.reason.message)
                                .font(.caption)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .lifeBoardRaisedClayCard(palette: palette)
        .accessibilityIdentifier("home.needsAttention")
    }
}

struct HomeContextCard: View {
    let candidate: HomeContextCandidate
    let store: AdaptiveHomeStore
    let router: AppRouter
    let palette: DaypartPalette
    let accessibilityIdentifier: String
    @Binding var contextReasonCandidate: HomeContextCandidate?
    let onPinAfterAction: (HomeContextCandidate) -> Void
    /// Reports a suppression so the section can show a receipt with Undo. The
    /// card itself disappears the moment the suggestion is suppressed, so it
    /// cannot host its own receipt.
    var onSuppressed: ((HomeContextCandidate, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: HomeSectionCopy.symbol(for: candidate.widgetKind, store: store))
                    .lifeboardFont(.title2)
                    .frame(width: 34, height: 34)
                    .background(palette.color(for: .canvasSecondary), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.title)
                        .lifeboardFont(.headline)
                        .lineLimit(2)
                    Text(candidate.reason.message)
                        .font(.caption)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Why?", systemImage: "info.circle") {
                        contextReasonCandidate = candidate
                    }
                    Button("Keep on Home", systemImage: "pin") {
                        store.pinContext(candidate)
                        Task { await store.saveCustomization() }
                    }
                    Menu("Move to section", systemImage: "rectangle.3.group") {
                        ForEach(
                            [HomeSectionRole.today, .keepSteady, .closeLoop, .userSpace],
                            id: \.self
                        ) { section in
                            Button(section.title) {
                                store.pinContext(candidate, section: section)
                                Task { await store.saveCustomization() }
                            }
                        }
                    }
                    Button("Hide for today", systemImage: "sun.horizon") {
                        store.hideContextForToday(candidate)
                        onSuppressed?(candidate, String(localized: "Hidden for today"))
                    }
                    Button("Suggest less often", systemImage: "arrow.down.right") {
                        store.suggestContextLessOften(candidate)
                        onSuppressed?(candidate, String(localized: "Shown less often"))
                    }
                    Button("Never suggest this", systemImage: "eye.slash", role: .destructive) {
                        store.neverSuggestContext(candidate)
                        onSuppressed?(candidate, String(localized: "Hidden for good"))
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(candidate.title)")
            }

            Button {
                onPinAfterAction(candidate)
                if let route = candidate.route {
                    // `navigate` rather than `select` + `push`: it lets the root
                    // change finish before the typed leaf is appended, so a
                    // just-popped empty path cannot be written over the new
                    // route. Root selection alone never leaves a blank frame now
                    // (`RootRetention`), but the ordering still matters.
                    router.navigate(route, in: candidate.destination)
                } else {
                    router.select(candidate.destination)
                }
                Haptic.pick.play()
            } label: {
                HStack {
                    Text(candidate.actionTitle)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .lifeBoardTransitionSource(
                candidate.route?.spatialTransitionID ?? "route.home.context.\(candidate.id)"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .lifeBoardFloatingClayCard(palette: palette)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(candidate.title)
        .accessibilityHint(candidate.reason.message)
        .accessibilityIdentifier(accessibilityIdentifier)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in store.setContextFrozen(true, reason: "context-touch") }
                .onEnded { _ in store.setContextFrozen(false, reason: "context-touch") }
        )
    }
}

struct HomeContextReasonSheet: View {
    let candidate: HomeContextCandidate
    let store: AdaptiveHomeStore
    let palette: DaypartPalette
    @Binding var contextReasonCandidate: HomeContextCandidate?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                Text("Why it’s here")
                    .lifeboardFont(.metric)
                Spacer()
            }
            Text(candidate.reason.message)
                .font(.body)
            if let signalLabel {
                Label(signalLabel, systemImage: "checkmark.shield")
                    .font(.subheadline)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Spacer()
            Button("Keep on Home") {
                store.pinContext(candidate)
                contextReasonCandidate = nil
                Task { await store.saveCustomization() }
            }
            .buttonStyle(.lifeBoardPrimaryCompact)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Color(SemanticColorTokens.foundationSurfaceSolid))
    }

    /// `reason.signal` is an identifier ("goalTargetDate"); a person sees what
    /// it stands for, or nothing.
    private var signalLabel: String? {
        switch candidate.reason.signal {
        case "goalTargetDate": String(localized: "Based on the goal’s date")
        case "lifeMomentThreshold": String(localized: "Based on the date you set")
        case "routineSchedule": String(localized: "Based on the routine’s schedule")
        default: nil
        }
    }
}
