//
//  ViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData
import SemiModalViewController
import CircleMenu
import ViewAnimator
import FSCalendar
import EasyPeasy
import BEMCheckBox
import Charts
import TinyConstraints
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialBottomAppBar
import MaterialComponents.MaterialButtons_Theming


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ChartViewDelegate {
    
    
    //MARK:- Tableview animation style
    private let animations = [AnimationType.from(direction:.right , offset: 400.0)]
    
    //MARK:- Positioning
    var headerEndY: CGFloat = 128
    
    //MARK:- LINE CHART
    lazy var lineChartView: LineChartView = {
        let chartView = LineChartView()
        chartView.backgroundColor = .clear
        //        chartView.legend.form = .empty
        chartView.legend.form = .default
        
        
        chartView.rightAxis.enabled = false
        
        let yAxis = chartView.leftAxis
        yAxis.labelFont = .boldSystemFont(ofSize: 12)
        //        yAxis.setLabelCount(7, force: false)
        yAxis.labelTextColor = .secondaryLabel
        yAxis.axisLineColor = .tertiaryLabel
        yAxis.labelPosition = .outsideChart
        
        //        yAxis
        //        yAxis.
        
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelFont = .boldSystemFont(ofSize: 12)
        chartView.xAxis.axisLineColor = .tertiaryLabel
        chartView.xAxis.labelTextColor = .secondaryLabel
        
        //        chartView.animate(yAxisDuration: 1.1, easingOption: .easeInBack)
        chartView.animate(yAxisDuration: 1.1, easingOption: .easeInOutBack)
        //        chartView.animate(yAxisDuration: 1.1, easingOption: .easeInCubic)
        
        
        return chartView
    }()
    
    //MARK:- cuurentt task list date
    var dateForTheView = Date.today()
    var dateToDisplay = Date.today()
    
    //MARK:- score for day label
    var scoreForTheDay: UILabel! = nil
    
    
    //MARK:- Buttons + Views + Bottom bar
    fileprivate weak var calendar: FSCalendar!
    let fab_revealCalAtHome = MDCFloatingButton(shape: .mini)
    let revealCalAtHomeButton = MDCButton()
    let revealChartsAtHomeButton = MDCButton()
    
    let homeDate_Day = UILabel()
    let homeDate_WeekDay = UILabel()
    let homeDate_Month = UILabel()
    
    //MARK: charts
    let tinyPieChartView = PieChartView()
    var shouldHideData: Bool = false
    var sliderX: UISlider!
    var sliderY: UISlider!
    var sliderTextX: UITextField!
    var sliderTextY: UITextField!
    
    var seperatorTopLineView = UIView()
    var backdropNochImageView = UIImageView()
    var backdropBackgroundImageView = UIImageView()
    var backdropForeImageView = UIImageView()
    let backdropForeImage = UIImage(named: "backdropFrontImage")
    var homeTopBar = UIView()
    let dateAtHomeLabel = UILabel()
    let scoreCounter = UILabel()
    let scoreAtHomeLabel = UILabel()
    var bottomAppBar = MDCBottomAppBarView()
    var isCalDown: Bool = false
    var isChartsDown: Bool = false
    
    
    //MARK:- Circle menu init
    let circleMenuItems: [(icon: String, color: UIColor)] = [
        //        ("icon_home", UIColor(red: 0.19, green: 0.57, blue: 1, alpha: 1)),
        ("", .clear),
        ("icon_search", UIColor(red: 0.22, green: 0.74, blue: 0, alpha: 1)),
        ("notifications-btn", UIColor(red: 0.96, green: 0.23, blue: 0.21, alpha: 1)),
        ("settings-btn", UIColor(red: 0.51, green: 0.15, blue: 1, alpha: 1)),
        //        ("nearby-btn", UIColor(red: 1, green: 0.39, blue: 0, alpha: 1))
        ("", .clear)
    ]
    
    // MARK: Outlets
    @IBOutlet weak var addTaskButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var switchState: UISwitch!
    
    
    //MARK: Theming: COLOURS
    var backgroundColor = UIColor.systemGray5
    var primaryColor = UIColor.systemIndigo // #colorLiteral(red: 0.3843137255, green: 0, blue: 0.9333333333, alpha: 1) //UIColor(red: 98.0/255.0, green: 0.0/255.0, blue: 238.0/255.0, alpha: 1.0)
    var primaryColorDarker = UIColor.black//#colorLiteral(red: 0.2784313725, green: 0.007843137255, blue: 0.7568627451, alpha: 1) //UIColor(red: 71.0/255.0, green: 2.0/255.0, blue: 193.0/255.0, alpha: 1.0)
    var secondaryAccentColor = UIColor.systemOrange// #colorLiteral(red: 0.007843137255, green: 0.6352941176, blue: 0.6156862745, alpha: 1) //02A29D
    //          var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    //          var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    
    //MARK: Fonts:
    //    var titleFont_1:UIFont = setFont
    //    var scoreNumberFont:UIFont = setFont(fontSize: 40, fontweight: .bold, fontDesign: .rounded)
    
    //MARK:- Elevation + Shadows:
    let bottomBarShadowElevation: ShadowElevation = ShadowElevation(rawValue: 8)
    
    //MARK: get name of the month
    func getMonth(date: Date) -> String {
        
        let dateFormatter_Month = DateFormatter()
        dateFormatter_Month.dateFormat = "LLL" //try MMM
        let nameOfMonth = dateFormatter_Month.string(from: date)
        return nameOfMonth
    }
    
    //MARK: get name of the weekday
    func getWeekday(date: Date) -> String {
        
        let dateFormatter_Weekday = DateFormatter()
        dateFormatter_Weekday.dateFormat = "EEE"
        let nameOfWeekday = dateFormatter_Weekday.string(from: date)
        return nameOfWeekday
    }
    
    //MARK:- TUESDAY, 5th May
    func setHomeViewDate() {
        
        
        //            let centerText = NSMutableAttributedString(string: "Charts\nby Daniel Cohen Gindi")
        //            centerText.setAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 13)!,
        //                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        //            centerText.addAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 11)!,
        //                                      .foregroundColor : UIColor.gray], range: NSRange(location: 10, length: centerText.length - 10))
        //            centerText.addAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 11)!,
        //                                      .foregroundColor : UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)], range: NSRange(location: centerText.length - 19, length: 19))
        //            chartView.centerAttributedText = centerText;
        
        //            chartView.centerText = "24"
        
        
        
        let today = dateToDisplay //Date() //TODO: change this with view date
        
        
        if("\(today.day)".count < 2) {
            homeDate_Day.text = "0\(today.day)"
        } else {
            homeDate_Day.text = "\(today.day)"
        }
        homeDate_WeekDay.text = getWeekday(date: today)
        homeDate_Month.text = getMonth(date: today)
        
        
        homeDate_Day.numberOfLines = 1
        homeDate_WeekDay.numberOfLines = 1
        homeDate_Month.numberOfLines = 1
        
        homeDate_Day.textColor = .systemGray6
        homeDate_WeekDay.textColor = .systemGray6
        homeDate_Month.textColor = .systemGray6
        
        homeDate_Day.font =  setFont(fontSize: 52, fontweight: .medium, fontDesign: .rounded)
        homeDate_WeekDay.font =  setFont(fontSize: 24, fontweight: .thin, fontDesign: .rounded)
        homeDate_Month.font =  setFont(fontSize: 24, fontweight: .regular, fontDesign: .rounded)
        
        homeDate_Day.textAlignment = .left
        homeDate_WeekDay.textAlignment = .left
        homeDate_Month.textAlignment = .left
        
        
        homeDate_Day.frame = CGRect(x: 5, y: 18, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        homeDate_WeekDay.frame = CGRect(x: 68, y: homeTopBar.bounds.minY+30, width: (homeTopBar.bounds.width/2)-100, height: homeTopBar.bounds.height)
        homeDate_Month.frame = CGRect(x: 68, y: homeTopBar.bounds.minY+10, width: (homeTopBar.bounds.width/2)-80, height: homeTopBar.bounds.height)
        
        
        homeDate_WeekDay.adjustsFontSizeToFitWidth = true
        homeDate_Month.adjustsFontSizeToFitWidth = true
        
        homeTopBar.addSubview(homeDate_Day)
        homeTopBar.addSubview(homeDate_WeekDay)
        homeTopBar.addSubview(homeDate_Month)
        
        //        homeDate_WeekDay.translatesAutoresizingMaskIntoConstraints = false
        //        homeDate_WeekDay.centerXAnchor.constraint(equalTo: homeDate_Day.centerXAnchor, constant: 20).isActive = true
        //        homeDate_WeekDay.leadingAnchor.constraint(equalTo: homeDate_Day.trailingAnchor, constant: 20).isActive = true
        //        homeDate_WeekDay.widthAnchor.constraint(equalToConstant: homeTopBar.bounds.width/2).isActive = true
        //        homeDate_WeekDay.heightAnchor.constraint(equalToConstant: homeTopBar.bounds.height/4).isActive = true
        
    }
    
    //MARK:- setup cal button
    func setupCalButton()  {
        
        
        //        let configuration = UIImage.SymbolConfiguration(scale: .large)
        let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .thin, scale: .default)
        //        let smallSymbolImage = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: configuration)
        let smallSymbolImage = UIImage(systemName: "chevron.down", withConfiguration: configuration)
        let colouredCalPullDownImage = smallSymbolImage?.withTintColor(secondaryAccentColor, renderingMode: .alwaysOriginal)
        
        let smallSymbolImage_Active = UIImage(systemName: "chevron.up", withConfiguration: configuration)
        let colouredCalPullDownImage_Active = smallSymbolImage_Active?.withTintColor(secondaryAccentColor, renderingMode: .alwaysOriginal)
        
        let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
        let calButton_Active = colouredCalPullDownImage_Active
        //        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.minX+UIScreen.main.bounds.width/4)+10 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
        //        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.minX+UIScreen.main.bounds.width/2)-20 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
        //        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2)-50 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2)-65 , y: UIScreen.main.bounds.minY+75, width: 200, height: 200)
        revealCalAtHomeButton.setImage(calButton, for: .normal)
        revealCalAtHomeButton.setImage(calButton_Active, for: .selected)
        revealCalAtHomeButton.backgroundColor = .clear
        revealCalAtHomeButton.titleLabel?.text = "GREEN"
        
        revealCalAtHomeButton.sizeToFit()
        revealCalAtHomeButton.addTarget(self, action: #selector(showCalMoreButtonnAction), for: .touchUpInside)
        view.addSubview(revealCalAtHomeButton)
        
    }
    
    //MARK:- CHARTS Button
    
    func setupChartButton()  {
        
        
        //        let configuration = UIImage.SymbolConfiguration(scale: .large)
        let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .thin, scale: .large)
        //        let smallSymbolImage = UIImage(systemName: "chart.pie", withConfiguration: configuration)
        let smallSymbolImage = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: configuration)
        let colouredCalPullDownImage = smallSymbolImage?.withTintColor(secondaryAccentColor, renderingMode: .alwaysOriginal)
        
        let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
        //        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.minX+UIScreen.main.bounds.width/4)+10 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
        //        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.minX+UIScreen.main.bounds.width/2)-20 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
        //        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2)-50 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
        revealChartsAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2) , y: UIScreen.main.bounds.minY+55, width: 200, height: 200)
        
        //TODO: - maximise button to makeripple tab
        
        //1 increase buttton size
        //2 add ink/ripple to the whole tab
        //3 fix image in frame CGRect at original position
        
        
        revealChartsAtHomeButton.setImage(calButton, for: .normal)
        revealChartsAtHomeButton.backgroundColor = .clear
        revealChartsAtHomeButton.titleLabel?.text = "GREEN 2"
        
        revealChartsAtHomeButton.sizeToFit()
        revealChartsAtHomeButton.addTarget(self, action: #selector(showChartsHHomeButton_Action), for: .touchUpInside)
        view.addSubview(revealChartsAtHomeButton)
        
    }
    
    //MARK: TOP SEPERATOR
    func setupTopSeperator() {
        
        seperatorTopLineView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2, y: backdropNochImageView.bounds.height + 10, width: 1.0, height: homeTopBar.bounds.height/2))
        seperatorTopLineView.layer.borderWidth = 1.0
        //        seperatorTopLineView.layer.borderColor = UIColor.white.cgColor
        seperatorTopLineView.layer.borderColor = UIColor.gray.cgColor
        self.view.addSubview(seperatorTopLineView)
        
    }
    
    
    //MARK:- SET CHART DATA - LINE
    func setLineChartData() {
        let set01 = LineChartDataSet(entries: generateLineChartData(), label: "Score for the day")
        //        let set01 = LineChartDataSet(entries: generateLineChartData())
        
        //        set01.drawCirclesEnabled = false
        set01.drawCirclesEnabled = false
        set01.mode = .cubicBezier
        set01.setColor(secondaryAccentColor)
        set01.lineWidth = 3
        set01.fill = Fill(color: primaryColorDarker)
        set01.fillAlpha = 0.8
        set01.drawFilledEnabled = true
        
        
        
        
        let lineChartData_01 = LineChartData(dataSet: set01)
        lineChartView.data = lineChartData_01
        
    }
    
    
    func generateLineChartData() -> [ChartDataEntry] {
        //        let daysOfWeek = [1,2,3,4,5,6,7]
        
        var yValues: [ChartDataEntry] = []
        //        for day in daysOfWeek {
        //            let mEntry = ChartDataEntry(x: Double(Int.random(in: 0 ..< 10)), y: Double(Int.random(in: 0 ..< 10)))
        //            yValues.append(ChartDataEntry(x: Double(Int.random(in: 0 ..< 10)), y: Double(Int.random(in: 0 ..< 10))))
        //            print("Set data for day \(day): \(mEntry)")
        //            print("----------------")
        //        }
        
        //TODO: This cal should show this week + last week in default view
        // so if today is wednesday show: last 7 days from last week + this week up till today(mon, tue, wed)
        
        yValues.append(ChartDataEntry(x: Double(1), y: Double(4)))
        yValues.append(ChartDataEntry(x: Double(2.0), y: Double(5)))
        yValues.append(ChartDataEntry(x: Double(3.0), y: Double(7)))
        yValues.append(ChartDataEntry(x: Double(4.0), y: Double(3)))
        yValues.append(ChartDataEntry(x: Double(5.0), y: Double(7.5)))
        yValues.append(ChartDataEntry(x: Double(6.0), y: Double(8)))
        yValues.append(ChartDataEntry(x: Double(7.0), y: Double(9)))
        yValues.append(ChartDataEntry(x: Double(8.0), y: Double(4.0)))
        yValues.append(ChartDataEntry(x: Double(9.0), y: Double(6)))
        yValues.append(ChartDataEntry(x: Double(10.0), y: Double(7)))
        
        //        yValues.append(ChartDataEntry(x: Double(1), y: Double(4), data: "HOLA !"))
        //                yValues.append(ChartDataEntry(x: Double(2.0), y: Double(5), data: "HOLA ! 1"))
        //                yValues.append(ChartDataEntry(x: Double(3.0), y: Double(7), data: "HOLA ! 2"))
        //                yValues.append(ChartDataEntry(x: Double(4.0), y: Double(3), data: "HOLA ! 3"))
        //                yValues.append(ChartDataEntry(x: Double(5.0), y: Double(7.5), data: "HOLA ! 4"))
        
        return yValues
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
        print("You selected data: \(entry)")
    }
    
    //MARK: setup line chart
    func setupLineChartView() {
        
        view.addSubview(lineChartView)
        //        lineChartView.centerInSuperview()
        //        lineChartView.width(to: view)
        //        lineChartView.heightToWidth(of: view)
        
        lineChartView.centerInSuperview()
        lineChartView.edges(to: backdropBackgroundImageView, insets: TinyEdgeInsets(top: 2*headerEndY, left: 0, bottom: UIScreen.main.bounds.height/2.5, right: 0))
        
        //        lineChartView.width(200)
        //        lineChartView.height(200)
        
        
    }
    
    //MARK:- View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //MARK: serve material backdrop
        headerEndY = 128
        setupBackdropBackground() //backdrop
        setupBackdropForeground() //foredrop
        setupBackdropNotch() //notch
        
        //MARK:- LOAD LINE CHART
        setupLineChartView()
        setLineChartData()
        lineChartView.isHidden = true //remove this from here hadle elsewhere in a fuc that hides all
        
        
        
        
        //        isBackdropDown() // get intit //refetch this n view reload
        
        // cal
        setupCal()
        view.addSubview(calendar)
        calendar.isHidden = true //hidden by default
        //--- done top cal
        
        // table view
        tableView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        view.addSubview(tableView)
        
        setupBottomAppBar()
        view.addSubview(bottomAppBar)
        setHomeViewDate()
        view.bringSubviewToFront(bottomAppBar)
        
        setupCalButton()
        setupChartButton()
        setupTopSeperator()
        
        //MARK: circle menu frame
        let circleMenuButton = CircleMenu(
            frame: CGRect(x: 32, y: 64, width: 30, height: 30),
            normalIcon:"icon_menu",
            //            selectedIcon:"icon_close",
            selectedIcon:"material_close",
            buttonsCount: 5,
            duration: 1,
            distance: 50)
        circleMenuButton.backgroundColor = backgroundColor
        
        circleMenuButton.delegate = self
        circleMenuButton.layer.cornerRadius = circleMenuButton.frame.size.width / 2.0
        //        view.addSubview(circleMenuButton) TODO: reconsider the top circle menu
        
        
        //MARK: NOTCH CHECK
        if (UIDevice.current.hasNotch) {
            print("I SEE NOTCH !!")
        } else {
            print("NO NOTCH !")
        }
        
        //---------- VIEW LOAD: CHART
        
        
        
        self.setup(pieChartView: tinyPieChartView)
        
        updateChartData()
        
        tinyPieChartView.delegate = self
        
        //        let l = chartView.legend
        //        l.horizontalAlignment = .right
        //        l.verticalAlignment = .top
        //        l.orientation = .vertical
        //        l.xEntrySpace = 7
        //        l.yEntrySpace = 0
        //        l.yOffset = 0
        
        //                chartView.legend = l
        
        // entry label styling
        tinyPieChartView.entryLabelColor = .brown
        tinyPieChartView.entryLabelFont = .systemFont(ofSize: 12, weight: .black)
        
        //        sliderX.value = 4
        //        sliderY.value = 100
        //        self.slidersValueChanged(nil)
        
        //        chartView.frame = CGRect(x: (UIScreen.main.bounds.width)-140, y: 15, width: (UIScreen.main.bounds.width/3)+40, height: (UIScreen.main.bounds.width/3)+40)
        
        tinyPieChartView.frame = CGRect(x: (UIScreen.main.bounds.width)-(UIScreen.main.bounds.width/3)+10, y: 18, width: (UIScreen.main.bounds.width/3)+25, height: (UIScreen.main.bounds.width/3)+25)
        
        
        
        //        lineChartView.centerInSuperview()
        //               lineChartView.edges(to: backdropBackgroundImageView, insets: TinyEdgeInsets(top: 2*headerEndY, left: 0, bottom: UIScreen.main.bounds.height/2.5, right: 0))
        
        //        chartView.centerInSuperview()
        //        chartView.edges(to: homeTopBar, insets: TinyEdgeInsets(top: 5, left: 20, bottom: 5, right: 20))
        //        chartView.width(50)
        //        chartView.height(50)
        
        
        //             chartView.frame = CGRect(x: (UIScreen.main.bounds.width/2), y: 50, width: (UIScreen.main.bounds.width/2)+40, height: (UIScreen.main.bounds.width/2)+40)
        
        
        
        
        
        //        chartView.maxAngle = 180 // Half chart
        //               chartView.rotationAngle = 180 // Rotate to make the half on the upper side
        //               chartView.centerTextOffset = CGPoint(x: 0, y: -20)
        
        //        chartView.isUsePercentValuesEnabled = false
        //        chartView.value
        
        
        //        chartView.entryLabelColor = .black
        //        chartView.setNeedsDisplay()
        
        view.addSubview(tinyPieChartView)
        
        tinyPieChartView.animate(xAxisDuration: 1.8, easingOption: .easeOutBack)
        
        
        
        
        //---------- VIEW LOAD: CHART DONE
        
        
        enableDarkModeIfPreset()
    }
    
    //---------- SETUP: CHART
    
    func updateChartData() {
        if self.shouldHideData {
            tinyPieChartView.data = nil
            return
        }
        print("--------------------------")
        print("X: \(10)")//print("X: \(Int(sliderX.value))")
        print("Y: \(40)")//print("Y: \(UInt32(sliderY.value))")
        print("--------------------------")
        
        //            self.setDataCount(Int(sliderX.value), range: UInt32(sliderY.value))
        self.setDataCount(4, range: 40)
    }
    
    //setup chart
    func setup(pieChartView chartView: PieChartView) {
        //            chartView.usePercentValuesEnabled = false
        chartView.drawSlicesUnderHoleEnabled = true
        chartView.holeRadiusPercent = 0.85
        chartView.holeColor = primaryColor
        //            chartView.holeRadiusPercent = 0.10
        chartView.transparentCircleRadiusPercent = 0.41
        //            chartView.chartDescription?.enabled = true
        
        chartView.setExtraOffsets(left: 5, top: 5, right: 5, bottom: 5)
        
        //            chartView.chartDescription?.text = "HOLA"
        chartView.drawCenterTextEnabled = true
        
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
        //            let centerText = NSMutableAttributedString(string: "Charts\nby Daniel Cohen Gindi")
        //            centerText.setAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 13)!,
        //                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        //            centerText.addAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 11)!,
        //                                      .foregroundColor : UIColor.gray], range: NSRange(location: 10, length: centerText.length - 10))
        //            centerText.addAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 11)!,
        //                                      .foregroundColor : UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)], range: NSRange(location: centerText.length - 19, length: 19))
        //            chartView.centerAttributedText = centerText;
        
        //            chartView.centerText = "24"
        
        
        
        let scoreNumber = "\(self.calculateTodaysScore())"
        let centerText = NSMutableAttributedString(string: "\(scoreNumber)")
        centerText.setAttributes([.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded),
                                  .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        chartView.centerAttributedText = centerText;
        
        
        //            chartView.drawEntryLabelsEnabled = false
        //        chartView.usePercentValuesEnabled = false
        //                      chartView.setNeedsDisplay()
        
        chartView.drawHoleEnabled = true
        chartView.rotationAngle = 0
        chartView.rotationEnabled = true
        chartView.highlightPerTapEnabled = true
        chartView.legend.form = .none
        
        
        
    }
    //    let parties = ["Party A", "Party B", "Party C", "Party D", "Party E", "Party F",
    //                      "Party G", "Party H", "Party I", "Party J", "Party K", "Party L",
    //                      "Party M", "Party N", "Party O", "Party P", "Party Q", "Party R",
    //                      "Party S", "Party T", "Party U", "Party V", "Party W", "Party X",
    //                      "Party Y", "Party Z"]
    //    let parties = ["P0", "P1", "P2", "P3"]
    let parties = [""]
    
    //MARK:-GET THIS 1
    func setDataCount(_ count: Int, range: UInt32) {
        let entries = (0..<count).map { (i) -> PieChartDataEntry in
            // IMPORTANT: In a PieChart, no values (Entry) should have the same xIndex (even if from different DataSets), since no values can be drawn above each other.
            
            return PieChartDataEntry(value: Double(arc4random_uniform(range) + range / 5),
                                     label: parties[i % parties.count],
                                     icon: #imageLiteral(resourceName: "material_done_White"))
            
            //                return PieChartDataEntry(value: 25, label: "25_1")
            //                return PieChartDataEntry(value: 25, label: "25_2")
            //                return PieChartDataEntry(value: 25, label: "25_3")
            //                return PieChartDataEntry(value: 25, label: "25_4")
        }
        
        //            let set = PieChartDataSet(entries: entries, label: "Election Results")
        let set = PieChartDataSet(entries: entries, label: "")
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        
        set.sliceSpace = 2
        
        //        let set01 = LineChartDataSet(entries: generateLineChartData(), label: "Score for the day")
        
        //            for set2 in set {
        //                                      set2.drawValuesEnabled = !set2.drawValuesEnabled
        //                                  }
        
        
        set.colors = ChartColorTemplates.vordiplom()
            + ChartColorTemplates.joyful()
            + ChartColorTemplates.colorful()
            + ChartColorTemplates.liberty()
            + ChartColorTemplates.pastel()
            + [UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)]
        
        let data = PieChartData(dataSet: set)
        
        
        
        
        
        tinyPieChartView.drawEntryLabelsEnabled = false
        tinyPieChartView.data = data
        //            chartView.highlightValues(nil)
    }
    
    //    //MARK:-GET THIS 2 //IMPORT COMMENNTED
    //    override func optionTapped(_ option: Option) {
    //        switch option {
    //        case .toggleXValues:
    //            chartView.drawEntryLabelsEnabled = !chartView.drawEntryLabelsEnabled
    //            chartView.setNeedsDisplay()
    //
    //        case .togglePercent:
    //            chartView.usePercentValuesEnabled = !chartView.usePercentValuesEnabled
    //            chartView.setNeedsDisplay()
    //
    //        case .toggleHole:
    //            chartView.drawHoleEnabled = !chartView.drawHoleEnabled
    //            chartView.setNeedsDisplay()
    //
    //        case .drawCenter:
    //            chartView.drawCenterTextEnabled = !chartView.drawCenterTextEnabled
    //            chartView.setNeedsDisplay()
    //
    //        case .animateX:
    //            chartView.animate(xAxisDuration: 1.4)
    //
    //        case .animateY:
    //            chartView.animate(yAxisDuration: 1.4)
    //
    //        case .animateXY:
    //            chartView.animate(xAxisDuration: 1.4, yAxisDuration: 1.4)
    //
    //        case .spin:
    //            chartView.spin(duration: 2,
    //                           fromAngle: chartView.rotationAngle,
    //                           toAngle: chartView.rotationAngle + 360,
    //                           easingOption: .easeInCubic)
    //
    //        default:
    //            handleOption(option, forChartView: chartView)
    //        }
    //    }
    //
    //    // MARK: - Actions //MARK:-GET THIS 3 //import commennted
    //    @IBAction func slidersValueChanged(_ sender: Any?) {
    //        sliderTextX.text = "\(Int(sliderX.value))"
    //        sliderTextY.text = "\(Int(sliderY.value))"
    //
    //        self.updateChartData()
    //    }
    
    //-----------
    //---------- SETUP: CHART DONE
    
    
    
    
    func serveSemiViewRed() -> UIView {
        
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        view.backgroundColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
        
        let mylabel = UILabel()
        mylabel.frame = CGRect(x: 20, y: 25, width: 370, height: 50)
        mylabel.text = "This is placeholder text"
        mylabel.textAlignment = .center
        mylabel.backgroundColor = .white
        view.addSubview(mylabel)
        
        return view
    }
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func serveNewPageHeader() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
        view.backgroundColor = .clear
        headerEndY = view.frame.maxY
        
        
        print("Header end point is: \(headerEndY)")
        
        
        let todaysDateLabel = UILabel()
        todaysDateLabel.frame = CGRect(x: 5, y: 70, width: view.frame.width/2, height: 40)
        todaysDateLabel.text = dateForTheView.dateString(in: .medium)
        todaysDateLabel.textColor = .secondaryLabel
        todaysDateLabel.textAlignment = .left
        todaysDateLabel.adjustsFontSizeToFitWidth = true
        view.addSubview(todaysDateLabel)
        
        return view
    }
    
    
    
    
    
    func serveSemiViewBlue(task: NTask) -> UIView { //TODO: put each of this in a tableview
        
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        //        view.backgroundColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
        view.backgroundColor = backgroundColor
        let frameForView = view.bounds
        
        let taskName = UILabel() //Task Name
        view.addSubview(taskName)
        taskName.frame = CGRect(x: frameForView.minX, y: frameForView.minY, width: frameForView.width, height: frameForView.height/5)
        taskName.text = task.name
        taskName.textAlignment = .center
        taskName.backgroundColor = .black
        taskName.textColor = UIColor.white
        
        let eveningLabel = UILabel() //Evening Label
        view.addSubview(eveningLabel)
        eveningLabel.text = "evening task"
        eveningLabel.textAlignment = .left
        eveningLabel.textColor =  primaryColor
        eveningLabel.frame = CGRect(x: frameForView.minX+40, y: frameForView.minY+85, width: frameForView.width-100, height: frameForView.height/8)
        
        let eveningSwitch = UISwitch() //Evening Switch
        view.addSubview(eveningSwitch)
        eveningSwitch.onTintColor = primaryColor
        
        if(Int(task.taskType) == 2) {
            print("Task type is evening; 2")
            eveningSwitch.setOn(true, animated: true)
        } else {
            print("Task type is NOT evening;")
            eveningSwitch.setOn(false, animated: true)
        }
        eveningSwitch.frame = CGRect(x: frameForView.maxX-80, y: frameForView.minY+85, width: frameForView.width-100, height: frameForView.height/8)
        
        
        let p = ["None", "Low", "High", "Highest"]
        let prioritySegmentedControl = UISegmentedControl(items: p) //Task Priority
        view.addSubview(prioritySegmentedControl)
        prioritySegmentedControl.selectedSegmentIndex = 1
        prioritySegmentedControl.backgroundColor = .white
        prioritySegmentedControl.selectedSegmentTintColor =  primaryColor
        
        
        
        prioritySegmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)
        
        prioritySegmentedControl.frame = CGRect(x: frameForView.minX+20, y: frameForView.minY+150, width: frameForView.width-40, height: frameForView.height/7)
        
        
        let datePicker = UIDatePicker() //DATE PICKER //there should not be a date picker here //there can be calendar icon instead
        view.addSubview(datePicker)
        datePicker.datePickerMode = .date
        datePicker.timeZone = NSTimeZone.local
        datePicker.backgroundColor = UIColor.white
        
        //Set minimum and Maximum Dates
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.month = 1
        let maxDate = calendar.date(byAdding: comps, to: Date())
        comps.month = 0
        comps.day = -1
        let minDate = calendar.date(byAdding: comps, to: Date())
        datePicker.maximumDate = maxDate
        datePicker.minimumDate = minDate
        datePicker.frame = CGRect(x: frameForView.minX+30, y: frameForView.minY+230, width: frameForView.width-60, height: frameForView.height/8)
        
        
        return view
    }
    
    // MARK:- DID SELECT ROW AT
    /*
     Prints logs on selecting a row
     */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You selected row \(indexPath.row) from section \(indexPath.section)")
        
        var currentTask: NTask!
        //        semiViewDefaultOptions(viewToBePrsented: serveViewBlue())
        switch indexPath.section {
        case 0:
            //            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
            let Tasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
            currentTask = Tasks[indexPath.row]
        case 1:
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            let Tasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            currentTask = Tasks[indexPath.row]
        default:
            break
        }
        
        //        semiViewDefaultOptions(viewToBePrsented: serveSemiViewRed())
        
        semiViewDefaultOptions(viewToBePrsented: serveSemiViewBlue(task: currentTask))
        
        //        semiViewDefaultOptions(viewToBePrsented: serveSemiViewGreen(task: currentTask))
        
        
        
    }
    
    func semiViewDefaultOptions(viewToBePrsented: UIView) {
        let options: [SemiModalOption : Any] = [
            SemiModalOption.pushParentBack: true,
            SemiModalOption.animationDuration: 0.2
        ]
        
        presentSemiView(viewToBePrsented, options: options) {
            print("Completed!")
        }
    }
    
    // MARK:- View Lifecycle methods
    
    override func viewWillAppear(_ animated: Bool) {
        // right spring animation
        //        tableView.reloadData(
        //            with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
        //                          constantDelay: 0))
        tableView.reloadData()
        
        animateTableViewReload()
        //        UIView.animate(views: tableView.visibleCells, animations: animations, completion: {
        
        //        })
    }
    
    
    
    
    /*
     Checks & enables dark mode if user previously set such
     */
    func enableDarkModeIfPreset() {
        if UserDefaults.standard.bool(forKey: "isDarkModeOn") {
            //switchState.setOn(true, animated: true)
            //            print("HOME: DARK ON")
            view.backgroundColor = UIColor.darkGray
        } else {
            //            print("HOME: DARK OFF !!")
            view.backgroundColor =  backgroundColor
        }
    }
    
    // MARK: calculate today's score
    /*
     Calculates daily productivity score
     */
    func calculateTodaysScore() -> Int { //TODO change this to handle NTASKs
        var score = 0
        
        let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
        
        for each in morningTasks {
            
            if each.isComplete {
                
                score = score + each.getTaskScore(task: each)
            }
        }
        for each in eveningTasks {
            if each.isComplete {
                score = score + each.getTaskScore(task: each)
            }
        }
        return score;
    }
    
    
    
    // MARK: toggle dark mode
    
    
    /*
     Toggles Dark Mode
     */
    @IBAction func toggleDarkMode(_ sender: Any) {
        
        let mSwitch = sender as! UISwitch
        
        if mSwitch.isOn {
            view.backgroundColor = UIColor.darkGray
            
            UserDefaults.standard.set(true, forKey: "isDarkModeOn")
            
        } else {
            UserDefaults.standard.set(false, forKey: "isDarkModeOn")
            view.backgroundColor = UIColor.white
        }
    }
    
    // MARK: SECTIONS
    func numberOfSections(in tableView: UITableView) -> Int {
        
        tableView.backgroundColor = UIColor.clear
        return 2;
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                  TABLEVIEW: HEADER VIEW
    //TODO: build filter here
    // has today, yesterday, tomorrw, project A, Prject B
    //
    //----------------------- *************************** -----------------------
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        
        if section == 0 {
            let myLabel = UILabel()
            myLabel.frame = CGRect(x:5, y: 0, width: (UIScreen.main.bounds.width/3) + 50, height: 30)
            
            //line.horizontal.3.decrease.circle
            let filterIconConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .thin, scale: .default)
            let filterIconImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: filterIconConfiguration)
            let colouredCalPullDownImage = filterIconImage?.withTintColor(secondaryAccentColor, renderingMode: .alwaysOriginal)
            //
            //            let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
            let filterMenuHomeButton = UIButton()
            //            filterMenuHomeButton.frame = CGRect(x:5, y: -10 , width: 50, height: 50)
            filterMenuHomeButton.frame = CGRect(x:5, y: 1 , width: 30, height: 30)
            filterMenuHomeButton.setImage(colouredCalPullDownImage, for: .normal)
            
            headerView.addSubview(filterMenuHomeButton)
            
            
            
            
            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
            myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
            myLabel.textAlignment = .right
            myLabel.adjustsFontSizeToFitWidth = true
            myLabel.textColor = .label
            myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
            
            //                   let headerView = UIView()
            headerView.addSubview(myLabel)
            
            return headerView
        } else if section == 1 {
            
            let myLabel2 = UILabel()
            myLabel2.frame = CGRect(x:5, y: 0, width: UIScreen.main.bounds.width/3, height: 30)
            //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
            myLabel2.font = setFont(fontSize: 20, fontweight: .medium, fontDesign: .rounded)//UIFont(name: "HelveticaNeue-Bold", size: 20)
            myLabel2.textAlignment = .left
            myLabel2.adjustsFontSizeToFitWidth = true
            myLabel2.textColor = .secondaryLabel
            myLabel2.text = self.tableView(tableView, titleForHeaderInSection: section)
            
            headerView.addSubview(myLabel2)
            
            
        }
        
        
        //        let myLabel = UILabel()
        //        myLabel.frame = CGRect(x:5, y: 0, width: UIScreen.main.bounds.width/3, height: 30)
        //        //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
        //        myLabel.font = setFont(fontSize: 24, fontweight: .medium, fontDesign: .serif)//UIFont(name: "HelveticaNeue-Bold", size: 20)
        //        myLabel.textAlignment = .right
        //        myLabel.adjustsFontSizeToFitWidth = true
        //        myLabel.textColor = .secondaryLabel
        //        myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
        //
        //        let headerView = UIView()
        //        headerView.addSubview(myLabel)
        //
        //        return headerView
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            let now = Date.today
            if (dateForTheView == now()) {
                return "Today's Tasks"
            } else {
                return "NOT TODAY"
            }
            
        //            return "Today's Tasks"
        case 1:
            return "Evening"
        default:
            return nil
        }
    }
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            //            print("Items in morning: \(TaskManager.sharedInstance.getMorningTasks.count)")
            //            return TaskManager.sharedInstance.getMorningTasks.count
            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
            return morningTasks.count
        case 1:
            //            print("Items in evening: \(TaskManager.sharedInstance.getEveningTasks.count)")
            //            return TaskManager.sharedInstance.getEveningTasks.count
            let eveTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            return eveTasks.count
        default:
            return 0;
        }
    }
    
    // MARK:- CELL AT ROW
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        
        //        chec
        
        
        var currentTask: NTask!
        let completedTaskCell = tableView.dequeueReusableCell(withIdentifier: "completedTaskCell", for: indexPath)
        let openTaskCell = tableView.dequeueReusableCell(withIdentifier: "openTaskCell", for: indexPath)
        
        //        print("NTASK count is: \(TaskManager.sharedInstance.count)")
        //        print("morning section index is: \(indexPath.row)")
        
        switch indexPath.section {
        case 0:
            print("morning section index is: \(indexPath.row)")
            
            //            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: Date.today())
            //            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
            
            
            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
            currentTask = morningTasks[indexPath.row]
            
        case 1:
            print("evening section index is: \(indexPath.row)")
            
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            
            let evenningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            currentTask = evenningTasks[indexPath.row]
            
        default:
            break
        }
        
        
        completedTaskCell.textLabel!.text = "\t\(currentTask.name)"
        completedTaskCell.backgroundColor = UIColor.clear
        
        //        openTaskCell.textLabel!.text = currentTask.name
        openTaskCell.textLabel!.text = "\t\(currentTask.name)"
        openTaskCell.backgroundColor = UIColor.clear
        
        if currentTask.isComplete {
            completedTaskCell.textLabel?.textColor = .tertiaryLabel
            //            completedTaskCell.accessoryType = .checkmark
            
            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
            checkBox.lineWidth = 1.0
            checkBox.animationDuration = 0.45
            checkBox.setOn(true, animated: false)
            checkBox.boxType = .square
            checkBox.onAnimationType = .oneStroke
            checkBox.offAnimationType = .oneStroke
            
            
            
            completedTaskCell.addSubview(checkBox)
            
            //          let priorityLineView = UIView(frame: CGRect(x: completedTaskCell.bounds.minX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
            //            priorityLineView.clipsToBounds = true
            
            //            let priorityLineView_Right = UIView(frame: CGRect(x: completedTaskCell.bounds.maxX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
            //            priorityLineView_Right.clipsToBounds = true
            
            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
            if (currentTask.taskPriority == 1) { //p0
                
                //                          priorityLineView.backgroundColor = .systemRed
                //                        priorityLineView_Right.backgroundColor = .systemRed
                
            } else if (currentTask.taskPriority == 2) {
                
                //                          priorityLineView.backgroundColor = .systemOrange
                //                        priorityLineView_Right.backgroundColor = .systemOrange
                
            } else if (currentTask.taskPriority == 3) {
                
                //                          priorityLineView.backgroundColor = .systemYellow
                //                        priorityLineView_Right.backgroundColor = .systemYellow
                
            } else {
                //                          priorityLineView.backgroundColor = .systemGray3
                //                        priorityLineView_Right.backgroundColor = .systemGray3
            }
            //            completedTaskCell.addSubview(priorityLineView)
            //            completedTaskCell.addSubview(priorityLineView_Right)
            
            return completedTaskCell
            
        } else {
            
            
            
            openTaskCell.textLabel?.textColor = .label
            //            openTaskCell.accessoryType = .detailButton
            openTaskCell.accessoryType = .disclosureIndicator
            
            
            
            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
            checkBox.lineWidth = 1.0
            checkBox.animationDuration = 0.45
            checkBox.setOn(false, animated: false)
            checkBox.boxType = .square
            checkBox.onAnimationType = .oneStroke
            checkBox.offAnimationType = .oneStroke
            
            openTaskCell.addSubview(checkBox)
            
            
            
            
            let priorityLineView_Right = UIView() //UIView(frame: CGPoint(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.midY))//(frame: CGRect(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.minY, width: 5.0, height: openTaskCell.bounds.height))
            
            
            priorityLineView_Right.clipsToBounds = true
            
            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
            if (currentTask.taskPriority == 1) { //p0
                
                
                //                priorityLineView_Right.backgroundColor = .systemRed
                
            } else if (currentTask.taskPriority == 2) {
                
                
                //                priorityLineView_Right.backgroundColor = .systemOrange
                
            } else if (currentTask.taskPriority == 3) {
                
                
                //                priorityLineView_Right.backgroundColor = .systemYellow
                
            } else {
                
                //                priorityLineView_Right.backgroundColor = .systemGray3
            }
            
            
            //            openTaskCell.addSubview(priorityLineView_Right)
            
            return openTaskCell
        }
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                  TABLEVIEW: HEADER VIEW
    //TODO: build filter here
    // has today, yesterday, tomorrw, project A, Prject B
    //
    //----------------------- *************************** -----------------------
    
    //        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    //            // We'll assume that there is only one section for now.
    //
    //              if section == 0 {
    //
    ////                  let imageView: UIImageView = UIImageView()
    //                  //imageView.clipsToBounds = true
    //                  //imageView.contentMode = .scaleAspectFill
    //                let filterHeaderView = UIView()
    //
    ////                imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 50)
    ////                  imageView.image =  UIImage(named: "Star")!
    ////                  return imageView
    //              }
    //
    //              return nil
    //        }
    
    
    @IBAction func changeBackground(_ sender: Any) {
        view.backgroundColor = UIColor.black
        
        let everything = view.subviews
        
        for each in everything {
            // is it a label
            if(each is UILabel) {
                let currenLabel = each as! UILabel
                currenLabel.textColor = UIColor.red
            }
            
            //each.backgroundColor = UIColor.red
        }
    }
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                  ANIMATION: MOVE BY OFFSETS
    //----------------------- *************************** -----------------------
    
    //MARK:- Animation Move Offses
    
    func moveRight(view: UIView) {
        view.center.x += 300
    }
    
    func moveLeft(view: UIView) {
        view.center.x -= 300
    }
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: MOVE FOR CAL
    //----------------------- *************************** -----------------------
    func moveDown_revealJustCal(view: UIView) {
        isCalDown = true
        print("move: Cal SHOW - down: \(UIScreen.main.bounds.height/6)")
        view.center.y += UIScreen.main.bounds.height/6
    }
    func moveUp_toHideCal(view: UIView) {
        isCalDown = false
        print("move: Cal HIDE - up: \(UIScreen.main.bounds.height/6)")
        view.center.y -= UIScreen.main.bounds.height/6
    }
    
