import SwiftUI
import UIKit

struct LifeManagementComposerPreviewMetric: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}
