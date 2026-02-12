//
//  OnboardingDownloadingModelProgressView.swift
//
//

import SwiftUI
import MLXLMCommon

struct OnboardingDownloadingModelProgressView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var appManager: AppManager
    @Binding var selectedModel: ModelConfiguration
    @Environment(LLMEvaluator.self) var llm
    @State var didSwitchModel = false

    var installed: Bool {
        llm.progress == 1 && didSwitchModel
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: TaskerTheme.Spacing.xxxl) {
                MoonAnimationView(isDone: installed)

                VStack(spacing: TaskerTheme.Spacing.xs) {
                    Text(installed ? "installed" : "installing")
                        .font(.tasker(.title1))
                        .foregroundColor(Color.tasker(.textPrimary))
                    Text(appManager.modelDisplayName(selectedModel.name))
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker(.textSecondary))
                        .multilineTextAlignment(.center)
                }

                // Custom progress bar
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill)
                                .fill(Color.tasker(.surfaceTertiary))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill)
                                .fill(Color.tasker(.accentPrimary))
                                .frame(width: geo.size.width * llm.progress, height: 8)
                                .animation(TaskerAnimation.gentle, value: llm.progress)
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(llm.progress * 100))%")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.textTertiary))
                        .monospacedDigit()
                }
                .padding(.horizontal, 48)
            }

            Spacer()

            if installed {
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
                .padding(.horizontal, TaskerTheme.Spacing.xl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(TaskerAnimation.bouncy, value: installed)
            } else {
                Text("keep this screen open and wait for the installation to complete.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.textQuaternary))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TaskerTheme.Spacing.xl)
            }
        }
        .padding()
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("downloading AI model..")
        .toolbar(installed ? .hidden : .visible)
        .navigationBarBackButtonHidden()
        .task {
            await loadLLM()
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: installed)
        #endif
        .onChange(of: installed) {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
            addInstalledModel()
        }
        .interactiveDismissDisabled(!installed)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    func loadLLM() async {
        await llm.switchModel(selectedModel)
        didSwitchModel = true
    }

    func addInstalledModel() {
        if installed {
            print("added installed model")
            appManager.currentModelName = selectedModel.name
            appManager.addInstalledModel(selectedModel.name)
        }
    }
}

#Preview {
    OnboardingDownloadingModelProgressView(showOnboarding: .constant(true), selectedModel: .constant(ModelConfiguration.defaultModel))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
