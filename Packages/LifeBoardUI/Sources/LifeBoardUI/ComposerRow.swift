import SwiftUI
import LifeBoardTokens
// Split out of `ComposerScaffold`, which stays app-side because
// it accepts `TrackComposerReceipt`. The row is generic over its trailing
// content and knows no feature type, so it travels with the fields that
// use it.
/// A label with a trailing control, on a `.well`.
///
/// The 48-point floor is above the 44-point minimum on purpose: composer rows
/// carry a label *and* a control, and 44 leaves the two touching at default type
/// size. At accessibility sizes the row reflows to label-over-control rather
/// than truncating, which is the specific failure DESIGN.md names — never shrink
/// or clip text to preserve a one-line row.
public struct ComposerRow<Trailing: View>: View {
    private let label: String
    private let detail: String?
    private let systemImage: String?
    private let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        _ label: String,
        detail: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.label = label
        self.detail = detail
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    public var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        layout {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                        .frame(width: 20)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.lifeboard(.body))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                    if let detail {
                        Text(detail)
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
            }
            trailing
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                    alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing
                )
                // The control wins the width fight, not the label. Without this
                // a row carrying both a date and a time capsule compressed the
                // values to "Aug…" and "11:…" while "Bedtime" sat uncut — the
                // two things you actually needed to read were the two that went.
                .layoutPriority(1)
        }
        .frame(minHeight: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
