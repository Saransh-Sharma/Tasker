import SwiftUI

struct FlowPromptChipsView: View {
    let prompts: [EvaStarterPrompt]
    let reduceMotion: Bool
    let onSelectPrompt: (EvaStarterPrompt) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 138), spacing: Theme.Spacing.xs, alignment: .leading)],
            alignment: .leading,
            spacing: Theme.Spacing.xs
        ) {
            ForEach(prompts) { prompt in
                Button {
                    onSelectPrompt(prompt)
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: promptIcon(for: prompt))
                            .lifeboardFont(.eyebrow)
                            .frame(width: 20, height: 20)
                        Text(prompt.title)
                            .font(ClayTypography.chip)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(ClayColorTokens.violetDeep)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        Color.clear.lifeBoardSystemGlass(
                            .regular,
                            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous),
                            interactive: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send prompt: \(prompt.submissionText)")
                .accessibilityIdentifier("eva.guide.prompt.\(prompt.id)")
                .lifeboardPressFeedback()
            }
        }
    }

    func promptIcon(for prompt: EvaStarterPrompt) -> String {
        prompt.style == .slashCommand ? "command" : "arrow.up.message"
    }
}
