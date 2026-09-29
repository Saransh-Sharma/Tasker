import Foundation

public enum StarterPackCatalog {
    public static func preview(_ pack: StarterPack) -> StarterPackPreview {
        let items: [StarterPackItem]
        switch pack {
        case .morningFoundation:
            items = [item("morning-check-in", .habit, String(localized: "Morning check-in")), item("morning-routine", .routine, String(localized: "Morning routine"))]
        case .workdayReset:
            items = [item("reset-goal", .goal, String(localized: "Focused work time")), item("reset-routine", .routine, String(localized: "Workday reset"))]
        case .lowEnergyRecovery:
            items = [item("recovery-check-in", .habit, String(localized: "Energy check-in")), item("recovery-routine", .routine, String(localized: "Low energy routine"))]
        case .medicationSupport:
            items = [item("medication-reminder", .reminder, String(localized: "Medication reminder")), item("medication-routine", .routine, String(localized: "Medication routine"))]
        case .eveningWindDown:
            items = [item("evening-habit", .habit, String(localized: "Evening reflection")), item("evening-routine", .routine, String(localized: "Evening wind-down"))]
        }
        return StarterPackPreview(pack: pack, items: items)
    }

    private static func item(_ id: String, _ kind: StarterPackItemKind, _ title: String) -> StarterPackItem {
        StarterPackItem(id: id, kind: kind, title: title, isSelected: true)
    }
}
