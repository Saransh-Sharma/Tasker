import SwiftUI
import UIKit

/// The list and board presentations of a project's open work.
///
/// Reordering and section moves stay with `ProjectRouteView`, which
/// owns the repositories; this reports the intent back through closures.
struct ProjectTaskListSection: View {
    let snapshot: ProjectExecutionSnapshot
    let projectID: UUID
    let displaysBoard: Bool
    let router: AppRouter
    let move: (PlanningTaskSummary, Int) -> Void
    let moveToSection: (PlanningTaskSummary, UUID?) -> Void

    var body: some View {
        if displaysBoard { board(snapshot) } else { list(snapshot) }
    }

    private func list(_ snapshot: ProjectExecutionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                snapshot.tasks.isEmpty ? "No open work" : "\(snapshot.tasks.count) open tasks",
                systemImage: "checklist"
            )
            .font(.headline)
            ForEach(Self.ordered(snapshot)) { task in
                taskRow(task, snapshot: snapshot)
            }
        }
        .taskEditorSurface()
    }

    private func board(_ snapshot: ProjectExecutionSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(boardSections(snapshot), id: \.id) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.name)
                            .font(.headline)
                        let tasks = Self.ordered(snapshot).filter {
                            section.sortOrder == Int.max
                                ? snapshot.sectionIDByTaskID[$0.id] == nil
                                : snapshot.sectionIDByTaskID[$0.id] == section.id
                        }
                        if tasks.isEmpty {
                            Text("No tasks")
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                .frame(maxWidth: .infinity, minHeight: 70)
                        } else {
                            ForEach(tasks) { task in
                                taskRow(task, snapshot: snapshot)
                            }
                        }
                    }
                    .frame(width: 286, alignment: .topLeading)
                    .taskEditorSurface()
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("project.board")
    }

    private func taskRow(
        _ task: PlanningTaskSummary,
        snapshot: ProjectExecutionSnapshot
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                router.push(.taskDetail(task.id), in: .plan)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: task.dependenciesReady ? "circle" : "link")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.leading)
                        Text(task.estimatedDuration.map(Self.durationLabel) ?? "No estimate")
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer()
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu {
                Button("Move earlier", systemImage: "arrow.up") { move(task, -1) }
                Button("Move later", systemImage: "arrow.down") { move(task, 1) }
                Section("Move to section") {
                    Button("Unsectioned") { moveToSection(task, nil) }
                    ForEach(snapshot.sections, id: \.id) { section in
                        Button(section.name) { moveToSection(task, section.id) }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Reorder \(task.title)")
        }
        .padding(.horizontal, 12)
        .background(
            Color(SemanticColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    static func ordered(_ snapshot: ProjectExecutionSnapshot) -> [PlanningTaskSummary] {
        snapshot.tasks.sorted {
            ($0.metadata.pinOrder ?? Int.max, $0.id.uuidString)
                < ($1.metadata.pinOrder ?? Int.max, $1.id.uuidString)
        }
    }

    private func boardSections(_ snapshot: ProjectExecutionSnapshot) -> [ProjectSectionDefinition] {
        var sections = snapshot.sections.sorted { $0.sortOrder < $1.sortOrder }
        if snapshot.tasks.contains(where: { snapshot.sectionIDByTaskID[$0.id] == nil }) {
            sections.append(
                ProjectSectionDefinition(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    projectID: projectID,
                    name: "Unsectioned",
                    sortOrder: Int.max
                )
            )
        }
        return sections
    }

    static func durationLabel(_ value: TimeInterval) -> String {
        let minutes = max(0, Int(value / 60))
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}
