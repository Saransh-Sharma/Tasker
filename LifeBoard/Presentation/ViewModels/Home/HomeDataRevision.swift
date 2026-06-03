//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct HomeDataRevision: Equatable, Hashable, Sendable {
    public static let zero = HomeDataRevision(rawValue: 0)
    public private(set) var rawValue: UInt64

    public init(rawValue: UInt64 = 0) {
        self.rawValue = rawValue
    }

    mutating func advance() {
        rawValue &+= 1
    }
}
