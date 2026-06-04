import SwiftUI
import UIKit

struct LifeManagementAreaComposerView: View {
    @State var draft: LifeManagementLifeAreaDraft
    @State var errorShakeTrigger = false
    @FocusState var titleFieldFocused: Bool

    let iconOptions: [LifeAreaIconOption]
    let containerMode: AddTaskContainerMode
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (LifeManagementLifeAreaDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    var readableWidth: CGFloat {
        switch containerMode {
        case .inspector:
            return layoutClass.isPad ? 860 : 760
        case .sheet:
            return 720
        }
    }

    init(
        draft: LifeManagementLifeAreaDraft,
        iconOptions: [LifeAreaIconOption],
        containerMode: AddTaskContainerMode,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (LifeManagementLifeAreaDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.iconOptions = iconOptions
        self.containerMode = containerMode
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var canSave: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    var selectedColorTitle: String {
        lifeManagementAreaPaletteMatch(for: draft.colorHex)?.title
            ?? HabitColorFamily.family(for: draft.colorHex, fallback: .green).title
    }

    var selectedIconTitle: String {
        lifeManagementAreaIconLabel(for: draft.iconSymbolName, options: iconOptions)
    }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: draft.isNew ? "New Area" : "Edit Area",
                canSave: canSave
            ) {
                onCancel()
            } onSave: {
                commit()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    LifeManagementComposerPreviewCard(
                        eyebrow: draft.isNew ? "Create area" : "Edit area",
                        title: draft.name.lifeManagementNilIfBlank ?? "New area",
                        subtitle: "Define the bucket that holds related projects and habits.",
                        iconName: draft.iconSymbolName,
                        accentColor: lifeManagementResolvedColor(hex: draft.colorHex, fallback: Color.lifeboard.accentPrimary),
                        metrics: [
                            LifeManagementComposerPreviewMetric(title: "Accent", value: selectedColorTitle),
                            LifeManagementComposerPreviewMetric(title: "Icon", value: selectedIconTitle)
                        ]
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $draft.name,
                        isFocused: $titleFieldFocused,
                        placeholder: "Name this area",
                        helperText: "Use a clear bucket like Health, Career, or Home.",
                        onSubmit: commit
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    LifeManagementComposerSectionCard(
                        title: "Appearance",
                        subtitle: "Pick an accent and icon so the area is easy to spot across the app.",
                        iconSystemName: "paintpalette.fill"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            LifeManagementComposerFieldLabel(
                                title: "Accent",
                                detail: "Choose from the same palette used for habit accents."
                            )

                            LifeManagementAreaSwatchPicker(
                                selectedHex: $draft.colorHex
                            )

                            LifeManagementComposerFieldLabel(
                                title: "Icon",
                                detail: "Choose the symbol that best represents this part of your life."
                            )

                            LifeManagementAreaIconPicker(
                                iconOptions: iconOptions,
                                selectedSymbolName: $draft.iconSymbolName
                            )
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    if let errorMessage {
                        LifeManagementComposerInlineMessage(
                            title: "Couldn’t save area",
                            message: errorMessage
                        )
                        .bellShake(trigger: $errorShakeTrigger)
                        .enhancedStaggeredAppearance(index: 3)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s24)
            }

            AddTaskCreateButton(
                isEnabled: canSave,
                isLoading: isSaving,
                successFlash: false,
                showAddAnother: false,
                buttonTitle: draft.isNew ? "Add Area" : "Save Area",
                onCreateAction: commit,
                onAddAnotherAction: {}
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.lifeboard.bgCanvas)
        .lifeboardReadableContent(maxWidth: readableWidth, alignment: .center)
        .accessibilityIdentifier("settings.lifeManagement.areaComposer")
        .onAppear {
            guard containerMode == .sheet else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFieldFocused = true
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                errorShakeTrigger.toggle()
            }
        }
    }

    func commit() {
        guard canSave else { return }
        onSave(draft)
    }
}
