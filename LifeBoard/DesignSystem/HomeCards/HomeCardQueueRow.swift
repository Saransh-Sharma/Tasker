import Foundation

struct HomeCardQueueRow: Identifiable {
    let id: UUID
    let title: String
    let symbol: String
    var detail: String? = nil
    var accessibilityIdentifier: String? = nil
}
