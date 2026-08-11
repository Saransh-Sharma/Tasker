import SwiftUI
import UIKit

// The sheets behind the less common decisions: edit, safe fixes, pause,
// and delete.

// MARK: - OverdueRescueQuickEditSheet

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


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

// MARK: - OverdueRescueEditDraft

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueEditDraft: Equatable {
    var dueDate: Date?
    var duration: TimeInterval?
    var projectID: UUID
    var priority: TaskPriority

    init(card: OverdueRescueCardModel) {
        dueDate = card.task.dueDate
        duration = card.task.estimatedDuration
        projectID = card.task.projectID
        priority = card.task.priority
    }
}

// MARK: - OverdueRescueSafeFixesView

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueSafeFixesView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(OverdueRescuePalette.ink)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(OverdueRescuePalette.glassFill))
                    .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                Spacer()
            }
            OverdueRescueShieldHero()
                .frame(width: 244, height: 210)
                .padding(.top, 8)
            Text("Apply \(viewModel.safeFixes.count) safe fixes?")
                .font(.lifeboard(.title1))
                .fontWeight(.bold)
                .foregroundStyle(OverdueRescuePalette.ink)
                .multilineTextAlignment(.center)
            Text("LifeBoard found \(viewModel.safeFixes.count) changes it is confident about.")
                .font(.lifeboard(.title3))
                .foregroundStyle(OverdueRescuePalette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                if viewModel.safeFixBreakdown.move > 0 {
                    safeRow(icon: "clock", title: "\(viewModel.safeFixBreakdown.move) move later", value: "\(viewModel.safeFixBreakdown.move)", color: Color.lifeboard.statusWarning)
                }
                if viewModel.safeFixBreakdown.move > 0, viewModel.safeFixBreakdown.stay > 0 {
                    Divider()
                }
                if viewModel.safeFixBreakdown.stay > 0 {
                    safeRow(icon: "checkmark.circle", title: "\(viewModel.safeFixBreakdown.stay) stay today", value: "\(viewModel.safeFixBreakdown.stay)", color: Color.lifeboard.statusSuccess)
                }
                if viewModel.safeFixBreakdown.duration > 0, viewModel.safeFixBreakdown.move + viewModel.safeFixBreakdown.stay > 0 {
                    Divider()
                }
                if viewModel.safeFixBreakdown.duration > 0 {
                    safeRow(icon: "calendar", title: "\(viewModel.safeFixBreakdown.duration) gets a duration", value: "\(viewModel.safeFixBreakdown.duration)", color: Color.lifeboard.accentPrimary)
                }
            }
            .padding(.vertical, 10)
            .background(
                OverdueRescueVisualSpec.glassCard(cornerRadius: 28, fill: OverdueRescuePalette.glassFill)
            )

            HStack(spacing: 14) {
                Image(systemName: "shield")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.lifeboard.accentPrimary.opacity(0.10)))
                Text("These changes are non-destructive\nand can be undone.")
                    .font(.lifeboard(.body))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 34)

            Spacer()
            Button("Apply \(viewModel.safeFixes.count) fixes") {
                dismiss()
                viewModel.applySafeFixes()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.primaryButtonHeight)
            .background(OverdueRescueVisualSpec.primaryButtonBackground())
            .disabled(viewModel.safeFixes.isEmpty)
            Button("Review first") {
                dismiss()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(Color.lifeboard.accentPrimary)
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.secondaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.lifeboard.accentPrimary.opacity(0.32), lineWidth: 1.2)
            )
        }
        .padding(28)
        .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OverdueRescueBackground())
        .presentationDetents([.large])
        .presentationBackground(.clear)
    }

    func safeRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 18).fill(color.opacity(0.12)))
            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(OverdueRescuePalette.ink)
            Spacer()
            Text(value)
                .font(.lifeboard(.headline))
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 22)
        .frame(height: 82)
    }
}

// MARK: - OverdueRescuePauseView

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescuePauseView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    let bottomInset: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                HStack {
                    Button("Close", systemImage: "xmark") { onDismiss() }
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(OverdueRescuePalette.glassFill))
                        .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                OverdueRescueCupHero()
                    .frame(width: 250, height: 248)

                VStack(spacing: 10) {
                    Text("Pause rescue?")
                        .font(.lifeboard(.title1))
                        .fontWeight(.bold)
                        .foregroundStyle(OverdueRescuePalette.ink)
                    Text("You reviewed \(viewModel.sprintResolvedCount) of \(viewModel.sprintTotal) tasks.\nYour changes are saved.\n\(viewModel.remainingCount) tasks can wait.")
                        .font(.lifeboard(.title3))
                        .foregroundStyle(OverdueRescuePalette.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                }

                HStack(spacing: 18) {
                    Button {
                        onDismiss()
                    } label: {
                        Label("Pause", systemImage: "cup.and.saucer")
                            .font(.lifeboard(.button))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.lifeboard.accentPrimary.opacity(0.38), lineWidth: 1.2)
                            )
                    }
                    .foregroundStyle(Color.lifeboard.accentPrimary)

                    Button {
                        viewModel.resume()
                    } label: {
                        Label("Keep going", systemImage: "arrow.right")
                            .font(.lifeboard(.button))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(OverdueRescueVisualSpec.primaryButtonBackground())
                    }
                    .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                }
                .padding(.horizontal, 28)

                Button {
                    viewModel.resume()
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "lifepreserver")
                            .lifeboardFont(.heroDisplay)
                            .foregroundStyle(Color.lifeboard.statusWarning)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(OverdueRescuePalette.glassFill))
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Resume rescue")
                                .font(.lifeboard(.headline))
                                .foregroundStyle(OverdueRescuePalette.ink)
                            Text("\(viewModel.summary.reviewed) done · \(viewModel.remainingCount) left")
                                .font(.lifeboard(.title3))
                                .foregroundStyle(OverdueRescuePalette.secondaryInk)
                            ProgressBar(progress: viewModel.progress, colors: [Color.lifeboard.accentPrimary])
                        }
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }
                    .padding(22)
                    .background(
                        OverdueRescueVisualSpec.glassCard(cornerRadius: 28, fill: OverdueRescuePalette.glassFill)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                Color.clear.frame(height: max(28, bottomInset))
            }
            .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - OverdueRescueDeleteOverlay

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueDeleteOverlay: View {
    let taskTitle: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.lifeboard(.overlayScrim).opacity(0.84)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "trash")
                        .lifeboardFont(.display)
                        .foregroundStyle(OverdueRescuePalette.deleteForeground)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(OverdueRescuePalette.deleteFill))

                    Text("Delete this task?")
                        .font(.lifeboard(.title3))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This removes it from your board. You can undo right after deleting.")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Delete task")
                            .font(.lifeboard(.button))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.lifeboard.statusDanger)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .accessibilityIdentifier("home.rescue.delete.confirm")

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.lifeboard(.button))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.lifeboard.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .accessibilityIdentifier("home.rescue.delete.cancel")
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.lifeboard.bgCanvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
                    )
                    .lbShadow(ShadowTokens.rescueOverlay)
            )
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(deleteAccessibilityLabel)
        .accessibilityIdentifier("home.rescue.delete.overlay")
    }

    var deleteAccessibilityLabel: String {
        if let taskTitle, taskTitle.isEmpty == false {
            return "Delete \(taskTitle)? This removes it from your board. You can undo right after deleting."
        }
        return "Delete this task? This removes it from your board. You can undo right after deleting."
    }
}
