import Foundation
import SwiftData

@MainActor
enum EvaMemoryProposalService {
    private struct ResultEnvelope: Decodable {
        struct Candidate: Decodable {
            let section: EvaMemoryStatement.Section
            let text: String
        }
        let candidate: Candidate?
    }

    /// Runs only after a successful Cloud turn. The route is non-billable and
    /// receives the latest user-authored turn plus a bounded list of confirmed
    /// memories used solely to avoid proposing a duplicate.
    static func propose(from userTurn: String) async -> EvaMemoryCandidate? {
        let trimmedTurn = userTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTurn.isEmpty == false else { return nil }

        let account = EvaCloudAccountState.shared
        guard let configuration = account.configuration,
              let policy = configuration.routes[.memoryCandidate],
              policy.enabled,
              policy.billable == false,
              let consent = account.consent else { return nil }

        let existing = EvaMemoryDefaultsStoreV3.load().statements.prefix(EvaMemoryStoreV3.maxStatements)
        let memoryPayload = EvaJSONValue.array(existing.map {
            .object([
                "id": .string($0.id.uuidString.lowercased()),
                "section": .string($0.section.rawValue),
                "text": .string($0.text),
            ])
        })
        let contractVersion = EvaInferenceRequest.negotiatedContractVersion(
            advertised: configuration.contractVersions
        )
        let context: [EvaCloudContextSection] = existing.isEmpty ? [] : [
            EvaCloudContextSection(
                category: .personalMemory,
                payload: memoryPayload,
                metadata: contractVersion >= 3 ? .init(
                    availability: "complete",
                    availableCount: existing.count,
                    includedCount: existing.count,
                    partialReasons: [],
                    sourceIDs: existing.map { $0.id.uuidString.lowercased() }
                ) : nil
            )
        ]
        let request = EvaInferenceRequest(
            requestId: UUID(),
            route: .memoryCandidate,
            contractVersion: contractVersion,
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            turnContext: contractVersion >= 4 ? .current(surface: .background) : nil,
            messages: [.init(role: .user, content: String(trimmedTurn.prefix(4_000)))],
            context: context.map { $0.forContract(contractVersion) },
            userInstructions: nil,
            clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            platform: EvaInstallationIdentity.platform,
            installationId: EvaInstallationIdentity.current,
            consentRevision: consent.revision,
            providerCapabilities: .init(streaming: true, structuredOutput: true, spokenOutput: false)
        )

        do {
            let output = try await EvaCloudProvider().generate(request: request) { _ in }
            guard account.configuration?.version == configuration.version,
                  account.consent?.revision == consent.revision,
                  let data = output.data(using: .utf8),
                  let candidate = try JSONDecoder.evaCloud.decode(ResultEnvelope.self, from: data).candidate else {
                return nil
            }
            let proposal = EvaMemoryCandidate(section: candidate.section, text: candidate.text)
            let inbox = EvaMemoryCandidateDefaultsStore.load()
            guard inbox.suppressedKeys.contains(proposal.suppressionKey) == false,
                  inbox.pending.contains(where: { $0.suppressionKey == proposal.suppressionKey }) == false else {
                return nil
            }
            return proposal
        } catch {
            // Suggestions are an optional trust affordance. Failure must never
            // alter or delay the completed answer.
            return nil
        }
    }

    static func attach(
        proposedFrom userTurn: String,
        to message: Message,
        in modelContext: ModelContext
    ) async -> Bool {
        guard let candidate = await propose(from: userTurn),
              let data = try? JSONEncoder.evaCloud.encode(candidate) else { return false }
        var inbox = EvaMemoryCandidateDefaultsStore.load()
        inbox.propose(candidate)
        guard inbox.pending.contains(where: { $0.id == candidate.id }) else { return false }
        EvaMemoryCandidateDefaultsStore.save(inbox)
        message.memoryCandidateData = data
        do {
            try modelContext.save()
            await ProductTelemetry.shared.record(.memoryProposalShown)
            return true
        } catch {
            inbox.pending.removeAll { $0.id == candidate.id }
            EvaMemoryCandidateDefaultsStore.save(inbox)
            return false
        }
    }
}
