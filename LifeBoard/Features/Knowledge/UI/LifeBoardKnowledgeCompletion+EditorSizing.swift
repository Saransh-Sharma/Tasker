import SwiftUI
import UIKit

extension UnifiedNoteEditor {
    public static func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        // An unspecified (ideal-size) proposal used to answer 680pt. The
        // editor's `LazyVStack` sized itself to that, wider than any phone, and
        // the whole column — title, date line, tags — slid off the leading
        // edge. Ideal is a modest width; the real proposal then fills the row.
        let proposed = proposal.width ?? 320
        let width = proposed.isFinite ? proposed : 320
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(220, size.height))
    }
}
