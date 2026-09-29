import Foundation

extension BehaviorNativeAreasView {
    func trackerSymbol(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.cursor"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }

    func trackerDefinitionSummary(_ tracker: TrackerDefinitionValue) -> String {
        var parts = [tracker.effectiveValueType.trackDisplayName]
        parts.append(tracker.effectiveAggregation.displayName)
        parts.append(tracker.effectivePrivacyClass.displayName)
        if tracker.permitsHomeProjection { parts.append(String(localized: "Shown on Home")) }
        return parts.joined(separator: " · ")
    }

    func medicationDefinitionSummary(_ medication: MedicationDefinitionValue) -> String {
        var parts: [String] = []
        if let form = medication.formRaw, form.isEmpty == false { parts.append(form.capitalized) }
        if let end = medication.endDate {
            parts.append(String(localized: "Until \(end.formatted(date: .abbreviated, time: .omitted))"))
        } else if medication.startDate != nil {
            parts.append(String(localized: "No end date"))
        }
        if let remaining = medication.refillRemaining {
            parts.append(String(localized: "\(remaining.formatted()) left"))
        }
        return parts.isEmpty ? String(localized: "Active") : parts.joined(separator: " · ")
    }
}
