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
    let fastModeEnabled: Bool

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
            userInterfaceIdiom: layout,
            fastModeEnabled: V2FeatureFlags.assistantFastModeEnabled
        )
    }

    static func from(appManager: AppManager) -> AIRuntimeSnapshot {
        AIRuntimeSnapshot(
            selectedModelName: appManager.currentModelName,
            installedModels: appManager.installedModels,
            availableMemoryGB: appManager.availableMemory,
            userInterfaceIdiom: appManager.userInterfaceIdiom,
            fastModeEnabled: V2FeatureFlags.assistantFastModeEnabled
        )
    }
}

struct AIChatModeRouter {
    /// Executes route.
    static func route(for feature: AIFeatureRoute, snapshot: AIRuntimeSnapshot = .current()) -> AIModelRoute {
        let ideal = idealModelName(for: feature, fastModeEnabled: snapshot.fastModeEnabled)
        let preferredFallbacks = fallbackCandidates(for: feature, fastModeEnabled: snapshot.fastModeEnabled)
        let installed = Set(snapshot.installedModels)
        let maxModelSize = maxSupportedModelSizeGB(for: snapshot)
        let idealConfig = ModelConfiguration.getModelByName(ideal)
        let idealSize = idealConfig?.modelSize
        let canUseIdeal = isAllowedByDeviceBudget(modelName: ideal, maxModelSize: maxModelSize)

        if installed.contains(ideal), canUseIdeal {
            return AIModelRoute(
                selectedModelName: ideal,
                idealModelName: ideal,
                fallbackReason: nil,
                usedFallback: false,
                idealModelSizeGB: idealSize,
                selectedModelSizeGB: idealSize,
                shouldPromptDownload: false,
                bannerMessage: nil
            )
        }

        if let fallback = preferredFallbacks.first(where: {
            installed.contains($0) && isAllowedByDeviceBudget(modelName: $0, maxModelSize: maxModelSize)
        }) {
            let fallbackSize = ModelConfiguration.getModelByName(fallback)?.modelSize
            let reason: String
            if installed.contains(ideal) && !canUseIdeal {
                reason = "ideal_model_memory_constrained"
            } else {
                reason = "ideal_model_not_installed"
            }
            return AIModelRoute(
                selectedModelName: fallback,
                idealModelName: ideal,
                fallbackReason: reason,
                usedFallback: true,
                idealModelSizeGB: idealSize,
                selectedModelSizeGB: fallbackSize,
                shouldPromptDownload: !installed.contains(ideal) && canUseIdeal,
                bannerMessage: fallbackBanner(
                    selectedModelName: fallback,
                    idealModelName: ideal,
                    idealModelSizeGB: idealSize,
                    shouldPromptDownload: !installed.contains(ideal) && canUseIdeal
                )
            )
        }

        if let current = snapshot.selectedModelName,
           isAllowedByDeviceBudget(modelName: current, maxModelSize: maxModelSize) {
            let currentSize = ModelConfiguration.getModelByName(current)?.modelSize
            return AIModelRoute(
                selectedModelName: current,
                idealModelName: ideal,
                fallbackReason: "using_current_model",
                usedFallback: true,
                idealModelSizeGB: idealSize,
                selectedModelSizeGB: currentSize,
                shouldPromptDownload: !installed.contains(ideal) && canUseIdeal,
                bannerMessage: fallbackBanner(
                    selectedModelName: current,
                    idealModelName: ideal,
                    idealModelSizeGB: idealSize,
                    shouldPromptDownload: !installed.contains(ideal) && canUseIdeal
                )
            )
        }

        return AIModelRoute(
            selectedModelName: nil,
            idealModelName: ideal,
            fallbackReason: "no_model_available",
            usedFallback: true,
            idealModelSizeGB: idealSize,
            selectedModelSizeGB: nil,
            shouldPromptDownload: canUseIdeal,
            bannerMessage: noModelBanner(
                idealModelName: ideal,
                idealModelSizeGB: idealSize,
                shouldPromptDownload: canUseIdeal
            )
        )
    }

    /// Executes route.
    static func route(for feature: AIFeatureRoute, appManager: AppManager) -> AIModelRoute {
        route(for: feature, snapshot: .from(appManager: appManager))
    }

