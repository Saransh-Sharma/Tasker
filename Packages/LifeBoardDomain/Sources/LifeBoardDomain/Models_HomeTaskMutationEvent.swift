import Foundation

/// Why a task changed.
///
/// Carried on `HomeTaskMutationPayload` so a mutation can be attributed after
/// the fact — by the receipt ledger, by Undo, and by analytics.
///
/// The file previously carried a `HomeViewModel.swift` header and imports of
/// Combine, UIKit and WidgetKit, none of which it used: it was carved out of
/// the view model and the preamble came with it. Those imports are what made
/// `Domain/` appear to depend on UIKit.
public enum HomeTaskMutationEvent: String, Codable, CaseIterable, Sendable {
    case created
    case updated
    case deleted
    case completed
    case reopened
    case rescheduled
    case projectChanged
    case priorityChanged
    case typeChanged
    case dueDateChanged
    case bulkChanged
}
