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
                connectionCard
                metricRings
                hydrationCard
                nutritionCard
                fastingSuggestionCard
                accessibleMetricTable
                domainConnections
            }
            .padding(20)
        }
        .background(Color.lifeboard(.bgCanvas).ignoresSafeArea())
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

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.title2)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                        .font(.headline)
                    Text(connectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                Spacer()
            }
            if store.statuses.values.allSatisfy({ $0.readRequestState == .neverRequested }) {
                Text("Choose what LifeBoard may share. Read access stays private—Apple does not reveal whether you denied a read category.")
                    .font(.subheadline)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                Button("Connect") {
                    educationDomain = .hydration
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
                .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
            }
        }
        .healthWarmCard()
        .lifeboardHealthSyncPulse(trigger: healthSyncPulseTrigger)
    }

    private var metricRings: some View {
        VStack(alignment: .leading, spacing: 12) {
            healthSectionHeader("Today from Apple Health", symbol: "clock")
            HStack(spacing: 12) {
                metricRing(metric: .steps, target: 10_000, label: "Steps")
                metricRing(metric: .activeEnergy, target: 500, label: "Active kcal")
                metricRing(metric: .walkingRunningDistance, target: 5_000, label: "Distance")
            }
        }
        .healthWarmCard()
    }

    private func metricRing(metric: HealthMetric, target: Double, label: String) -> some View {
        let value = store.aggregates[metric]?.value
        return VStack(spacing: 8) {
            Gauge(value: min(value ?? 0, target), in: 0...target) {
                Text(label)
            } currentValueLabel: {
                Text(value.map { metricValue($0, metric: metric) } ?? "—")
                    .font(.caption2.weight(.semibold))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Color.lifeboard(.accentPrimary))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { metricValue($0, metric: metric) } ?? "Unavailable")
    }

    private var hydrationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                healthSectionHeader("Hydration", symbol: "drop.fill")
                Spacer()
                Button("Log water") { showsWaterLog = true }
                    .buttonStyle(.bordered)
            }
            let value = store.aggregates[.water]?.value
            GeometryReader { proxy in
                let progress = min(max((value ?? 0) / 2_000, 0), 1)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.lifeboard(.bgElevated))
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.lifeboard(.accentPrimary).opacity(0.42))
                        .frame(height: proxy.size.height * progress)
                }
            }
            .frame(height: 92)
            .accessibilityHidden(true)
            .lifeboardVitalOrbWarp(trigger: vitalOrbWarpTrigger)
            Text(value.map { "\(Int($0)) mL today · Apple Health + LifeBoard" } ?? "No hydration data available")
                .font(.subheadline)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .healthWarmCard()
    }

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            healthSectionHeader("Nutrition aggregate", symbol: "fork.knife")
            Text("Apple Health entries stay aggregated. LifeBoard never reconstructs them into meals.")
                .font(.caption)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Chart(nutritionValues) { item in
                BarMark(
                    x: .value("Nutrient", item.label),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(Color.lifeboard(.accentSecondary))
            }
            .frame(height: 150)
            .accessibilityHidden(true)
            if let last = store.aggregates[.dietaryEnergy]?.lastSampleAt {
                Text("Last dietary energy: \(last.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
            }
        }
        .healthWarmCard()
    }

    private var accessibleMetricTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            healthSectionHeader("Accessible values", symbol: "tablecells")
            ForEach(store.aggregates.values.sorted { $0.metric.rawValue < $1.metric.rawValue }) { item in
                HStack {
                    Text(metricTitle(item.metric))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(metricValue(item.value, metric: item.metric))
                            .font(.body.monospacedDigit())
                        Text("\(item.sourceLabel) · Today")
                            .font(.caption2)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
                .accessibilityElement(children: .combine)
                Divider()
            }
        }
        .healthWarmCard()
    }

    private var fastingSuggestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            healthSectionHeader("Fasting context", symbol: "hourglass")
            Text("Suggestion only · LifeBoard never auto-starts a fast or writes fasting to Apple Health.")
                .font(.caption)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            if let suggestion = fastingSuggestionDate {
                Text("Suggested start: \(suggestion.formatted(date: .abbreviated, time: .shortened))")
                    .font(.body.weight(.semibold))
                Text(fastingSuggestionSource)
                    .font(.caption)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            } else {
                Text("Log a meal or connect dietary energy to receive a start suggestion.")
                    .font(.subheadline)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .healthWarmCard()
    }

    private var domainConnections: some View {
        VStack(alignment: .leading, spacing: 12) {
            healthSectionHeader("Connections", symbol: "switch.2")
            ForEach(HealthDomain.allCases) { domain in
                let status = store.statuses[domain] ?? .init(domain: domain)
                HStack(spacing: 12) {
                    Image(systemName: domain.symbolName)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(domain.title)
                        Text(domainStatusText(status))
                            .font(.caption)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                    Spacer()
                    if domain.supportsWriteBack {
                        Toggle("", isOn: Binding(
                            get: { status.writeEnabled },
                            set: { enabled in
                                if enabled && status.readRequestState == .neverRequested {
                                    educationDomain = domain
                                } else {
                                    Task { await store.setWriteEnabled(enabled, for: domain) }
                                }
                            }
                        ))
                        .labelsHidden()
                    } else if status.readRequestState == .neverRequested {
                        Button("Connect") { educationDomain = domain }
                            .buttonStyle(.bordered)
                    }
                }
                .frame(minHeight: 48)
            }
            Button("Log weight") { showsWeightLog = true }
                .buttonStyle(.bordered)
        }
        .healthWarmCard()
    }

    private var connectionSubtitle: String {
        if let date = store.lastSuccessfulSync {
            return "Last synced \(date.formatted(date: .omitted, time: .shortened))"
        }
        return store.isRefreshing ? "Syncing…" : "Not synced yet"
    }

    private var nutritionValues: [NutritionChartValue] {
        [
            .init(label: "kcal", value: store.aggregates[.dietaryEnergy]?.value ?? 0),
            .init(label: "Protein", value: store.aggregates[.dietaryProtein]?.value ?? 0),
            .init(label: "Carbs", value: store.aggregates[.dietaryCarbohydrates]?.value ?? 0),
            .init(label: "Fat", value: store.aggregates[.dietaryFat]?.value ?? 0)
        ]
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

    private func domainStatusText(_ status: HealthDomainStatus) -> String {
        if status.hasPartialWriteAuthorization { return "Partially allowed" }
        if status.writeAuthorizations.values.contains(.denied) { return "Writing denied · local logging still works" }
        if status.readRequestState == .neverRequested { return "Not requested" }
        return status.writeEnabled ? "Future LifeBoard entries sync" : "Read only"
    }

    private func metricTitle(_ metric: HealthMetric) -> String {
        metric.rawValue
            .replacingOccurrences(of: "walkingRunning", with: "walking running ")
            .replacingOccurrences(of: "dietary", with: "")
            .replacingOccurrences(of: "body", with: "body ")
            .capitalized
    }

    private func metricValue(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps: "\(Int(value))"
        case .walkingRunningDistance: String(format: "%.1f km", value / 1_000)
        case .water: "\(Int(value)) mL"
        case .bodyMass: String(format: "%.1f kg", value)
        case .bodyFatPercentage: String(format: "%.1f%%", value)
        case .waistCircumference: String(format: "%.1f cm", value)
        case .restingHeartRate: "\(Int(value)) bpm"
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat: String(format: "%.0f g", value)
        case .activeEnergy, .restingEnergy, .dietaryEnergy: "\(Int(value)) kcal"
        default: String(format: "%.1f", value)
        }
    }

    private func healthSectionHeader(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(Color.lifeboard(.textPrimary))
    }
}

