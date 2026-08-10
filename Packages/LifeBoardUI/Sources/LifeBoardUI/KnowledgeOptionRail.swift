import LifeBoardTokens
import SwiftUI

// MARK: - Option rail

/// A wrapping rail of clay chips for a small closed set.
///
/// Selection is carried by *depth* — chosen options sit on raised clay, the rest
/// are carved into the surface — so the state survives greyscale and
/// Differentiate Without Colour without the tint doing any work on its own.
///
/// This is not `LensPicker`, and the difference matters. The lens
/// picker is a view switcher: one travelling thumb, equal-weight segments, and a
/// `matchedGeometryEffect` id that is a global constant, so two of them on one
/// screen fight over the same thumb. It stays reserved for replacing
/// `.pickerStyle(.segmented)`. This is for choosing a *value*, where labels have
/// wildly different lengths and more than one rail per screen is normal.
public struct OptionRail<Value: Hashable>: View {
    private let label: String
    private let values: [Value]
    private let identifierPrefix: String
    private let title: (Value) -> String
    private let systemImage: ((Value) -> String)?
    private let detail: ((Value) -> String)?
    private let pressBloomTint: Color?
    private let showsLabel: Bool
    @Binding private var selection: Value

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var bloomTrigger = 0
    @State private var bloomCenter: UnitPoint = .center

    public init(
        _ label: String,
        selection: Binding<Value>,
        values: [Value],
        identifierPrefix: String,
        title: @escaping (Value) -> String,
        systemImage: ((Value) -> String)? = nil,
        detail: ((Value) -> String)? = nil,
        /// Set false when the enclosing section header already names this
        /// choice. Two headings for one control is the "repeated headings"
        /// failure DESIGN.md calls out, and it read as a bug on screen.
        showsLabel: Bool = true,
        pressBloomTint: Color? = nil
    ) {
        self.label = label
        self._selection = selection
        self.values = values
        self.identifierPrefix = identifierPrefix
        self.title = title
        self.systemImage = systemImage
        self.detail = detail
        self.showsLabel = showsLabel
        self.pressBloomTint = pressBloomTint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsLabel {
                Text(label)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            rail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifierPrefix)
            }

    /// A grid at accessibility sizes rather than a horizontal scroll: long
    /// labels at AX5 make a scrolling rail a guessing game about how many
    /// options exist.
    @ViewBuilder
    private var rail: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                ForEach(values, id: \.self) { chip($0) }
            }
        } else {
            OptionFlow(spacing: 8) {
                ForEach(values, id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ value: Value) -> some View {
        let isSelected = value == selection
        return Button {
            guard isSelected == false else { return }
            Haptic.pick.play()
            selection = value
            if pressBloomTint != nil { bloomTrigger &+= 1 }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage(value))
                            .font(.lifeboard(.caption1))
                            .accessibilityHidden(true)
                    }
                    Text(title(value))
                        .font(.lifeboard(isSelected ? .bodyStrong : .body))
                }
                if let detail {
                    Text(detail(value))
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                }
            }
            .foregroundStyle(
                Color(isSelected
                    ? SemanticColorTokens.inkPrimary
                    : SemanticColorTokens.inkSecondary)
            )
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .lifeBoardClaySurface(
                isSelected ? .raised : .well,
                cornerRadius: Radius.pill
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .lifeBoardMotion(.selection, value: selection)
        .accessibilityIdentifier("\(identifierPrefix).\(chipIdentifier(value))")
        .accessibilityLabel(Text(title(value)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Enum-backed values expose a stable raw value; anything else falls back to
    /// its description. The tracker flow drives `track.tracker.kind.quantity`,
    /// so this composition has to match what `Picker` tags produced before.
    private func chipIdentifier(_ value: Value) -> String {
        if let raw = (value as? any RawRepresentable)?.rawValue as? String {
            return raw
        }
        return String(describing: value)
    }
}

/// Applies the press bloom only when a call site opted in.
///
/// Deliberately opt-in per rail. A bloom on every option in the app is exactly
/// the "animate every state change" failure DESIGN.md warns about; it belongs on
/// choices that carry weight — the kind of tracker you are creating, the mood
/// you are recording — and not on a unit toggle.
/// A flow layout that wraps chips onto new lines instead of scrolling them off
/// the edge. Chips whose labels vary from "Yes" to "Recurring meaningful event"
/// cannot share a fixed grid without either truncating or leaving half the row
/// empty.
public struct OptionFlow: Layout {
    let spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? spacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        widestRow = max(widestRow, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: min(widestRow, maxWidth), height: totalHeight)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
