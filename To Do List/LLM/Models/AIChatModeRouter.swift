import Foundation
import MLXLMCommon
#if os(iOS)
import UIKit
#endif

enum AIFeatureRoute {
    case addTaskSuggestion
    case dynamicChips
    case dailyBrief
    case planMode
    case topThree
    case breakdown
}

struct AIModelRoute {
    let selectedModelName: String?
    let idealModelName: String
    let fallbackReason: String?
    let usedFallback: Bool
    let idealModelSizeGB: Decimal?
    let selectedModelSizeGB: Decimal?
    let shouldPromptDownload: Bool
    let bannerMessage: String?
}

struct AIRuntimeSnapshot {
    let selectedModelName: String?
    let installedModels: [String]
    let availableMemoryGB: Double
    let userInterfaceIdiom: AppManager.LayoutType

    static func current(defaults: UserDefaults = .standard) -> AIRuntimeSnapshot {
        let persistedState = LLMPersistedModelSelection.normalize(defaults: defaults)

        #if os(visionOS)
        let layout: AppManager.LayoutType = .vision
        #elseif os(macOS)
        let layout: AppManager.LayoutType = .mac
        #elseif os(iOS)
        let layout: AppManager.LayoutType = UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #else
        let layout: AppManager.LayoutType = .unknown
        #endif

        return AIRuntimeSnapshot(
            selectedModelName: persistedState.currentModelName,
            installedModels: persistedState.installedModels,
            availableMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024),
            userInterfaceIdiom: layout
        )
    }

    static func from(appManager: AppManager) -> AIRuntimeSnapshot {
        AIRuntimeSnapshot(
            selectedModelName: appManager.currentModelName,
            installedModels: appManager.installedModels,
            availableMemoryGB: appManager.availableMemory,
            userInterfaceIdiom: appManager.userInterfaceIdiom
        )
    }
}

struct AIChatModeRouter {
    static func route(for feature: AIFeatureRoute, snapshot: AIRuntimeSnapshot = .current()) -> AIModelRoute {
        let ideal = idealModelName(for: feature)
        let installed = Set(snapshot.installedModels)
        let idealSize = ModelConfiguration.getModelByName(ideal)?.modelSize

        if let selectedModelName = snapshot.selectedModelName,
           installed.contains(selectedModelName),
           LLMRuntimeSupportMatrix.compatibility(for: selectedModelName)?.canActivate == true,
           isAllowedByDeviceBudget(modelName: selectedModelName, snapshot: snapshot) {
            let selectedSize = ModelConfiguration.getModelByName(selectedModelName)?.modelSize
            let usedFallback = selectedModelName != ideal
            return AIModelRoute(
                selectedModelName: selectedModelName,
                idealModelName: ideal,
                fallbackReason: usedFallback ? "active_model_differs_from_default" : nil,
                usedFallback: usedFallback,
                idealModelSizeGB: idealSize,
                selectedModelSizeGB: selectedSize,
                shouldPromptDownload: installed.isEmpty,
                bannerMessage: usedFallback ? "Using \(displayName(for: selectedModelName)) across all AI features." : nil
            )
        }

        if installed.contains(ideal),
           LLMRuntimeSupportMatrix.compatibility(for: ideal)?.canActivate == true,
           isAllowedByDeviceBudget(modelName: ideal, snapshot: snapshot) {
            let selectedSize = ModelConfiguration.getModelByName(ideal)?.modelSize
            return AIModelRoute(
                selectedModelName: ideal,
                idealModelName: ideal,
                fallbackReason: nil,
                usedFallback: false,
                idealModelSizeGB: idealSize,
                selectedModelSizeGB: selectedSize,
                shouldPromptDownload: false,
                bannerMessage: nil
            )
        }

        let fallbackCandidates = ModelConfiguration.availableModels.map(\.name).filter { $0 != ideal }
        if let fallback = fallbackCandidates.first(where: {
            installed.contains($0)
                && LLMRuntimeSupportMatrix.compatibility(for: $0)?.canActivate == true
                && isAllowedByDeviceBudget(modelName: $0, snapshot: snapshot)
        }) {
            return AIModelRoute(
                selectedModelName: fallback,
                idealModelName: ideal,
                fallbackReason: "default_model_unavailable",
                usedFallback: true,
                idealModelSizeGB: idealSize,
                selectedModelSizeGB: ModelConfiguration.getModelByName(fallback)?.modelSize,
                shouldPromptDownload: installed.isEmpty,
                bannerMessage: "Using \(displayName(for: fallback)) because the default model is unavailable."
            )
        }

        return AIModelRoute(
            selectedModelName: nil,
            idealModelName: ideal,
            fallbackReason: "no_supported_model_installed",
            usedFallback: true,
            idealModelSizeGB: idealSize,
            selectedModelSizeGB: nil,
            shouldPromptDownload: installed.isEmpty,
            bannerMessage: installed.isEmpty
                ? "Install a local model to use AI features."
                : "Installed models are unavailable on this device."
        )
    }

    static func route(for feature: AIFeatureRoute, appManager: AppManager) -> AIModelRoute {
        route(for: feature, snapshot: .from(appManager: appManager))
    }

    static func idealModelName(for feature: AIFeatureRoute) -> String {
        _ = feature
        return ModelConfiguration.defaultModel.name
    }

    private static func isAllowedByDeviceBudget(
        modelName: String,
        snapshot: AIRuntimeSnapshot
    ) -> Bool {
        guard let size = ModelConfiguration.getModelByName(modelName)?.modelSize else {
            return false
        }
        let maximum = maxSupportedModelSizeGB(for: snapshot)
        return size <= maximum
    }

    private static func maxSupportedModelSizeGB(for snapshot: AIRuntimeSnapshot) -> Decimal {
        let available = snapshot.availableMemoryGB
        let memoryBudget: Decimal
        if available < 4 {
            memoryBudget = 0.5
        } else if available < 6 {
            memoryBudget = 0.7
        } else {
            memoryBudget = 1.2
        }

        if snapshot.userInterfaceIdiom == .phone {
            return min(memoryBudget, 0.8)
        }
        return memoryBudget
    }

    static func displayName(for modelName: String) -> String {
        ModelConfiguration.getModelByName(modelName)?.displayName
            ?? modelName
                .replacingOccurrences(of: "mlx-community/", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "NexVeridian/", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Jackrong/", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Prism-ML/", with: "", options: .caseInsensitive)
    }
}
