//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueQuickEditSheet: View {
    let card: OverdueRescueCardModel
    let projects: [Project]
    let save: (OverdueRescueEditDraft) -> Void
    let cancel: () -> Void

    @State var draft: OverdueRescueEditDraft
    @Environment(\.dismiss) var dismiss

    init(
        card: OverdueRescueCardModel,
        projects: [Project],
        save: @escaping (OverdueRescueEditDraft) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.card = card
        self.projects = projects
        self.save = save
        self.cancel = cancel
        _draft = State(initialValue: OverdueRescueEditDraft(card: card))
    }

    var body: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(Color(red: 0.78, green: 0.78, blue: 0.82))
                .frame(width: 58, height: 6)
                .padding(.top, 12)
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                Text("Adjust task")
                    .font(.lifeboard(.title2))
                    .fontWeight(.bold)
                    .foregroundStyle(OverdueRescuePalette.ink)
                Spacer()
                Button("Close", systemImage: "xmark") {
                    cancel()
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .font(.title2.weight(.semibold))
                .frame(width: 58, height: 58)
                .background(Circle().fill(OverdueRescuePalette.glassFill))
                .foregroundStyle(OverdueRescuePalette.ink)
                .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                .accessibilityIdentifier("home.rescue.edit.close")
            }

            HStack {
                Text(card.task.title)
                    .font(.lifeboard(.title3))
                    .fontWeight(.bold)
                    .foregroundStyle(OverdueRescuePalette.ink)
                    .lineLimit(3)
                Spacer()
                OverdueRescuePlant()
                    .frame(width: 104, height: 108)
            }
            .padding(.leading, 24)
            .padding(.trailing, 16)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(OverdueRescuePalette.glassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(OverdueRescuePalette.glassStroke, lineWidth: 1)
                    )
            )

            VStack(spacing: 0) {
                Menu {
                    Button("Today") { draft.dueDate = DatePreset.today.resolvedDueDate() }
                    Button("Tomorrow") { draft.dueDate = DatePreset.tomorrow.resolvedDueDate() }
                    Button("This week") { draft.dueDate = DatePreset.thisWeek.resolvedDueDate() }
                } label: {
                    editRow(icon: "calendar", title: "Due date", value: dueText)
                }
                .accessibilityIdentifier("home.rescue.edit.dueDate")
                Divider()
                Menu {
                    Button("15 min") { draft.duration = 15 * 60 }
                    Button("30 min") { draft.duration = 30 * 60 }
                    Button("45 min") { draft.duration = 45 * 60 }
                    Button("1 hour") { draft.duration = 60 * 60 }
                    Button("No duration") { draft.duration = nil }
                } label: {
                    editRow(icon: "clock", title: "Duration", value: durationText)
                }
                .accessibilityIdentifier("home.rescue.edit.duration")
                Divider()
                Menu {
                    Button("No project") { draft.projectID = ProjectConstants.inboxProjectID }
                    ForEach(projects, id: \.id) { project in
                        Button(project.name) { draft.projectID = project.id }
                    }
                } label: {
                    editRow(icon: "folder", title: "Project", value: projectText)
                }
                .accessibilityIdentifier("home.rescue.edit.project")
                Divider()
                Menu {
                    ForEach(TaskPriority.uiOrder, id: \.self) { priority in
                        Button(priority.displayName) { draft.priority = priority }
                    }
                } label: {
                    editRow(
                        icon: "flag",
                        title: "Priority",
                        value: draft.priority.displayName,
                        valueColor: draft.priority.isHighPriority ? Color.lifeboard.statusDanger : Color.lifeboard.textSecondary,
                        iconColor: draft.priority.isHighPriority ? Color.lifeboard.statusDanger : Color.lifeboard.textSecondary
                    )
                }
                .accessibilityIdentifier("home.rescue.edit.priority")
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(OverdueRescuePalette.glassFill)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(OverdueRescuePalette.glassStroke, lineWidth: 1))
            )

            HStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.confidenceLabel)
                        .font(.lifeboard(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                    Text("Based on project relevance and how long the task has needed a decision.")
                        .font(.lifeboard(.body))
                        .foregroundStyle(OverdueRescuePalette.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.lifeboard.accentPrimary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.lifeboard.accentPrimary.opacity(0.16), lineWidth: 1))
            )

            Spacer()

            Button("Save and continue") {
                save(draft)
                dismiss()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(OverdueRescueVisualSpec.primaryButtonBackground())
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityIdentifier("home.rescue.edit.save")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OverdueRescueBackground())
        .presentationDetents([.large])
        .presentationCornerRadius(36)
        .presentationBackground(.clear)
        .presentationDragIndicator(.hidden)
        .accessibilityIdentifier("home.rescue.edit.sheet")
    }

    func editRow(
        icon: String,
        title: String,
        value: String,
        valueColor: Color = Color.lifeboard.textSecondary,
        iconColor: Color = Color.lifeboard.textSecondary
    ) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(OverdueRescuePalette.ink)
            Spacer()
            Text(value)
                .font(.lifeboard(.headline))
                .foregroundStyle(valueColor)
            Image(systemName: "chevron.down")
                .font(.callout.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .frame(minHeight: 74)
        .padding(.horizontal, 20)
    }

    var dueText: String {
        guard let dueDate = draft.dueDate else { return "No due date" }
        if Calendar.current.isDateInToday(dueDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(dueDate) { return "Tomorrow" }
        return dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var durationText: String {
        guard let duration = draft.duration else { return "No duration" }
        let minutes = Int(duration / 60)
        return minutes >= 60 ? "\(minutes / 60) hour" : "\(minutes) min"
    }

    var projectText: String {
        if draft.projectID == ProjectConstants.inboxProjectID { return "No project" }
        return projects.first(where: { $0.id == draft.projectID })?.name ?? "Project"
    }
}
