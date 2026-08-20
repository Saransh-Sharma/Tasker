import Foundation
import SwiftUI

struct EvaContextReceiptSnapshot: Codable, Equatable, Sendable {
    struct CategoryReceipt: Codable, Equatable, Identifiable, Sendable {
        let category: String
        let availability: String
        let includedCount: Int?
        let availableCount: Int?
        let sourceIDs: [String]
        var id: String { category }
    }

    let provider: EvaTurnRuntime.Provider
    let route: EvaCloudRoute
    let timestamp: Date
    let consentRevision: Int
    let configurationVersion: Int
    let categories: [CategoryReceipt]

    static func make(
        runtime: EvaTurnRuntime,
        sections: [EvaCloudContextSection],
        timestamp: Date = Date()
    ) -> EvaContextReceiptSnapshot? {
        guard runtime.usesCloud,
              let consentRevision = runtime.consentRevision,
              let configurationVersion = runtime.configurationVersion else { return nil }
        return EvaContextReceiptSnapshot(
            provider: runtime.provider,
            route: runtime.route,
            timestamp: timestamp,
            consentRevision: consentRevision,
            configurationVersion: configurationVersion,
            categories: sections.map { section in
                let ids = section.metadata?.sourceIDs.isEmpty == false
                    ? section.metadata?.sourceIDs ?? []
                    : section.payload.stableSourceIDs
                return CategoryReceipt(
                    category: section.category.rawValue,
                    availability: section.metadata?.availability ?? "complete",
                    includedCount: section.metadata?.includedCount ?? (ids.isEmpty ? nil : ids.count),
                    availableCount: section.metadata?.availableCount,
                    sourceIDs: ids
                )
            }
        )
    }

    var encodedData: Data? { try? JSONEncoder.evaCloud.encode(self) }
}

struct EvaContextExclusionStore: Codable, Equatable, Sendable {
    private static let defaultsKey = "eva.contextExclusions.v1"
    private(set) var keys: Set<String> = []

    static func load(defaults: UserDefaults = .standard) -> EvaContextExclusionStore {
        guard let data = defaults.data(forKey: defaultsKey),
              let store = try? JSONDecoder().decode(EvaContextExclusionStore.self, from: data) else {
            return EvaContextExclusionStore()
        }
        return store
    }

    mutating func exclude(
        category: String,
        sourceID: String,
        defaults: UserDefaults = .standard
    ) {
        keys.insert(Self.key(category: category, sourceID: sourceID))
        persist(defaults: defaults)
    }

    mutating func restore(
        category: String,
        sourceID: String,
        defaults: UserDefaults = .standard
    ) {
        keys.remove(Self.key(category: category, sourceID: sourceID))
        persist(defaults: defaults)
    }

    func contains(category: String, sourceID: String) -> Bool {
        keys.contains(Self.key(category: category, sourceID: sourceID))
    }

    func filtering(_ section: EvaCloudContextSection) -> EvaCloudContextSection {
        let category = section.category.rawValue
        let originalIDs = section.payload.stableSourceIDs
        let filteredPayload = section.payload.excludingRecords {
            contains(category: category, sourceID: $0)
        }
        let includedIDs = filteredPayload.stableSourceIDs
        let removedAnyRecord = includedIDs.count < originalIDs.count
        let originalMetadata = section.metadata
        return EvaCloudContextSection(
            category: section.category,
            payload: filteredPayload.removingRenderedOverview(if: removedAnyRecord && section.category == .planning),
            metadata: originalMetadata.map {
                EvaContextSectionMetadata(
                    availability: removedAnyRecord ? "partial" : $0.availability,
                    availableCount: $0.availableCount ?? originalIDs.count,
                    includedCount: includedIDs.count,
                    partialReasons: removedAnyRecord
                        ? Array(Set($0.partialReasons + ["userExcludedRecords"])).sorted()
                        : $0.partialReasons,
                    sourceIDs: includedIDs
                )
            }
        )
    }

    private static func key(category: String, sourceID: String) -> String { "\(category)|\(sourceID)" }

