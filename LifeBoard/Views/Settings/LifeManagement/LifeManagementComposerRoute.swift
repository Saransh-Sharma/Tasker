import SwiftUI
import UIKit

enum LifeManagementComposerRoute: Identifiable, Equatable {
    case area(LifeManagementLifeAreaDraft)
    case project(LifeManagementProjectDraft)

    var id: UUID {
        switch self {
        case .area(let draft):
            return draft.id
        case .project(let draft):
            return draft.id
        }
    }
}
