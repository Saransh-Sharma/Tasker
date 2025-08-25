//
//  HomeViewController+Utilities.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit

extension HomeViewController {
    
    // MARK: - UI Container Utilities
    
    static func createVerticalContainer() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 16
        return stackView
    }
    
    // MARK: - Font Utilities
    
    func setFont(fontSize: CGFloat, fontweight: UIFont.Weight = .regular, fontDesign: UIFontDescriptor.SystemDesign = .default) -> UIFont {
        let _ = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body) // descriptor - unused
            .withDesign(fontDesign)!
        
        return UIFont.systemFont(ofSize: fontSize, weight: fontweight)
    }
    
    // MARK: - UI Updates
    
    func updateHomeDateLabel(date: Date) {
        let titleText = formatDateTitle(for: date)
        
        // Update date label with formatted date
        toDoListHeaderLabel.text = titleText
        

    }
    
    private func formatDateTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let today = Date.today()
        
        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) {
            return "Yesterday"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today)!) {
            return "Tomorrow"
        } else {
            // Format as "Weekday, Ordinal" (e.g., "Friday, 13th" or "Monday, 3rd")
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE" // Full weekday name
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d" // Day number
            
            let weekday = weekdayFormatter.string(from: date)
            let day = Int(dayFormatter.string(from: date)) ?? 1
            let ordinalDay = formatDayWithOrdinalSuffix(day)
            
            return "\(weekday), \(ordinalDay)"
        }
    }
    
    private func formatDayWithOrdinalSuffix(_ day: Int) -> String {
        let suffix: String
        
        switch day {
        case 11, 12, 13:
            suffix = "th" // Special cases for 11th, 12th, 13th
        default:
            switch day % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }
        
        return "\(day)\(suffix)"
    }
    
    // MARK: - Task Counting
    
    func getTaskForTodayCount() -> Int {
        // Note: This method needs to be refactored to use async repository calls
        // For now, returning 0 as a placeholder until the calling code is updated
        // to handle async operations properly
        return 0
    }
    
    /// Async version of getTaskForTodayCount that uses the repository pattern
    func getTaskForTodayCount(completion: @escaping (Int) -> Void) {
        let today = Date()
        var morningCount = 0
        var eveningCount = 0
        let group = DispatchGroup()
        
        group.enter()
        taskRepository.getMorningTasks(for: today) { tasks in
            morningCount = tasks.count
            group.leave()
        }
        
        group.enter()
        taskRepository.getEveningTasks(for: today) { tasks in
            eveningCount = tasks.count
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(morningCount + eveningCount)
        }
    }
    
    func getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: Bool) -> Int {
        // Convert between morning/evening task index and global collection index
        return morningOrEveningTask ? 0 : 1
    }
    
    // MARK: - Theme Toggle
    
    @IBAction func toggleDarkModeAction(_ sender: Any) {
        let mSwitch = sender as! UISwitch
        
        if mSwitch.isOn {
            UserDefaults.standard.set(true, forKey: "isDarkModeOn")
            enableDarkMode()
        } else {
            UserDefaults.standard.set(false, forKey: "isDarkModeOn")
            disableDarkMode()
        }
    }
    
    func enableDarkMode() {
        view.backgroundColor = todoColors.darkModeColor
        // Updated to use FluentUI table view
        fluentToDoTableViewController?.tableView.backgroundColor = todoColors.darkModeColor
        
        // Apply dark mode to other UI elements as needed
        for view in self.view.subviews {
            if let view = view as? UILabel {
                view.textColor = .white
            }
        }
    }
    
    func disableDarkMode() {
        view.backgroundColor = todoColors.primaryColor
        // Updated to use FluentUI table view
        fluentToDoTableViewController?.tableView.backgroundColor = todoColors.backgroundColor
        
        // Restore light mode to other UI elements as needed
        for view in self.view.subviews {
            if let view = view as? UILabel {
                view.textColor = todoColors.primaryTextColor
            }
        }
    }
    
    func enableDarkModeIfPreset() {
        if UserDefaults.standard.bool(forKey: "isDarkModeOn") {
            darkModeToggle.isOn = true
            enableDarkMode()
        } else {
            view.backgroundColor = todoColors.primaryColor
        }
    }
    
    // MARK: - Background Change
    
    @IBAction func changeBackgroundAction(_ sender: Any) {
        // Implement background changing logic
    }
    
    // MARK: - Semi View Helpers
    
    func serveSemiViewRed() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        view.backgroundColor = UIColor.red
        
        let mylabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 60))
        mylabel.center = view.center
        mylabel.text = "This is placeholder text"
        mylabel.textAlignment = .center
        mylabel.backgroundColor = .white
        view.addSubview(mylabel)
        
        return view
    }
    
    func serveSemiViewBlue(task: NTask) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        
        let _ = view.frame // frameForView - unused
        
        // Create and configure UI controls for the semi-modal view
        // (Implementation would be specific to your app's requirements)
        
        return view
    }
    
    func semiViewDefaultOptions(viewToBePrsented: UIView) {
        // Fallback implementation using UIKit's sheet presentation
        let wrapper = UIViewController()
        wrapper.view.backgroundColor = .clear
        viewToBePrsented.translatesAutoresizingMaskIntoConstraints = false
        wrapper.view.addSubview(viewToBePrsented)
        NSLayoutConstraint.activate([
            viewToBePrsented.leadingAnchor.constraint(equalTo: wrapper.view.leadingAnchor),
            viewToBePrsented.trailingAnchor.constraint(equalTo: wrapper.view.trailingAnchor),
            viewToBePrsented.bottomAnchor.constraint(equalTo: wrapper.view.safeAreaLayoutGuide.bottomAnchor),
            viewToBePrsented.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        wrapper.modalPresentationStyle = .pageSheet
        if let sheet = wrapper.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(wrapper, animated: true)
    }
}