private struct NutritionChartValue: Identifiable {
    let label: String
    let value: Double
    var id: String { label }
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

private struct HealthWaterLogSheet: View {
    let repository: CoreDataTrackFoundationRepository
    @State private var amount = "250"
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Milliliters", text: $amount)
                    .keyboardType(.decimalPad)
                if let errorMessage { Text(errorMessage).foregroundStyle(Color.lifeboard(.statusDanger)) }
            }
            .navigationTitle("Log water")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(amount), value > 0 else {
                            errorMessage = "Enter an amount greater than zero."
                            return
                        }
                        Task {
                            do {
                                try await repository.saveHydrationLog(.init(
                                    amount: value,
                                    unit: .milliliters,
                                    source: .manual
                                ))
                                SystemSurfaceRefresher.requestRefreshSoon()
                                dismiss()
                            } catch {
                                errorMessage = "Water could not be saved locally."
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HealthWeightLogSheet: View {
    let repository: any WellnessRepository
    @State private var kilograms = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Kilograms", text: $kilograms)
                    .keyboardType(.decimalPad)
                if let errorMessage { Text(errorMessage).foregroundStyle(Color.lifeboard(.statusDanger)) }
            }
            .navigationTitle("Log weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(kilograms), value > 0,
                              let sample = try? BodyMetricSample(
                                kind: .bodyMass,
                                value: value,
                                unit: .kilograms,
                                source: .manual
                              ) else {
                            errorMessage = "Enter a valid weight."
                            return
                        }
                        Task {
                            do {
                                try await repository.save(sample)
                                SystemSurfaceRefresher.requestRefreshSoon()
                                dismiss()
                            } catch {
                                errorMessage = "Weight could not be saved locally."
                            }
                        }
                    }
                }
            }
        }
    }
}

private extension View {
    func healthWarmCard() -> some View {
        self
            .padding(16)
            .background(Color.lifeboard(.bgElevated), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.lifeboard(.strokeHairline).opacity(0.5), lineWidth: 1)
            }
    }
}
