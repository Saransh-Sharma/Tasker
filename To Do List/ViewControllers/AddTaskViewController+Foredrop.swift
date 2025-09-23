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
        guard !currentTaskInMaterialTextBox.isEmpty else { 
            print("⚠️ AddTask: Task name is empty, returning early")
            return 
        }
        
        print("🚀 AddTask: Starting task creation process...")
        print("📝 AddTask: Task name: '\(currentTaskInMaterialTextBox)'")
        print("📅 AddTask: Due date: \(dateForAddTaskView)")
        print("📁 AddTask: Project: '\(currenttProjectForAddTaskView)'")
        print("🤝 AddTask: Delegate is set: \(delegate != nil)")
        
        // CRITICAL: Check taskRepository state before using it
        print("🔍 AddTask: Checking taskRepository state...")
        if taskRepository == nil {
            print("❌ AddTask: CRITICAL ERROR - taskRepository is nil!")
            print("🔧 AddTask: This indicates dependency injection failed")
            print("📊 AddTask: View controller type: \(String(describing: type(of: self)))")
            print("🏗️ AddTask: Attempting to get repository from DependencyContainer...")
            
            // Fallback: try to get repository from dependency container
            if let fallbackRepository = DependencyContainer.shared.taskRepository {
                print("✅ AddTask: Found fallback repository from DependencyContainer")
                taskRepository = fallbackRepository
            } else {
                print("💥 AddTask: FATAL - No repository available anywhere!")
                // Show error to user instead of crashing
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error", message: "Unable to save task. Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                return
            }
        } else {
            print("✅ AddTask: taskRepository is properly initialized")
            print("📊 AddTask: Repository type: \(String(describing: type(of: taskRepository)))")
        }
        
        // Determine task type based on evening switch
        let taskType: Int32 = isThisEveningTask ? 2 : 1 // 2=evening, 1=morning
        print("🌅 AddTask: Task type: \(taskType)")
        
        // Create TaskData object
        let taskData = TaskData(
            name: currentTaskInMaterialTextBox,
            details: currentTaskDescription.isEmpty ? nil : currentTaskDescription,
            type: taskType,
            priorityRawValue: Int32(currentTaskPriority.rawValue),
            dueDate: dateForAddTaskView,
            project: currenttProjectForAddTaskView
        )
        print("📦 AddTask: TaskData created successfully")
        
        // Add task using repository pattern
        print("💾 AddTask: Calling taskRepository.addTask...")
        taskRepository.addTask(data: taskData) { [weak self] (result: Result<NTask, Error>) in
            print("📬 AddTask: Received response from taskRepository.addTask")
            DispatchQueue.main.async {
                print("🔄 AddTask: Processing result on main queue")
                switch result {
                case .success(let createdTask):
                    print("✅ AddTask: Task created successfully!")
                    print("🆔 AddTask: Task ID: \(createdTask.objectID)")
                    print("📝 AddTask: Task name: \(createdTask.name ?? "Unknown")")
                    print("📅 AddTask: Task due date: \(createdTask.dueDate ?? Date() as NSDate)")
                    
                    // Dismiss view and notify delegate after dismissal
                    print("🚪 AddTask: Dismissing view and will notify delegate after dismissal")
                    self?.dismiss(animated: true) {
                        print("🔔 AddTask: View dismissed, now notifying delegate...")
                        if let delegate = self?.delegate {
                            print("👥 AddTask: Delegate found, calling didAddTask()")
                            print("📊 AddTask: Delegate type: \(String(describing: type(of: delegate)))")
                            delegate.didAddTask(createdTask)
                            print("✅ AddTask: Delegate notified successfully!")
                        } else {
                            print("❌ AddTask: ERROR - Delegate is nil after dismissal!")
                            print("🔍 AddTask: This might indicate the parent view controller was deallocated")
                        }
                    }
                    
                case .failure(let error):
                    print("❌ AddTask: Failed to create task!")
                    print("💥 AddTask: Error: \(error)")
                    print("🔍 AddTask: Error type: \(String(describing: type(of: error)))")
                    if let nsError = error as NSError? {
                        print("📊 AddTask: Error domain: \(nsError.domain)")
                        print("🔢 AddTask: Error code: \(nsError.code)")
                        print("📝 AddTask: Error description: \(nsError.localizedDescription)")
                        if let userInfo = nsError.userInfo as? [String: Any], !userInfo.isEmpty {
                            print("ℹ️ AddTask: Error userInfo: \(userInfo)")
                        }
                    }
                    
                    // Show error alert to user
                    let alert = UIAlertController(
                        title: "Error Creating Task",
                        message: "Failed to create task: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    print("🚨 AddTask: Error alert presented to user")
                }
            }
        }
    }
}
