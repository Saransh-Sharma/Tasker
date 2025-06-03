//
//  HomeDrawerFilterView.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/06/20.
//  Copyright 2020 saransh1337. All rights reserved.
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
    
    @objc private func showAllProjectsButtonTapped(sender: UIButton) {
        updateViewForHome(viewType: .allProjectsGrouped, dateForView: dateForTheView)
        dismiss(animated: true)
    }
    
    @objc private func applySelectedProjectsFilter() {
        // Only apply the filter if projects are selected
        if !selectedProjectNamesForFilter.isEmpty {
            updateViewForHome(viewType: .selectedProjectsGrouped, dateForView: dateForTheView)
            dismiss(animated: true)
        }
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
    
    private func createProjectMultiSelectView() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Create a collection view for the project pills
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.allowsMultipleSelection = true
        collectionView.register(ProjectPillCell.self, forCellWithReuseIdentifier: "ProjectPillCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        
        containerView.addSubview(collectionView)
        
        // Add Apply button
        let applyButton = UIButton(type: .system)
        applyButton.setTitle("Apply Filters", for: .normal)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.backgroundColor = todoColors.primaryColor
        applyButton.layer.cornerRadius = 8
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.addTarget(self, action: #selector(applySelectedProjectsFilter), for: .touchUpInside)
        
        containerView.addSubview(applyButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            collectionView.heightAnchor.constraint(equalToConstant: 120),
            
            applyButton.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 8),
            applyButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            applyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            applyButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            applyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Set fixed height for the container
        containerView.heightAnchor.constraint(equalToConstant: 180).isActive = true
        
        return containerView
    }
    
    private func actionViews(drawerHasFlexibleHeight: Bool) -> [UIView] {
        let spacer = UIView()
        spacer.backgroundColor = .orange
        spacer.layer.borderWidth = 1
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        
        var views = [UIView]()
        if drawerHasFlexibleHeight {
            
            let filterLabel = Label(textStyle: .title1, colorStyle: .regular)
            filterLabel.text = "Filter By Days"
            filterLabel.numberOfLines = 0
            views.append(filterLabel)
            
            views.append(createButton(title: "Today", action: #selector(changeDateFromFilterToday)))
            views.append(createButton(title: "Tomorrow", action: #selector(changeDateFromFilterTomorrow)))
            //views.append(createButton(title: "Upcoming", action: #selector(changeDateFromFilterTomorrow)))
            
            views.append(Separator())
            
            // Project Filtering Section
            let projectFilterLabel = Label(textStyle: .title1, colorStyle: .regular)
            projectFilterLabel.text = "Project Filters"
            projectFilterLabel.numberOfLines = 0
            views.append(projectFilterLabel)
            
            views.append(createButton(title: "Show All Projects", action: #selector(showAllProjectsButtonTapped)))
            
            // Project multi-select section
            let projectSelectionLabel = Label(textStyle: .caption1, colorStyle: .regular)
            projectSelectionLabel.text = "Select specific projects:"
            projectSelectionLabel.numberOfLines = 0
            views.append(projectSelectionLabel)
            
            // Add project multi-select container
            let projectSelectionView = createProjectMultiSelectView()
            views.append(projectSelectionView)
            
            views.append(Separator())
            
            let subLabel = Label(textStyle: .caption1, colorStyle: .regular)
            subLabel.text = "more filters like priority & upcoming tasks coming soon!"
            subLabel.numberOfLines = 0
            views.append(subLabel)
            
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
    public func addLabel(text: String) -> Label {
        let label = Label()
        label.text = text
        label.numberOfLines = 0
        return label
    }
    
    
    public func containerForActionViews(drawerHasFlexibleHeight: Bool = true) -> UIView {
        let container = HomeViewController.createVerticalContainer()
        container.backgroundColor = UIColor.white
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

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ProjectManager.sharedInstance.displayedProjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProjectPillCell", for: indexPath) as! ProjectPillCell
        let project = ProjectManager.sharedInstance.displayedProjects[indexPath.item]
        
        if let projectName = project.projectName {
            cell.configure(with: projectName)
            
            // Pre-select the cell if this project is in the selectedProjectNamesForFilter array
            if selectedProjectNamesForFilter.contains(projectName) {
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                cell.isSelected = true
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let projectName = ProjectManager.sharedInstance.displayedProjects[indexPath.item].projectName {
            if !selectedProjectNamesForFilter.contains(projectName) {
                selectedProjectNamesForFilter.append(projectName)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let projectName = ProjectManager.sharedInstance.displayedProjects[indexPath.item].projectName {
            if let index = selectedProjectNamesForFilter.firstIndex(of: projectName) {
                selectedProjectNamesForFilter.remove(at: index)
            }
        }
    }
}

// MARK: - PillButtonBarDemoController: PillButtonBarDelegate

extension HomeViewController: PillButtonBarDelegate {
    func pillBar(_ pillBar: PillButtonBar, didSelectItem item: PillButtonBarItem, atIndex index: Int) {
        //        currenttProjectForAddTaskView = item.title
        //        setProjectForViewValue(projectName: item.title)
        // 1) Assign the selected project name
        setProjectForViewValue(projectName: item.title)

        // 2) Switch to projectView (the stored projectForTheView will be used internally)
        updateViewForHome(viewType: .projectView)
        print("woo Project SELECTED is: \(projectForTheView)")
        
        
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
