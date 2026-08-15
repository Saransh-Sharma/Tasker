import Foundation

/// Context categories that may cross the device boundary for a remote Eva
/// request. These grants are intentionally narrower than in-app evidence
/// authorization and never authorize widgets, notifications, Spotlight, Watch,
/// or lock-screen previews.
public enum RemoteEvaContextCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case journal
    case health
    case lifeMoments
    case personalMemory
    case planningContext
}

/// One already-minimized context fragment prepared for a possible remote
/// request. The policy filters whole fragments; it never tries to redact an
/// opaque payload after authorization.
public struct RemoteEvaContextSection: Codable, Equatable, Sendable {
    public let category: RemoteEvaContextCategory
    public let payload: Data

    public init(category: RemoteEvaContextCategory, payload: Data) {
        self.category = category
        self.payload = payload
    }
}

/// Account-scoped, deny-by-default authorization for remote Eva context.
///
/// Remote transport is not currently composed by LifeBoard. This contract is
/// the mandatory gate for any future transport: the account must opt in and
/// every included category must have its own grant. System-surface disclosure
/// remains governed by `SystemSurfaceSnapshot` and is deliberately
/// outside this policy.
public struct RemoteEvaContextPolicy: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let accountID: String
    public private(set) var isRemoteEvaEnabled: Bool
    public private(set) var grantedCategories: Set<RemoteEvaContextCategory>

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        accountID: String,
        isRemoteEvaEnabled: Bool = false,
        grantedCategories: Set<RemoteEvaContextCategory> = []
    ) {
        self.schemaVersion = schemaVersion
        self.accountID = accountID
        self.isRemoteEvaEnabled = isRemoteEvaEnabled
        self.grantedCategories = grantedCategories
    }

    public func permitsRemoteRequest(forAccountID requestAccountID: String) -> Bool {
        let normalizedRequestAccountID = requestAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPolicyAccountID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        return schemaVersion == Self.currentSchemaVersion
            && isRemoteEvaEnabled
            && normalizedPolicyAccountID.isEmpty == false
            && normalizedRequestAccountID == normalizedPolicyAccountID
    }

    public func permits(
        _ category: RemoteEvaContextCategory,
        forAccountID requestAccountID: String
    ) -> Bool {
        permitsRemoteRequest(forAccountID: requestAccountID)
            && grantedCategories.contains(category)
    }

    public mutating func setRemoteEvaEnabled(_ enabled: Bool) {
        isRemoteEvaEnabled = enabled
    }

    public mutating func setGrant(_ granted: Bool, for category: RemoteEvaContextCategory) {
        if granted {
            grantedCategories.insert(category)
        } else {
            grantedCategories.remove(category)
        }
    }

    /// Returns only sections authorized at the instant the request is built.
    /// Duplicate categories are collapsed deterministically to the last
    /// prepared value, avoiding two differently redacted variants in one call.
    public func authorize(
        _ sections: [RemoteEvaContextSection],
        forAccountID requestAccountID: String
    ) -> [RemoteEvaContextSection] {
        guard permitsRemoteRequest(forAccountID: requestAccountID) else { return [] }
        var latestByCategory: [RemoteEvaContextCategory: RemoteEvaContextSection] = [:]
        for section in sections where permits(section.category, forAccountID: requestAccountID) {
            latestByCategory[section.category] = section
        }
        return RemoteEvaContextCategory.allCases.compactMap { latestByCategory[$0] }
    }
}

/// Serializes policy changes with request authorization. A revocation therefore
/// takes effect before the next `authorize` call and cannot race a stale cached
/// grant in a transport client.
public actor RemoteEvaContextAuthorizer {
    private var policy: RemoteEvaContextPolicy

    public init(policy: RemoteEvaContextPolicy) {
        self.policy = policy
    }

    public func currentPolicy() -> RemoteEvaContextPolicy {
        policy
    }

    public func replacePolicy(_ policy: RemoteEvaContextPolicy) {
        self.policy = policy
    }

    public func setRemoteEvaEnabled(_ enabled: Bool) {
        policy.setRemoteEvaEnabled(enabled)
    }

    public func setGrant(_ granted: Bool, for category: RemoteEvaContextCategory) {
        policy.setGrant(granted, for: category)
    }

    public func authorize(
        _ sections: [RemoteEvaContextSection],
        forAccountID requestAccountID: String
    ) -> [RemoteEvaContextSection] {
        policy.authorize(sections, forAccountID: requestAccountID)
    }
}