    private func persist(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
    }
}

private extension EvaJSONValue {
    var stableSourceIDs: [String] {
        switch self {
        case .object(let object):
            let own = [object["id"], object["reference"]].compactMap { value -> String? in
                if case .string(let id) = value { return id }
                return nil
            }
            return Array(Set(own + object.values.flatMap { $0.stableSourceIDs })).sorted()
        case .array(let values):
            return Array(Set(values.flatMap { $0.stableSourceIDs })).sorted()
        default:
            return []
        }
    }

    func excludingRecords(where excluded: (String) -> Bool) -> EvaJSONValue {
        switch self {
        case .object(let object):
            let sourceID = [object["id"], object["reference"]].compactMap { value -> String? in
                if case .string(let id) = value { return id }
                return nil
            }.first
            if let sourceID, excluded(sourceID) { return .null }
            return .object(object.mapValues { $0.excludingRecords(where: excluded) })
        case .array(let values):
            return .array(values.map { $0.excludingRecords(where: excluded) }.filter { $0 != .null })
        default: return self
        }
    }

    func removingRenderedOverview(if shouldRemove: Bool) -> EvaJSONValue {
        guard shouldRemove, case .object(var object) = self else { return self }
        object["renderedOverview"] = .null
        return .object(object)
    }
}

struct EvaContextReceiptSheet: View {
    let receipt: EvaContextReceiptSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var exclusions = EvaContextExclusionStore.load()
    @State private var account = EvaCloudAccountState.shared
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Request") {
                    LabeledContent("Provider", value: "Cloud EVA")
                    LabeledContent("Route", value: receipt.route.rawValue)
                    LabeledContent("Sent", value: receipt.timestamp.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Consent revision", value: String(receipt.consentRevision))
                }
                ForEach(receipt.categories) { category in
                    Section(category.category.capitalized) {
                        LabeledContent("Availability", value: category.availability.capitalized)
                        if let included = category.includedCount {
                            LabeledContent("Records included", value: String(included))
                        }
                        if category.sourceIDs.isEmpty {
                            Text("No record identifiers were included in this section.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(category.sourceIDs, id: \.self) { sourceID in
                                sourceRow(category: category.category, sourceID: sourceID)
                            }
                        }
                        if let grant = EvaConsentPolicy.Grant(rawValue: category.category) {
                            Button("Turn off \(category.category.capitalized) for future turns") {
                                updateGrant(grant, enabled: false)
                            }
                        }
                    }
                }
                Section {
                    Text("These controls affect future EVA requests only. Excluding a record never deletes it from LifeBoard.")
                        .foregroundStyle(.secondary)
                    NavigationLink("EVA privacy and consent settings") {
                        EvaCloudSettingsView()
                    }
                }
            }
            .navigationTitle("Context used")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("EVA privacy", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func sourceRow(category: String, sourceID: String) -> some View {
        let isExcluded = exclusions.contains(category: category, sourceID: sourceID)
        return HStack {
            Text("\(category.capitalized) record •\(sourceID.suffix(4))")
            Spacer()
            Button(isExcluded ? "Undo" : "Don't use") {
                if isExcluded {
                    exclusions.restore(category: category, sourceID: sourceID)
                    Task { await ProductTelemetry.shared.record(.contextSourceRestored) }
                } else {
                    exclusions.exclude(category: category, sourceID: sourceID)
                    Task { await ProductTelemetry.shared.record(.contextSourceExcluded) }
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private func updateGrant(_ grant: EvaConsentPolicy.Grant, enabled: Bool) {
        Task { @MainActor in
            guard let consent = account.consent else { return }
            var grants = Set(consent.grants)
            if enabled { grants.insert(grant) } else { grants.remove(grant) }
            do {
                _ = try await EvaCloudTransport.shared.updateConsent(
                    expectedRevision: consent.revision,
                    grants: Array(grants)
                )
                await account.refresh()
                await ProductTelemetry.shared.record(.contextConsentChanged, outcome: enabled ? "enabled" : "disabled")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
