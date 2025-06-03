//
//  HomeViewController+Utilities.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import SemiModalViewController

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
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(fontDesign)!
        
        return UIFont.systemFont(ofSize: fontSize, weight: fontweight)
    }
    
    // MARK: - UI Updates
    
    func updateHomeDateLabel(date: Date) {
        // Update date label with formatted date
        if date == Date.today() {
            toDoListHeaderLabel.text = "Today"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            toDoListHeaderLabel.text = formatter.string(from: date)
        }
    }
    
    // MARK: - Task Counting
    
    func getTaskForTodayCount() -> Int {
        var morningTasks = [NTask]()
        var eveTasks = [NTask]()
        
        morningTasks = TaskManager.sharedInstance.getMorningTasks(for: Date.today()) // Plan Step F: Updated call
        eveTasks = TaskManager.sharedInstance.getEveningTasksForToday()
        
        return morningTasks.count + eveTasks.count
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
        tableView.backgroundColor = todoColors.darkModeColor
        
        // Apply dark mode to other UI elements as needed
        for view in self.view.subviews {
            if let view = view as? UILabel {
                view.textColor = .white
            }
        }
    }
    
    func disableDarkMode() {
        view.backgroundColor = todoColors.backgroundColor
        tableView.backgroundColor = todoColors.backgroundColor
        
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
            view.backgroundColor = todoColors.backgroundColor
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
        
        let frameForView = view.frame
        
        // Create and configure UI controls for the semi-modal view
        // (Implementation would be specific to your app's requirements)
        
        return view
    }
    
    func semiViewDefaultOptions(viewToBePrsented: UIView) {
        let options: [SemiModalOption : Any] = [
            SemiModalOption.pushParentBack: true,
            SemiModalOption.animationDuration: 0.2
        ]
        
        presentSemiView(viewToBePrsented, options: options)
    }
}
