import SwiftUI

struct HomeSearchChromeView: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let onQueryChanged: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        LifeBoardSearchHeaderView(
            query: $query,
            isFocused: _isFocused,
            onQueryChanged: onQueryChanged,
            onSubmit: onSubmit,
            onClear: onClear
        )
        .ignoresSafeArea(.keyboard)
        .accessibilityIdentifier("search.chromeContainer")
    }
}
