//
//  CalendarExtention.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import FSCalendar
import CoreData  // TODO: Migrate away from NSFetchRequest to use repository pattern


//----------------------- *************************** -----------------------
//MARK:-                            CALENDAR DELEGATE
//----------------------- *************************** -----------------------

//MARK:- CAL Extention: task count as day subtext
extension HomeViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendarView: FSCalendar, subtitleFor date: Date) -> String? {
        // Get tasks from Core Data directly
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        let allTasks = (try? context?.fetch(request)) ?? []
        
        if(allTasks.count == 0) {
            return "-"
        } else {
            return "\(allTasks.count) tasks"
        }
    }
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                       CALENDAR:SETUP
    //----------------------- *************************** -----------------------
    
    func setupCalView() {
        // Set appropriate height for week view - approximately 100 points is sufficient for a single week
        let calendarHeight: CGFloat = 100
        self.calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.frame.maxY-6, width: UIScreen.main.bounds.width, height: calendarHeight))
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                       CALENDAR:APPEARENCE
    //----------------------- *************************** -----------------------
    func setupCalAppearence() {
        
//        self.calendar.calendarHeaderView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        self.calendar.calendarHeaderView.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.5)
        self.calendar.calendarHeaderView.backgroundColor?.setFill()
        //UIColor.lightGray.withAlphaComponent(0.1)
        self.calendar.calendarWeekdayView.backgroundColor = todoColors.primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        
        
        
        self.calendar.appearance.headerTitleColor = .white
        self.calendar.appearance.headerTitleFont = setFont(fontSize: 16, fontweight: .light, fontDesign: .default) as UIFont
        
        
        //weekday title
        self.calendar.appearance.weekdayTextColor = .white
        // Customize weekday label colors for weekends
        for (index,label) in self.calendar.calendarWeekdayView.weekdayLabels.enumerated() {
            label.textColor = (index == 0 || index == 6) ? .systemRed : .white
        }
        self.calendar.appearance.weekdayFont = setFont(fontSize: 14, fontweight: .light, fontDesign: .rounded) as UIFont
        
        //weekend
        self.calendar.appearance.titleWeekendColor = .systemRed
        self.calendar.appearance.subtitleWeekendColor = .systemRed
        self.calendar.appearance.subtitleWeekendColor = .systemRed
        
        //date
        self.calendar.appearance.titleFont = setFont(fontSize: 16, fontweight: .regular, fontDesign: .rounded) as UIFont
        self.calendar.appearance.titleDefaultColor = .white
        self.calendar.appearance.caseOptions = .weekdayUsesUpperCase
        
        //selection
        self.calendar.appearance.selectionColor = todoColors.secondaryAccentColor
        self.calendar.appearance.subtitleDefaultColor = .white
        self.calendar.appearance.subtitleSelectionColor = .white
        self.calendar.appearance.subtitleTodayColor = .white
        
        self.calendar.firstWeekday = 2
        
        //today
        self.calendar.appearance.todayColor = todoColors.primaryColorDarker
        self.calendar.appearance.titleTodayColor = .white
        self.calendar.appearance.titleSelectionColor = .white
        self.calendar.appearance.subtitleSelectionColor = todoColors.primaryColorDarker
        self.calendar.appearance.subtitleFont = setFont(fontSize: 8, fontweight: .regular, fontDesign: .rounded) as UIFont
        self.calendar.appearance.borderSelectionColor = todoColors.primaryColorDarker
        
        
        self.calendar.dataSource = self
        self.calendar.delegate = self
        
        self.calendar.scope = FSCalendarScope.week
        
        // Ensure today's date is selected by default so filled circle is shown
        self.calendar.select(Date())
        self.calendar.reloadData()
    }
    
    // MARK: Text color customization to enforce white text and red weekends
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? {
        let weekday = Calendar.current.component(.weekday, from: date)
        return .white
    }
    
    // Date numbers/subtitles always white
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, subtitleDefaultColorFor date: Date) -> UIColor? {
        let weekday = Calendar.current.component(.weekday, from: date)
        return .white
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleSelectionColorFor date: Date) -> UIColor? {
        return .white
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, subtitleSelectionColorFor date: Date) -> UIColor? {
        return .white
    }
    
    // Additional customization for cell appearance (selected and today)
    func calendar(_ calendar: FSCalendar, willDisplay cell: FSCalendarCell, for date: Date, at monthPosition: FSCalendarMonthPosition) {
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = calendar.selectedDates.contains(date)
        let diameter = min(cell.bounds.width, cell.bounds.height) * 1.1 // 10% bigger than cell
        let rect = CGRect(x: (cell.bounds.width - diameter)/3, y: (cell.bounds.height - diameter)/3, width: diameter, height: diameter)

        // Draw outline circle for **today** only when it is *not* the currently selected date
        if isToday && !isSelected {
            cell.shapeLayer.fillColor = UIColor.clear.cgColor
            cell.shapeLayer.strokeColor = self.todoColors.secondaryAccentColor.cgColor
            cell.shapeLayer.lineWidth = 5
            cell.shapeLayer.path = UIBezierPath(ovalIn: rect).cgPath
            cell.shapeLayer.isHidden = false
        } else {
            cell.shapeLayer.isHidden = true
        }
        


        // Handle filled selection circle
        let innerTag = "selectedFillLayer"
        // Remove any existing inner layer first
        cell.contentView.layer.sublayers?.removeAll(where: { $0.name == innerTag })

        if isToday && isSelected {
            let innerDiameter = diameter * 1 // slightly smaller to stay inside outline
            let innerRect = CGRect(x: (cell.bounds.width - innerDiameter)/2, y: (cell.bounds.height - innerDiameter)/2, width: innerDiameter, height: innerDiameter)
            let innerLayer = CAShapeLayer()
            innerLayer.name = innerTag
            innerLayer.path = UIBezierPath(ovalIn: innerRect).cgPath
            innerLayer.fillColor = (calendar.appearance.selectionColor ?? self.todoColors.secondaryAccentColor).cgColor
            cell.contentView.layer.insertSublayer(innerLayer, above: cell.shapeLayer)
        }
        
        if isSelected {
            let innerDiameter = diameter * 1 // slightly smaller to stay inside outline
            let innerRect = CGRect(x: (cell.bounds.width - innerDiameter)/2, y: (cell.bounds.height - innerDiameter)/2, width: innerDiameter, height: innerDiameter)
            let innerLayer = CAShapeLayer()
            innerLayer.name = innerTag
            innerLayer.path = UIBezierPath(ovalIn: innerRect).cgPath
            innerLayer.fillColor = (calendar.appearance.selectionColor ?? self.todoColors.secondaryAccentColor).cgColor
            cell.contentView.layer.insertSublayer(innerLayer, above: cell.shapeLayer)
        }
        

    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                            CALENDAR: didSelect
    //----------------------- *************************** -----------------------
    
    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendarView: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        print("\n=== CALENDAR DATE SELECTED ===")
        print("You selected Date from Cal: \(date.stringIn(dateStyle: .full, timeStyle: .none))")
        print("Selected date: \(date)")
        print("Is today? \(date == Date.today())")
        
        setDateForViewValue(dateToSetForView: date)
        print("dateForTheView set to: \(dateForTheView)")
        
        if (date == Date.today()) {
            print("Updating view for TODAY")
            updateViewForHome(viewType: .todayHomeView)
        } else {
            print("Updating view for CUSTOM DATE")
            updateViewForHome(viewType: .customDateView, dateForView: date)
        }
        
        print("=== CALENDAR SELECTION COMPLETE ===")
        
        self.updateHomeDateLabel(date: dateForTheView)
        // Asynchronously calculate and display the new score for the selected date
        self.updateDailyScore(for: date)

        
        
        reloadTinyPicChartWithAnimation()
        reloadToDoListWithAnimation()

        // Phase 7: Update horizontal chart cards for the new week
        updateChartCardsScrollView()

        // Refresh sample table view with selected date
        refreshSampleTableView(for: date)
        
        // Reload calendar to update custom cell appearance (today outline etc.)
        self.calendar.reloadData()
        
    }
    
    //MARK: Calendar page change - updates chart when week changes
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        print("\n=== CALENDAR PAGE CHANGED ===")
        print("Calendar current page: \(calendar.currentPage)")

        // Phase 7: Update horizontal chart cards for the new week
        updateChartCardsScrollView()

        print("=== CALENDAR PAGE CHANGE COMPLETE ===")
    }
    
    
    
    
}
