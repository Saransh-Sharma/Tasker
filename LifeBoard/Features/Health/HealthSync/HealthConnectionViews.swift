import SwiftUI

struct HealthReadDisclosure: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bring your health into LifeBoard")
                .lifeboardFont(.screenTitle)
            Text("See activity, sleep, workouts, and the wellness data you already record beside your day. Choose what LifeBoard may read in Apple Health.")
                .lifeboardFont(.body)
            Text("This connection only reads data. Saving LifeBoard logs to Apple Health is a separate choice.")
                .lifeboardFont(.support)
            Text("Health imports are processed on this device. Available Health context may accompany EVA requests; manage EVA context in Settings.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("health.connection.disclosure")
    }
}

struct HealthAccessInstructions: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Review access in Apple Health")
                    .lifeboardFont(.screenTitle)
                Text("Open the Health app, tap your profile, then Apps under Privacy. Choose LifeBoard and review the categories you want to share.")
                Text("Return to LifeBoard when you’re done. We’ll refresh the data available to this device.")
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                Spacer()
            }
            .padding(24)
            }
            .navigationTitle("Health access")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Shared by direct and contextual entry points. Dismissal returns to the caller;
/// the store owns authorization/import work beyond this sheet's lifetime.
struct HealthConnectionSheet: View {
    var context = ConnectionPresentationContext(.health, from: .health)
    var onAuthorizationResult: ((HealthAuthorizationOutcome) -> Void)? = nil
    @State private var visitID: UUID?
    @State private var isSubmitting = false
    private var isOnboarding: Bool { context.origin == .onboarding }
    @State private var store = HealthCoordinator.shared.connectionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsAccess = false
    @State private var showsWriteBack = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isOnboarding {
                        Text("Bring your health into LifeBoard").lifeboardFont(.screenTitle)
                        Text("See activity, sleep, and workouts beside your day. Choose what LifeBoard may read in Apple Health.")
                        Text("This only requests read access. Available Health context may accompany EVA requests; manage EVA context in Settings.")
                            .lifeboardFont(.caption1)
                        if store.presentation == .authorizationFailed { Text(store.presentation.summary) }
                        if store.isRequestingAuthorization { ProgressView("Waiting for Apple Health") }
                    } else if store.presentation == .notRequested {
                        HealthReadDisclosure()
                    } else {
                        Text("Apple Health").lifeboardFont(.screenTitle)
                        Text(store.presentation.summary)
                            .fixedSize(horizontal: false, vertical: true)
                        if store.isRefreshing || store.isRequestingAuthorization { ProgressView() }
                    }
                    if let title = actionTitle {
                        Button(title) { performAction() }
                            .buttonStyle(.lifeBoardPrimary)
                            .disabled(store.isRequestingAuthorization || isSubmitting)
                            .accessibilityIdentifier("health.connection.primary")
                    }
                    if !isOnboarding && store.presentation != .notRequested && store.presentation != .unavailable {
                        Button("Manage Health access") { showsAccess = true }
                            .buttonStyle(.lifeBoardChip)
                        Button("Save LifeBoard logs to Apple Health") { showsWriteBack = true }
                            .buttonStyle(.lifeBoardChip)
                            .disabled(store.isRequestingAuthorization)
                    }
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button(isOnboarding ? "Not now" : "Continue using LifeBoard") { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding()
                    .background(Color.lifeboard(.bgCanvas))
                    .accessibilityIdentifier("health.connection.continue")
            }
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showsAccess) { HealthAccessInstructions() }
            .sheet(isPresented: $showsWriteBack) {
                HealthConnectPromptSheet(
                    leadDomain: .activity,
                    initialWritableDomains: Set(store.statuses.values.filter(\.writeEnabled).map(\.domain)),
                    requestsWriteBack: true,
                    onConnect: { domains in
                        showsWriteBack = false
                        Task {
                            if !domains.isEmpty { await store.requestWriteBack(domains: domains) }
                            for domain in HealthDomain.allCases where domain.supportsWriteBack && !domains.contains(domain) {
                                await store.setWriteEnabled(false, for: domain)
                            }
                        }
                    },
                    onDecline: { showsWriteBack = false }
                )
            }
            .onAppear { visitID = UUID() }
            .onDisappear { visitID = nil }
            .task { await store.bootstrap() }
            .onChange(of: store.presentation) { previous, current in
                if !isOnboarding, case .ready = current, previous == .syncing || previous == .requesting {
                    AccessibilityNotification.Announcement("Health data is available in LifeBoard.").post()
                    dismiss()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.syncIfNeededOnForeground() } }
            }
        }
        .accessibilityIdentifier("connection.\(context.origin.rawValue).health")
    }

    private var actionTitle: String? {
        if isOnboarding {
            switch store.presentation {
            case .notRequested: return "Connect Apple Health"
            case .authorizationFailed: return "Retry Health access"
            case .requesting: return nil
            default: return "Continue"
            }
        }
        return switch store.presentation {
        case .notRequested: "Connect Apple Health"
        case .authorizationFailed: "Retry Health access"
        case .partial: "Retry sync"
        case .ready, .reviewedNoDataYet: "Sync now"
        case .unavailable, .requesting, .syncing, .protectedDataLocked: nil
        }
    }

    private func performAction() {
        guard !isSubmitting else { return }
        isSubmitting = true
        let requestVisit = visitID
        Task {
            defer { isSubmitting = false }
            if store.presentation == .notRequested || store.presentation == .authorizationFailed {
                let outcome = await store.connectReadOnly()
                await ProductTelemetry.shared.record(.connectorResult, outcome: "health_authorization_\(outcome)")
                guard let requestVisit, visitID == requestVisit else { return }
                onAuthorizationResult?(outcome)
                if isOnboarding && outcome != .failed { dismiss() }
            } else if isOnboarding {
                guard let requestVisit, visitID == requestVisit else { return }
                onAuthorizationResult?(store.presentation == .unavailable ? .unavailable : .reviewed)
                dismiss()
            } else { await store.syncNow() }
        }
    }
}
