//
//  BackdropView.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/05/20.
//  Copyright 2020 saransh1337. All rights reserved.


import Foundation
import TinyConstraints
import FSCalendar
import MaterialComponents.MaterialRipple
import UIKit


extension HomeViewController {
    
    func setupBackdrop() {
        
        backdropContainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        headerEndY = UIScreen.main.bounds.height/8
        setupBackdropBackground()
        // addTinyChartToBackdrop() - removed pie chart
        setupBackdropNotch()
        setupHomeDateView()
        updateHomeViewDate(dateToDisplay: dateForTheView)
        setupLineChartView()
        updateLineChartData()
        lineChartView.isHidden = false // Show chart by default with sample data
        
        // Phase 3: Setup SwiftUI Chart Card alongside existing chart
        setupSwiftUIChartCard()
        
        // cal
        setupCalView()
        setupCalAppearence()
        backdropContainer.addSubview(calendar)
        calendar.isHidden = false   // always present under foredrop
        setupCalButton()
        setupChartButton()
        setupTopSeperator()
        
        // Pie chart setup removed
        // self.setupPieChartView(pieChartView: tinyPieChartView)
        // updateTinyPieChartData()
        // tinyPieChartView.delegate = self
        
        // entry label styling - removed
        // tinyPieChartView.entryLabelColor = .clear
        // tinyPieChartView.entryLabelFont = .systemFont(ofSize: 12, weight: .bold)
        
        backdropContainer.bringSubviewToFront(calendar)
        // remember original position for restore
        originalForedropCenterY = foredropContainer.center.y

        // compute revealDistance once
        let bottomOfCalendar = calendar.frame.maxY
        let bottomOfChart    = lineChartView.frame.maxY
        let requiredReveal   = max(bottomOfCalendar, bottomOfChart)
        let foredropTopY     = foredropContainer.frame.minY
        let padding: CGFloat = 16
        revealDistance = (requiredReveal - foredropTopY) + padding

        // hook both buttons to same toggle
        revealCalAtHomeButton.addTarget(self, action: #selector(toggleCalendar), for: .touchUpInside)
        revealChartsAtHomeButton.addTarget(self, action: #selector(toggleCharts), for: .touchUpInside)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1: SETUP BACKGROUND
    //----------------------- *************************** -----------------------
    
    //MARK:- Setup Backdrop Background - Today label + Score
    func setupBackdropBackground() {
        
//        backdropBackgroundImageView.frame =  CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = todoColors.primaryColor
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)
        
        
        //---------- score at home
        
        scoreAtHomeLabel.text = "\n\nscore"
        scoreAtHomeLabel.numberOfLines = 3
        scoreAtHomeLabel.textColor = .label
        scoreAtHomeLabel.font = setFont(fontSize: 20, fontweight: .regular, fontDesign: .monospaced)
        
        
        scoreAtHomeLabel.textAlignment = .center
        scoreAtHomeLabel.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 20, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        
        //        homeTopBar.addSubview(scoreAtHomeLabel)
        
        //---- score
        
        scoreCounter.text = "\(self.calculateTodaysScore())"
        scoreCounter.numberOfLines = 1
        scoreCounter.textColor = .systemGray5
        scoreCounter.font = setFont(fontSize: 52, fontweight: .bold, fontDesign: .rounded)
        
        scoreCounter.textAlignment = .center
        scoreCounter.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 15, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        
        backdropContainer.addSubview(backdropBackgroundImageView)
        
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1.1 : SETUP NOTCH BACKDROP
    //----------------------- *************************** -----------------------
    
    //MARK:- Setup Backdrop Notch
    func setupBackdropNotch() {
        // inline safe-area check instead of hasNotch extension
        let topInset: CGFloat
        if #available(iOS 11.0, *) {
            topInset = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
        } else {
            topInset = 0
        }
        if topInset > 20 {
            print("I SEE NOTCH !!")
        } else {
            print("NO NOTCH !")
        }
    }
    
    func addTinyChartToBackdrop() {
        // Pie chart removed - method disabled
        // tinyPieChartView.frame = CGRect(x: homeTopBar.frame.maxX-(homeTopBar.frame.height + 10), y: homeTopBar.frame.minY + 15, width: (homeTopBar.frame.height)+41, height: (homeTopBar.frame.height)+41)
        // backdropContainer.addSubview(tinyPieChartView)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    SETUP HOME DATE VIEW
    //                          sub:homeTopBar
    //----------------------- *************************** -----------------------
    func setupHomeDateView() {
        homeDate_WeekDay.adjustsFontSizeToFitWidth = true
        homeDate_Month.adjustsFontSizeToFitWidth = true
        
        homeDate_Day.frame = CGRect(x: 5, y: 18, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        homeDate_WeekDay.frame = CGRect(x: 76, y: homeTopBar.bounds.minY+30, width: (homeTopBar.bounds.width/2)-100, height: homeTopBar.bounds.height)
        homeDate_Month.frame = CGRect(x: 76, y: homeTopBar.bounds.minY+10, width: (homeTopBar.bounds.width/2)-80, height: homeTopBar.bounds.height)
    }
    
    func updateHomeViewDate(dateToDisplay: Date) {
        let today = dateToDisplay
        if("\(today.day)".count < 2) {
            homeDate_Day.text = "0\(today.day)"
        } else {
            homeDate_Day.text = "\(today.day)"
        }
        homeDate_WeekDay.text = todoTimeUtils.getWeekday(date: today)
        homeDate_Month.text = todoTimeUtils.getMonth(date: today)
        
        
        homeDate_Day.numberOfLines = 1
        homeDate_WeekDay.numberOfLines = 1
        homeDate_Month.numberOfLines = 1
        
        homeDate_Day.textColor = .systemGray6
        homeDate_WeekDay.textColor = .systemGray6
        homeDate_Month.textColor = .systemGray6
        
        
        homeDate_Day.font =  setFont(fontSize: 58, fontweight: .medium, fontDesign: .rounded)
        homeDate_WeekDay.font =  setFont(fontSize: 26, fontweight: .thin, fontDesign: .rounded)
        homeDate_Month.font =  setFont(fontSize: 26, fontweight: .regular, fontDesign: .rounded)
        
        homeDate_Day.textAlignment = .left
        homeDate_WeekDay.textAlignment = .left
        homeDate_Month.textAlignment = .left
        
        homeTopBar.addSubview(homeDate_Day)
        homeTopBar.addSubview(homeDate_WeekDay)
        homeTopBar.addSubview(homeDate_Month)
        
        
        homeDate_Day.layer.shadowColor =  todoColors.primaryColorDarker.cgColor//todoColors.primaryColorDarker.cgColor
        homeDate_Day.layer.shadowOpacity = 0.6
        homeDate_Day.layer.shadowOffset = .zero //CGSize(width: -2.0, height: -2.0) //.zero
        homeDate_Day.layer.shadowRadius = 8
        
        homeDate_WeekDay.layer.shadowColor = todoColors.primaryColorDarker.cgColor
        homeDate_WeekDay.layer.shadowOpacity = 0.6
        homeDate_WeekDay.layer.shadowOffset = .zero //CGSize(width: -2.0, height: -2.0) //.zero
        homeDate_WeekDay.layer.shadowRadius = 8
        
        homeDate_Month.layer.shadowColor = todoColors.primaryColorDarker.cgColor
        homeDate_Month.layer.shadowOpacity = 0.6
        homeDate_Month.layer.shadowOffset = .zero //CGSize(width: -2.0, height: -2.0) //.zero
        homeDate_Month.layer.shadowRadius = 8
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                         TOP SEPERATOR
    //                               sub:homeTopBar
    //----------------------- *************************** -----------------------
    func setupTopSeperator() {
        
        seperatorTopLineView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2, y: backdropNochImageView.bounds.height + 10, width: 1.0, height: homeTopBar.bounds.height/2))
        seperatorTopLineView.layer.borderWidth = 1.0
        seperatorTopLineView.layer.borderColor = UIColor.gray.cgColor
        homeTopBar.addSubview(seperatorTopLineView)
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    SETUP CALENDAR BUTTON
    //                          sub:backdrop view
    //----------------------- *************************** -----------------------
    func setupCalButton()  {
        revealCalAtHomeButton.backgroundColor = .clear
        revealCalAtHomeButton.frame = CGRect(x: 0 , y: UIScreen.main.bounds.minY+40, width: (UIScreen.main.bounds.width/2), height: homeTopBar.bounds.height/2 + 30 )
        let CalButtonRippleDelegate = DateViewRippleDelegate()
        let calButtonRippleController = MDCRippleTouchController(view: revealCalAtHomeButton)
        calButtonRippleController.delegate = CalButtonRippleDelegate
        //        homeTopBar.addSubview(revealCalAtHomeButton)
        view.addSubview(revealCalAtHomeButton)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     CHARTS BUTTON
    //----------------------- *************************** -----------------------
    
    func setupChartButton()  {
        revealChartsAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2) , y: UIScreen.main.bounds.minY+40, width: (UIScreen.main.bounds.width/2), height: homeTopBar.bounds.height/2 + 30 )
        revealChartsAtHomeButton.backgroundColor = .clear
        let ChartsButtonRippleDelegate = TinyPieChartRippleDelegate()
        let chartsButtonRippleController = MDCRippleTouchController(view: revealChartsAtHomeButton)
        chartsButtonRippleController.delegate = ChartsButtonRippleDelegate
        view.addSubview(revealChartsAtHomeButton)
        //        homeTopBar.addSubview(revealChartsAtHomeButton)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     ACTION: SHOW CALENDAR
    //----------------------- *************************** -----------------------
    
    @objc func toggleCalendar() {
        let padding: CGFloat = 8
        let isOpening = calendar.isHidden
        let targetY = isOpening ? calendar.frame.maxY + padding : foredropClosedY
        animateForedrop(to: targetY) {
            self.calendar.isHidden.toggle()
        }
    }
    
    @objc func toggleCharts() {
        let padding: CGFloat = 8
        // Use SwiftUI chart container instead of lineChartView (Phase 5)
        let isOpening = swiftUIChartContainer?.isHidden ?? true
        let chartHeight: CGFloat = swiftUIChartContainer?.frame.height ?? 200
        let targetY = isOpening ? foredropClosedY + chartHeight + padding : foredropClosedY
        animateForedrop(to: targetY) {
            self.swiftUIChartContainer?.isHidden.toggle()
            // Keep old chart hidden (Phase 5: Cleanup)
            self.lineChartView.isHidden = true
        }
    }
    
    private func animateForedrop(to y: CGFloat, completion: @escaping () -> Void) {
        UIView.animate(
          withDuration: 0.6,
          delay: 0,
          usingSpringWithDamping: 0.8,
          initialSpringVelocity: 1,
          options: .curveEaseInOut
        ) {
          var f = self.foredropContainer.frame
          f.origin.y = y
          self.foredropContainer.frame = f
        } completion: { _ in
          completion()
        }
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    setup line chart (Phase 5: DEPRECATED)
    //----------------------- *************************** -----------------------
    func setupLineChartView() {
        // Phase 5: Legacy UIKit chart setup - keeping for compatibility but chart will remain hidden
        backdropContainer.addSubview(lineChartView)
        lineChartView.centerInSuperview()
        lineChartView.edges(to: backdropBackgroundImageView, insets: TinyEdgeInsets(top: 2*headerEndY, left: 0, bottom: UIScreen.main.bounds.height/2.5, right: 0))
        
        // Immediately hide the old chart (Phase 5: Transition)
        lineChartView.isHidden = true
        
        print("⚠️ Phase 5: Legacy UIKit chart setup completed but hidden")
    }
    
    @objc func hideChartsAndCalendar() {
        let delay: TimeInterval    = 0.2
        let duration: TimeInterval = 1.2

        UIView.animate(
          withDuration: duration,
          delay: delay,
          usingSpringWithDamping: 0.5,
          initialSpringVelocity: 2,
          options: .curveLinear
        ) {
          self.foredropContainer.center.y = self.originalForedropCenterY
        } completion: { _ in
          self.calendar.isHidden      = true
          // Phase 5: Only hide SwiftUI chart, keep old chart permanently hidden
          self.lineChartView.isHidden = true
          self.swiftUIChartContainer?.isHidden = true
          self.isCalDown    = false
          self.isChartsDown = false
          self.tableView.reloadData()
        }
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                    setup SwiftUI chart card (Phase 5: Transition)
    //----------------------- *************************** -----------------------
    func setupSwiftUIChartCard() {
        // Create SwiftUI chart card
        let chartCard = TaskProgressCard(referenceDate: dateForTheView)
        swiftUIChartHostingController = UIHostingController(rootView: AnyView(chartCard))
        
        guard let hostingController = swiftUIChartHostingController else { return }
        
        // Create container view for the SwiftUI chart
        swiftUIChartContainer = UIView()
        guard let container = swiftUIChartContainer else { return }
        
        // Add hosting controller as child
        addChild(hostingController)
        container.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Configure container
        container.backgroundColor = .clear
        backdropContainer.addSubview(container)
        
        // Position SwiftUI chart in the original chart location (Phase 5)
        container.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container constraints - same position as original lineChartView
            container.leadingAnchor.constraint(equalTo: backdropBackgroundImageView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: backdropBackgroundImageView.trailingAnchor),
            container.topAnchor.constraint(equalTo: backdropBackgroundImageView.topAnchor, constant: 2*headerEndY),
            container.bottomAnchor.constraint(equalTo: backdropBackgroundImageView.bottomAnchor, constant: -UIScreen.main.bounds.height/2.5),
            
            // Hosting controller view constraints
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Show SwiftUI chart as primary chart (Phase 5)
        container.isHidden = false
        
        print("✅ Phase 5: SwiftUI Chart Card positioned as primary chart")
    }
    
    func updateSwiftUIChartCard() {
        // Update the SwiftUI chart with new data when needed
        guard let hostingController = swiftUIChartHostingController else { return }
        
        let updatedChartCard = TaskProgressCard(referenceDate: dateForTheView)
        hostingController.rootView = updatedChartCard
        
        print("📊 SwiftUI Chart Card updated with new reference date")
    }

}
