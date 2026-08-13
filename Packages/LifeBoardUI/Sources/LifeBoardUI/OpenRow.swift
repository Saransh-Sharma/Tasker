import LifeBoardTokens
import SwiftUI

/// How a row sits on the canvas.
///
/// `DESIGN.md` reserves raised clay for independent objects and asks ordinary
/// content to live on the open canvas. Most rows are `.plain`; `.resting` is for
/// a row that is itself the movable or independent thing.
public enum OpenRowDepth: Sendable {
    case plain
    case resting
}

/// Metadata is prose by default. `DESIGN.md` reserves SF Mono for "aligned
/// times, durations, and compact numeric metadata" — `.metric` is that case, and
/// it also switches on monospaced digits so a column of times does not jitter.
public enum OpenRowMetadataStyle: Sendable {
    case support
    case metric
}

/// The canonical row for tasks, events, habits, logs, evidence, and settings.
///
/// There were roughly twenty hand-rolled versions of this in the app and each
/// one got a different subset right. What this type owns, so no call site has to
/// remember it:
///
///   * a 44pt minimum height and a `contentShape` covering the whole row, so the
///     tap target is the row rather than the glyph;
///   * a full-row navigation target that stays semantically distinct from
///     completion, disclosure and destructive controls — `open` becomes the
///     row's button, while `leading`/`trailing` keep their own accessibility
///     elements instead of being flattened into the row's label;
///   * the accessibility-size reflow: at `isAccessibilitySize` the metadata
///     moves *below* the title and the trailing content stacks under the text
///     rather than competing with it for width. `DESIGN.md`: "Never shrink type
///     to preserve a card grid."
///
/// Separators deliberately belong to `OpenRowGroup`, not here. A row that draws
/// its own bottom hairline always draws one too many at the end of a list, which
/// is exactly why the private `nativeBehaviorOpenRow()` in the Journal file
/// could never be lifted out of it.
public struct OpenRow<Leading: View, Trailing: View>: View {
    private let title: String
    private let metadata: String?
    private let metadataStyle: OpenRowMetadataStyle
    private let depth: OpenRowDepth
    private let transitionSourceID: String?
    private let accessibilityID: String?
    private let open: (() -> Void)?
    private let leading: Leading
    private let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        metadata: String? = nil,
        metadataStyle: OpenRowMetadataStyle = .support,
        depth: OpenRowDepth = .plain,
        transitionSourceID: String? = nil,
        accessibilityID: String? = nil,
        open: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.metadata = metadata
        self.metadataStyle = metadataStyle
        self.depth = depth
        self.transitionSourceID = transitionSourceID
        self.accessibilityID = accessibilityID
        self.open = open
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        surface
            .modifier(OptionalTransitionSource(id: transitionSourceID))
            .accessibilityIdentifier(accessibilityID ?? "")
    }

    @ViewBuilder
    private var surface: some View {
        if let open {
            Button(action: open) { content }
                .buttonStyle(.plain)
                .lifeBoardPressResponse(.row, haptic: nil)
                .accessibilityAddTraits(.isButton)
        } else {
            content
        }
    }

    private var content: some View {
        OpenRowLayout(
            usesStackedLayout: dynamicTypeSize.isAccessibilitySize,
            leading: leading,
            trailing: trailing,
            text: text
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .modifier(OpenRowSurface(depth: depth))
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .fixedSize(horizontal: false, vertical: true)
            if let metadata, metadata.isEmpty == false {
                Text(metadata)
                    .font(metadataStyle == .metric ? .caption.monospacedDigit() : .subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Split out so `OpenRow.body` stays a single small expression.
///
/// Not an aesthetic choice: view bodies in this app are held under a hard
/// budget because at `-Onone` a body that composes too much inline walks the
/// main-thread stack and crashes on the guard page at launch, before anything
/// draws. See `LifeBoardTrackFoundationViews.swift:193`.
private struct OpenRowLayout<Leading: View, Trailing: View, Text: View>: View {
    let usesStackedLayout: Bool
    let leading: Leading
    let trailing: Trailing
    let text: Text

    var body: some View {
        if usesStackedLayout {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    leading
                    text
                }
                // Trailing content keeps its full tap target instead of being
                // squeezed into a sliver beside wrapped text.
                HStack(spacing: 12) { trailing }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                leading
                text
                trailing
            }
        }
    }
}

private struct OpenRowSurface: ViewModifier {
    let depth: OpenRowDepth

    @ViewBuilder
    func body(content: Content) -> some View {
        switch depth {
        case .plain:
            content
        case .resting:
            content
                .padding(.horizontal, 8)
                .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        }
    }
}

private struct OptionalTransitionSource: ViewModifier {
    let id: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let id {
            content.lifeBoardTransitionSource(id)
        } else {
            content
        }
    }
}

// MARK: - Convenience initializers

public extension OpenRow where Leading == EmptyView {
    init(
        title: String,
        metadata: String? = nil,
        metadataStyle: OpenRowMetadataStyle = .support,
        depth: OpenRowDepth = .plain,
        transitionSourceID: String? = nil,
        accessibilityID: String? = nil,
        open: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: title,
            metadata: metadata,
            metadataStyle: metadataStyle,
            depth: depth,
            transitionSourceID: transitionSourceID,
            accessibilityID: accessibilityID,
            open: open,
            leading: { EmptyView() },
            trailing: trailing
        )
    }
}

public extension OpenRow where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String,
        metadata: String? = nil,
        metadataStyle: OpenRowMetadataStyle = .support,
        depth: OpenRowDepth = .plain,
        transitionSourceID: String? = nil,
        accessibilityID: String? = nil,
        open: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            metadata: metadata,
            metadataStyle: metadataStyle,
            depth: depth,
            transitionSourceID: transitionSourceID,
            accessibilityID: accessibilityID,
            open: open,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}
