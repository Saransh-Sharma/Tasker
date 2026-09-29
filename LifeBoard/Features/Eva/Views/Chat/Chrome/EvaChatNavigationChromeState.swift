import SwiftUI

struct EvaChatNavigationChromeState {
    let title: String
    let subtitle: String
    let showsUtilityActions: Bool
    let showsHistoryAction: Bool
    let showsNewChatAction: Bool

    static var empty: EvaChatNavigationChromeState {
        EvaChatNavigationChromeState(
            title: AssistantIdentityText.currentSnapshot().displayName,
            subtitle: String(localized: "New chat"),
            showsUtilityActions: true,
            showsHistoryAction: true,
            showsNewChatAction: false
        )
    }
}
