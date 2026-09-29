import Foundation
import LifeBoardDomain

/// One starting point for a habit: name, icon, colour seed, cadence, and —
/// the part the old two-entry starter list never carried — a real target.
/// Picking one fills the composer; nothing is created until "Add habit".
struct HabitTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let colorHex: String
    let kind: AddHabitKind
    let cadence: HabitCadenceDraft
    let target: HabitTarget
    let notes: String?

    /// "8 glasses a day", "20 min", "Check in", "Stay clear".
    var targetSummary: String {
        HabitTemplateCatalog.summary(for: target)
    }
}

enum HabitTemplateCatalog {
    static let all: [HabitTemplate] = [
        HabitTemplate(
            id: "water", title: String(localized: "Water"), systemImage: "drop.fill", colorHex: "#3B82F6",
            kind: .positive, cadence: .daily(),
            target: .quantitative(value: 8, unit: "glasses"), notes: nil
        ),
        HabitTemplate(
            id: "read", title: String(localized: "Read"), systemImage: "book.fill", colorHex: "#F59E0B",
            kind: .positive, cadence: .daily(),
            target: .timed(seconds: 20 * 60), notes: String(localized: "Any book or article.")
        ),
        HabitTemplate(
            id: "walk", title: String(localized: "Walk"), systemImage: "figure.walk", colorHex: "#10B981",
            kind: .positive, cadence: .daily(),
            target: .timed(seconds: 30 * 60), notes: nil
        ),
        HabitTemplate(
            id: "meditate", title: String(localized: "Meditate"), systemImage: "leaf.fill", colorHex: "#8B5CF6",
            kind: .positive, cadence: .daily(),
            target: .timed(seconds: 10 * 60), notes: nil
        ),
        HabitTemplate(
            id: "stretch", title: String(localized: "Stretch"), systemImage: "figure.flexibility", colorHex: "#EC4899",
            kind: .positive, cadence: .daily(),
            target: .binary, notes: String(localized: "5 min is enough.")
        ),
        HabitTemplate(
            id: "no-phone-after-ten", title: String(localized: "No phone after 10 PM"), systemImage: "moon.zzz.fill", colorHex: "#6366F1",
            kind: .negative, cadence: .daily(),
            target: .avoidance, notes: nil
        ),
    ]

    static func template(id: String) -> HabitTemplate? {
        all.first { $0.id == id }
    }

    static func summary(for target: HabitTarget) -> String {
        switch target {
        case .binary:
            return String(localized: "Check in")
        case .avoidance:
            return String(localized: "Stay clear")
        case let .quantitative(value, unit):
            let amount = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
            return String(localized: "\(amount) \(unit) a day")
        case let .quota(count, period):
            let unit: String
            switch period {
            case .day: unit = String(localized: "a day")
            case .week: unit = String(localized: "a week")
            case .month: unit = String(localized: "a month")
            }
            return String(localized: "\(count)× \(unit)")
        case let .timed(seconds):
            let minutes = Int((seconds / 60).rounded())
            return minutes >= 60 && minutes % 60 == 0 ? String(localized: "\(minutes / 60) hr") : String(localized: "\(minutes) min")
        }
    }

    /// The composer's prefill for a template. Life area and project are the
    /// caller's: the sheet already knows where it was opened from.
    static func prefill(for template: HabitTemplate, lifeAreaID: UUID?, projectID: UUID?) -> AddHabitPrefillTemplate {
        AddHabitPrefillTemplate(
            title: template.title,
            notes: template.notes,
            lifeAreaID: lifeAreaID,
            projectID: projectID,
            kind: template.kind,
            trackingMode: .dailyCheckIn,
            cadence: template.cadence,
            iconSymbolName: template.systemImage,
            colorHex: template.colorHex,
            target: template.target
        )
    }
}
