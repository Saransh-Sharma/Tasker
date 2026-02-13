//
//  HomeQuickView.swift
//  Tasker
//
//  Canonical quick filter views for Home "Focus Engine"
//

import Foundation

public enum HomeQuickView: String, CaseIterable, Codable {
    case today
    case upcoming
    case done
    case morning
    case evening

    public static let defaultView: HomeQuickView = .today

    public var title: String {
        switch self {
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .done: return "Done"
        case .morning: return "Morning"
        case .evening: return "Evening"
        }
    }

    public var analyticsAction: String {
        switch self {
        case .today: return "today"
        case .upcoming: return "upcoming"
        case .done: return "done"
        case .morning: return "morning"
        case .evening: return "evening"
        }
    }
}

public enum HomeListScope: Equatable, Codable {
    case today
    case customDate(Date)
    case upcoming
    case done
    case morning
    case evening

    public var quickView: HomeQuickView {
        switch self {
        case .today, .customDate:
            return .today
        case .upcoming:
            return .upcoming
        case .done:
            return .done
        case .morning:
            return .morning
        case .evening:
            return .evening
        }
    }

    public var referenceDate: Date {
        switch self {
        case .today:
            return Date()
        case .customDate(let date):
            return date
        case .upcoming, .done, .morning, .evening:
            return Date()
        }
    }

    public static func fromQuickView(_ quickView: HomeQuickView) -> HomeListScope {
        switch quickView {
        case .today:
            return .today
        case .upcoming:
            return .upcoming
        case .done:
            return .done
        case .morning:
            return .morning
        case .evening:
            return .evening
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case date
    }

    private enum Kind: String, Codable {
        case today
        case customDate
        case upcoming
        case done
        case morning
        case evening
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .today:
            self = .today
        case .customDate:
            let date = try container.decode(Date.self, forKey: .date)
            self = .customDate(date)
        case .upcoming:
            self = .upcoming
        case .done:
            self = .done
        case .morning:
            self = .morning
        case .evening:
            self = .evening
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .today:
            try container.encode(Kind.today, forKey: .kind)
        case .customDate(let date):
            try container.encode(Kind.customDate, forKey: .kind)
            try container.encode(date, forKey: .date)
        case .upcoming:
            try container.encode(Kind.upcoming, forKey: .kind)
        case .done:
            try container.encode(Kind.done, forKey: .kind)
        case .morning:
            try container.encode(Kind.morning, forKey: .kind)
        case .evening:
            try container.encode(Kind.evening, forKey: .kind)
        }
    }
}
