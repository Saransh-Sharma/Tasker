//
//  TableViewCellSampleData.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import FluentUI

// MARK: TableViewCellSampleData

class TableViewCellSampleData: ToDoListData {
    //    static let numberOfItemsInSection: Int = 5
    //    static let numberOfItemsInSectionForShimmer: Int = 3
    
    // for custom date view & today view:
    // 0) spacer
    // 1) inbox for (today || date)
    // 2) projects for (today || date)
    static let DateForViewSections: [Section] = [
        Section(
            title: "section 0",
            taskListItems: [
                TaskListItem(text1: "Spacer"
                )
            ]
        ),
        Section( // inbox for (today || date)
            title: "",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey"
                )
            ]
        ),
        Section( //projects for (today || date)
            title: "Projects",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey"
                )
            ]
        )
    ]
    
    // for custom project view
    static let ProjectForViewSections: [Section] = [
        Section(
            title: "section 0",
            taskListItems: [
                TaskListItem(text1: "Spacer"
                )
            ]
        ),
        Section(  //Goal: build project sections at run time // each sub project is a section
            title: "",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey"
                )
            ]
        )
    ]
    
    static let UpcomingViewSections: [Section] = [
        Section(
            title: "section 0",
            taskListItems: [
                TaskListItem(text1: "Spacer"
                )
            ]
        ),
        Section(
            title: "", // build dynamic sections for 1 week/10/14/30 days
            taskListItems: [
                TaskListItem(text1: "Contoso Survey"
                )
            ]
        )
    ]
    
    static let HistoryViewSections: [Section] = [
        Section(
            title: "section 0",
            taskListItems: [
                TaskListItem(text1: "Spacer"
                )
            ]
        ),
        Section(
            title: "",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey"
                )
            ]
        )
    ]
    
    static let OLDtodayViewSetions: [Section] = [
        Section(
            title: "section 0",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey",
                             text2: "Research Notes",
                             image: "excelIcon",
                             //                                    text1LeadingAccessoryView:  createIconsAccessoryView(images: ["success-12x12"]),
                             text1LeadingAccessoryView: { createIconsAccessoryView(images: ["success-12x12"]) },
                             text1TrailingAccessoryView: { createIconsAccessoryView(images: ["shared-12x12", "success-12x12"]) },
                             //                         text2TrailingAccessoryView: { createIconsAccessoryView(images: ["shared-12x12", "success-12x12"]) },
                             text2LeadingAccessoryView: { createIconsAccessoryView(images: ["success-12x12"]) })
            ]
        ),
        Section(
            title: "",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey",
                             text2: "Research Notes",
                             image: "excelIcon",
                             //                                    text1LeadingAccessoryView:  createIconsAccessoryView(images: ["success-12x12"]),
                             text1LeadingAccessoryView: { createIconsAccessoryView(images: ["success-12x12"]) },
                             text1TrailingAccessoryView: { createIconsAccessoryView(images: ["shared-12x12", "success-12x12"]) },
                             //                         text2TrailingAccessoryView: { createIconsAccessoryView(images: ["shared-12x12", "success-12x12"]) },
                             text2LeadingAccessoryView: { createIconsAccessoryView(images: ["success-12x12"]) })
            ]
        ),
        Section(
            title: "Projects",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey",
                             image: "excelIcon",
                             text1LeadingAccessoryView: { createIconsAccessoryView(images: ["success-12x12"]) })
            ]
        ),
        Section(
            title: "Double line cell",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey",
                             text2: "Research Notes",
                             image: "excelIcon",
                             text2LeadingAccessoryView: { createIconsAccessoryView(images: ["shared-12x12", "success-12x12"]) })
            ]
        ),
        Section(
            title: "Triple line cell",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey",
                             text2: "Research Notes",
                             text3: "22 views",
                             image: "excelIcon",
                             text2TrailingAccessoryView: { createIconsAccessoryView(images: ["shared-12x12", "success-12x12"]) },
                             text3TrailingAccessoryView: { createProgressAccessoryView() })
            ],
            hasFullLengthLabelAccessoryView: true
        ),
        Section(
            title: "Cell without custom view",
            taskListItems: [
                TaskListItem(text1: "Contoso Survey",
                             text2: "Research Notes",
                             text1TrailingAccessoryView: { createTextAccessoryView(text: "8:13 AM") },
                             text2LeadingAccessoryView: { createIconsAccessoryView(images: ["success-12x12"]) },
                             text2TrailingAccessoryView: { createIconsAccessoryView(images: ["at-12x12"], rightAligned: true) })
            ]
        ),
        Section(
            title: "Cell with custom accessory view",
            taskListItems: [
                TaskListItem(text1: "Format")
            ],
            hasAccessory: true
        ),
        Section(
            title: "Cell with text truncation",
            taskListItems: [
                TaskListItem(text1: "This is a cell with a long text1 as an example of how this label will render",
                             text2: "This is a cell with a long text2 as an example of how this label will render",
                             text3: "This is a cell with a long text3 as an example of how this label will render",
                             image: "excelIcon",
                             text1TrailingAccessoryView: { createTextAccessoryView(text: "10:21 AM") },
                             text2TrailingAccessoryView: { createIconsAccessoryView(images: ["at-12x12"], rightAligned: true) },
                             text3TrailingAccessoryView: { createTextAccessoryView(text: "2", withBorder: true) })
            ]
        ),
        Section(
            title: "Cell with text wrapping",
            taskListItems: [
                TaskListItem(text1: "This is a cell with a long text1 as an example of how this label will render",
                             text2: "This is a cell with a long text2 as an example of how this label will render",
                             text3: "This is a cell with a long text3 as an example of how this label will render",
                             image: "excelIcon",
                             text1TrailingAccessoryView: { createTextAccessoryView(text: "10:21 AM") },
                             text2TrailingAccessoryView: { createIconsAccessoryView(images: ["at-12x12"], rightAligned: true) },
                             text3TrailingAccessoryView: { createTextAccessoryView(text: "2", withBorder: true) })
            ],
            numberOfLines: 0,
            allowsMultipleSelection: false
        )
    ]
    
    static var customAccessoryView: UIView {
        let label = Label(style: .body, colorStyle: .secondary)
        label.text = "overdue !"
        label.maxFontSize = 12
        label.colorStyle = .error
        label.sizeToFit()
        label.numberOfLines = 0
        return label
    }
    
    static func hasLabelAccessoryViews(at indexPath: IndexPath) -> Bool {
        return indexPath.row == 4
    }
    
    static func hasFullLengthLabelAccessoryView(at indexPath: IndexPath) -> Bool {
        let section = DateForViewSections[indexPath.section]
        return section.hasFullLengthLabelAccessoryView && hasLabelAccessoryViews(at: indexPath)
    }
    
    static func accessoryType(for indexPath: IndexPath) -> TableViewCellAccessoryType {
        // Demo accessory types based on indexPath row
        switch indexPath.row {
        case 0:
            return .none
        case 1:
            return .disclosureIndicator
        case 2:
            return .detailButton
        case 3:
            return .checkmark
        case 4:
            return .none
        default:
            return .none
        }
    }
    
    static func labelAccessoryView(accessories: [UIView], spacing: CGFloat, alignment: UIStackView.Alignment) -> UIStackView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = alignment
        
        let accessoryView = UIStackView()
        accessoryView.axis = .horizontal
        accessoryView.alignment = .center
        accessoryView.spacing = spacing
        
        accessories.forEach { accessoryView.addArrangedSubview($0) }
        
        container.addArrangedSubview(accessoryView)
        
        return container
    }
    
    static func createIconsAccessoryView(images: [String], rightAligned: Bool = false) -> UIView {
        let iconSpacing: CGFloat = 6
        var icons: [UIImageView] = []
        
//        images.forEach {
////            icons.append(UIImageView(image: UIImage(named: $0))) //systemName: "circle.fill")
//            icons.append(UIImageView(image: UIImage(systemName: "circle.fill")))
//        }
        
        return labelAccessoryView(accessories: icons, spacing: iconSpacing, alignment: rightAligned ? .trailing : .leading )
    }
    
    static func createProgressAccessoryView() -> UIView {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = 0.5
        return labelAccessoryView(accessories: [progressView], spacing: 0, alignment: .fill)
    }
    
    static func createTextAccessoryView(text: String, withBorder: Bool = false) -> UIView {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.axis = .vertical
        
        let label = Label(style: .footnote)
        label.textColor = UIColor(light: Colors.gray500, lightHighContrast: Colors.gray700, dark: Colors.gray400, darkHighContrast: Colors.gray200) //Colors.t
        label.text = text
        stackView.addArrangedSubview(label)
        
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        
        let container = UIView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        NSLayoutConstraint.activate([stackView.topAnchor.constraint(equalTo: container.topAnchor),
                                     stackView.heightAnchor.constraint(equalTo: container.heightAnchor),
                                     stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                                     stackView.widthAnchor.constraint(equalTo: container.widthAnchor)])
        
        if withBorder {
            container.layer.borderWidth = UIScreen.main.devicePixel
            container.layer.borderColor = UIColor(light: Colors.gray500, lightHighContrast: Colors.gray700, dark: Colors.gray400, darkHighContrast: Colors.gray200).cgColor//Colors.textSecondary.cgColor //Colors.textSecondary.cgColor
            container.layer.cornerRadius = 3
        }
        
        return labelAccessoryView(accessories: [container], spacing: 0, alignment: .trailing)
    }
}
