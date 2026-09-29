import SwiftUI

extension WeeklyPlannerView {
    @ViewBuilder
    var footerActions: some View {
        switch viewModel.currentStep {
        case .review:
            HStack(spacing: spacing.s8) {
                Button(viewModel.isRequestingEvaPreview ? "Loading…" : WeeklyCopy.getAISuggestion) {
                    viewModel.requestEvaPreview()
                }
                .buttonStyle(.lifeBoardChip)
                .disabled(viewModel.isSaving || viewModel.isRequestingEvaPreview)

                Button(viewModel.isSaving ? "Saving…" : WeeklyCopy.savePlan) {
                    viewModel.save()
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .disabled(viewModel.isSaving)
            }
        default:
            Button(viewModel.currentStep.nextButtonTitle) {
                viewModel.moveForward()
            }
            .buttonStyle(.lifeBoardPrimaryCompact)
            .disabled(viewModel.isLoading || viewModel.canMoveForward == false)
        }
    }
}
