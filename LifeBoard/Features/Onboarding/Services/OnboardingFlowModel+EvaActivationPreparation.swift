import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension OnboardingFlowModel {
    func startEvaPreparation(modelName: String) async {
        guard LLMRuntimeSupportMatrix.compatibility(for: modelName)?.canActivate == true else {
            deferEvaPreparationForUnsupportedRuntime(modelName: modelName)
            return
        }

        evaPreparationState.phase = .downloading
        evaPreparationState.progress = 0
        evaPreparationState.statusMessage = "Getting your assistant ready in the background."
        evaProgressObservationTask?.cancel()
        evaProgressObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while Task.isCancelled == false, self.evaPreparationState.phase == .downloading {
                self.evaPreparationState.progress = LLMRuntimeCoordinator.shared.evaluator.progress
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        let preferred = modelName
        let fastFallback = ModelConfiguration.qwen_3_0_6b_4bit.name
        let didSwitchPreferred = await LLMRuntimeCoordinator.shared.switchModelIfNeeded(modelName: preferred)
        let didSwitchFallback = if preferred != fastFallback,
                                   LLMRuntimeSupportMatrix.compatibility(for: fastFallback)?.canActivate == true {
            await LLMRuntimeCoordinator.shared.switchModelIfNeeded(modelName: fastFallback)
        } else {
            false
        }
        let switched = didSwitchPreferred || didSwitchFallback

        evaProgressObservationTask?.cancel()
        evaProgressObservationTask = nil

        if switched {
            let resolvedModelName = didSwitchPreferred ? preferred : fastFallback
            evaAppManager.addInstalledModel(resolvedModelName)
            evaAppManager.setActiveModel(resolvedModelName)
            evaPreparationState.phase = .ready
            evaPreparationState.selectedModelName = resolvedModelName
            evaPreparationState.progress = 1
            evaPreparationState.statusMessage = "\(selectedMascotPersona.displayName) is ready."
        } else {
            evaPreparationState.phase = .failed
            evaPreparationState.statusMessage = "\(selectedMascotPersona.displayName) setup can finish later from Home."
        }
        persistJourney()
    }

    func recommendedEvaModelName() -> String? {
        let smarter = ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name
        if LLMRuntimeSupportMatrix.compatibility(for: smarter)?.canActivate == true {
            return smarter
        }
        let fast = ModelConfiguration.qwen_3_0_6b_4bit.name
        if LLMRuntimeSupportMatrix.compatibility(for: fast)?.canActivate == true {
            return fast
        }
        return nil
    }

    func deferEvaPreparationForUnsupportedRuntime(modelName: String? = nil) {
        evaProgressObservationTask?.cancel()
        evaProgressObservationTask = nil
        evaPreparationState.phase = .deferred
        evaPreparationState.progress = 0
        evaPreparationState.selectedModelName = modelName
        let reason = modelName.flatMap { LLMRuntimeSupportMatrix.compatibility(for: $0)?.statusReason }
        evaPreparationState.statusMessage = reason ?? "\(selectedMascotPersona.displayName) setup can finish on a compatible device."
        persistJourney()
    }

    func detectNetworkClass() async -> OnboardingNetworkClass {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "lifeboard.onboarding.network")
            monitor.pathUpdateHandler = { path in
                let resolved: OnboardingNetworkClass
                if path.status != .satisfied {
                    resolved = .unavailable
                } else if path.usesInterfaceType(.cellular) || path.isExpensive {
                    resolved = .cellular
                } else {
                    resolved = .wifi
                }
                monitor.cancel()
                continuation.resume(returning: resolved)
            }
            monitor.start(queue: queue)
        }
    }

    func persistEvaActivationCompletion() {
        var activationState = EvaActivationState()
        activationState.selectedWorkingStyleIDs = evaProfileDraft.selectedWorkingStyleIDs
        activationState.selectedMomentumBlockerIDs = evaProfileDraft.selectedMomentumBlockerIDs
        activationState.goals = evaProfileDraft.goals.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        activationState.chosenModelName = evaPreparationState.selectedModelName
        activationState.installedChosenModel = evaPreparationState.phase == .ready
        activationState.preparedModelName = evaPreparationState.phase == .ready ? evaPreparationState.selectedModelName : nil
        activationState.hasTriggeredInstall = evaPreparationState.phase == .ready || evaPreparationState.phase == .downloading
        activationState.stage = .completed
        activationState.isComplete = true
        EvaActivationDefaultsStore.save(activationState, defaults: evaDefaults)
    }

    func project(for task: TaskDefinition) -> Project? {
        resolvedProjects.first(where: { $0.project.id == task.projectID })?.project
    }

    func projectName(for task: TaskDefinition) -> String? {
        project(for: task)?.name ?? task.projectName
    }
}
