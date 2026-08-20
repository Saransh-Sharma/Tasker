@preconcurrency import DeclaredAgeRange
import Foundation
import UIKit

struct EvaAdultEligibilityRequestV1: Codable, Sendable {
    let declaration: String
    let lowerBound: Int?
    let policyVersion: String

    private enum CodingKeys: String, CodingKey {
        case declaration, lowerBound, policyVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(declaration, forKey: .declaration)
        try container.encode(lowerBound, forKey: .lowerBound)
        try container.encode(policyVersion, forKey: .policyVersion)
    }
}

@MainActor
struct EvaAgeEligibilityService {
    private static let lastEligibleAtKey = "eva.cloud.age.last-eligible-at.v1"
    private static let validityInterval: TimeInterval = 24 * 60 * 60

    struct Result: Sendable {
        let eligibleAdult: Bool
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

    func requestAndRegister(using client: EvaCloudTransport = .shared) async throws -> Result {
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?.topmostPresentedViewController else {
            throw EvaProviderError.unavailable(String(localized: "The age-range sheet cannot be presented right now."))
        }
        let response: AgeRangeService.Response
        do {
            response = try await AgeRangeService.shared.requestAgeRange(ageGates: 18, in: presenter)
        } catch AgeRangeService.Error.notAvailable {
            try await registerResult(lowerBound: nil, declaration: "unavailable", using: client)
            UserDefaults.standard.removeObject(forKey: Self.lastEligibleAtKey)
            return Result(eligibleAdult: false, lowerBound: nil, declaration: "unavailable")
        }
        switch response {
        case .declinedSharing:
            try await registerResult(lowerBound: nil, declaration: "declined", using: client)
            UserDefaults.standard.removeObject(forKey: Self.lastEligibleAtKey)
            return Result(eligibleAdult: false, lowerBound: nil, declaration: "declined")
        case .sharing(let range):
            let source = range.ageRangeDeclaration.map { String(describing: $0) } ?? "unspecified"
            try await registerResult(lowerBound: range.lowerBound, declaration: "shared", using: client)
            if (range.lowerBound ?? 0) >= 18 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastEligibleAtKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastEligibleAtKey)
            }
            return Result(
                eligibleAdult: (range.lowerBound ?? 0) >= 18,
                lowerBound: range.lowerBound,
                declaration: source
            )
        @unknown default:
            throw EvaProviderError.unavailable(String(localized: "The system did not provide a supported age-range result."))
        }
    }

    func revalidateIfNeeded(using client: EvaCloudTransport = .shared) async throws {
        guard Self.cachedEligibilityIsValid == false else { return }
        let result = try await requestAndRegister(using: client)
        guard result.eligibleAdult else { throw EvaProviderError.adultEligibilityRequired }
    }

    private func registerResult(
        lowerBound: Int?,
        declaration: String,
        using client: EvaCloudTransport
    ) async throws {
        do {
            try await client.registerAdultEligibility(lowerBound: lowerBound, declaration: declaration)
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
