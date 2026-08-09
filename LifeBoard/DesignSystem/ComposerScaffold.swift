import SwiftUI

// MARK: - Composer receipt
//
// Every LifeBoard data-entry surface reports the same thing when it succeeds:
// that something was persisted, and when. Two byte-identical private copies of
// this type existed — `TrackComposerReceipt` in the PhaseIV views and
// `TrackerCommitReceipt` in the PhaseII views — purely because the two host
// files cannot see each other's `private` declarations. Neither carried any
// information the other lacked.

/// What a composer hands back once its work is on disk.
public struct ComposerReceipt: Equatable, Sendable {
    public let operationID: UUID
    public let completedAt: Date

    public init(operationID: UUID = UUID(), completedAt: Date = Date()) {
        self.operationID = operationID
        self.completedAt = completedAt
    }
}

/// The commit lifecycle of a composer, spelled once.
public typealias LifeBoardComposerPhase = AsyncActionPhase<ComposerReceipt>

// MARK: - Scaffold

/// Sheet chrome, canvas, cancel and commit for a LifeBoard data-entry surface.
///
/// This replaces the incantation
/// `NavigationStack { Form { … } .lifeBoardFormSurface() .toolbar { cancel }
/// .safeAreaInset(.bottom) { commitBar } }`, repeated near-verbatim in twenty
/// places across Track, Wellness, Nutrition, Medication and Journal.
///
/// `Form` is **removed here, not restyled.** `Form` owns its row insets, its
/// separator geometry, its control chrome and its grouped background, and
/// `.scrollContentBackground(.hidden)` only paints over the last of those. That
/// is why the "fixed" composers still read as grey iOS forms wearing a warm
/// backdrop: the background was the only part the app ever controlled. A
/// `ScrollView` over clay sections is the only arrangement in which the corner
/// vocabulary, the 4/8/12/16/20 rhythm and the depth scale are actually ours.
///
/// **A note for the next author.** The composer body that uses this must hold
/// nothing but the scaffold and one `struct` per section — never a computed
/// `some View` and never a `@ViewBuilder func`. Both of those inline into the
/// caller's frame, and a composer that builds eight controls' view values in a
/// single frame is exactly the shape that walked off the main thread's guard
/// page at `-Onone` before. The doctrine is stated at length on
/// `TrackFoundationRootView.categoryContent`; this is the same rule one
/// level down.
@MainActor
public struct ComposerScaffold<Content: View, Commit: View>: View {
    private let title: String
    private let subtitle: String?
    private let cancelTitle: String
    private let titleDisplayMode: NavigationBarItem.TitleDisplayMode
    private let detents: Set<PresentationDetent>
    private let isPrivacySensitive: Bool
    private let identifier: String?
    private let isDismissBlocked: Bool
    private let onCancel: (() -> Void)?
    private let content: Content
    private let commit: Commit
    /// Set only by the toolbar-confirm variant below. `nil` means the surface
    /// closes through a commit bar instead.
    fileprivate var confirmation: ComposerConfirmation?

    @Environment(\.dismiss) private var dismiss

    public init(
        title: String,
        subtitle: String? = nil,
        cancelTitle: String = "Cancel",
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
        detents: Set<PresentationDetent> = [.large],
        isPrivacySensitive: Bool = false,
        identifier: String? = nil,
        isDismissBlocked: Bool = false,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder commit: () -> Commit
    ) {
        self.title = title
        self.subtitle = subtitle
        self.cancelTitle = cancelTitle
        self.titleDisplayMode = titleDisplayMode
        self.detents = detents
        self.isPrivacySensitive = isPrivacySensitive
        self.identifier = identifier
        self.isDismissBlocked = isDismissBlocked
        self.onCancel = onCancel
        self.content = content()
        self.commit = commit()
    }