    /// Executes idealModelName.
    static func idealModelName(for feature: AIFeatureRoute, fastModeEnabled: Bool) -> String {
        switch feature {
        case .addTaskSuggestion, .dynamicChips, .dailyBrief:
            return ModelConfiguration.qwen_3_0_6b_4bit.name
        case .planMode:
            return ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name
        case .topThree, .breakdown:
            if fastModeEnabled {
                return ModelConfiguration.qwen_3_0_6b_4bit.name
            }
            return ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name
        }
    }

    /// Executes fallbackCandidates.
    static func fallbackCandidates(for feature: AIFeatureRoute, fastModeEnabled: Bool) -> [String] {
        switch feature {
        case .addTaskSuggestion, .dynamicChips, .dailyBrief:
            return [
                ModelConfiguration.qwen_3_0_6b_4bit.name,
                ModelConfiguration.llama_3_2_1b_4bit.name,
                ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name,
                ModelConfiguration.llama_3_2_3b_4bit.name,
                ModelConfiguration.qwen_3_4b_4bit.name
            ]
        case .planMode:
            return [
                ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name,
                ModelConfiguration.qwen_3_0_6b_4bit.name,
                ModelConfiguration.llama_3_2_1b_4bit.name,
                ModelConfiguration.llama_3_2_3b_4bit.name,
                ModelConfiguration.qwen_3_4b_4bit.name
            ]
        case .topThree, .breakdown:
            if fastModeEnabled {
                return [
                    ModelConfiguration.qwen_3_0_6b_4bit.name,
                    ModelConfiguration.llama_3_2_1b_4bit.name,
                    ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name,
                    ModelConfiguration.llama_3_2_3b_4bit.name,
                    ModelConfiguration.qwen_3_4b_4bit.name
                ]
            }
            return [
                ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name,
                ModelConfiguration.llama_3_2_1b_4bit.name,
                ModelConfiguration.qwen_3_0_6b_4bit.name,
                ModelConfiguration.llama_3_2_3b_4bit.name,
                ModelConfiguration.qwen_3_4b_4bit.name
            ]
        }
    }

    /// Executes maxSupportedModelSizeGB.
    private static func maxSupportedModelSizeGB(for snapshot: AIRuntimeSnapshot) -> Decimal {
        let available = snapshot.availableMemoryGB
        let memoryBudget: Decimal
        if available < 4 {
            memoryBudget = 1.0
        } else if available < 6 {
            memoryBudget = 2.3
        } else {
            memoryBudget = 4.7
        }

        if snapshot.userInterfaceIdiom == .phone {
            return min(memoryBudget, 2.3)
        }
        return memoryBudget
    }

    /// Executes isAllowedByDeviceBudget.
    private static func isAllowedByDeviceBudget(
        modelName: String,
        maxModelSize: Decimal
    ) -> Bool {
        guard let size = ModelConfiguration.getModelByName(modelName)?.modelSize else {
            return true
        }
        return size <= maxModelSize
    }

    /// Executes fallbackBanner.
    private static func fallbackBanner(
        selectedModelName: String,
        idealModelName: String,
        idealModelSizeGB: Decimal?,
        shouldPromptDownload: Bool
    ) -> String {
        let selected = displayName(for: selectedModelName)
        guard shouldPromptDownload else {
            return "Using \(selected) for this AI action."
        }
        let ideal = displayName(for: idealModelName)
        let sizeText = idealModelSizeGB.map { " (\(format(sizeGB: $0)) GB)" } ?? ""
        return "Using \(selected) for now. For best results, install \(ideal)\(sizeText)."
    }

    /// Executes noModelBanner.
    private static func noModelBanner(
        idealModelName: String,
        idealModelSizeGB: Decimal?,
        shouldPromptDownload: Bool
    ) -> String {
        let ideal = displayName(for: idealModelName)
        let sizeText = idealModelSizeGB.map { " (\(format(sizeGB: $0)) GB)" } ?? ""
        if shouldPromptDownload {
            return "No compatible model selected. Install \(ideal)\(sizeText) to use this AI action."
        }
        return "No compatible model available for this device profile."
    }

    /// Executes displayName.
    private static func displayName(for modelName: String) -> String {
        modelName.replacingOccurrences(of: "mlx-community/", with: "")
    }

    /// Executes format.
    private static func format(sizeGB: Decimal) -> String {
        NSDecimalNumber(decimal: sizeGB).stringValue
    }
}
