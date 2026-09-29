import SwiftUI

extension ClayColorTokens {
    static func actionGradient(for role: ClayRole) -> [Color] {
        switch role {
        case .routine, .windDown, .warning:
            return [
                adaptive(light: "#B87300", dark: "#D58A00"),
                adaptive(light: "#8C5400", dark: "#9E6400")
            ]
        case .task:
            return [
                adaptive(light: "#15952B", dark: "#218A38"),
                adaptive(light: "#0B6F1D", dark: "#11692A")
            ]
        case .meeting, .assistant:
            return [violetFill, violetFillDeep]
        case .personal, .meal, .error:
            return [
                adaptive(light: "#C74716", dark: "#C85B32"),
                adaptive(light: "#A83A32", dark: "#96372F")
            ]
        case .focus:
            return [
                adaptive(light: "#1266D6", dark: "#1F6ECB"),
                adaptive(light: "#0B4FA8", dark: "#134C95")
            ]
        case .neutral:
            return [
                adaptive(light: "#48607F", dark: "#3A4258"),
                adaptive(light: "#203765", dark: "#252D40")
            ]
        }
    }
}
