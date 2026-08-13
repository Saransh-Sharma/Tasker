import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// The Life OS shell's Settings destination.
///
/// This route used to be a ~40 line `Form` with three pickers, while the real
/// `SettingsRootView` — profile, notifications, quiet hours, rituals, calendar,
/// Life Management, assistant and account controls — was reachable *only* from
/// the legacy UIKit home. Anyone running the Life OS shell simply could not get
/// to most of the app's settings. The full screen is now the destination, with
/// the shell-owned atmosphere controls pushed from a row inside it.
struct SettingsRouteView: View {
    @Environment(PresentationPreferences.self) private var preferences
    let router: AppRouter
    @StateObject private var viewModel = SettingsViewModel(
        calendarIntegrationService: CompositionRoot.shared
            .coordinator
            .calendarIntegrationService
    )

    var body: some View {
        SettingsRootView(
            viewModel: viewModel,
            presentationPreferences: preferences,
            onNavigate: { router.push(.settingsDetail($0)) }
        )
            .navigationTitle("Settings")
            .accessibilityIdentifier("foundation.settings")
            .onAppear {
                viewModel.reload()
            }
    }
}

struct SettingsDetailRouteView: View {
    let route: SettingsDetailRoute
    let router: AppRouter

    @Environment(PresentationPreferences.self) private var preferences
    @StateObject private var viewModel = SettingsViewModel(
        calendarIntegrationService: CompositionRoot.shared
            .coordinator
            .calendarIntegrationService
    )

    var body: some View {
        Group {
            if route == .lifeManagement {
                LifeManagementView(
                    viewModel: CompositionRoot.shared.makeLifeManagementViewModel()
                )
            } else {
                SettingsRootView(
                    viewModel: viewModel,
                    destination: route,
                    presentationPreferences: preferences,
                    onNavigate: { router.push(.settingsDetail($0)) }
                )
            }
        }
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("foundation.settings.detail.\(route.rawValue)")
    }
}

struct AppearanceSettingsView: View {
    @Environment(PresentationPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section("Atmosphere") {
                Picker("Daypart", selection: $preferences.daypartSelection) {
                    ForEach(DaypartSelection.allCases, id: \.self) { selection in
                        Label(selection.title, systemImage: selection.systemImage).tag(selection)
                    }
                }
                Picker("Comfort", selection: $preferences.comfortProfile) {
                    ForEach(ComfortProfile.allCases, id: \.self) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                Picker("Rendering", selection: $preferences.renderingTier) {
                    ForEach(AmbientRenderingTier.allCases, id: \.self) { tier in
                        Text(tier.title).tag(tier)
                    }
                }
            }
            Section("Privacy") {
                Label("Journal evidence stays off until you allow it", systemImage: "lock.shield")
                Label("Sensitive media uses protected local storage", systemImage: "externaldrive.badge.lock")
            }
            Section("About") {
                NavigationLink {
                    ThirdPartyNoticesView()
                } label: {
                    Label("Third-party notices", systemImage: "doc.text")
                }
                .accessibilityIdentifier("foundation.settings.third-party-notices")
            }
        }
        .navigationTitle("Appearance & motion")
        .accessibilityIdentifier("foundation.settings.appearance")
    }
}

struct ThirdPartyNoticesView: View {
    private let notice: String = {
        guard let url = Bundle.main.url(forResource: "SwiftUI-Animations-NOTICE", withExtension: "txt"),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return "The bundled third-party notice could not be loaded."
        }
        return value
    }()

    var body: some View {
        ScrollView {
            Text(notice)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .navigationTitle("Third-party notices")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("foundation.third-party-notices")
    }
}
