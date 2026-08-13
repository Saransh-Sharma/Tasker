import SwiftUI

struct EvaChiefOfStaffGuideSection: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let body: String
    let prompts: [EvaStarterPrompt]
}
