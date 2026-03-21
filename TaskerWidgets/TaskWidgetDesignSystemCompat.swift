import Foundation
import SwiftUI

enum V2FeatureFlags {
    static var iPadPerfThemeTokenCacheV2Enabled: Bool { true }
    static var iPadPerfHomeAnimationTrimV3Enabled: Bool { false }
}

enum TaskerTextFieldTokens {
    static let singleLineHeight: CGFloat = 52
}

enum TaskerSettingsMetrics {
    static let chipMinHeight: CGFloat = 32
}

func logDebug(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {}

func logDebug(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {}

func logDebug(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {}
