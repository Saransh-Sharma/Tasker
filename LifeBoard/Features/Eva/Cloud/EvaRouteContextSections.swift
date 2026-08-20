import Foundation

/// Decides where a route's own projection travels: inside the prompt, or as an
/// authorized cloud context section.
///
/// It has to be one or the other, never both. The Worker authorizes a structured
/// result by scanning `request.context` for the UUIDs the model is allowed to
/// name (`semanticValidationError` in
/// `Shared/EVACloudContracts/src/structured.ts`), so a `plan`, `planRepair`, or
/// `topThree` answer that references a real record is rejected outright when the
/// projection was inlined into the message instead. Inlining it *as well* would
/// simply pay for the payload twice.
///
/// Offline keeps the projection in the prompt, because the MLX path never sends
/// a context envelope at all.
///
/// This is deliberately a thin, additive shim. Phase 3 replaces the ad-hoc
/// per-route payloads with a typed envelope builder; until then each route keeps
/// the projection it already computes and only changes where it is carried.
enum EvaRouteContextSections {
    /// Kind labels let the server-side prompt tell projections apart while every
    /// section still shares the single `planning` category the consent model
    /// already understands. A new category would need a consent revision.
    enum Kind: String {
        case plan
        case planRepair
        case topThree
    }

    /// The context envelope for a cloud-bound route; empty when offline, since
    /// the projection is already in the prompt there.
    static func planning(
        projection: String,
        kind: Kind,
        modelName: String
    ) -> [EvaCloudContextSection] {
        let trimmed = projection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EvaModelSelection.isCloud(modelName), trimmed.isEmpty == false else { return [] }
        return [
            EvaContextSectionFactory.planning(renderedOverview: trimmed, kind: kind.rawValue),
        ]
    }

    /// Appends the projection to a prompt only on the offline path.
    static func inlining(_ projection: String, into header: String, modelName: String) -> String {
        let trimmed = projection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EvaModelSelection.isCloud(modelName) == false, trimmed.isEmpty == false else { return header }
        return "\(header)\n\n\(trimmed)"
    }
}
