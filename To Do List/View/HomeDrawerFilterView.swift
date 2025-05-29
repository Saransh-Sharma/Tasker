//
//  HomeDrawerFilterView.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit
import FluentUI

extension HomeViewController {
    
    
    @objc private func changeContentHeightButtonTapped(sender: UIButton) {
        if let spacer = (sender.superview as? UIStackView)?.arrangedSubviews.last,
           let heightConstraint = spacer.constraints.first {
            heightConstraint.constant = heightConstraint.constant == 20 ? 100 : 20
        }
    }
    
    
    @objc private func changeProjectFromFilter(sender: UIButton) {
        if let spacer = (sender.superview as? UIStackView)?.arrangedSubviews.last,
           let heightConstraint = spacer.constraints.first {
            heightConstraint.constant = heightConstraint.constant == 20 ? 100 : 20
        }
        
    }
    
    @objc private func changeDateFromFilterToday(sender: UIButton) {
        
        updateViewForHome(viewType: .todayHomeView, dateForView: Date.today())
        dismiss(animated: true)
        
    }
    
    @objc private func changeDateFromFilterTomorrow(sender: UIButton) {
        
        
        
        updateViewForHome(viewType: .customDateView, dateForView: Date.tomorrow())
        
        dismiss(animated: true)
    }
    
    @objc private func expandButtonTapped(sender: UIButton) {
        guard let drawer = presentedViewController as? DrawerController else {
            return
        }
        drawer.isExpanded = !drawer.isExpanded
        sender.setTitle(drawer.isExpanded ? "Return to normal" : "Expand", for: .normal)
    }
    
