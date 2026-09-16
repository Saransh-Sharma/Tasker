import Foundation

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
