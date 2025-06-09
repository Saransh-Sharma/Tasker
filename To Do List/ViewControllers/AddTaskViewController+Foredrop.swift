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
        // Position the foredrop container below the calendar
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let safeAreaBottomInset = view.safeAreaInsets.bottom
        
        // Calculate position dynamically based on calendar position
        let calendarStartY = homeTopBar.frame.maxY - 6
        let calendarHeight = homeTopBar.frame.maxY
        let foredropTopY = calendarStartY + calendarHeight + 10 // Add 10pt padding
        let foredropHeight = screenHeight - foredropTopY - safeAreaBottomInset - 20
        
        foredropContainer.frame = CGRect(x: 0, 
                                       y: foredropTopY, 
                                       width: screenWidth, 
                                       height: foredropHeight)
        foredropContainer.backgroundColor = todoColors.foregroundColor
        foredropContainer.layer.cornerRadius = 24
        foredropContainer.clipsToBounds = true
        
        // Add shadow for better visual separation
        foredropContainer.layer.shadowColor = UIColor.black.cgColor
        foredropContainer.layer.shadowOffset = CGSize(width: 0, height: -3)
        foredropContainer.layer.shadowOpacity = 0.1
        foredropContainer.layer.shadowRadius = 10
        foredropContainer.layer.masksToBounds = false
        
        view.addSubview(foredropContainer)

        foredropStackContainer.translatesAutoresizingMaskIntoConstraints = false
        foredropContainer.addSubview(foredropStackContainer)
        NSLayoutConstraint.activate([
            foredropStackContainer.leadingAnchor.constraint(equalTo: foredropContainer.leadingAnchor, constant: 16),
            foredropStackContainer.trailingAnchor.constraint(equalTo: foredropContainer.trailingAnchor, constant: -16),
            foredropStackContainer.topAnchor.constraint(equalTo: foredropContainer.topAnchor, constant: 20),
            foredropStackContainer.bottomAnchor.constraint(lessThanOrEqualTo: foredropContainer.bottomAnchor, constant: -20)
        ])
    }

    // Pills across the top for project picking - method moved to AddTaskForedropView.swift to avoid duplicate declaration

    // MARK: – Actions wired from selectors

    @objc func cancelAddTaskAction() {
        dismiss(animated: true)
    }

    @objc func doneAddTaskAction() {
        guard !currentTaskInMaterialTextBox.isEmpty else { return }
        
        print("💾 AddTask: Starting task creation process...")
        print("💾 AddTask: Task name: '\(currentTaskInMaterialTextBox)'")
        print("💾 AddTask: Due date: \(dateForAddTaskView)")
        print("💾 AddTask: Project: '\(currenttProjectForAddTaskView)'")
        
        // Use the selected calendar date as the due date
        let newTask = TaskManager.sharedInstance.addNewTask_Future(
            name: currentTaskInMaterialTextBox,
            taskType: isThisEveningTask ? 2 : 1,
            taskPriority: currentTaskPriority,
            futureTaskDate: dateForAddTaskView,
            isEveningTask: isThisEveningTask,
            project: currenttProjectForAddTaskView
        )
        
        print("💾 AddTask: Task created with ID: \(newTask.objectID)")
        
        // Update the task details with the description if provided
        if !currentTaskDescription.isEmpty {
            print("💾 AddTask: Updating task details...")
            newTask.taskDetails = currentTaskDescription
            TaskManager.sharedInstance.saveContext()
            print("💾 AddTask: Task details saved to Core Data")
        }
        
        print("💾 AddTask: About to notify delegate...")
        // Notify delegate that a new task was added
        delegate?.didAddTask(newTask)
        print("💾 AddTask: Delegate notified, dismissing view...")
        
        dismiss(animated: true)
    }
}
