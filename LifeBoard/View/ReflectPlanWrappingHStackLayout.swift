import SwiftUI

struct ReflectPlanWrappingHStackLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + verticalSpacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }

        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursor = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > bounds.maxX, cursor.x > bounds.minX {
                cursor.x = bounds.minX
                cursor.y += lineHeight + verticalSpacing
                lineHeight = 0
            }

            subview.place(
                at: cursor,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            cursor.x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
