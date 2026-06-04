import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingCustomEntryRow: View {
    let placeholder: String
    @Binding var text: String
    let actionTitle: String
    let focus: FocusState<OnboardingInputField?>.Binding
    let focusID: OnboardingInputField
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .lifeboardFont(.body)
                .foregroundStyle(OnboardingTheme.textPrimary)
                .submitLabel(.done)
                .focused(focus, equals: focusID)
                .onSubmit(onAdd)

            Button(actionTitle) {
                onAdd()
            }
            .lifeboardFont(.buttonSmall)
            .foregroundStyle(OnboardingTheme.marigold)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
        .id(focusID)
    }
}
