import Charts
import SwiftUI
import UIKit

struct HealthHubView: View {
    @State private var store: HealthConnectionStore
    @State private var educationDomain: HealthDomain?
    @State private var showsWaterLog = false
    @State private var showsWeightLog = false
    @State private var latestLocalMealAt: Date?
    @State private var healthSyncPulseTrigger = 0
    @State private var vitalOrbWarpTrigger = 0
    @AppStorage("healthPrivacyLocalOnlyNoticeAcknowledged") private var didAcknowledgeHealthPrivacyNotice = false
    @State private var showsHealthPrivacyNotice = false
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private let trackRepository: CoreDataTrackFoundationRepository
    private let wellnessRepository: any WellnessRepository
    private let nutritionRepository: any NutritionRepository

    init(
        store: HealthConnectionStore = HealthCoordinator.shared.connectionStore,
        trackRepository: CoreDataTrackFoundationRepository,
        wellnessRepository: any WellnessRepository,
        nutritionRepository: any NutritionRepository
    ) {
        _store = State(initialValue: store)
        self.trackRepository = trackRepository
        self.wellnessRepository = wellnessRepository
        self.nutritionRepository = nutritionRepository
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HealthHubHeroSection(
                    isConnected: isConnected,
                    statusLine: connectionSubtitle,
                    palette: DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme),
                    onConnect: { educationDomain = .hydration },
                    onLogWater: { showsWaterLog = true },
                    pulseTrigger: healthSyncPulseTrigger
                )
                HealthHubMovementSection(store: store, warpTrigger: vitalOrbWarpTrigger)
                HealthHubHydrationSection(store: store, onLogWater: { showsWaterLog = true })
                HealthHubNutritionSection(store: store)
                HealthHubFastingSection(suggestion: fastingSuggestionDate, source: fastingSuggestionSource)
                HealthHubValuesSection(store: store)
                HealthHubConnectionsSection(
                    store: store,
                    onEducate: { educationDomain = $0 },
                    onLogWeight: { showsWeightLog = true }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            // Measured clearance for the floating dock and composer.
            .padding(.bottom, ClayLayoutMetrics.bottomDockClearance)
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.syncNow() }
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isRefreshing)
                .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
            }
        }
        .task {
            showsHealthPrivacyNotice = didAcknowledgeHealthPrivacyNotice == false
            latestLocalMealAt = try? await nutritionRepository.logs(from: nil, to: nil).first?.loggedAt
            await store.refreshAuthorization()
            if store.statuses.values.contains(where: { $0.readRequestState != .neverRequested }) {
                await store.syncNow()
            }
        }
        .refreshable { await store.syncNow() }
        .onChange(of: store.lastSuccessfulSync) { oldValue, newValue in
            guard newValue != nil, newValue != oldValue else { return }
            healthSyncPulseTrigger &+= 1
            HapticFeedback.success()
        }
        .onChange(of: store.aggregates[.water]?.value) { _, newValue in
            guard let newValue, newValue >= 2_000,
                  HealthGoalCelebrationGate.claim(metric: .water, day: Date()) else {
                return
            }
            vitalOrbWarpTrigger &+= 1
            HapticFeedback.success()
        }
        .sheet(item: $educationDomain) { domain in
            HealthConnectPromptSheet(
                leadDomain: domain,
                onConnect: { domains in
                    educationDomain = nil
                    Task { await store.connect(domains: domains) }
                },
                onDecline: { educationDomain = nil }
            )
        }
        .sheet(isPresented: $showsWaterLog) {
            HealthWaterLogSheet(repository: trackRepository)
        }
        .sheet(isPresented: $showsWeightLog) {
            HealthWeightLogSheet(repository: wellnessRepository)
        }
        .alert("Health data now stays on this device", isPresented: $showsHealthPrivacyNotice) {
            Button("Got it") { didAcknowledgeHealthPrivacyNotice = true }
        } message: {
            Text("LifeBoard wellness records are local-only and are never placed in analytics or logs.")
        }
    }

    /// Connected once any domain has actually been asked for. Apple never
    /// reveals a read denial, so "requested" is the strongest honest claim.
    private var isConnected: Bool {
        store.statuses.values.contains { $0.readRequestState != .neverRequested }
    }

    private var connectionSubtitle: String {
        if let date = store.lastSuccessfulSync {
            return "Last synced \(date.formatted(date: .omitted, time: .shortened))"
        }
        return store.isRefreshing ? "Syncing…" : "Not synced yet"
    }

    private var fastingSuggestionDate: Date? {
        HealthFastingSuggestion.latestStart(
            localMealAt: latestLocalMealAt,
            externalDietaryEnergyAt: store.aggregates[.dietaryEnergy]?.lastSampleAt
        )
    }

    private var fastingSuggestionSource: String {
        guard let latest = fastingSuggestionDate else { return "" }
        if latest == latestLocalMealAt { return "Based on your latest LifeBoard meal." }
        return "Based on the latest external dietary-energy timestamp in Apple Health."
    }
}