//    func moveUp_hideCalFurther(view: UIView) { //
//           isCalDown = false
//           view.center.y -= (150+50)
//       }
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: MOVE FOR CHARTS
    //----------------------- *************************** -----------------------
    func moveDown_revealCharts(view: UIView) {
        isChartsDown = true
        print("move: CHARTS SHOW - down: \(UIScreen.main.bounds.height/2)")
        view.center.y += UIScreen.main.bounds.height/2
    }
    func moveDown_revealChartsKeepCal(view: UIView) {
         isChartsDown = true
         print("move: CHARTS SHOW, CAL SHOW - down some: \(UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12)")
         view.center.y += (UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12)
     }
    func moveUp_hideCharts(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE - up: \(UIScreen.main.bounds.height/2)")
        view.center.y -= UIScreen.main.bounds.height/2
    }
    func moveUp_hideChartsKeepCal(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE, CAL SHOW - up some: \(UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/4)")
        view.center.y -= (UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/4)
    }
    
    //----------------------- *************************** -----------------------
      //MARK:-                ANIMATION: LINE CHAR ANIMATION
      //----------------------- *************************** -----------------------
    
    
    func animateLineChart(chartView: LineChartView) {
            chartView.animate(yAxisDuration: 1.1, easingOption: .easeInOutBack)
    }
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: WHOLE TABLE VIEW RELOAD
    //----------------------- *************************** -----------------------

    
    
    //MARK: animations
    func animateTableViewReload() {
        let zoomAnimation = AnimationType.zoom(scale: 0.5)
        let rotateAnimation = AnimationType.rotate(angle: CGFloat.pi/6)
        
        UIView.animate(views: tableView.visibleCells,
                       animations: [zoomAnimation, rotateAnimation],
                       duration: 0.3)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: TABLE CELL RELOAD
    //----------------------- *************************** -----------------------
    
    func animateTableCellReload() {
        // Combined animations example
        //           let fromAnimation = AnimationType.from(direction: .right, offset: 70.0)
        let zoomAnimation = AnimationType.zoom(scale: 0.5)
        let rotateAnimation = AnimationType.rotate(angle: CGFloat.pi/6)
        //           UIView.animate(views: collectionView.visibleCells,
        //                          animations: [zoomAnimation, rotateAnimation],
        //                          duration: 0.5)
        
        UIView.animate(views: tableView.visibleCells,
                       animations: [zoomAnimation, rotateAnimation],
                       duration: 0.3)
        
        //           UIView.animate(views: tableView.visibleCells,
        //                          animations: [fromAnimation, zoomAnimation], delay: 0.3)
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                        BOTTOM BAR + FAB
    //----------------------- *************************** -----------------------
    
    //MARK:- setup bottom bar
    func setupBottomAppBar() {
        bottomAppBar.floatingButton.setImage(UIImage(named: "material_add_White"), for: .normal)
        bottomAppBar.floatingButton.backgroundColor = secondaryAccentColor //.systemIndigo
        bottomAppBar.frame = CGRect(x: 0, y: UIScreen.main.bounds.maxY-100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.maxY-100)
        bottomAppBar.barTintColor = primaryColor//primaryColor
        
        // The following lines of code are to define the buttons on the right and left side
        let barButtonMenu = UIBarButtonItem(
            image: UIImage(named:"material_menu_White"), // Icon
            style: .plain,
            target: self,
            action: #selector(self.onMenuButtonTapped))
        
        let barButtonSearch = UIBarButtonItem(
            image: UIImage(named: "material_search_White"), // Icon
            style: .plain,
            target: self,
            action: #selector(self.onNavigationButtonTapped))
        let barButtonInbox = UIBarButtonItem(
            image: UIImage(named: "material_inbox_White"), // Icon
            style: .plain,
            target: self,
            action: #selector(self.onNavigationButtonTapped))
        bottomAppBar.leadingBarButtonItems = [barButtonMenu, barButtonSearch, barButtonInbox]
        //                 bottomAppBar.trailingBarButtonItems = [barButtonTrailingItem]
        bottomAppBar.elevation = ShadowElevation(rawValue: 8)
        bottomAppBar.floatingButtonPosition = .trailing
        
        
        bottomAppBar.floatingButton.addTarget(self, action: #selector(AddTaskAction), for: .touchUpInside)
    }
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                ACTION: BOTTOMBAR BUTTON STUBS
    //----------------------- *************************** -----------------------
    
    @objc
    func onMenuButtonTapped() {
        print("menu buttoon tapped")
    }
    
    @objc
    func onNavigationButtonTapped() {
        print("nav buttoon tapped")
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     IS BACKDROP DOWN
    //----------------------- *************************** -----------------------
    //TODO: Improve this; make more resilient; if this breaks, the view breaks
    //    func isBackdropDown() -> Bool{
    //        print("---------------------------------------------")
    //        print("backdrop midY:\(backdropForeImageView.bounds.midY)")
    //        print("backdrop minY:\(backdropForeImageView.bounds.minY)")
    //        print("backdrop maxY:\(backdropForeImageView.bounds.maxY)")
    //        print("backdrop screen height:\(UIScreen.main.bounds.height-headerEndY)")
    //        print("backdrop headerEndY:\(headerEndY)")
    //
    ////        if backdropForeImageView.bounds.maxY == UIScreen.main.bounds.height-headerEndY {
    ////
    ////            print("isBackdropDown: NOT DOWN - Header INIT positio exact match !")
    ////            return false
    ////
    ////        } else {
    ////            print("isBackdropDown: YES DOWN -  !")
    ////            return true
    ////        }
    //
    //
    //    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     ACTION: SHOW CHARTS
    //----------------------- *************************** -----------------------
    
    @objc func showChartsHHomeButton_Action() {
        
        print("Show CHARTS !!")
        let delay: Double = 0.2
        let duration: Double = 1.2
        
        if (!isChartsDown && !isCalDown) { //if backdrop is up; then push down & show charts
            
            print("charts: Case RED")
            //--------------------
            
            print("ShowChartsButton: backdrop is UP; pushing down to show charts")
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealCharts(view: self.tableView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealCharts(view: self.backdropForeImageView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.bringSubviewToFront(self.bottomAppBar)
            self.lineChartView.isHidden = false
            self.animateLineChart(chartView: self.lineChartView)
            
            
            //            tableView.reloadData()
            
            
            //-------
            
            
        } else if (!isChartsDown && isCalDown){ //charts hidden & cal shown
            //            print("Charts + CAL")
            
            print("ShowChartsButton: backdrop is DOWN; + CAL is SHOWING; pushing down FURTHER to show charts")
            
            print("charts: Case BLUE")
            //                        print("***************** Charts are hidden; foredrop ginng DOWN; reveal charts")
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealChartsKeepCal(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealChartsKeepCal(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                if (self.isChartsDown) { //todo replace with addtarget observer on foredropimagview
                    
                    print("KEEP SHWING CHARTS")
                    self.lineChartView.isHidden = false
                    self.isChartsDown = true
                    self.animateLineChart(chartView: self.lineChartView)
                    
                } else {
                    print("backdrop is up; HIDE CHARTS")
                    self.lineChartView.isHidden = true
                }
                
            }
            
            
            
            
            self.view.bringSubviewToFront(self.bottomAppBar)
            
            
        } else if (isChartsDown && !isCalDown) {//pull it back up // charts shown + cal hidden
            print("charts: Case YELLOW")
            print("ShowChartsButton: backdrop is DOWN; + CAL is HIDDEN; pushing down to show charts")
            
            //                        print("***************** Charts are hidden; foredrop ginng DOWN; reveal charts")
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideCharts(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideCharts(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                if (self.isChartsDown) { //todo replace with addtarget observer on foredropimagview
                    
                    print("KEEP SHWING CHARTS")
                    self.lineChartView.isHidden = false
                    self.isChartsDown = true
                } else {
                    print("backdrop is up; HIDE CHARTS")
                    self.lineChartView.isHidden = true
                    self.isChartsDown = false
                }
                
            }
            
            
            
            
            self.view.bringSubviewToFront(self.bottomAppBar)
        }
            
        else if (isChartsDown && isCalDown) { //pull back to hide charts --> keep showing cal
            print("charts: Case GREEN")
            print("charts: charts & cal are shown; --> hiding charts")
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(lineChartView)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideChartsKeepCal(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideChartsKeepCal(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                
                
                if (self.isChartsDown) { //todo replace with addtarget observer on foredropimagview
                    
                    print("KEEP SHWING CHARTS")
                    self.lineChartView.isHidden = false
                    
//                    self.calendar.isHidden
                    
                    self.isChartsDown = true
                } else {
                    print("backdrop is up; HIDE CHARTS")
                    self.lineChartView.isHidden = true
                    self.calendar.isHidden = true
                    self.isCalDown = false
                    self.isChartsDown = false
                }
                
            }
            
            
            
            
            self.view.bringSubviewToFront(self.bottomAppBar)
            
        }
            
        else {
            print("ERROR LAYOUT - SHOW CHARTS")
        }
        
        
        
        //          if(isCalDown) { //cal is out; it sldes back up
        //
        //
        //              self.view.bringSubviewToFront(self.tableView)
        //              self.view.sendSubviewToBack(calendar)
        //              self.view.sendSubviewToBack(backdropBackgroundImageView)
        //              UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
        //                  self.moveUp_hideCal(view: self.tableView)
        //              }) { (_) in
        //
        //              }
        //
        //              UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
        //                  self.moveUp_hideCal(view: self.backdropForeImageView)
        //              }) { (_) in
        //
        //              }
        //
        //              DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
        //
        //                  // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
        //
        //              }
        //
        //              self.view.bringSubviewToFront(self.bottomAppBar)
        //
        //          } else {
        //              self.view.bringSubviewToFront(self.tableView)
        //              self.view.sendSubviewToBack(calendar)
        //              self.view.sendSubviewToBack(backdropBackgroundImageView)
        //
        //              UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
        //                  self.moveDown_revealCal(view: self.tableView)
        //              }) { (_) in
        //                  //            self.moveLeft(view: self.black4)
        //              }
        //
        //              UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
        //                  self.moveDown_revealCal(view: self.backdropForeImageView)
        //              }) { (_) in
        //                  //            self.moveLeft(view: self.black4)
        //              }
        //
        //              self.view.bringSubviewToFront(self.tableView)
        //              self.view.bringSubviewToFront(self.bottomAppBar)
        //              self.calendar.isHidden = false
        //
        //          }
        tableView.reloadData()
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     ACTION: SHOW CALENDAR
    //----------------------- *************************** -----------------------
    
    //MARK:    showCalMoreButtonnAction
    
    @objc func showCalMoreButtonnAction() {
        
        print("Show cal !!")
        
        let delay: Double = 0.2
        let duration: Double = 1.2
        
        //isChartsDown && !isCalDown
        
        if(isCalDown && !isChartsDown) { //cal is out; it sldes back up
//            wewed
            
//            moveUp_hideCalFurther
            
            print("***************** Cal is out; frodrop ging up")
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(calendar)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_toHideCal(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_toHideCal(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
                if (self.isCalDown) { //todo replace with addtarget observer on foredropimagview
                    
                    print("KEEP SHWING CAL")
                    self.calendar.isHidden = false
                    self.isCalDown = true
                } else {
                    print("backdrop is up; Hidinng CAL")
                    self.calendar.isHidden = true
                    self.isCalDown = false
                }
                
            }
            
            
            print("cal CASE: BLUE")
            
            self.view.bringSubviewToFront(self.bottomAppBar)
            
        } else if (isCalDown && isChartsDown) { //cal is shown & charts are shown --> hide cal
            
            //            isChartsDown && !isCalDown
            
            print("cal CASE: GREEN")
            print("cal isCalDown: \(isCalDown)")
            print("cal isChartsDown: \(isChartsDown)")
            print("Cal is downn & charts are down !")
            
            self.calendar.isHidden = true
            isCalDown = false
            
        }
        else if (!isCalDown && isChartsDown) { //cal hidden & charts show --> show cal without moving foredrop
            
            //            isChartsDown && !isCalDown
            print("cal CASE: YELLOW")
            
            print("cal isCalDown: \(isCalDown)")
            print("cal isChartsDown: \(isChartsDown)")
            print("Cal is downn & charts are down !")
            
            self.calendar.isHidden = false
            isCalDown = true
            
        }
            
            //            else if (!isCalDown && isChartsDown) { //cal is hidden & charts are shown --> hide cal
            //            print("cal isCalDown: \(isCalDown)")
            //            print("cal isChartsDown: \(isChartsDown)")
            //            print("Cal is HIDDEN & charts are SHOWN !")
            //
            //            self.calendar.isHidden = t
            //        }
            
//
        else { //cal is covered; reveal it
            
            print("Cal ELSE !")
            print("cal isCalDown: \(isCalDown)")
            print("cal isChartsDown: \(isChartsDown)")
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(calendar)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealJustCal(view: self.tableView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealJustCal(view: self.backdropForeImageView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.bringSubviewToFront(self.bottomAppBar)
            self.calendar.isHidden = false
            
        }
        tableView.reloadData()
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                        ACTION: ADD TASK
    //----------------------- *************************** -----------------------
    
    @objc func AddTaskAction() {
        
        //       tap add fab --> addTask
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "addTask") as! NAddTaskScreen
        newViewController.modalPresentationStyle = .fullScreen
        self.present(newViewController, animated: true, completion: nil)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                          UTIL: text,
    //----------------------- *************************** -----------------------
    
    //Mark: Util: set font
    func setFont(fontSize: CGFloat, fontweight: UIFont.Weight, fontDesign: UIFontDescriptor.SystemDesign) -> UIFont {
        
        // Here we get San Francisco with the desired weight
        let systemFont = UIFont.systemFont(ofSize: fontSize, weight: fontweight)
        
        // Will be SF Compact or standard SF in case of failure.
        let font: UIFont
        
        if let descriptor = systemFont.fontDescriptor.withDesign(fontDesign) {
            font = UIFont(descriptor: descriptor, size: fontSize)
        } else {
            font = systemFont
        }
        return font
    }
    
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                            DATE
    //----------------------- *************************** -----------------------
    
    //MARK: set passed date as day, week, month label text
    func updateHomeDate(date: Date) {
        
        if("\(date.day)".count < 2) {
            self.homeDate_Day.text = "0\(date.day)"
        } else {
            self.homeDate_Day.text = "\(date.day)"
        }
        self.homeDate_WeekDay.text = getWeekday(date: date)
        self.homeDate_Month.text = getMonth(date: date)
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1.1 : SETUP NOTCH BACKDROP
    //----------------------- *************************** -----------------------
    
    //MARK:- Setup Backdrop Notch
    func setupBackdropNotch() {
        backdropNochImageView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40)
        backdropNochImageView.backgroundColor = primaryColorDarker
        
        view.addSubview(backdropNochImageView)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 1: SETUP BACKGROUND
    //----------------------- *************************** -----------------------
    
    //MARK:- Setup Backdrop Background - Today label + Score
    func setupBackdropBackground() {
        
        backdropBackgroundImageView.frame =  CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = primaryColor
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)
        
        
        //---------- score at home
        
        scoreAtHomeLabel.text = "\n\nscore"
        scoreAtHomeLabel.numberOfLines = 3
        scoreAtHomeLabel.textColor = .systemGray6
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
        
        //        homeTopBar.addSubview(scoreCounter)
        
        view.addSubview(backdropBackgroundImageView)
        
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN 2: SETUP FOREGROUND
    //----------------------- *************************** -----------------------
    
    //MARK: Setup forground
    func setupBackdropForeground() {
        //    func setupBackdropForeground() {
        
        print("Backdrop starts from: \(headerEndY)") //this is key to the whole view; charts, cal, animations, all
        backdropForeImageView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        
        
        
        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
        backdropForeImageView.tintColor = .systemGray6
        
        
        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowOpacity = 0.8
        backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0) //.zero
        backdropForeImageView.layer.shadowRadius = 10
        
        view.addSubview(backdropForeImageView)
        
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                       CALENNDAR:SETUP
    //----------------------- *************************** -----------------------
    
    //MARK: Setup calendar appearence
    func setupCal() {
        let calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2))
        calendar.calendarHeaderView.backgroundColor = primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        calendar.calendarWeekdayView.backgroundColor = primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        calendar.appearance.weekdayTextColor = .white
        calendar.appearance.headerTitleColor = .white
        calendar.appearance.titleWeekendColor = .red
        calendar.appearance.caseOptions = .weekdayUsesUpperCase
        //        calendar.appearance.eventSelectionColor = secondaryAccentColor
        //        calendar.appearance.separators = .interRows
        //        calendar.appearance.selectionColor = secondaryAccentColor
        calendar.appearance.subtitleDefaultColor = .white
        //        calendar.appearance.subtitleTodayColor
        //        calendar.appearance.todayColor = .green
        
        
        calendar.dataSource = self
        calendar.delegate = self
        
        self.calendar = calendar
        self.calendar.scope = FSCalendarScope.week
        //        calendar.backgroundColor = .white
    }
    
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                            CALENDAR
    //----------------------- *************************** -----------------------
    
    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        print("You selected Date: \(date.stringIn(dateStyle: .full, timeStyle: .none))")
        dateToDisplay = date
        dateForTheView = date
        
        updateHomeDate(date: dateToDisplay)
        //        (self.calculateTodaysScore()
        self.scoreCounter.text = "\(self.calculateTodaysScore())"
        
        let scoreNumber = "\(self.calculateTodaysScore())"
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
        //            let centerText = NSMutableAttributedString(string: "\(scoreNumber)\nscore")
        let centerText = NSMutableAttributedString(string: "\(scoreNumber)")
        if scoreNumber.count == 1 {
            centerText.setAttributes([.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded),
                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        } else if scoreNumber.count == 2 {
            centerText.setAttributes([.font : setFont(fontSize: 45, fontweight: .medium, fontDesign: .rounded),
                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
        } else {
            centerText.setAttributes([.font : setFont(fontSize: 28, fontweight: .medium, fontDesign: .rounded),
                                      .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
            
        }
        
        //            centerText.addAttributes([.font : setFont(fontSize: 16, fontweight: .regular, fontDesign: .monospaced),
        //                                      .foregroundColor : UIColor.secondaryLabel], range: NSRange(location: scoreNumber.count+1, length: centerText.length - (scoreNumber.count+1)))
        self.tinyPieChartView.centerAttributedText = centerText;
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        
        tableView.reloadData()
        animateTableViewReload()
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                      GET GLOBAL TASK
    //----------------------- *************************** -----------------------
    /*
     Pass this a morning or evening or inbox or upcoming task &
     this will give the index of that task in the global task array
     using that global task array index the element can then be removed
     or modded
     */
    func getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: NTask) -> Int {
        var tasks = [NTask]()
        var idxHolder = 0
        tasks = TaskManager.sharedInstance.getAllTasks
        if let idx = tasks.firstIndex(where: { $0 === morningOrEveningTask }) {
            
            print("Marking task as complete: \(TaskManager.sharedInstance.getAllTasks[idx].name)")
            print("func IDX is: \(idx)")
            idxHolder = idx
            
        }
        return idxHolder
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                      TABLE SWIPE ACTIONS
    //----------------------- *************************** -----------------------
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: self.dateForTheView)
            let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
            
            switch indexPath.section {
            case 0:
                
                //                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getMorningTasks[indexPath.row])].isComplete = true
                
                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: morningTasks[indexPath.row])].isComplete = true
                
                TaskManager.sharedInstance.saveContext()
                
            case 1:
                
                //                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getEveningTasks[indexPath.row])].isComplete = true
                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: eveningTasks[indexPath.row])].isComplete = true
                TaskManager.sharedInstance.saveContext()
                
            default:
                break
            }
            
            //            self.scoreForTheDay.text = "\(self.calculateTodaysScore())"
            print("SCORE IS: \(self.calculateTodaysScore())")
            self.scoreCounter.text = "\(self.calculateTodaysScore())"
            
            tableView.reloadData()
            self.animateTableViewReload()
            //            UIView.animate(views: tableView.visibleCells, animations: self.animations, completion: {
            //
            //                   })
            
            // right spring animation
            //            tableView.reloadData(
            //                with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
            //                              constantDelay: 0))
            
            self.title = "\(self.calculateTodaysScore())"
            actionPerformed(true)
        }
        
        return UISwipeActionsConfiguration(actions: [completeTaskAction])
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let deleteTaskAction = UIContextualAction(style: .destructive, title: "Delete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let confirmDelete = UIAlertController(title: "Are you sure?", message: "This will delete this task", preferredStyle: .alert)
            
            let yesDeleteAction = UIAlertAction(title: "Yes", style: .destructive)
            {
                (UIAlertAction) in
                
                let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: self.dateForTheView)
                let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
                
                switch indexPath.section {
                case 0:
                    
                    //                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getMorningTasks[indexPath.row]))
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: morningTasks[indexPath.row]))
                case 1:
                    //                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getEveningTasks[indexPath.row]))
                    
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: eveningTasks[indexPath.row]))
                default:
                    break
                }
                
                //                tableView.reloadData()
                //                tableView.reloadData(
                //                    with: .simple(duration: 0.45, direction: .rotation3D(type: .captainMarvel),
                //                                  constantDelay: 0))
                
                tableView.reloadData()
                self.animateTableViewReload()
                //                UIView.animate(views: tableView.visibleCells, animations: self.animations, completion: {
                //
                //                       })
                
                
            }
            let noDeleteAction = UIAlertAction(title: "No", style: .cancel)
            { (UIAlertAction) in
                
                print("That was a close one. No deletion.")
            }
            
            //add actions to alert controller
            confirmDelete.addAction(yesDeleteAction)
            confirmDelete.addAction(noDeleteAction)
            
            //show it
            self.present(confirmDelete ,animated: true, completion: nil)
            
            self.title = "\(self.calculateTodaysScore())"
            actionPerformed(true)
        }
        
        
        return UISwipeActionsConfiguration(actions: [deleteTaskAction])
    }
    
}

//----------------------- *************************** -----------------------
//MARK:-                            CALENDAR DELEGATE
//----------------------- *************************** -----------------------

//MARK:- CAL Extention: task count as day subtext
extension ViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, subtitleFor date: Date) -> String? {
        
        let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: date)
        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: date)
        let allTasks = morningTasks+eveningTasks
        
        if(allTasks.count == 0) {
            return "-"
        } else {
            return "\(allTasks.count) tasks"
        }
    }
}

//----------------------- *************************** -----------------------
//MARK:-                      CIRCLE MENU DELEGATE
//----------------------- *************************** -----------------------

extension ViewController: CircleMenuDelegate {
    // MARK:- CircleMenuDelegate
    
    func circleMenu(_: CircleMenu, willDisplay button: UIButton, atIndex: Int) {
        button.backgroundColor = circleMenuItems[atIndex].color
        
        button.setImage(UIImage(named: circleMenuItems[atIndex].icon), for: .normal)
        
        // set highlited image
        let highlightedImage = UIImage(named: circleMenuItems[atIndex].icon)?.withRenderingMode(.alwaysTemplate)
        button.setImage(highlightedImage, for: .highlighted)
        button.tintColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
    }
    
    func circleMenu(_: CircleMenu, buttonWillSelected _: UIButton, atIndex: Int) {
        print("button will selected: \(atIndex)")
        if (atIndex == 3) { //Opens settings menu
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { //adds delay
                // your code here
                let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                let newViewController = storyBoard.instantiateViewController(withIdentifier: "settingsPage")
                self.present(newViewController, animated: true, completion: nil)
            }
            
            
        }
    }
    
    
    func circleMenu(_: CircleMenu, buttonDidSelected _: UIButton, atIndex: Int) {
        print("button did selected: \(atIndex)")
    }
    
    
    
    
    
}

//----------------------- *************************** -----------------------
//MARK:-                        DETECT NOTCH
//----------------------- *************************** -----------------------

//extension UIDevice {
//    var hasNotch: Bool {
//        let bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
//        return bottom > 0
//    }
//}

extension UIDevice {
    var hasNotch: Bool {
        if #available(iOS 11.0, *) {
            if UIApplication.shared.windows.count == 0 { return false }          // Should never occur, but…
            let top = UIApplication.shared.windows[0].safeAreaInsets.top
            return top > 20          // That seem to be the minimum top when no notch…
        } else {
            // Fallback on earlier versions
            return false
        }
    }
}