    func rearrange<T>(array: Array<T>, fromIndex: Int, toIndex: Int) -> Array<T>{
        var arr = array
        let element = arr.remove(at: fromIndex)
        arr.insert(element, at: toIndex)
        
        return arr
    }
    
    
    func buildProojectsPillBarData() {
        
        let allProjects = ProjectManager.sharedInstance.displayedProjects
        //        var indexToRemove = [Int]()
        self.pillBarProjectList = []
        
        for each in allProjects {
            if let projectName = each.projectName {
                print("do9 added to pill bar, from ProjectManager: \(projectName)")
                self.pillBarProjectList.append(PillButtonBarItem(title: projectName))
            }
        }
        
        
        
        for (index, value) in pillBarProjectList.enumerated() {
            print("do9 --- AT INDEX \(index) value is \(value.title)")
        }
    }
    
    
    private func actionViews(drawerHasFlexibleHeight: Bool) -> [UIView] {
        let spacer = UIView()
        spacer.backgroundColor = .orange
        spacer.layer.borderWidth = 1
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        
        var views = [UIView]()
        if drawerHasFlexibleHeight {
            
            views.append(addLabel(text: "Filter By Days", style: .headline, colorStyle: .regular))
            
            views.append(createButton(title: "Today", action: #selector(changeDateFromFilterToday)))
            views.append(createButton(title: "Tomorrow", action: #selector(changeDateFromFilterTomorrow)))
            //views.append(createButton(title: "Upcoming", action: #selector(changeDateFromFilterTomorrow)))
            
            
            
            //addProjectContainer.addArrangedSubview(Separator())
            
            views.append(Separator())
            
            //            let mProjects = ProjectManageeer.sharedInstance.getAllProjects
            
            views.append(addLabel(text: "more filters like project, priority & upcoming tasks coming soon !", style: .caption2, colorStyle: .regular))
            
            //            views.append(addLabel(text: "Filter By Projects", style: .headline, colorStyle: .regular))
            //            buildProojectsPillBarData()
            //            filterProjectsPillBar = createProjectsBar(items: pillBarProjectList, style: .filled)
            //            filterProjectsPillBar!.frame = CGRect(x: 0, y: 300, width: UIScreen.main.bounds.width, height: 65)
            //            _ = bar.selectItem(atIndex: 0)
            //            views.append(filterProjectsPillBar!)
            views.append(Separator())
            
        }
        return views
    }
    
    @discardableResult
    func addLabel(text: String, style: TextStyle, colorStyle: TextColorStyle) -> Label {
        let label = Label(style: style, colorStyle: colorStyle)
        label.text = text
        label.numberOfLines = 0
        if colorStyle == .white {
            label.backgroundColor = .black
        }
        //        addProjectContainer.addArrangedSubview(label)
        return label
    }
    
    
    public func containerForActionViews(drawerHasFlexibleHeight: Bool = true) -> UIView {
        let container = HomeViewController.createVerticalContainer()
        container.backgroundColor = .white
        for view in actionViews(drawerHasFlexibleHeight: drawerHasFlexibleHeight) {
            container.addArrangedSubview(view)
        }
        return container
    }
    
    @discardableResult
    public func presentDrawer(sourceView: UIView? = nil, barButtonItem: UIBarButtonItem? = nil, presentationOrigin: CGFloat = -1, presentationDirection: DrawerPresentationDirection, presentationStyle: DrawerPresentationStyle = .automatic, presentationOffset: CGFloat = 0, presentationBackground: DrawerPresentationBackground = .black, presentingGesture: UIPanGestureRecognizer? = nil, permittedArrowDirections: UIPopoverArrowDirection = [.left, .right], contentController: UIViewController? = nil, contentView: UIView? = nil, resizingBehavior: DrawerResizingBehavior = .none, adjustHeightForKeyboard: Bool = false, animated: Bool = true, customWidth: Bool = false) -> DrawerController {
        let controller: DrawerController
        if let sourceView = sourceView {
            controller = DrawerController(sourceView: sourceView, sourceRect: sourceView.bounds.insetBy(dx: sourceView.bounds.width / 2, dy: 0), presentationOrigin: presentationOrigin, presentationDirection: presentationDirection)
        } else if let barButtonItem = barButtonItem {
            controller = DrawerController(barButtonItem: barButtonItem, presentationOrigin: presentationOrigin, presentationDirection: presentationDirection)
        } else {
            preconditionFailure("Presenting a drawer requires either a sourceView or a barButtonItem")
        }
        
        controller.presentationStyle = presentationStyle
        controller.presentationOffset = presentationOffset
        controller.presentationBackground = presentationBackground
        controller.presentingGesture = presentingGesture
        controller.permittedArrowDirections = permittedArrowDirections
        controller.resizingBehavior = resizingBehavior
        controller.adjustsHeightForKeyboard = adjustHeightForKeyboard
        controller.backgroundColor = .systemGray6
        
        if let contentView = contentView {
            // `preferredContentSize` can be used to specify the preferred size of a drawer,
            // but here we just define the width and allow it to calculate height automatically
            controller.preferredContentSize.width = 360
            controller.contentView = contentView
            if customWidth {
                //                controller.shouldUseWindowFullWidthInLandscape = false
                //                controller.landsc
            }
        } else {
            controller.contentController = contentController
        }
        
        present(controller, animated: animated)
        
        return controller
    }
    
}

// MARK: - PillButtonBarDemoController: PillButtonBarDelegate

extension HomeViewController: PillButtonBarDelegate {
    func pillBar(_ pillBar: PillButtonBar, didSelectItem item: PillButtonBarItem, atIndex index: Int) {
        //        currenttProjectForAddTaskView = item.title
        //        setProjectForViewValue(projectName: item.title)
        updateViewForHome(viewType: .projectView, projectForView: item.title)
        print("woo Project SELCTED is: \(projectForTheView)")
        
        
        //        let allProjects = ProjectManager.sharedInstance.getAllProjects
        let allTasks = TaskManager.sharedInstance.getAllTasks
        //        let selectedProjectName =
        
        
        var list: [String] = [""]
        for each in allTasks {
            
            
            if each.project?.lowercased() == projectForTheView {
                print("-----------------------")
                print("project Task: \(each.name)")
                print("name project \(projectForTheView)")
                list.append(each.name)
                print("-----------------------\n")
                
            }
        }
        
        print("-----****************----")
        for i in list {
            print("\(i)")
        }
        print("-----****************----")
        
        print("project selecction DONE !")
        
    }
}
