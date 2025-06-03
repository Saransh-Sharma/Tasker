//
//  HomeViewController+DateTimePicker.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

extension HomeViewController: DateTimePickerDelegate {
    
    func dateTimePicker(_ dateTimePicker: FluentUI.DateTimePicker, didPickStartDate startDate: Date, endDate: Date) {
        guard let task = self.editingTaskForDatePicker, let detailView = self.activeTaskDetailViewFluent else { return }
        
        let mode = dateTimePicker.mode ?? .date
        if mode.singleSelection {
            task.dueDate = startDate as NSDate
            detailView.updateDueDateButtonTitle(date: startDate)
            
            TaskManager.sharedInstance.saveContext()
            self.tableView.reloadData()
            updateLineChartData()
        }
        
        self.editingTaskForDatePicker = nil
        self.activeTaskDetailViewFluent = nil
        dateTimePicker.dismiss()
    }
    
    func dateTimePicker(_ dateTimePicker: DateTimePicker, didTapSelectedDate date: Date) {
        dateTimePicker.dismiss()
        self.editingTaskForDatePicker = nil
        self.activeTaskDetailViewFluent = nil
    }
}
