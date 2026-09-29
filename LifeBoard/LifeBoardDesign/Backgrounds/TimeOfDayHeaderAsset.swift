import Foundation
import Synchronization
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TimeOfDayHeaderAsset: Equatable {
    enum Period: String, CaseIterable {
        case morning = "M"
        case afternoon = "A"
        case evening = "E"
        case night = "N"

        var greeting: String {
            switch self {
            case .morning: return String(localized: "Good morning")
            case .afternoon: return String(localized: "Good afternoon")
            case .evening: return String(localized: "Good evening")
            case .night: return String(localized: "Tonight")
            }
        }

        var assistantTitle: String {
            switch self {
            case .morning: return String(localized: "This morning")
            case .afternoon: return String(localized: "This afternoon")
            case .evening: return String(localized: "This evening")
            case .night: return String(localized: "Tonight")
            }
        }

        var symbolName: String {
            switch self {
            case .morning: return "sun.max"
            case .afternoon: return "sun.max"
            case .evening: return "sunset"
            case .night: return "moon.stars"
            }
        }
    }

    let period: Period
    let name: String
    let selectionKey: String

    static let defaultActivationID = "default"
    private static let cachedBySelectionKey = Mutex<[String: TimeOfDayHeaderAsset]>([:])
    fileprivate static let luminanceCache = Mutex<[String: CGFloat]>([:])

    static func period(for date: Date, calendar: Calendar = .current) -> Period {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    static func assetNames(for period: Period) -> [String] {
        switch period {
        case .morning: ["CelestialDawnBackground", "CelestialMorningBackground"]
        case .afternoon: ["CelestialMiddayBackground"]
        case .evening: ["CelestialGoldenHourBackground", "CelestialTwilightBackground"]
        case .night: ["CelestialNightBackground"]
        }
    }

    static func resolve(
        for date: Date,
        activationID: String = defaultActivationID,
        calendar: Calendar = .current
    ) -> TimeOfDayHeaderAsset {
        let phase = CelestialPhase.resolve(at: date, calendar: calendar)
        let period = period(for: date, calendar: calendar)
        let key = "\(phase.rawValue)-\(activationID)"
        if let cached = cachedBySelectionKey.withLock({ $0[key] }) {
            return cached
        }

        let name = AtmosphereDescriptor.descriptor(for: phase).backgroundAsset
        let asset = TimeOfDayHeaderAsset(period: period, name: name, selectionKey: key)

        return cachedBySelectionKey.withLock { cache in
            if let cached = cache[key] {
                return cached
            }
            cache[key] = asset
            return asset
        }
    }

    static func makeActivationID() -> String {
        UUID().uuidString
    }

    static func selectionKey(for period: Period, activationID: String) -> String {
        "\(period.rawValue)-\(activationID)"
    }

    static func stableIndex(selectionKey: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let hash = selectionKey.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    static func resetCacheForTests() {
        cachedBySelectionKey.withLock {
            $0.removeAll()
        }
        luminanceCache.withLock {
            $0.removeAll()
        }
    }

    #if canImport(UIKit)
    static func image(named name: String, bundle: Bundle = .main) -> UIImage? {
        UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    static func averageLuminance(in image: UIImage, rect: CGRect) -> CGFloat {
        guard let cgImage = image.cgImage else { return 1 }
        let width = max(1, Int(CGFloat(cgImage.width) * rect.width))
        let height = max(1, Int(CGFloat(cgImage.height) * rect.height))
        let originX = max(0, Int(CGFloat(cgImage.width) * rect.minX))
        let originY = max(0, Int(CGFloat(cgImage.height) * rect.minY))
        let cropRect = CGRect(x: originX, y: originY, width: min(width, cgImage.width - originX), height: min(height, cgImage.height - originY))
        guard let cropped = cgImage.cropping(to: cropRect) else { return 1 }
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel
        var pixel = [UInt8](repeating: 0, count: bytesPerPixel)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 1
        }
        context.interpolationQuality = .medium
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let r = CGFloat(pixel[0]) / 255
        let g = CGFloat(pixel[1]) / 255
        let b = CGFloat(pixel[2]) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    #endif
}

struct HeaderTimeContext: Equatable {
    enum ForegroundStyle: Equatable {
        case navy
        case light

        // The header art is the same picture in both appearances, so its ink is
        // fixed too. `textInverse` flipped to dark cocoa in dark appearance and
        // put dark titles, controls and glass on the dark sky art.
        private static var scenicInk: Color { Color(SemanticColorTokens.foundationOnScenicDark) }

        var titleColor: Color {
            switch self {
            case .navy:
                return Color(lifeboardHex: "#071B52")
            case .light:
                return Self.scenicInk
            }
        }

        var controlColor: Color {
            switch self {
            case .navy:
                return Color(lifeboardHex: "#071B52")
            case .light:
                return Self.scenicInk
            }
        }

        var glassFill: Color {
            switch self {
            case .navy:
                return Self.scenicInk.opacity(0.58)
            case .light:
                return Self.scenicInk.opacity(0.20)
            }
        }

        var glassStroke: Color {
            switch self {
            case .navy:
                return Self.scenicInk.opacity(0.72)
            case .light:
                return Self.scenicInk.opacity(0.52)
            }
        }
    }

    let selectedDate: Date
    let now: Date
    let effectiveDate: Date
    let period: TimeOfDayHeaderAsset.Period
    let greeting: String
    let foregroundStyle: ForegroundStyle
    let asset: TimeOfDayHeaderAsset

    static func resolve(
        selectedDate: Date,
        now: Date = Date(),
        activationID: String = TimeOfDayHeaderAsset.defaultActivationID,
        calendar: Calendar = .current
    ) -> HeaderTimeContext {
        let effectiveDate = effectiveDate(selectedDate: selectedDate, now: now, calendar: calendar)
        // The selected date changes the content lens, not the ambient world.
        let asset = TimeOfDayHeaderAsset.resolve(for: now, activationID: activationID, calendar: calendar)
        let foregroundStyle = foregroundStyle(for: asset)
        return HeaderTimeContext(
            selectedDate: selectedDate,
            now: now,
            effectiveDate: effectiveDate,
            period: asset.period,
            greeting: asset.period.greeting,
            foregroundStyle: foregroundStyle,
            asset: asset
        )
    }

    static func navigatorTitle(
        selectedDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let currentDay = calendar.startOfDay(for: now)
        let dayDelta = calendar.dateComponents([.day], from: currentDay, to: selectedDay).day

        if dayDelta == 0 {
            return String(localized: "Today")
        }
        if dayDelta == 1 {
            return String(localized: "Tomorrow")
        }
        if dayDelta == -1 {
            return String(localized: "Yesterday")
        }
        let weekday = weekdayTitle(for: selectedDate, calendar: calendar)
        if calendar.component(.year, from: selectedDate) == calendar.component(.year, from: now) {
            return weekday
        }
        return "\(weekday) \(calendar.component(.year, from: selectedDate))"
    }

    static func effectiveDate(
        selectedDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        if calendar.isDate(selectedDate, inSameDayAs: now) {
            return now
        }
        let start = calendar.startOfDay(for: selectedDate)
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
    }

    static func assistantCopy(
        for period: TimeOfDayHeaderAsset.Period,
        gapStart: Date?,
        gapEnd: Date?,
        now: Date = Date()
    ) -> (title: String, subtitle: String) {
        let title = period.assistantTitle
        // No subtitle when there is no free time to report: the title stands
        // alone rather than filling the line with advice.
        guard let gapStart else {
            return (title, "")
        }
        let targetEnd = gapEnd ?? gapStart
        let interval = max(0, targetEnd.timeIntervalSince(max(now, gapStart)))
        let duration = conciseDuration(for: interval)
        if duration.isEmpty {
            return (title, "")
        }
        return (title, String(localized: "\(duration) free"))
    }

    /// "45 min", "1 hr, 30 min", or empty outside 15 min–4 hr.
    private static func conciseDuration(for interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        guard minutes >= 15, minutes <= 240 else { return "" }
        return LifeBoardDuration.text(minutes: minutes)
    }

    private static func foregroundStyle(for asset: TimeOfDayHeaderAsset) -> ForegroundStyle {
        #if canImport(UIKit)
        if let cached = TimeOfDayHeaderAsset.luminanceCache.withLock({ $0[asset.name] }) {
            return ImageReadabilityPolicy.foregroundStyle(forLuminance: cached) == .lightContent ? .light : .navy
        }
        if let image = TimeOfDayHeaderAsset.image(named: asset.name) {
            let luminance = TimeOfDayHeaderAsset.averageLuminance(
                in: image,
                rect: CGRect(x: 0.12, y: 0.34, width: 0.76, height: 0.34)
            )
            TimeOfDayHeaderAsset.luminanceCache.withLock {
                $0[asset.name] = luminance
            }
            return ImageReadabilityPolicy.foregroundStyle(forLuminance: luminance) == .lightContent ? .light : .navy
        }
        #endif
        return asset.period == .night ? .light : .navy
    }

    private static func weekdayTitle(for date: Date, calendar: Calendar) -> String {
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        guard calendar.weekdaySymbols.indices.contains(weekdayIndex) else {
            return ""
        }
        return calendar.weekdaySymbols[weekdayIndex]
    }
}
