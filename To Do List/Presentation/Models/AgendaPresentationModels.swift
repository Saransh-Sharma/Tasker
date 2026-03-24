//
//  AgendaPresentationModels.swift
//  Tasker
//
//  Shared presentation scaffolding for Home agenda rows and Insights modules.
//

import Foundation

public enum HomeBand: String, CaseIterable, Hashable {
    case context
    case activeWork
    case pressure
    case secondary
}

public enum AgendaRowStateTone: String, Hashable {
    case neutral
    case accent
    case success
    case warning
    case danger
    case quiet
}

public struct AgendaRowStateBadge: Equatable, Hashable {
    public let text: String
    public let systemImage: String?
    public let tone: AgendaRowStateTone

    public init(
        text: String,
        systemImage: String? = nil,
        tone: AgendaRowStateTone
    ) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }
}

public enum HabitSubtypePresentation: String, Equatable, Hashable {
    case build
    case quit
    case dailyLog
    case lapseOnly
}

public struct AgendaRowPresentationModel: Equatable, Hashable {
    public let title: String
    public let leadingSystemImage: String
    public let metadataLine: String?
    public let secondaryLine: String?
    public let primaryBadge: AgendaRowStateBadge
    public let secondaryBadge: AgendaRowStateBadge?
    public let primaryActionTitle: String?
    public let secondaryActionTitle: String?

    public init(
        title: String,
        leadingSystemImage: String,
        metadataLine: String? = nil,
        secondaryLine: String? = nil,
        primaryBadge: AgendaRowStateBadge,
        secondaryBadge: AgendaRowStateBadge? = nil,
        primaryActionTitle: String? = nil,
        secondaryActionTitle: String? = nil
    ) {
        self.title = title
        self.leadingSystemImage = leadingSystemImage
        self.metadataLine = metadataLine
        self.secondaryLine = secondaryLine
        self.primaryBadge = primaryBadge
        self.secondaryBadge = secondaryBadge
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
    }
}

public enum InsightsModuleVisibility: Equatable {
    case visible
    case empty(message: String)
    case hidden
}

public struct InsightsTabBlueprint: Equatable {
    public let heroQuestion: String
    public let supportModuleIDs: [String]

    public init(
        heroQuestion: String,
        supportModuleIDs: [String]
    ) {
        self.heroQuestion = heroQuestion
        self.supportModuleIDs = supportModuleIDs
    }
}
