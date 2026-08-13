import LifeBoardTokens
import SwiftUI

/// A title, an optional count, and at most one trailing action.
///
/// `DESIGN.md` asks for one type size and one spacing across the product, and
/// says a section header that has been individually restyled is a defect. Before
/// this existed there were roughly thirty ad-hoc `Text(…).font(…)` pairs, using
/// four different vocabularies, with the trailing action sometimes a `Button`,
/// sometimes a tappable `Text`, and sometimes below the title.
///
/// The count is deliberately a separate parameter rather than something the
/// caller interpolates into the title: it renders as quiet metadata beside the
/// title rather than competing with it, and it stays out of the accessibility
/// label's leading position, where it would be read before the thing it counts.
public struct SectionHeader<Trailing: View>: View {
    private let title: String
    private let symbol: String?
    private let count: Int?
    private let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        _ title: String,
        symbol: String? = nil,
        count: Int? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.symbol = symbol
        self.count = count
        self.trailing = trailing()
    }

    public var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        layout {
            if let symbol {
                Image(systemName: symbol)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .accessibilityHidden(true)
            }

            Text(title)
                .lifeboardFont(.sectionTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)

            if let count {
                Text(count.formatted())
                    .lifeboardFont(.meta)
                    .monospacedDigit()
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }

            if dynamicTypeSize.isAccessibilitySize == false {
                Spacer(minLength: 8)
            }

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isHeader)
    }
}

public extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, count: Int? = nil) {
        self.init(title, symbol: symbol, count: count) { EmptyView() }
    }
}
