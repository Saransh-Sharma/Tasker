import Foundation
import LifeBoardContracts

/// Posted when the person records the day's first kind of commitment: a
/// habit completed (or a clean day kept), or a capture committed from the
/// composer. `FirstLightGate` decides whether this one is the *first* today.
extension Notification.Name {
    static let lifeboardDailyCommitment = Notification.Name("LifeBoardDailyCommitment")
    /// The gate was claimed: the surface that recorded the commitment runs
    /// its `firstLight` sweep. Posted at most once per calendar day.
    static let lifeboardFirstLightFired = Notification.Name("LifeBoardFirstLightFired")
}

/// Who recorded a daily commitment. The shell forwards this on
/// `.lifeboardFirstLightFired`, so only the surface that crossed the boundary
/// runs the sweep: a composer capture used to light every habit tile on Home.
enum FirstLightCommitment {
    static let sourceKey = "source"
    /// A per-commit token, for a surface that needs to know the claim was its own.
    static let tokenKey = "token"

    enum Source: String {
        case habit, task, composer
    }

    static func source(of notification: Notification) -> Source? {
        (notification.userInfo?[sourceKey] as? String).flatMap(Source.init(rawValue:))
    }

    static func token(of notification: Notification) -> String? {
        notification.userInfo?[tokenKey] as? String
    }
}

/// `firstLight` is reserved for the first commitment of the day, whichever
/// boundary it crosses. The old gate was `TransitionCoordinator.claimOneShot`,
/// in memory per window, so every relaunch re-armed it and the fifth thing you
/// recorded could still be lit. This one persists the day it last fired in the
/// app-group defaults and hands out exactly one claim per calendar day.
struct FirstLightGate: @unchecked Sendable {
    static let storageKey = "lifeboard.firstLight.lastDay"
    static let resetArgument = "-LIFEBOARD_TEST_RESET_FIRST_LIGHT"

    let defaults: UserDefaults
    let calendar: Calendar

    init(defaults: UserDefaults, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    static let shared: FirstLightGate = {
        let gate = FirstLightGate(defaults: UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard)
        // The gate survives relaunches by design, which also means a UI test
        // on the same day as the last one would never see it fire.
        if ProcessInfo.processInfo.arguments.contains(resetArgument) {
            gate.defaults.removeObject(forKey: storageKey)
        }
        return gate
    }()

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    /// `true` exactly once per calendar day; the claim is recorded before it
    /// is returned, so two boundaries racing on the same day cannot both win.
    @discardableResult
    func claim(now: Date = Date()) -> Bool {
        let key = Self.dayKey(for: now, calendar: calendar)
        guard defaults.string(forKey: Self.storageKey) != key else { return false }
        defaults.set(key, forKey: Self.storageKey)
        return true
    }

    /// Whether a claim would succeed, without taking it.
    func isAvailable(now: Date = Date()) -> Bool {
        defaults.string(forKey: Self.storageKey) != Self.dayKey(for: now, calendar: calendar)
    }
}