/// The warm, contextual "Connect Apple Health" priming sheet. Presented both by
/// the hub and, globally, by any health feature via `HealthJustInTimeCoordinator`.
/// It never blocks the underlying action — callers save locally first. `onConnect`
/// receives the writable domains the user chose to share.
struct HealthConnectPromptSheet: View {
    let leadDomain: HealthDomain
    let onConnect: (Set<HealthDomain>) -> Void
    let onDecline: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseTrigger = 0
    @State private var showsShareOptions = false
    @State private var selectedWritableDomains: Set<HealthDomain>

    private static let writableDomains: [HealthDomain] = [.hydration, .nutrition, .body, .workouts]

    init(
        leadDomain: HealthDomain,
        onConnect: @escaping (Set<HealthDomain>) -> Void,
        onDecline: @escaping () -> Void
    ) {
        self.leadDomain = leadDomain
        self.onConnect = onConnect
        self.onDecline = onDecline
        _selectedWritableDomains = State(
            initialValue: leadDomain.supportsWriteBack ? [leadDomain] : []
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HealthSyncBridgeHero(pulseTrigger: pulseTrigger)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline)
                            .font(.title2.bold())
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text(leadDomain.shareBlurb)
                            .font(.body)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                    trustRow
                    shareDisclosure
                }
                .padding(24)
            }
            actions
        }
        .background(Color.lifeboard(.bgCanvas).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            HapticFeedback.light()
            if reduceMotion == false { pulseTrigger &+= 1 }
        }
    }

    private var headline: String {
        switch leadDomain {
        case .hydration: "Keep your hydration in sync"
        case .nutrition: "Keep your nutrition in sync"
        case .body: "Your weight, in sync both ways"
        case .workouts: "Your workouts, in sync both ways"
        case .activity: "Bring your activity into LifeBoard"
        case .energy: "Bring your energy into LifeBoard"
        case .sleep: "Bring your sleep into LifeBoard"
        case .fasting: "Smarter fasting with Apple Health"
        }
    }

    private var trustRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
            Text("Your health data stays on this device. Read access is private to Apple Health — LifeBoard never sees what you keep to yourself, and never labels a read denied.")
                .font(.caption)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .padding(12)
        .background(Color.lifeboard(.bgElevated), in: RoundedRectangle(cornerRadius: 14))
    }

    private var shareDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { showsShareOptions.toggle() }
            } label: {
                HStack {
                    Text("Choose what to share")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: showsShareOptions ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.lifeboard(.textPrimary))
            }
            .buttonStyle(.plain)
            if showsShareOptions {
                ForEach(Self.writableDomains) { domain in
                    Toggle(isOn: binding(for: domain)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(domain.title, systemImage: domain.symbolName)
                                .font(.subheadline)
                            Text(domain.shareBlurb)
                                .font(.caption2)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                        }
                    }
                    .tint(Color.lifeboard(.accentPrimary))
                }
                Text("Reading — steps, energy, sleep — is always private and needs no sharing choice.")
                    .font(.caption2)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .padding(14)
        .background(Color.lifeboard(.bgElevated), in: RoundedRectangle(cornerRadius: 16))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                HapticFeedback.success()
                onConnect(selectedWritableDomains)
            } label: {
                Text("Connect Apple Health")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
            Button("Not now") { onDecline() }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(Color.lifeboard(.bgCanvas))
    }

    private func binding(for domain: HealthDomain) -> Binding<Bool> {
        Binding(
            get: { selectedWritableDomains.contains(domain) },
            set: { isOn in
                if isOn {
                    selectedWritableDomains.insert(domain)
                } else {
                    selectedWritableDomains.remove(domain)
                }
            }
        )
    }
}

/// Two nodes — LifeBoard and Apple Health — with data flowing *both* directions
/// between them, so the two-way nature is felt, not just told. The particle flow
/// falls back to a static double-arrow under Reduce Motion; the whole hero plays
/// the `HealthSyncPulse` aurora once on appear.
private struct HealthSyncBridgeHero: View {
    let pulseTrigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.lifeboard(.bgElevated))
            LinearGradient(
                colors: [
                    Color.lifeboard(.accentPrimary).opacity(0.16),
                    Color.lifeboard(.accentSecondary).opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            HStack(spacing: 12) {
                node(symbol: "hexagon.fill", title: "LifeBoard")
                SyncBridgeChannel()
                    .frame(maxWidth: .infinity)
                node(symbol: "heart.fill", title: "Apple Health")
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 150)
        .lifeboardHealthSyncPulse(trigger: pulseTrigger)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LifeBoard and Apple Health, syncing both ways")
    }

    private func node(symbol: String, title: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.lifeboard(.bgCanvas))
                    .frame(width: 56, height: 56)
                Circle()
                    .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
            }
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
    }
}

private struct SyncBridgeChannel: View {
    var body: some View {
        Image(systemName: "arrow.left.arrow.right")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.lifeboard(.accentPrimary))
            .frame(height: 34)
            .accessibilityHidden(true)
    }
}
