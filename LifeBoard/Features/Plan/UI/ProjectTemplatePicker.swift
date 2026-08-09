import SwiftUI
import UIKit

struct ProjectTemplatePicker: View {
    let service: ProjectTemplateInstantiationService
    let onCreated: (ProjectTemplateCreationReceipt) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templates: [Project] = []
    @State private var selectedTemplateID: UUID?
    @State private var projectName = ""
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Finding project templates…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if templates.isEmpty {
                    ContentUnavailableView(
                        "No project templates",
                        systemImage: "folder.badge.plus",
                        description: Text(
                            "Archive a project marked as a template source, then return here to create a fresh copy."
                        )
                    )
                } else {
                    List {
                        Section("Choose a template") {
                            ForEach(templates, id: \.id) { template in
                                templateButton(template)
                            }
                        }

                        Section("New project") {
                            TextField("Project name", text: $projectName)
                                .textInputAutocapitalization(.words)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("plan.projectTemplates.name")

                            Button {
                                createProject()
                            } label: {
                                HStack {
                                    if isCreating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isCreating ? "Creating…" : "Create project")
                                        .frame(maxWidth: .infinity)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                selectedTemplateID == nil
                                    || projectName.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ).isEmpty
                                    || isCreating
                            )
                            .accessibilityIdentifier("plan.projectTemplates.create")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Project template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadTemplates() }
        .alert(
            "Template unavailable",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if $0 == false { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await service.templates()
            if let first = templates.first {
                selectedTemplateID = first.id
                projectName = defaultName(for: first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createProject() {
        guard let selectedTemplateID else { return }
        let resolvedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolvedName.isEmpty == false else { return }
        isCreating = true
        Task {
            do {
                let receipt = try await service.instantiate(
                    sourceProjectID: selectedTemplateID,
                    name: resolvedName
                )
                await MainActor.run {
                    isCreating = false
                    onCreated(receipt)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func defaultName(for template: Project) -> String {
        template.name.replacingOccurrences(of: " Template", with: "")
    }

    private func templateButton(_ template: Project) -> some View {
        let isSelected = selectedTemplateID == template.id
        let identifier = "plan.projectTemplates.template." + template.id.uuidString
        return Button {
            selectedTemplateID = template.id
            projectName = defaultName(for: template)
        } label: {
            templateRow(template)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier(identifier)
    }

    private func templateRow(_ template: Project) -> some View {
        let isSelected = selectedTemplateID == template.id
        return HStack(spacing: 12) {
            Image(systemName: template.icon.rawValue)
                .frame(width: 28)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                if let description = template.projectDescription,
                   description.isEmpty == false {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(
                    isSelected
                        ? Color.lifeboard(.statusSuccess)
                        : Color(LifeBoardColorTokens.inkSecondary)
                )
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}
