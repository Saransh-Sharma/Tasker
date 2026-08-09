import SwiftUI
import UIKit

/// Everything the task links to: tags, subtasks, and dependencies.
struct TaskEditorRelationsSection: View {
    @Bindable var editor: TaskEditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            tags(editor: $editor)
            subtasks(editor: $editor)
            dependencies(editor: $editor)
        }
    }

    private func tags(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TaskEditorControls.header("Tags", symbol: "tag")
            if editor.wrappedValue.tags.isEmpty {
                Text("No tags yet")
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(editor.wrappedValue.tags, id: \.id) { tag in
                        let selected = editor.wrappedValue.draft.tagIDs.contains(tag.id)
                        Button {
                            if selected {
                                editor.wrappedValue.draft.tagIDs.removeAll { $0 == tag.id }
                            } else {
                                editor.wrappedValue.draft.tagIDs.append(tag.id)
                            }
                        } label: {
                            Label(tag.name, systemImage: selected ? "checkmark" : "plus")
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(selected
                            ? Color(LifeBoardColorTokens.foundationSageAccent)
                            : Color(LifeBoardColorTokens.inkSecondary))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
        .taskEditorSurface()
    }

    private func subtasks(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TaskEditorControls.header("Subtasks", symbol: "list.bullet.indent")
                Spacer()
                Menu {
                    let available = editor.wrappedValue.taskCandidates.filter {
                        $0.parentTaskID == nil
                            && editor.wrappedValue.draft.subtasks.contains($0.id) == false
                    }
                    if available.isEmpty {
                        Text("No available tasks")
                    } else {
                        ForEach(available, id: \.id) { candidate in
                            Button(candidate.title) {
                                editor.wrappedValue.toggleSubtask(candidate.id)
                            }
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityIdentifier("task.editor.subtask.add")
            }

            if editor.wrappedValue.draft.subtasks.isEmpty {
                Text("Break this down by linking an existing task.")
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                ForEach(
                    Array(editor.wrappedValue.draft.subtasks.enumerated()),
                    id: \.element
                ) { index, subtaskID in
                    HStack(spacing: 8) {
                        Text(taskTitle(subtaskID, editor: editor.wrappedValue))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            guard index > 0 else { return }
                            editor.wrappedValue.moveSubtask(
                                fromOffsets: IndexSet(integer: index),
                                toOffset: index - 1
                            )
                        } label: {
                            Image(systemName: "arrow.up")
                                .frame(width: 44, height: 44)
                        }
                        .disabled(index == 0)
                        .accessibilityLabel("Move subtask earlier")
                        Button {
                            guard index + 1 < editor.wrappedValue.draft.subtasks.count else {
                                return
                            }
                            editor.wrappedValue.moveSubtask(
                                fromOffsets: IndexSet(integer: index),
                                toOffset: index + 2
                            )
                        } label: {
                            Image(systemName: "arrow.down")
                                .frame(width: 44, height: 44)
                        }
                        .disabled(index + 1 == editor.wrappedValue.draft.subtasks.count)
                        .accessibilityLabel("Move subtask later")
                        Button(role: .destructive) {
                            editor.wrappedValue.toggleSubtask(subtaskID)
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Remove subtask")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("task.editor.subtask.\(subtaskID.uuidString)")
                }
            }
        }
        .taskEditorSurface()
    }

    private func dependencies(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TaskEditorControls.header("Dependencies", symbol: "link")
                Spacer()
                Menu {
                    let linked = Set(
                        editor.wrappedValue.draft.dependencies.map(\.dependsOnTaskID)
                    )
                    let available = editor.wrappedValue.taskCandidates.filter {
                        linked.contains($0.id) == false
                    }
                    if available.isEmpty {
                        Text("No available tasks")
                    } else {
                        ForEach(available, id: \.id) { candidate in
                            Button(candidate.title) {
                                editor.wrappedValue.toggleDependency(on: candidate.id)
                            }
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityIdentifier("task.editor.dependency.add")
            }

            if editor.wrappedValue.draft.dependencies.isEmpty {
                Text("Nothing else has to finish first.")
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                ForEach(editor.wrappedValue.draft.dependencies, id: \.id) { link in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(taskTitle(link.dependsOnTaskID, editor: editor.wrappedValue))
                                .font(.subheadline.weight(.medium))
                            Text(link.kind == .blocks ? "Must finish first" : "Related")
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        Spacer()
                        Menu {
                            ForEach(TaskDependencyKind.allCases, id: \.self) { kind in
                                Button(kind == .blocks ? "Must finish first" : "Related") {
                                    guard let index = editor.wrappedValue.draft.dependencies
                                        .firstIndex(where: { $0.id == link.id }) else {
                                        return
                                    }
                                    editor.wrappedValue.draft.dependencies[index].kind = kind
                                }
                            }
                            Button("Remove", role: .destructive) {
                                editor.wrappedValue.toggleDependency(on: link.dependsOnTaskID)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Dependency actions")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(
                        "task.editor.dependency.\(link.dependsOnTaskID.uuidString)"
                    )
                }
            }
        }
        .taskEditorSurface()
    }

    private func taskTitle(_ id: UUID, editor: TaskEditorStore) -> String {
        editor.taskCandidates.first(where: { $0.id == id })?.title ?? "Unavailable task"
    }}
