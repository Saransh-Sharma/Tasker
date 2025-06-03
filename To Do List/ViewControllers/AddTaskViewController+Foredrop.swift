import UIKit
import FluentUI
import FSCalendar
import MaterialComponents

extension AddTaskViewController {

    // Backdrop identical to HomeVC – extracted for reuse
    func setupBackdrop() {
        backdropContainer.frame = view.bounds
        backdropContainer.backgroundColor = todoColors.backgroundColor
    }

    // The main foredrop sheet
    func setupAddTaskForedrop() {
        foredropContainer.backgroundColor = todoColors.foregroundColor
        foredropContainer.layer.cornerRadius = 24
        foredropContainer.clipsToBounds = true
        view.addSubview(foredropContainer)

        foredropStackContainer.translatesAutoresizingMaskIntoConstraints = false
        foredropContainer.addSubview(foredropStackContainer)
        NSLayoutConstraint.activate([
            foredropStackContainer.leadingAnchor.constraint(equalTo: foredropContainer.leadingAnchor),
            foredropStackContainer.trailingAnchor.constraint(equalTo: foredropContainer.trailingAnchor),
            foredropStackContainer.topAnchor.constraint(equalTo: foredropContainer.topAnchor),
            foredropStackContainer.bottomAnchor.constraint(equalTo: foredropContainer.bottomAnchor)
        ])
    }

    // Pills across the top for project picking
    func setupProjectsPillBar() {
        pillBarProjectList = ProjectManager.sharedInstance.displayedProjects
            .map { PillButtonBarItem(title: $0.projectName ?? "") }
        pillBarProjectList.insert(PillButtonBarItem(title: addProjectString), at: 0)

        let pillBar = PillButtonBar(pillButtonStyle: .primary)
        pillBar.items = pillBarProjectList
        pillBar.barDelegate = self
        filledBar?.removeFromSuperview()

        filledBar = pillBar
        foredropStackContainer.insertArrangedSubview(pillBar, at: 0)
    }

    // MARK: – Actions wired from selectors

    @objc func cancelAddTaskAction() {
        dismiss(animated: true)
    }

    @objc func doneAddTaskAction() {
        guard !currentTaskInMaterialTextBox.isEmpty else { return }
        TaskManager.sharedInstance.addNewTask_Today(
            name: currentTaskInMaterialTextBox,
            taskType: isThisEveningTask ? 2 : 1,
            taskPriority: currentTaskPriority,
            isEveningTask: isThisEveningTask
        )
        delegate?.didAddTask(TaskManager.sharedInstance.getAllTasks.last!)
        dismiss(animated: true)
    }
}