    public var body: some View {
        PresentationScaffold(mode: .editor) {
            NavigationStack {
                // A ZStack base rather than `.background` on the scroll view.
                // As a background the canvas lost to the presentation
                // scaffold's own elevated fill and the composer rendered
                // near-white instead of warm paper.
                ZStack {
                    ComposerCanvas()
                    scroll
                }
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(titleDisplayMode)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(cancelTitle) {
                                onCancel?()
                                dismiss()
                            }
                        }
                        if let confirmation {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(confirmation.title, action: confirmation.action)
                                    .disabled(confirmation.isEnabled == false)
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { commit }
            }
        }
        .presentationDetents(detents)
        .interactiveDismissDisabled(isDismissBlocked)
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let subtitle {
                    Text(subtitle)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 2)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            // Clearance for the commit bar. Without it the last section's
            // footer sits underneath the glass and cannot be read.
            .padding(.bottom, 24)
            .modifier(ComposerPrivacy(isSensitive: isPrivacySensitive))
            // The identifier belongs to the scroll *content*, not to the
            // `NavigationStack`: the hydration flow asserts that
            // `track.hydration.composer` stops existing after commit, and a
            // navigation container can outlive the dismissal animation.
            .modifier(ComposerIdentity(identifier: identifier))
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: Confirm-in-toolbar variant

public extension ComposerScaffold where Commit == EmptyView {
    /// For pushed editors and preference surfaces that confirm through the
    /// navigation bar rather than a commit bar. There is no persistence phase to
    /// report, so there is no commit control to morph.
    init(
        title: String,
        subtitle: String? = nil,
        cancelTitle: String = "Cancel",
        confirmTitle: String,
        isConfirmEnabled: Bool = true,
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
        detents: Set<PresentationDetent> = [.large],
        isPrivacySensitive: Bool = false,
        identifier: String? = nil,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            cancelTitle: cancelTitle,
            titleDisplayMode: titleDisplayMode,
            detents: detents,
            isPrivacySensitive: isPrivacySensitive,
            identifier: identifier,
            onCancel: onCancel,
            content: content,
            commit: { EmptyView() }
        )
        self.confirmation = ComposerConfirmation(
            title: confirmTitle,
            isEnabled: isConfirmEnabled,
            action: onConfirm
        )
    }
}

/// Carried as a value rather than a second generic parameter, so the common
/// commit-bar form does not pay for a confirmation button it never shows.
struct ComposerConfirmation {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
}

// MARK: - Pushed page

/// The same clay entry surface for an editor that was **pushed**, not presented.
///
/// `ComposerScaffold` owns a `NavigationStack` and sheet presentation,
/// which a pushed destination must not do — it would nest a navigation stack
/// inside the one that pushed it and strand the back button. This is the same
/// canvas, scroll geometry and commit inset with the navigation left alone, so
/// the host's title and back affordance keep working.
@MainActor
public struct ComposerPage<Content: View, Commit: View>: View {
    private let subtitle: String?
    private let isPrivacySensitive: Bool
    private let identifier: String?
    private let content: Content
    private let commit: Commit

    public init(
        subtitle: String? = nil,
        isPrivacySensitive: Bool = false,
        identifier: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder commit: () -> Commit
    ) {
        self.subtitle = subtitle
        self.isPrivacySensitive = isPrivacySensitive
        self.identifier = identifier
        self.content = content()
        self.commit = commit()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let subtitle {
                    Text(subtitle)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .modifier(ComposerPrivacy(isSensitive: isPrivacySensitive))
            .modifier(ComposerIdentity(identifier: identifier))
        }
        .scrollIndicators(.hidden)
        .background { ComposerCanvas() }
        .safeAreaInset(edge: .bottom, spacing: 0) { commit }
    }
}

// MARK: - Canvas

/// The composer's paper.
///
/// Grain sits **behind** content and never over it. Applying a `layerEffect` to
/// a whole scrolling composer asks Metal to flatten every control, label and
/// field into one oversized render surface; keeping it in the background is both
/// cheaper and makes it structurally impossible for the shader to soften type.
/// The workspace redesign learned this the expensive way and left the note at
/// `WeeklyPlanningWorkspaceView.swift:104`.
///
/// The two layers are not redundant. `.lifeboardPaperGrain` is a `layerEffect`,
/// and a `layerEffect` applied to a bare `Color` rasterizes to nothing: this
/// composer rendered as the sheet's plain elevated fill (#FFFDF7) instead of
/// warm paper (#FFF7D8) until the pixels were sampled and compared. So the flat
/// canvas is painted unconditionally underneath, and the grain rides a
/// `Rectangle` that a `GeometryReader` has given a concrete size — which is the
/// thing the effect can actually rasterize. If the shader is unavailable the
/// texture simply never arrives and the paper is still paper.
private struct ComposerCanvas: View {
    var body: some View {
        GrainedCanvas(intensity: 0.42)
    }
}

/// Warm paper with its tooth, as one named view.
///
/// Every surface that wants grain uses this rather than inlining the two-layer
/// `ZStack` + `GeometryReader`. Inlining it four times was not just duplication:
/// dropping the closure into an existing `body` pushed
/// `KnowledgeNoteEditor` from under to over the 500 ms type-check
/// budget this repo treats as a required split. A named `View` gets its own
/// `body` call, its own stack frame, and costs the caller one identifier.
public struct GrainedCanvas: View {
    private let intensity: Double

    public init(intensity: Double = 0.30) {
        self.intensity = intensity
    }

