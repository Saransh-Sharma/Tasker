//
//  JournalHaptics.swift
//  JournalFoundation
//
//  Haptics seam so shared UI (mood dial, capture surfaces) never depends on
//  an app-side singleton. OffRecord adapts HapticManager; LifeBoard adapts
//  its own haptic vocabulary.
//

import Foundation

public protocol JournalHapticsProviding: Sendable {
    func selectionChanged()
    func moodSelected()
    func buttonTap()
    func recordingStarted()
    func recordingStopped()
    func entrySaved()
    func warning()
    func error()
}

/// Default no-op provider (previews, tests, watchOS surfaces without haptics).
public struct NoopJournalHaptics: JournalHapticsProviding {
    public init() {}
    public func selectionChanged() {}
    public func moodSelected() {}
    public func buttonTap() {}
    public func recordingStarted() {}
    public func recordingStopped() {}
    public func entrySaved() {}
    public func warning() {}
    public func error() {}
}
