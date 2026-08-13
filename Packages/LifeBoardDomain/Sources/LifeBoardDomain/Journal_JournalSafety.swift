//
//  JournalSafety.swift
//  JournalFoundation
//
//  Shared safety vocabulary for sensitive journal content. Matches
//  OffRecord's weekly-reflection safety ladder so extracted engines keep
//  identical behavior, and gives both apps one review gate for risk-safe,
//  non-clinical language.
//

import Foundation

public enum JournalSafetyLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case none
    case mildDistress
    case moderateConcern
    /// Content at this level is excluded from generated output entirely;
    /// surfaces respond with supportive, non-clinical copy instead.
    case highRiskExcluded

    private var rank: Int {
        switch self {
        case .none: return 0
        case .mildDistress: return 1
        case .moderateConcern: return 2
        case .highRiskExcluded: return 3
        }
    }

    public static func < (lhs: JournalSafetyLevel, rhs: JournalSafetyLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// How an AI surface should respond given detected content safety.
public enum SensitiveResponseMode: String, Sendable, Codable {
    /// Answer normally.
    case normal
    /// Answer, but soften tone and avoid probing follow-ups.
    case gentle
    /// Do not analyze or quote; reply only with the persona's
    /// `riskSafeSupport` copy. Never give advice, never cite evidence.
    case supportOnly
}

/// The single review gate for sensitive-domain behavior across both apps:
/// maps safety levels to response modes and audits copy for clinical
/// language that the products must not use.
public struct SensitiveDomainPolicy: Sendable {
    public var modeForLevel: @Sendable (JournalSafetyLevel) -> SensitiveResponseMode

    public init(modeForLevel: @escaping @Sendable (JournalSafetyLevel) -> SensitiveResponseMode) {
        self.modeForLevel = modeForLevel
    }

    public static let standard = SensitiveDomainPolicy { level in
        switch level {
        case .none: return .normal
        case .mildDistress: return .gentle
        case .moderateConcern: return .gentle
        case .highRiskExcluded: return .supportOnly
        }
    }

    public func responseMode(for level: JournalSafetyLevel) -> SensitiveResponseMode {
        modeForLevel(level)
    }

    /// Clinical / diagnostic terms that product copy must not present as
    /// assessments of the user. Used by copy-audit tests in both apps.
    public static let clinicalTermsDenylist: [String] = [
        "diagnosis", "diagnose", "disorder", "clinical", "symptom",
        "patient", "treatment plan", "prescribe", "pathological",
        "mental illness", "prognosis",
    ]

    /// Returns denylisted terms found in the given copy (case-insensitive).
    public static func clinicalTermViolations(in copy: String) -> [String] {
        let lowered = copy.lowercased()
        return clinicalTermsDenylist.filter { lowered.contains($0) }
    }
}
