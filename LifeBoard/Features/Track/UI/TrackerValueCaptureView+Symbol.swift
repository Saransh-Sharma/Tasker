extension TrackerValueCaptureView {
    var trackerSymbol: String {
        switch tracker.effectiveValueType {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.bubble"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }
}
