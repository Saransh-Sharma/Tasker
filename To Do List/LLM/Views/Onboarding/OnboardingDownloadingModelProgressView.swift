import MLXLMCommon
import SwiftUI

struct OnboardingDownloadingModelProgressView: View {
    private enum InstallOutcome: Equatable {
        case installing
        case success
        case partialFailure
        case failed
    }

    @Binding var showOnboarding: Bool
    @EnvironmentObject var appManager: AppManager
    let selectedModels: [ModelConfiguration]
    @Environment(LLMEvaluator.self) var llm

    @State private var completedModelNames: [String] = []
    @State private var failedModelNames: [String] = []
    @State private var currentModelName: String?
    @State private var installStarted = false

    private var currentModel: ModelConfiguration? {
        guard let currentModelName else { return nil }
        return ModelConfiguration.getModelByName(currentModelName)
    }

    private var totalCount: Int {
        max(1, selectedModels.count)
    }

    private var completedCount: Int {
        min(completedModelNames.count, totalCount)
    }

    private var overallProgress: Double {
        let unit = Double(completedCount) / Double(totalCount)
        let partial = (selectedModels.count > completedCount && currentModelName != nil) ? (llm.progress / Double(totalCount)) : 0
        return min(1, unit + partial)
    }

    private var installOutcome: InstallOutcome {
        guard installStarted else { return .installing }
        if currentModelName != nil {
            return .installing
        }
        if completedModelNames.count == selectedModels.count, selectedModels.isEmpty == false {
            return .success
        }
        if completedModelNames.isEmpty == false {
            return .partialFailure
        }
        return .failed
    }

    private var canContinue: Bool {
        switch installOutcome {
        case .success, .partialFailure:
            return true
        case .installing, .failed:
            return false
        }
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: TaskerTheme.Spacing.xxxl) {
                MoonAnimationView(isDone: canContinue)

                VStack(spacing: TaskerTheme.Spacing.xs) {
                    Text(titleText)
                        .font(.tasker(.title1))
                        .foregroundColor(Color.tasker(.textPrimary))
                    Text(statusSubtitle)
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker(.textSecondary))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: TaskerTheme.Spacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill)
                                .fill(Color.tasker(.surfaceTertiary))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill)
                                .fill(Color.tasker(.accentPrimary))
                                .frame(width: geo.size.width * overallProgress, height: 8)
                                .animation(TaskerAnimation.gentle, value: overallProgress)
                        }
                    }
                    .frame(height: 8)

                    Text(progressLabel)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.textTertiary))
                        .monospacedDigit()
                }
                .padding(.horizontal, 48)
            }

            Spacer()

            if canContinue {
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    Button(action: { showOnboarding = false }) {
                        Text("done")
                            #if os(iOS) || os(visionOS)
                            .font(.tasker(.button))
                            .foregroundColor(Color.tasker(.accentOnPrimary))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.tasker(.accentPrimary))
                            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous))
                            #endif
                    }
                    #if os(macOS)
                    .buttonStyle(.borderedProminent)
                    #endif
                    .scaleOnPress()

                    if failedModelNames.isEmpty == false {
                        Button(action: retryFailedModels) {
                            Text("retry failed downloads")
                                #if os(iOS) || os(visionOS)
                                .font(.tasker(.button))
                                .foregroundColor(Color.tasker(.accentPrimary))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.tasker(.accentWash))
                                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous))
                                #endif
                        }
                        #if os(macOS)
                        .buttonStyle(.bordered)
                        #endif
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.xl)
            } else {
                Text("keep this screen open while the selected models install in sequence.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.textQuaternary))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TaskerTheme.Spacing.xl)
                if installOutcome == .failed {
                    Button(action: retryFailedModels) {
                        Text("retry downloads")
                            #if os(iOS) || os(visionOS)
                            .font(.tasker(.button))
                            .foregroundColor(Color.tasker(.accentOnPrimary))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.tasker(.accentPrimary))
                            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous))
                            #endif
                    }
                    #if os(macOS)
                    .buttonStyle(.borderedProminent)
                    #endif
                    .padding(.horizontal, TaskerTheme.Spacing.xl)
                }
            }
        }
        .padding()
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("downloading AI models..")
        .toolbar(canContinue ? .hidden : .visible)
        .navigationBarBackButtonHidden()
        .task {
            await installSelectedModelsIfNeeded()
        }
        .onChange(of: canContinue) {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        .interactiveDismissDisabled(!canContinue)
        #if os(iOS)
        .sensoryFeedback(.success, trigger: canContinue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    private var titleText: String {
        switch installOutcome {
        case .installing:
            return "installing"
        case .success:
            return "installed"
        case .partialFailure:
            return "partially installed"
        case .failed:
            return "install failed"
        }
    }

    private var statusSubtitle: String {
        switch installOutcome {
        case .success:
            return completedModelNames
                .compactMap { ModelConfiguration.getModelByName($0)?.displayName }
                .joined(separator: " • ")
        case .partialFailure:
            let completed = completedModelNames
                .compactMap { ModelConfiguration.getModelByName($0)?.displayName }
                .joined(separator: " • ")
            let failed = failedModelNames
                .compactMap { ModelConfiguration.getModelByName($0)?.displayName }
                .joined(separator: " • ")
            return "Ready to use \(completed). Retry failed: \(failed)."
        case .failed:
            let failed = failedModelNames
                .compactMap { ModelConfiguration.getModelByName($0)?.displayName }
                .joined(separator: " • ")
            return failed.isEmpty ? "No local model was installed." : "Unable to install \(failed)."
        case .installing:
            break
        }
        if let currentModel {
            return currentModel.displayName
        }
        return "Preparing local AI"
    }

    private var progressLabel: String {
        let percent = Int(overallProgress * 100)
        return "\(percent)% • \(completedCount)/\(selectedModels.count) models"
    }

    private func installSelectedModelsIfNeeded() async {
        guard installStarted == false else { return }
        installStarted = true
        failedModelNames.removeAll()

        await install(models: selectedModels)
    }

    private func retryFailedModels() {
        let failedModels = selectedModels.filter { failedModelNames.contains($0.name) }
        guard failedModels.isEmpty == false else { return }
        Task {
            await install(models: failedModels)
        }
    }

    private func install(models: [ModelConfiguration]) async {
        guard models.isEmpty == false else {
            finalizeActiveModelSelection()
            return
        }

        var failedThisPass: [String] = []
        for model in models {
            guard completedModelNames.contains(model.name) == false else { continue }
            currentModelName = model.name
            let switched = await LLMRuntimeCoordinator.shared.switchModelIfNeeded(modelName: model.name)
            if switched {
                completedModelNames.append(model.name)
                failedModelNames.removeAll { $0 == model.name }
                appManager.addInstalledModel(model.name)
            } else if failedThisPass.contains(model.name) == false {
                failedThisPass.append(model.name)
            }
        }

        currentModelName = nil
        failedModelNames = Array(Set(failedModelNames + failedThisPass))
        finalizeActiveModelSelection()
    }

    private func finalizeActiveModelSelection() {
        appManager.setActiveModel(AppManager.preferredActiveModelName(from: completedModelNames))
    }
}

#Preview {
    OnboardingDownloadingModelProgressView(
        showOnboarding: .constant(true),
        selectedModels: ModelConfiguration.availableModels
    )
    .environmentObject(AppManager())
    .environment(LLMEvaluator())
}
