import Foundation
import FluentUI

class ToDoListData {
    struct Section {
        let sectionTitle: String
        var item: TaskListItem { return items[0] }
        let items: [TaskListItem]
        let numberOfLines: Int
        let hasFullLengthLabelAccessoryView: Bool
        let hasAccessory: Bool
        let accessoryButtonStyle: TableViewHeaderFooterView.AccessoryButtonStyle
        let allowsMultipleSelection: Bool
        let headerStyle: TableViewHeaderFooterView.Style
        let hasFooter: Bool
        let footerText: String
        let footerLinkText: String
        let hasCustomLinkHandler: Bool
        let hasCustomAccessoryView: Bool
        
        init(title: String, taskListItems: [TaskListItem] = [], numberOfLines: Int = 1, hasFullLengthLabelAccessoryView: Bool = false, hasAccessory: Bool = false, accessoryButtonStyle: TableViewHeaderFooterView.AccessoryButtonStyle = .regular, allowsMultipleSelection: Bool = true, headerStyle: TableViewHeaderFooterView.Style = .header, hasFooter: Bool = false, footerText: String = "", footerLinkText: String = "", hasCustomLinkHandler: Bool = false, hasCustomAccessoryView: Bool = false) {
            self.sectionTitle = title
            self.items = taskListItems
            self.numberOfLines = numberOfLines
            self.hasFullLengthLabelAccessoryView = hasFullLengthLabelAccessoryView
            self.hasAccessory = hasAccessory
            self.accessoryButtonStyle = accessoryButtonStyle
            self.allowsMultipleSelection = allowsMultipleSelection
            self.headerStyle = headerStyle
            self.hasFooter = hasFooter
            self.footerText = footerText
            self.footerLinkText = footerLinkText
            self.hasCustomLinkHandler = hasCustomLinkHandler
            self.hasCustomAccessoryView = hasCustomAccessoryView
        }
    }
    
    struct TaskListItem {
        typealias LabelAccessoryView = () -> UIView?
        
        let TaskTitle: String
        let text2: String
        let text3: String
        let image: String
        let text1LeadingAccessoryView: LabelAccessoryView
        let text1TrailingAccessoryView: LabelAccessoryView
        let text2LeadingAccessoryView: LabelAccessoryView
        let text2TrailingAccessoryView: LabelAccessoryView
        let text3LeadingAccessoryView: LabelAccessoryView
        let text3TrailingAccessoryView: LabelAccessoryView
        
        init(
            text1: String = "",
            text2: String = "",
            text3: String = "",
            image: String = "",
            text1LeadingAccessoryView: @escaping LabelAccessoryView = { return nil },
            text1TrailingAccessoryView: @escaping LabelAccessoryView = { return nil },
            text2LeadingAccessoryView: @escaping LabelAccessoryView = { return nil },
            text2TrailingAccessoryView: @escaping LabelAccessoryView = { return nil },
            text3LeadingAccessoryView: @escaping LabelAccessoryView = { return nil },
            text3TrailingAccessoryView: @escaping LabelAccessoryView = { return nil }
        ) {
            self.TaskTitle = text1
            self.text2 = text2
            self.text3 = text3
            self.image = image
            self.text1LeadingAccessoryView = text1LeadingAccessoryView
            self.text1TrailingAccessoryView = text1TrailingAccessoryView
            self.text2LeadingAccessoryView = text2LeadingAccessoryView
            self.text2TrailingAccessoryView = text2TrailingAccessoryView
            self.text3LeadingAccessoryView = text3LeadingAccessoryView
            self.text3TrailingAccessoryView = text3TrailingAccessoryView
        }
    }
    
    static func createCustomView(imageName: String, useImageAsTemplate: Bool = false) -> UIImageView? {
        if imageName == "" {
            return nil
        }
        var image = UIImage(named: imageName)
        if useImageAsTemplate {
            image = image?.withRenderingMode(.alwaysTemplate)
        }
        let customView = UIImageView(image: image)
        customView.contentMode = .scaleAspectFit
        customView.tintColor = .secondaryLabel
        return customView
    }
}
