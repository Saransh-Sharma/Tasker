import LifeBoardTokens
import SwiftUI

/// A run of `OpenRow`s with hairlines *between* them and none after the last.
///
/// This is the half that every hand-rolled row got wrong. A row that draws its
/// own bottom separator always draws one too many at the end of a list, so
/// screens compensated with a trailing negative padding, or an `if isLast`
/// parameter threaded through the row's initializer, or a `Divider()` the caller
/// had to remember. Making the group own the separator removes the question.
///
/// Built on `ForEach` over an explicit collection rather than on a
/// `@ViewBuilder` closure with `_VariadicView`: the variadic API is SPI-adjacent
/// and its child count is not knowable at the point the separator is decided.
public struct OpenRowGroup<Data: RandomAccessCollection, Row: View>: View
where Data.Element: Identifiable {
    private let data: Data
    private let showsSeparators: Bool
    private let row: (Data.Element) -> Row

    public init(
        _ data: Data,
        showsSeparators: Bool = true,
        @ViewBuilder row: @escaping (Data.Element) -> Row
    ) {
        self.data = data
        self.showsSeparators = showsSeparators
        self.row = row
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(data) { element in
                row(element)
                if showsSeparators, isLast(element) == false {
                    OpenRowSeparator()
                }
            }
        }
    }

    private func isLast(_ element: Data.Element) -> Bool {
        data.last?.id == element.id
    }
}

/// The hairline between rows.
///
/// Inset from the leading edge so it reads as a division inside one list rather
/// than as a full-width rule cutting the canvas — and hidden from VoiceOver,
/// which has no use for a decorative line between two elements it already
/// announces separately.
public struct OpenRowSeparator: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color(SemanticColorTokens.foundationHairline))
            .frame(height: 1)
            .padding(.leading, 4)
            .accessibilityHidden(true)
    }
}
