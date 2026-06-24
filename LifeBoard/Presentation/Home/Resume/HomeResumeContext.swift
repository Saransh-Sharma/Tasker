//
//  HomeResumeContext.swift
//  LifeBoard
//
//  Drives the calm, context-aware "pick up where you left off" surface at the top
//  of Home. Resolved from HomeSessionContextStore on foreground; intentionally
//  optional and dismissible so it never reads as pressure.
//

import Foundation

public enum HomeResumeMode: Equatable, Sendable {
    /// Early-day orientation: how many open tasks, and the next thing on the timeline.
    case morningBrief(taskCount: Int, nextItem: String?)
    /// Mid-day continuation of the task the user was last on.
    case resumeTask(title: String, pausedMinutesAgo: Int, taskID: UUID)
    /// End-of-day reflection + a gentle path to move unfinished work forward.
    case eveningWrap(doneCount: Int, openCount: Int)
}

public struct HomeResumeContext: Equatable, Sendable {
    public let mode: HomeResumeMode

    public init(mode: HomeResumeMode) {
        self.mode = mode
    }
}
