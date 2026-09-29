import Foundation

/// Every word the first run says, in one place.
///
/// The rules this file is held to — and that `LifeWeaveOnboardingTests` enforce:
///
/// - One screen, one question. The title *is* the question.
/// - Titles are six words or fewer, options four, buttons three.
/// - The user's words, not the system's: never "map", "weave", "route",
///   "power up", "context", or "clearest path".
/// - Defaults over questions. Anything with a good default is editable in one
///   tap and never asked.
/// - Privacy is one plain sentence with detail one tap away, never repeated on
///   the same screen.
///
/// Strings go through `String(localized:)` so they reach the string catalog.
/// Most onboarding copy used to be passed around as plain `String` values and
/// never did.
enum LifeWeaveCopy {

    enum Dock {
        static let `continue` = String(localized: "Continue")
        static let pickOne = String(localized: "Pick one")
        static let save = String(localized: "Save")
        static let skip = String(localized: "Skip")
        static let startMyDay = String(localized: "Start my day")
        static let notNow = String(localized: "Not now")
        static let setUpLater = String(localized: "Set up later")
        static let done = String(localized: "Done")
        static let close = String(localized: "Close")

        /// The disabled label says what is missing, so the rule never has to be
        /// spelled out in the support line.
        static func pickMore(_ remaining: Int) -> String {
            String(localized: "Pick \(remaining) more")
        }
    }

    enum Welcome {
        /// "Good morning" and friends come from the daypart, so the first thing
        /// the app says matches the sky behind it.
        static func greeting(_ daypartGreeting: String) -> String {
            String(localized: "\(daypartGreeting). Welcome to LifeBoard.")
        }
        static let title = String(localized: "What do you want help with?")
        static let privacy = String(localized: "Private by default. Nothing connects without you.")
    }

    enum Intent {
        static func title(_ intent: LifeWeaveIntent) -> String {
            switch intent {
            case .clarityToday: String(localized: "Knowing what's next")
            case .reduceMentalLoad: String(localized: "Clearing my head")
            case .resilientPlanning: String(localized: "Plans that hold up")
            case .steadyRoutines: String(localized: "Sticking to routines")
            case .wholeLifeView: String(localized: "Seeing the big picture")
            case .somethingElse: String(localized: "Looking around")
            }
        }
    }

    enum Areas {
        static let title = String(localized: "What's on your plate?")
        static let support = String(localized: "You can change this later.")
        static let atLimitHint = String(localized: "Deselect one to choose another")

        static func badgeLabel(_ position: Int) -> String {
            String(localized: "Pick \(position)")
        }
    }

    enum Capture {
        static let title = String(localized: "What's on your mind?")
        static let support = String(localized: "Add one thing to do or remember.")
        static let saveAs = String(localized: "Save as")
        static let reading = String(localized: "Reading…")
        static let task = String(localized: "Task")
        static let journal = String(localized: "Journal")

        static func kindTitle(_ kind: LifeMapCaptureKind) -> String {
            kind == .journal ? journal : task
        }

        /// Personalised by the area the user picked first, so the example reads
        /// like their life rather than a demo.
        static func placeholder(primaryAreaTemplateID: String?) -> String {
            switch primaryAreaTemplateID {
            case "health-self": String(localized: "Walk before my first coffee")
            case "relationships": String(localized: "Call Mum on Sunday")
            case "learning-growth": String(localized: "Read chapter 4 this weekend")
            case "creativity-fun": String(localized: "Sketch something on Saturday")
            case "money": String(localized: "Check the insurance renewal")
            case "life-admin": String(localized: "Renew passport photos")
            default: String(localized: "Send the launch handoff Friday")
            }
        }
    }

    enum Ready {
        static let title = String(localized: "You're all set")
        static let emptyCapture = String(localized: "Add your first thing anytime.")
        static let edit = String(localized: "Edit")
        static let connectHeader = String(localized: "Connections")
        static let evaNotice = String(localized: "Eva uses OpenAI once you turn it on.")
        static let evaNoticeLink = String(localized: "What Eva can see")

        static func areas(primary: String, others: Int) -> String {
            switch others {
            case 0: String(localized: "\(primary) first")
            default: String(localized: "\(primary) first, plus \(others) more")
            }
        }

        static func hours(start: String, end: String) -> String {
            String(localized: "Weekdays \(start)–\(end)")
        }
    }

    enum Hours {
        static let title = String(localized: "What are your usual hours?")
        static let support = String(localized: "LifeBoard plans inside these.")
        static let editHours = String(localized: "Set exact hours")
        static let hideHours = String(localized: "Hide exact hours")
        static let start = String(localized: "Weekdays start")
        static let end = String(localized: "Weekdays end")
        static let weekends = String(localized: "I work weekends too")
        static let change = String(localized: "Change")

        static func weekStarts(_ day: String) -> String {
            String(localized: "Week starts \(day)")
        }

        static func presetTitle(_ preset: LifeWeaveDayShapePreset) -> String {
            switch preset {
            case .typical: String(localized: "Regular hours")
            case .early: String(localized: "Early starts")
            case .later: String(localized: "Late starts")
            case .flexible: String(localized: "It varies")
            case .custom: String(localized: "My own hours")
            }
        }
    }

    enum Connection {
        static func name(_ connector: LifeWeavePowerUpStep) -> String {
            switch connector {
            case .calendar: String(localized: "Calendar")
            case .health: String(localized: "Apple Health")
            case .eva: String(localized: "Eva")
            }
        }

        static func value(_ connector: LifeWeavePowerUpStep) -> String {
            switch connector {
            case .calendar: String(localized: "See your events")
            case .health: String(localized: "See sleep and activity")
            case .eva: String(localized: "Plan with an assistant")
            }
        }

        static let reminders = String(localized: "Reminders")
        static let remindersValue = String(localized: "When a task is due")
        static let remindersOn = String(localized: "On")
        static let remindersOff = String(localized: "Off. Turn on in Settings")

        static let connected = String(localized: "Connected")
        static let connecting = String(localized: "Connecting…")
        static let needsAttention = String(localized: "Tap to finish")
        @MainActor static var offlineReady: String { String(localized: "Runs on \(DeviceNoun.this)") }

        static func calendars(_ count: Int) -> String {
            count == 1 ? String(localized: "1 calendar") : String(localized: "\(count) calendars")
        }
    }

    enum EvaData {
        static let title = String(localized: "How Eva uses your data")
        static let bullets: [String] = [
            String(localized: "Eva stays off until you turn it on."),
            String(localized: "It uses your tasks, plans, and life areas."),
            String(localized: "Journal, Health, life moments, and memory start on."),
            String(localized: "Turn any of them off before you connect."),
            String(localized: "Requests pass through LifeBoard to OpenAI.")
        ]
        static let manage = String(localized: "Change this anytime in Settings › Eva.")
    }

    enum Failure {
        static let title = String(localized: "Couldn't save your setup")
        static let body = String(localized: "Your choices are still here.")
        static let retry = String(localized: "Try again")
    }

    /// VoiceOver names for the four positions. Human words, never case names.
    enum Progress {
        static func stepName(_ step: LifeWeaveStep) -> String {
            switch step {
            case .arrival, .intent: String(localized: "Welcome")
            case .lifeAreas, .dayShape: String(localized: "Life areas")
            case .firstCapture: String(localized: "First thing")
            case .reveal: String(localized: "Ready")
            }
        }

        static func spoken(index: Int, total: Int, name: String) -> String {
            String(localized: "Setup, step \(index) of \(total), \(name)")
        }
    }
}
