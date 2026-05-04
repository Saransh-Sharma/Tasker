import MLXLMCommon
import SwiftUI

enum LLMCatalogSectionKind: CaseIterable, Identifiable {
    case availableNow
    case additionalTextModels

    var id: Self { self }

    var title: String {
        switch self {
        case .availableNow:
            return "available now"
        case .additionalTextModels:
            return "additional text models"
        }
    }
}

struct LLMCatalogEntry: Identifiable {
    let model: ModelConfiguration
    let compatibility: LLMModelCompatibilityResult
    let isInstalled: Bool

    var id: String { model.name }

    var isSelectable: Bool {
        compatibility.canInstall && !isInstalled
    }

    var sectionKind: LLMCatalogSectionKind {
        switch model.metadata.tier {
        case .default, .smarter:
            return .availableNow
        case .experimental:
            return .additionalTextModels
        }
    }
}

struct LLMCatalogSection: Identifiable {
    let kind: LLMCatalogSectionKind
    let entries: [LLMCatalogEntry]

    var id: LLMCatalogSectionKind { kind }
}

struct LocalModelInstallCatalog {
    let entries: [LLMCatalogEntry]

    static func make(installedModelNames: [String]) -> Self {
        let installedSet = Set(installedModelNames)
        let entries = ModelConfiguration.availableModels.map { model in
            LLMCatalogEntry(
                model: model,
                compatibility: LLMRuntimeSupportMatrix.compatibility(for: model),
                isInstalled: installedSet.contains(model.name)
            )
        }
        return Self(entries: entries)
    }

    var installedEntries: [LLMCatalogEntry] {
        entries.filter(\.isInstalled)
    }

    var selectableModels: [ModelConfiguration] {
        entries.filter(\.isSelectable).map(\.model)
    }

    var sections: [LLMCatalogSection] {
        LLMCatalogSectionKind.allCases.compactMap { kind in
            let groupedEntries = entries.filter { $0.sectionKind == kind && $0.isInstalled == false }
            guard groupedEntries.isEmpty == false else { return nil }
            return LLMCatalogSection(kind: kind, entries: groupedEntries)
        }
    }
}

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var deviceSupportsMetal3 = true
    @Binding var showOnboarding: Bool
    @State private var selectedModelNames: Set<String> = [ModelConfiguration.defaultModel.name]

    private var catalog: LocalModelInstallCatalog {
        LocalModelInstallCatalog.make(
            installedModelNames: appManager.installedModels
        )
    }

    private var selectedModels: [ModelConfiguration] {
        catalog.selectableModels.filter { selectedModelNames.contains($0.name) }
    }

    private var canInstall: Bool {
        selectedModels.isEmpty == false
    }

    var body: some View {
        ZStack {
            if deviceSupportsMetal3 {
                content
                    .task {
                        syncSelection()
                    }
            } else {
                DeviceNotSupportedView()
            }
        }
        .onAppear {
            checkMetal3Support()
        }
    }

    private var content: some View {
        Form {
            Section {
                VStack(spacing: LifeBoardTheme.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.lifeboard(.accentWash))
                            .frame(width: 80, height: 80)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Color.lifeboard(.accentPrimary))
                    }

                    VStack(spacing: LifeBoardTheme.Spacing.xs) {
                        Text("choose your local models")
                            .font(.lifeboard(.title1))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text("install one or more local models for chat. qwen3 0.6b stays the default, qwen 3.5 improves quality, and bonsai 1.7b 1-bit is available as an experimental tiny-footprint option.")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, LifeBoardTheme.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            if catalog.installedEntries.isEmpty == false {
                Section("installed") {
                    ForEach(catalog.installedEntries) { entry in
                        InstalledModelStatusRow(entry: entry)
                    }
                }
            }

            ForEach(catalog.sections) { section in
                Section(section.kind.title) {
                    ForEach(section.entries) { entry in
                        LLMModelOptionCard(
                            entry: entry,
                            isSelected: selectedModelNames.contains(entry.model.name)
                        ) {
                            toggleSelection(for: entry)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
            }

            #if os(macOS)
            Section {} footer: {
                NavigationLink(
                    destination: OnboardingDownloadingModelProgressView(
                        showOnboarding: $showOnboarding,
                        selectedModels: selectedModels
                    )
                ) {
                    Text("install selected models")
                }
                .disabled(!canInstall)
            }
            #endif
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.lifeboard(.bgCanvas))
        .accessibilityIdentifier("llm.modelPicker.view")
        #if os(iOS) || os(visionOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(
                    destination: OnboardingDownloadingModelProgressView(
                        showOnboarding: $showOnboarding,
                        selectedModels: selectedModels
                    )
                ) {
                    Text("install")
                        .font(.lifeboard(.button))
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                }
                .disabled(!canInstall)
            }
        }
        .listStyle(.insetGrouped)
        #endif
    }

    private func toggleSelection(for entry: LLMCatalogEntry) {
        guard entry.isSelectable else { return }
        if selectedModelNames.contains(entry.model.name) {
            selectedModelNames.remove(entry.model.name)
        } else {
            selectedModelNames.insert(entry.model.name)
        }
    }

    private func syncSelection() {
        let selectableNames = Set(catalog.selectableModels.map(\.name))
        selectedModelNames = selectedModelNames.intersection(selectableNames)
        if selectedModelNames.isEmpty,
           let defaultInstall = catalog.selectableModels.first(where: { $0 == .defaultModel }) ?? catalog.selectableModels.first {
            selectedModelNames = [defaultInstall.name]
        }
    }

    private func checkMetal3Support() {
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
        #endif
    }
}