    public var body: some View {
        ZStack {
            Color(SemanticColorTokens.foundationCanvas)
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color(SemanticColorTokens.foundationCanvas))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .lifeboardPaperGrain(intensity: intensity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ComposerPrivacy: ViewModifier {
    let isSensitive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSensitive {
            content.privacySensitive()
        } else {
            content
        }
    }
}

private struct ComposerIdentity: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

// MARK: - Section

/// A grouped clay section: prose on the canvas, controls on clay.
///
/// DESIGN.md is explicit that a card is justified only when its contents form
/// one independent decision, and that wrapping every section in a card is a
/// failure mode rather than a style. So the header, the explanatory detail and
/// the footnote all stay on open canvas where they read as writing, and only the
/// controls themselves take a surface. `Form` cannot express that distinction at
/// all — everything it contains becomes a row on the same grouped slab.
public struct ComposerSection<Content: View>: View {
    private let header: String?
    private let detail: String?
    private let footer: String?
    private let depth: ClayDepth
    private let cornerRadius: CGFloat
    private let spacing: CGFloat
    private let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        _ header: String? = nil,
        detail: String? = nil,
        footer: String? = nil,
        depth: ClayDepth = .resting,
        cornerRadius: CGFloat = 20,
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header
        self.detail = detail
        self.footer = footer
        self.depth = depth
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if header != nil || detail != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let header {
                        Text(header)
                            .font(Typography.sectionTitle())
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    }
                    if let detail {
                        Text(detail)
                            .font(.lifeboard(.support))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .lifeBoardClaySurface(depth, cornerRadius: cornerRadius)

            if let footer {
                Text(footer)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .modifier(ComposerSectionLabel(header: header))
    }
}

private struct ComposerSectionLabel: ViewModifier {
    let header: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let header {
            content.accessibilityLabel(Text(header))
        } else {
            content
        }
    }
}

// MARK: - Row

// MARK: - Commit bar

/// The failure banner and commit control that close every composer.
///
/// The backing is Regular Liquid Glass rather than `.regularMaterial`. That is
/// not a cosmetic swap: a commit bar is navigation and control chrome, which is
/// precisely — and only — what the glass law reserves glass for, and routing it
/// through `lifeBoardSystemGlass` is what makes it honour Reduce Transparency
/// and the Clear-Glass ban along with the rest of the chrome layer.
public struct ComposerCommitBar: View {
    private let title: String
    private let runningTitle: String
    private let successTitle: String
    private let phase: LifeBoardComposerPhase
    private let isEnabled: Bool
    private let identifier: String?
    private let action: () -> Void

    @Environment(\.lifeBoardTransitionCoordinator) private var transitions
    @State private var firstLightTrigger = 0

    public init(
        title: String,
        runningTitle: String = "Saving",
        successTitle: String = "Saved",
        phase: LifeBoardComposerPhase,
        isEnabled: Bool = true,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.runningTitle = runningTitle
        self.successTitle = successTitle
        self.phase = phase
        self.isEnabled = isEnabled
        self.identifier = identifier
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 8) {
            if case .recoverableFailure(let failure) = phase {
                Label(failure.message, systemImage: "exclamationmark.circle")
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            CommitControl(
                title: title,
                runningTitle: runningTitle,
                successTitle: successTitle,
                phase: phase,
                isEnabled: isEnabled,
                action: action
            )
            // The liquid-metal bezel, which had exactly two uses in the whole
            // app and never once in `.pill`. A composer's commit is the single
            // dominant action on its screen, which is what the bezel is for.
            // `.staticIdle` is not negotiable — `.slowLoop` is a literal ambient
            // loop and DESIGN.md forbids those outside the two sites that
            // already justify them.
            .lifeboardCTABezel(
                style: .pill,
                palette: .copper,
                idleMotion: .staticIdle,
                isEnabled: isEnabled,
                isBusy: isRunning
            )
            // Identity only, never `accessibilityElement(children:)`. The
            // commit control has to keep reporting as a `Button`, because the
            // Track suite drives `app.buttons["track.*.commit"]` throughout;
            // wrapping it in a container would hide the button inside it.
            .modifier(FieldIdentity(identifier: identifier))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            Color.clear
                .lifeBoardSystemGlass(.regular, in: Rectangle())
                .ignoresSafeArea(edges: .bottom)
        }
        // `firstLight` is reserved for the first daily commitment. Claimed once
        // per calendar day across the whole window, so the first thing you
        // record today is lit and the fifth is not.
        .lifeboardFirstLight(
            trigger: firstLightTrigger,
            tint: Color(SemanticColorTokens.foundationSunAccent)
        )
        .onChange(of: isSucceeded) { _, succeeded in
            guard succeeded else { return }
            let key = "lifeboard.firstLight.\(Self.dayKey())"
            guard transitions?.claimOneShot(key) == true else { return }
            firstLightTrigger &+= 1
        }
    }

    private var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    private var isSucceeded: Bool {
        if case .success = phase { return true }
        return false
    }

    private static func dayKey() -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
