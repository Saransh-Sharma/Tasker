import Combine
import LifeBoardDomain
import SwiftData
import SwiftUI
import UIKit

struct LLMStoreUnavailableView: View {
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .lifeboardFont(.title1)
                .foregroundColor(.lifeboard(.statusWarning))
                .accessibilityHidden(true)
            Text("\(AssistantIdentitySnapshot.current.displayName) can’t open your chats")
                .lifeboardFont(.headline)
                .foregroundColor(.lifeboard(.textPrimary))
                .multilineTextAlignment(.center)
            Text("Your tasks are safe. Try again, or restart LifeBoard.")
                .lifeboardFont(.callout)
                .foregroundColor(.lifeboard(.textSecondary))
                .multilineTextAlignment(.center)
            Button {
                guard isRetrying == false else { return }
                isRetrying = true
                Task { @MainActor in
                    await LLMStoreBootstrap.shared.retryAfterFailure()
                    isRetrying = false
                }
            } label: {
                if isRetrying {
                    ProgressView()
                } else {
                    Text("Try again")
                }
            }
            .buttonStyle(.lifeBoardPrimaryCompact)
            .disabled(isRetrying)
            .accessibilityIdentifier("eva.storeUnavailable.retry")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lifeboard(.bgCanvas))
    }
}

struct LLMStoreLoadingView: View {
    var onAppear: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Getting \(AssistantIdentitySnapshot.current.displayName) ready")
                .lifeboardFont(.headline)
                .foregroundColor(.lifeboard(.textPrimary))
            Text("Your conversations are loading.")
                .lifeboardFont(.callout)
                .foregroundColor(.lifeboard(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lifeboard(.bgCanvas))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eva.store.loading")
        .onAppear { onAppear?() }
    }
}

/// Reusable asynchronous boundary for every surface that embeds Eva.
///
/// The closure returns `AnyView` deliberately: callers cannot accidentally
/// recreate a conditional type containing the loading, failure, and full chat
/// hierarchies.
struct LLMStoreContainerHost: View {
    @StateObject private var bootstrap = LLMStoreBootstrap.shared
    private let onLoadingAppear: (() -> Void)?
    private let content: (ModelContainer) -> AnyView

    init(
        onLoadingAppear: (() -> Void)? = nil,
        content: @escaping (ModelContainer) -> AnyView
    ) {
        self.onLoadingAppear = onLoadingAppear
        self.content = content
    }

    var body: some View {
        currentView
            .task {
                _ = await bootstrap.load()
            }
    }

    private var currentView: AnyView {
        switch bootstrap.state {
        case .ready(let container), .degraded(let container?, _):
            content(container)
        case .degraded(nil, _):
            AnyView(LLMStoreUnavailableView())
        case .idle, .loading:
            AnyView(LLMStoreLoadingView(onAppear: onLoadingAppear))
        }
    }
}