private struct InstalledModelStatusRow: View {
    let entry: LLMCatalogEntry

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.lifeboard(.accentPrimary))
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                Text(entry.model.displayName.lowercased())
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                if let statusReason = entry.compatibility.statusReason,
                   entry.compatibility.canActivate == false {
                    Text(statusReason)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
            }
            Spacer()
            Text(entry.compatibility.statusBadgeTitle ?? "installed")
                .font(.lifeboard(.caption1))
                .foregroundStyle(entry.compatibility.canActivate ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.statusWarning))
        }
    }
}

private struct LLMModelOptionCard: View {
    let entry: LLMCatalogEntry
    let isSelected: Bool
    let action: () -> Void

    private var sizeLabel: String {
        "\(entry.model.modelSize.map { NSDecimalNumber(decimal: $0).stringValue } ?? "?") GB"
    }

    private var isDisabled: Bool {
        entry.isSelectable == false
    }

    private var badgeTitle: String {
        entry.compatibility.statusBadgeTitle ?? entry.model.onboardingBadgeTitle
    }

    private var isDefaultModel: Bool {
        entry.model.name == ModelConfiguration.defaultModel.name
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
                HStack(spacing: LifeBoardTheme.Spacing.sm) {
                    Image(systemName: isDisabled ? "minus.circle" : (isSelected ? "checkmark.circle.fill" : "circle"))
                        .font(.title3)
                        .foregroundStyle(isDisabled ? Color.lifeboard(.textQuaternary) : (isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.textQuaternary)))

                    Text(entry.model.displayName)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))

                    Spacer()

                    Text(badgeTitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(isDisabled ? Color.lifeboard(.statusWarning) : Color.lifeboard(.accentPrimary))
                        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                        .padding(.vertical, LifeBoardTheme.Spacing.xs)
                        .background(isDisabled ? Color.lifeboard(.accentWash) : Color.lifeboard(.accentWash))
                        .clipShape(Capsule())
                        .accessibilityIdentifier(isDefaultModel ? "llm.modelPicker.recommendedBadge" : "")
                }

                Text(entry.model.shortDescription)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .multilineTextAlignment(.leading)

                if let statusReason = entry.compatibility.statusReason,
                   isDisabled {
                    Text(statusReason)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.statusWarning))
                } else {
                    Text(entry.model.onboardingSubtitle)
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard(.textQuaternary))
                }

                HStack {
                    Text(sizeLabel)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                    Spacer()
                    if entry.model.sourceModelID != nil {
                        Text("converted MLX equivalent")
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color.lifeboard(.textQuaternary))
                    }
                }
            }
            .padding(LifeBoardTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous)
                    .fill(isSelected ? Color.lifeboard(.accentWash) : Color.lifeboard(.bgElevated))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous)
                    .stroke(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.borderSubtle), lineWidth: 1)
            )
            .opacity(isDisabled ? 0.78 : 1)
        }
        .disabled(isDisabled)
        .accessibilityIdentifier(isDefaultModel ? "llm.modelPicker.recommendedRow" : "")
        .accessibilityValue(isSelected ? "selected" : "unselected")
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
    }
}

#Preview {
    NavigationStack {
        OnboardingInstallModelView(showOnboarding: .constant(true))
            .environmentObject(AppManager())
    }
}
