import Foundation

/// The person's editable instruction from Settings.
///
/// It reached nothing before contract v2: the composed system prompt was dropped
/// at the wire, so this field is what makes that setting take effect at all.
struct EvaUserInstructions: Codable, Sendable, Equatable {
    /// Matches the server cap. Trimming here keeps a long prompt from failing
    /// the whole request at admission.
    static let maxPersonaCharacters = 2_000

    let persona: String
    let tone: String?

    /// Returns instructions only when the stored prompt is genuinely the
    /// person's own.
    ///
    /// Shipping a built-in default back to the server would be worse than
    /// sending nothing: `prompts.ts` already states EVA's persona, and echoing a
    /// second, differently-worded copy of it as a "user preference" invites the
    /// model to reconcile two voices instead of following one.
    static func customized(
        storedPrompt: String?,
        builtInPrompts: Set<String>
    ) -> EvaUserInstructions? {
        guard let storedPrompt else { return nil }
        guard builtInPrompts.contains(storedPrompt) == false else { return nil }
        return EvaUserInstructions(persona: storedPrompt)
    }

    init?(persona: String?, tone: String? = nil) {
        let trimmedPersona = (persona ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTone = tone?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPersona.isEmpty == false || (trimmedTone?.isEmpty == false) else { return nil }
        self.persona = String(trimmedPersona.prefix(Self.maxPersonaCharacters))
        self.tone = (trimmedTone?.isEmpty == false) ? trimmedTone : nil
    }
}

enum EvaJSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: EvaJSONValue])
    case array([EvaJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: EvaJSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([EvaJSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
