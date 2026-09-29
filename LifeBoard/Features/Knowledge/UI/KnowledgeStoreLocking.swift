import LifeBoardContracts
import LifeBoardDomain
import LifeBoardPersistence
import Foundation

extension KnowledgeStore {
    func lock(_ note: KnowledgeNoteValue) async {
        guard let secureNotes else {
            errorMessage = String(localized: "Locked notes aren’t available.")
            return
        }
        do {
            let attachments = try await repository.fetchKnowledgeAttachments(noteID: note.id)
            let encryptedLinks = links.filter {
                $0.sourceNoteID == note.id || $0.destinationNoteID == note.id
            }
            let envelope = try await secureNotes.lock(
                note: note,
                attachments: attachments,
                links: encryptedLinks,
                reason: "Lock “\(note.displayTitle)”"
            )
            var redacted = note
            redacted.title = ""
            redacted.blocks = []
            redacted.tagIDs = []
            redacted.lockPolicy = .deviceAuthentication
            redacted.updatedAt = Date()
            let payload = KnowledgeSecurePayloadValue(
                noteID: note.id,
                ciphertext: envelope.ciphertext,
                contentVersion: envelope.contentVersion,
                algorithmVersion: envelope.algorithmVersion,
                keyIdentifier: envelope.keyIdentifier
            )
            let secureAttachments = attachments.compactMap { attachment -> KnowledgeSecureAttachmentPayloadValue? in
                guard let ciphertext = envelope.attachmentCiphertexts[attachment.id] else { return nil }
                return .init(
                    noteID: note.id,
                    attachmentID: attachment.id,
                    ciphertext: ciphertext,
                    checksum: attachment.checksum,
                    byteCount: attachment.byteCount ?? Int64(attachment.payload.count)
                )
            }
            try await repository.lockKnowledgeNote(
                redacted: redacted,
                payload: payload,
                attachments: secureAttachments
            )
            try? await searchIndex?.remove(noteID: note.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlock(_ note: KnowledgeNoteValue) async throws -> KnowledgeUnlockedNoteSession {
        guard let secureNotes,
              let (payload, attachments) = try await repository.fetchKnowledgeSecurePayload(noteID: note.id) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let envelope = KnowledgeSecureEnvelope(
            noteID: note.id,
            keyIdentifier: payload.keyIdentifier,
            algorithmVersion: payload.algorithmVersion,
            contentVersion: payload.contentVersion,
            ciphertext: payload.ciphertext,
            attachmentCiphertexts: Dictionary(uniqueKeysWithValues: attachments.map { ($0.attachmentID, $0.ciphertext) })
        )
        let unlocked = try await secureNotes.unlock(envelope, reason: "Unlock this note")
        return .init(
            note: unlocked.0,
            attachments: unlocked.1,
            links: unlocked.2,
            keyIdentifier: payload.keyIdentifier
        )
    }

    func saveLocked(_ session: KnowledgeUnlockedNoteSession) async throws {
        guard let secureNotes else { throw CocoaError(.featureUnsupported) }
        var note = session.note
        note.lockPolicy = .deviceAuthentication
        note.updatedAt = Date()
        note.contentVersion = max(1, note.contentVersion ?? 1) + 1
        let envelope = try await secureNotes.reseal(
            note: note,
            attachments: session.attachments,
            links: session.links,
            keyIdentifier: session.keyIdentifier
        )
        var redacted = note
        redacted.title = ""
        redacted.blocks = []
        redacted.tagIDs = []
        let payload = KnowledgeSecurePayloadValue(
            noteID: note.id,
            ciphertext: envelope.ciphertext,
            contentVersion: envelope.contentVersion,
            algorithmVersion: envelope.algorithmVersion,
            keyIdentifier: envelope.keyIdentifier
        )
        let secureAttachments = session.attachments.compactMap { attachment -> KnowledgeSecureAttachmentPayloadValue? in
            guard let ciphertext = envelope.attachmentCiphertexts[attachment.id] else { return nil }
            return .init(
                noteID: note.id,
                attachmentID: attachment.id,
                ciphertext: ciphertext,
                checksum: attachment.checksum,
                byteCount: attachment.byteCount ?? Int64(attachment.payload.count)
            )
        }
        try await repository.lockKnowledgeNote(redacted: redacted, payload: payload, attachments: secureAttachments)
    }
}
