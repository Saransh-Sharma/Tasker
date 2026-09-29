import SwiftUI

struct EvaFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = arrangeRows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map { row in row.width }.max() ?? 0
        let height = rows.reduce(0) { partialResult, row in
            partialResult + row.height
        } + max(0, CGFloat(rows.count - 1) * rowSpacing)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = arrangeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                let proposal = ProposedViewSize(width: element.size.width, height: element.size.height)
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: proposal
                )
                x += element.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func arrangeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        guard subviews.isEmpty == false else { return [] }

        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.elements.isEmpty ? size.width : current.width + spacing + size.width

            if current.elements.isEmpty == false && nextWidth > maxWidth {
                rows.append(current)
                current = Row()
            }

            current.elements.append(Row.Element(index: index, size: size))
            current.width = current.elements.dropFirst().reduce(current.elements.first?.size.width ?? 0) { partialResult, element in
                partialResult + spacing + element.size.width
            }
            current.height = max(current.height, size.height)
        }

        if current.elements.isEmpty == false {
            rows.append(current)
        }

        return rows
    }

    private struct Row {
        struct Element {
            let index: Int
            let size: CGSize
        }

        var elements: [Element] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
}
