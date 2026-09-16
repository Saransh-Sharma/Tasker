import SwiftUI

/// A question the composer needs answered before it can act.
///
/// One `private struct … : View` per section is this repo's composer-kit rule,
/// and it is enforced by `scripts/premium-ui-guardrails.sh` for a concrete
/// reason: at `-Onone`, a body that inlines this many conditional sections walks
/// the 1 MB main-thread stack and crashes on the guard page *at launch*, before
/// anything is drawn — so it never shows up in a Release smoke test. These two
/// blocks were the largest remaining inline sections in `LifeThreadComposerHost`.
struct ComposerClarificationRow: View {
    let clarification: ClarificationRequest
    let onDismiss: () -> Void
    let onChoose: (ClarificationOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(clarification.question)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss clarification")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(clarification.options) { option in
                        Button {
                            onChoose(option)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: option.systemImage)
                                Text(option.label)
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .lifeBoardPressResponse(.control, haptic: nil)
                    }
                }
            }
        }
        .padding(12)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
    }
}

/// What the composer thinks you meant, offered as one tappable proposal.
///
/// The label names what Send will do ("Add task" saves in place). Each
/// recognized piece is its own chip; removing one takes those words out of the
/// draft, so a misread date or tag is corrected where it was typed.
struct ComposerInterpretationRow: View {
    let interpretation: ComposerInterpretation
    let onAccept: () -> Void
    var onRemoveChip: (InterpretationChip) -> Void = { _ in }
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onAccept) {
                    HStack(spacing: 8) {
                        Image(systemName: interpretation.systemImage)
                            .foregroundColor(Color.lifeboard(.accentPrimary))
                        Text(interpretation.label)
                            .lifeboardFont(.caption1)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lifeThread.interpretation.accept")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(interpretation.chips) { chip in
                            ComposerInterpretationChip(chip: chip) { onRemoveChip(chip) }
                        }
                    }
                }

                Button(action: onAccept) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(interpretation.label)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.lifeboard(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
            }
            .lifeBoardPressResponse(.card, haptic: nil)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .lifeboardFont(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(SemanticColorTokens.inkSecondary))
                    .frame(width: 26, height: 26)
                    .background(Color.lifeboard(.surfaceSecondary), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss interpretation")
        }
        .padding(.horizontal, 4)
    }
}

private struct ComposerInterpretationChip: View {
    let chip: InterpretationChip
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage = chip.systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(chip.label)
            if chip.isRemovable {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .fontWeight(.bold)
                        .frame(width: 24, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(chip.label)")
                .accessibilityHint("Takes these words out of the draft")
            }
        }
        .lifeboardFont(.caption2)
        .fontWeight(.medium)
        .padding(.leading, 8)
        .padding(.trailing, chip.isRemovable ? 2 : 8)
        .frame(minHeight: 28)
        .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Capsule())
        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        .accessibilityElement(children: .combine)
    }
}


/// Names the composer can complete: existing tags, projects, and contexts.
///
/// Loaded once and refreshed whenever the composer gains focus, so a tag
/// created a moment ago in the task editor is offered the next time someone
/// types `#`. Kept process-wide because the composer host is rebuilt on every
/// root switch and would otherwise refetch on each one.
@MainActor
@Observable
final class CaptureSuggestionCatalog {
    static let shared = CaptureSuggestionCatalog()

    private(set) var tagNames: [String] = []
    private(set) var projectNames: [String] = []
    let contextNames = TaskContext.allCases.filter { $0 != .anywhere }.map(\.rawValue)
    private var isLoading = false

    func names(for kind: CaptureTokenCompletion.Kind) -> [String] {
        switch kind {
        case .tag: tagNames
        case .project: projectNames
        case .context: contextNames
        }
    }

    func refresh() {
        guard isLoading == false else { return }
        isLoading = true
        let root = CompositionRoot.shared
        root.tagRepository?.fetchAll { result in
            let names = (try? result.get())?.map(\.name) ?? []
            Task { @MainActor in self.tagNames = names }
        }
        root.projectRepository?.fetchAllProjects { result in
            let names = (try? result.get())?.filter { $0.isInbox == false }.map(\.name) ?? []
            Task { @MainActor in
                self.projectNames = names
                self.isLoading = false
            }
        }
    }
}

/// The row that finishes a `#tag`, `+project`, or `@context` as it is typed.
///
/// It sits where the interpretation chips appear, because it is the same
/// conversation: what the composer understood, and what it could mean next.
struct ComposerTokenSuggestionRow: View {
    let draftText: String
    let catalog: CaptureSuggestionCatalog
    let onChoose: (String) -> Void

    var body: some View {
        if let token = CaptureTokenCompletion.activeToken(in: draftText) {
            let suggestions = CaptureTokenCompletion.suggestions(for: token, candidates: catalog.names(for: token.kind))
            if suggestions.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                Haptic.pick.play()
                                onChoose(CaptureTokenCompletion.apply(suggestion.name, kind: token.kind, to: draftText))
                            } label: {
                                Label {
                                    Text(
                                        suggestion.isNew
                                            ? "Create \(token.kind.sigil)\(CaptureTokenCompletion.tokenText(suggestion.name))"
                                            : "\(token.kind.sigil)\(CaptureTokenCompletion.tokenText(suggestion.name))"
                                    )
                                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                                } icon: {
                                    // Colour marks the kind; the words stay in primary ink
                                    // so they keep full contrast on any daypart.
                                    Image(systemName: suggestion.isNew ? "plus" : Self.symbol(token.kind))
                                        .foregroundStyle(Color(ComposerTokenPalette.color(for: token.kind)))
                                }
                            }
                            .buttonStyle(.lifeBoardChip)
                            .accessibilityLabel(suggestion.isNew ? "Create tag \(suggestion.name)" : suggestion.name)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .accessibilityIdentifier("lifeThread.tokenSuggestions")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private static func symbol(_ kind: CaptureTokenCompletion.Kind) -> String {
        switch kind {
        case .tag: "number"
        case .project: "folder"
        case .context: "mappin"
        }
    }
}

/// One colour per kind of token (tag, project, context) for the suggestion
/// chips' icons. Text stays in primary ink so contrast never rests on the tint.
enum ComposerTokenPalette {
    static func color(for kind: CaptureTokenCompletion.Kind) -> UIColor {
        switch kind {
        case .tag: SemanticColorTokens.foundationSageAccent
        case .project: SemanticColorTokens.foundationFocusRing
        case .context: SemanticColorTokens.foundationApricotAccent
        }
    }
}

