import SwiftUI
import UIKit

struct LifeManagementProjectComposerView: View {
    @State var draft: LifeManagementProjectDraft
    @State var errorShakeTrigger = false
    @FocusState var titleFieldFocused: Bool

    let lifeAreas: [LifeManagementAreaRow]
    let fallbackAreaRows: [LifeManagementAreaRow]
    let containerMode: AddTaskContainerMode
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (LifeManagementProjectDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: SemanticSpacingTokens { tokens.spacing }
    var readableWidth: CGFloat {
        switch containerMode {
        case .inspector:
            return layoutClass.isPad ? 860 : 760
        case .sheet:
            return 720
        }
    }

    var availableAreas: [LifeManagementAreaRow] {
        lifeAreas.isEmpty ? fallbackAreaRows : lifeAreas
    }

    var canSave: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    init(
        draft: LifeManagementProjectDraft,
        lifeAreas: [LifeManagementAreaRow],
        fallbackAreaRows: [LifeManagementAreaRow],
        containerMode: AddTaskContainerMode,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (LifeManagementProjectDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.lifeAreas = lifeAreas
        self.fallbackAreaRows = fallbackAreaRows
        self.containerMode = containerMode
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var selectedAreaName: String {
        availableAreas.first(where: { $0.id == draft.lifeAreaID })?.lifeArea.name ?? String(localized: "No area")
    }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: draft.isNew ? "New project" : "Edit project",
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
                        eyebrow: "Project",
                        title: draft.name.lifeManagementNilIfBlank ?? "New project",
                        subtitle: draft.description.lifeManagementNilIfBlank ?? String(localized: "No description"),
                        iconName: draft.icon.systemImageName,
                        accentColor: lifeManagementResolvedColor(hex: draft.color.hexString, fallback: Color.lifeboard.accentPrimary),
                        metrics: [
                            LifeManagementComposerPreviewMetric(title: "Area", value: selectedAreaName),
                            LifeManagementComposerPreviewMetric(title: "Color", value: draft.color.displayName)
                        ]
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $draft.name,
                        isFocused: $titleFieldFocused,
                        placeholder: "Project name",
                        onSubmit: commit
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    LifeManagementComposerSectionCard(
                        title: "Details",
                        subtitle: "",
                        iconSystemName: "text.alignleft"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                LifeManagementComposerFieldLabel(
                                    title: "Description",
                                    detail: "Optional"
                                )

                                TextField("Description", text: $draft.description, prompt: Text("Description").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                                    .textFieldStyle(TokenTextFieldStyle())
                                    .lineLimit(3, reservesSpace: true)
                            }

                            AddTaskEntityPicker(
                                label: "Area",
                                items: availableAreas.map {
                                    AddTaskEntityPickerItem(
                                        id: $0.id,
                                        name: $0.lifeArea.name,
                                        icon: $0.lifeArea.icon,
                                        accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.lifeArea.color, for: $0.id)
                                    )
                                },
                                selectedID: $draft.lifeAreaID
                            )
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    LifeManagementComposerSectionCard(
                        title: "Appearance",
                        subtitle: "",
                        iconSystemName: "paintbrush.pointed.fill"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            LifeManagementComposerFieldLabel(
                                title: "Color",
                                detail: ""
                            )

                            LifeManagementProjectColorPicker(selectedColor: $draft.color)

                            LifeManagementComposerFieldLabel(
                                title: "Icon",
                                detail: ""
                            )

                            LifeManagementProjectIconPicker(selectedIcon: $draft.icon)
                        }
                    }
                    .enhancedStaggeredAppearance(index: 3)

                    if let errorMessage {
                        LifeManagementComposerInlineMessage(
                            title: "Couldn’t save project",
                            message: errorMessage
                        )
                        .bellShake(trigger: $errorShakeTrigger)
                        .enhancedStaggeredAppearance(index: 4)
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
                buttonTitle: draft.isNew ? "Add project" : "Save",
                onCreateAction: commit,
                onAddAnotherAction: {}
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.lifeboard.bgCanvas)
        .lifeboardReadableContent(maxWidth: readableWidth, alignment: .center)
        .accessibilityIdentifier("settings.lifeManagement.projectComposer")
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
