@preconcurrency import DeclaredAgeRange
import Foundation
import UIKit

struct EvaAdultEligibilityRequestV1: Codable, Sendable {
    let declaration: String
    let lowerBound: Int?
    let policyVersion: String
    let policyRequired: Bool

    private enum CodingKeys: String, CodingKey {
        case declaration, lowerBound, policyVersion, policyRequired
    }

    init(declaration: String, lowerBound: Int?, policyVersion: String, policyRequired: Bool) {
        self.declaration = declaration
        self.lowerBound = lowerBound
        self.policyVersion = policyVersion
        self.policyRequired = policyRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        declaration = try container.decode(String.self, forKey: .declaration)
        lowerBound = try container.decodeIfPresent(Int.self, forKey: .lowerBound)
        policyVersion = try container.decode(String.self, forKey: .policyVersion)
        // Version-one fixtures and older clients predate this policy hint. A
        // missing value means the ordinary, non-forced eligibility check.
        policyRequired = try container.decodeIfPresent(Bool.self, forKey: .policyRequired) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(declaration, forKey: .declaration)
        try container.encode(lowerBound, forKey: .lowerBound)
        try container.encode(policyVersion, forKey: .policyVersion)
        // Keep the original v1 wire representation stable unless the server
        // must distinguish a policy-enforced revalidation.
        if policyRequired {
            try container.encode(true, forKey: .policyRequired)
        }
    }
}

@MainActor
struct EvaAgeEligibilityService {
    private static let lastEligibleAtKey = "eva.cloud.age.last-eligible-at.v1"
    private static let validityInterval: TimeInterval = 24 * 60 * 60

    struct Result: Sendable {
        let eligible: Bool
        let lowerBound: Int?
        let declaration: String
    }

    /// Mirrors the server's 24-hour age lease. When this holds, re-presenting the
    /// system sheet would ask the user to confirm something both sides already
    /// agree on.
    static var cachedEligibilityIsValid: Bool {
        let last = UserDefaults.standard.double(forKey: lastEligibleAtKey)
        return last > 0 && Date().timeIntervalSince1970 - last < validityInterval
    }

    static func invalidateCachedEligibility() {
        UserDefaults.standard.removeObject(forKey: lastEligibleAtKey)
    }

    func requestAndRegister(
        using client: EvaCloudTransport = .shared,
        policyRequired: Bool = false
    ) async throws -> Result {
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?.topmostPresentedViewController else {
            throw EvaProviderError.unavailable(String(localized: "The age-range sheet cannot be presented right now."))
        }
        let response: AgeRangeService.Response
        do {
            response = try await AgeRangeService.shared.requestAgeRange(ageGates: 13, in: presenter)
        } catch AgeRangeService.Error.notAvailable {
            try await registerResult(lowerBound: nil, declaration: "unavailable", policyRequired: policyRequired, using: client)
            UserDefaults.standard.removeObject(forKey: Self.lastEligibleAtKey)
            return Result(eligible: false, lowerBound: nil, declaration: "unavailable")
        }
        switch response {
        case .declinedSharing:
            try await registerResult(lowerBound: nil, declaration: "declined", policyRequired: policyRequired, using: client)
            UserDefaults.standard.removeObject(forKey: Self.lastEligibleAtKey)
            return Result(eligible: false, lowerBound: nil, declaration: "declined")
        case .sharing(let range):
            let source = range.ageRangeDeclaration.map { String(describing: $0) } ?? "unspecified"
            try await registerResult(lowerBound: range.lowerBound, declaration: "shared", policyRequired: policyRequired, using: client)
            if (range.lowerBound ?? 0) >= 13 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastEligibleAtKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastEligibleAtKey)
            }
            return Result(
                eligible: (range.lowerBound ?? 0) >= 13,
                lowerBound: range.lowerBound,
                declaration: source
            )
        @unknown default:
            throw EvaProviderError.unavailable(String(localized: "The system did not provide a supported age-range result."))
        }
    }

    func revalidateIfNeeded(using client: EvaCloudTransport = .shared) async throws {
        guard Self.cachedEligibilityIsValid == false else { return }
        let result = try await requestAndRegister(using: client, policyRequired: true)
        guard result.eligible else { throw EvaProviderError.adultEligibilityRequired }
    }

    private func registerResult(
        lowerBound: Int?,
        declaration: String,
        policyRequired: Bool,
        using client: EvaCloudTransport
    ) async throws {
        do {
            try await client.registerAgeEligibility(
                lowerBound: lowerBound,
                declaration: declaration,
                policyRequired: policyRequired
            )
        } catch let error as EvaErrorEnvelope where error.code == "adult_eligibility_required" {
            // The server records the negative result before returning the fail-closed error.
        }
    }
}

private extension UIViewController {
    var topmostPresentedViewController: UIViewController {
        presentedViewController?.topmostPresentedViewController ?? self
    }
}
