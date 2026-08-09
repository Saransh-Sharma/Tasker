import SwiftUI
import UIKit

func lifeManagementAreaIconLabel(for symbolName: String, options: [LifeAreaIconOption]) -> String {
    options.first(where: { $0.symbolName == symbolName })?.keywords.first?.capitalized ?? symbolName
}
