//
//  HomeViewController+TaskDetailFluent.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

extension HomeViewController: TaskDetailViewFluentDelegate {
    
    func taskDetailViewFluentDidUpdateRequest(_ view: TaskDetailViewFluent, updatedTask: NTask) {
        // Handle task update
        TaskManager.sharedInstance.saveContext()
        
        // Refresh UI
        // Updated to use FluentUI table view
        fluentSampleTableViewController?.tableView.reloadData()
        updateLineChartData()
    }
    
    @objc func dismissFluentDetailView() {
        guard let presentedFluentDetailView = presentedFluentDetailView, let overlayView = overlayView else {
            return
        }
        
        // Animate out
        UIView.animate(withDuration: 0.3, animations: {
            presentedFluentDetailView.alpha = 0
            overlayView.alpha = 0
        }, completion: { _ in
            presentedFluentDetailView.removeFromSuperview()
            overlayView.removeFromSuperview()
            self.presentedFluentDetailView = nil
            self.overlayView = nil
        })
    }
    
    func taskDetailViewFluentDidRequestDatePicker(_ view: TaskDetailViewFluent, for task: NTask, currentValue: Date?) {
        let dateTimePicker = FluentUI.DateTimePicker()
        dateTimePicker.delegate = self
        
        self.editingTaskForDatePicker = task
        self.activeTaskDetailViewFluent = view
        
        if let presentedVC = self.presentedViewController {
            if presentedVC is DateTimePicker || presentedVC is BottomSheetController {
                presentedVC.dismiss(animated: false, completion: nil)
            }
        }
        
        dateTimePicker.present(
            from: self,
            with: .dateTime,
            startDate: currentValue ?? Date()
        )
    }
    
    func taskDetailViewFluentDidRequestProjectPicker(_ view: TaskDetailViewFluent, for task: NTask, currentProject: Projects?, availableProjects: [Projects]) {
        if let presentedVC = self.presentedViewController {
            if presentedVC is DateTimePicker || presentedVC is BottomSheetController {
                presentedVC.dismiss(animated: false, completion: nil)
            }
        }
        
        let projectListVC = ProjectPickerViewController(projects: availableProjects, selectedProject: currentProject)
        projectListVC.onProjectSelected = { [weak self, weak view] selectedProjectEntity in
            guard let self = self, let view = view, let taskToUpdate = self.editingTaskForProjectPicker else { return }
            
            taskToUpdate.project = selectedProjectEntity?.projectName
            view.updateProjectButtonTitle(project: selectedProjectEntity?.projectName)
            
            TaskManager.sharedInstance.saveContext()
            // Updated to use FluentUI table view
            self.fluentSampleTableViewController?.tableView.reloadData()
            
            self.editingTaskForProjectPicker = nil
            self.activeTaskDetailViewFluent = nil
            
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
        
        self.editingTaskForProjectPicker = task
        self.activeTaskDetailViewFluent = view
        
        let bottomSheetController = BottomSheetController(expandedContentView: projectListVC.view)
        bottomSheetController.preferredExpandedContentHeight = CGFloat(min(availableProjects.count, 5) * 50 + 20)
        bottomSheetController.isHidden = false
        
        self.present(bottomSheetController, animated: true)
    }
}
