public enum SettingsDetailRoute: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case setupCenter
    case planAndOrganize
    case calendarAndHealth
    case eva
    case reminders
    case lookAndFeel
    case dataAndHelp
    case lifeManagement
    case llm
    case chats
    case models
    case recovery
    case notices
    public var id: String { rawValue }
    public static let categories: [SettingsDetailRoute] = [
        .setupCenter,
        .planAndOrganize,
        .calendarAndHealth,
        .eva,
        .reminders,
        .lookAndFeel,
        .dataAndHelp,
    ]
    public var isCategory: Bool { Self.categories.contains(self) }
    public var title: String {
        switch self {
        case .setupCenter: return String(localized: "Connections")
        case .planAndOrganize: return String(localized: "Plan & organize")
        case .calendarAndHealth: return String(localized: "Calendar & Health")
        case .eva: return String(localized: "Eva")
        case .reminders: return String(localized: "Notifications")
        case .lookAndFeel: return String(localized: "Look & feel")
        case .dataAndHelp: return String(localized: "Data & help")
        case .lifeManagement: return String(localized: "Life management")
        case .llm: return String(localized: "Eva")
        case .chats: return String(localized: "Chat behavior")
        case .models: return String(localized: "Models")
        case .recovery: return String(localized: "Recovery")
        case .notices: return String(localized: "Acknowledgements")
        }
    }
    public var transitionID: String { "route.settings.\(rawValue)" }
}
