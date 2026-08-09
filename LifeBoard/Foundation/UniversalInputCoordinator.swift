//
//  UniversalInputCoordinator.swift
//  LifeBoard
//
//  Assembles the universal input intent resolution pipeline. Deterministic
//  adapters run first; the semantic classifier (when available) handles
//  paraphrases; unrecognized input falls through to EVA conversation.
//

import Foundation

/// Assembles the universal input pipeline and provides the single entry point
/// for resolving composer input into a structured intent.
///
/// The pipeline tries adapters in order:
/// 1. `CommandIntentAdapter` — exact commands and slash aliases
/// 2. `TaskCaptureIntentAdapter` — structured task parsing
/// 3. `CaptureLanguageIntentAdapter` — note/journal capture language
/// 4. `SemanticIntentAdapter` — Foundation Models classifier (when available)
///
/// Unrecognized input falls through to `.answer` (EVA conversation).
public actor UniversalInputCoordinator {
    private let previewResolver: LifeThreadIntentResolver
    private let resolver: LifeThreadIntentResolver
    
    public init(
        mutationCoordinator: MutationCoordinator = .init(),
        mutationAdapters: [any LifeThreadMutationIntentAdapter] = [],
        semanticAdapter: (any LifeThreadIntentAdapter)? = UniversalInputSemanticAdapter()
    ) {
        let deterministicAdapters: [any LifeThreadIntentAdapter] = [
            CommandIntentAdapter(),
            TaskCaptureIntentAdapter(),
            CaptureLanguageIntentAdapter(),
        ]
        let adapters = deterministicAdapters + (semanticAdapter.map { [$0] } ?? [])
        
        self.previewResolver = LifeThreadIntentResolver(
            adapters: deterministicAdapters,
            mutationAdapters: [],
            mutationCoordinator: mutationCoordinator
        )
        self.resolver = LifeThreadIntentResolver(
            adapters: adapters,
            mutationAdapters: mutationAdapters,
            mutationCoordinator: mutationCoordinator
        )
    }
    
    public func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution {
        await resolver.resolve(input)
    }

    /// Fast, deterministic-only resolution for live composer hints. Semantic
    /// model work runs only after explicit submission so pauses while typing
    /// do not repeatedly start on-device inference.
    public func resolvePreview(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution {
        await previewResolver.resolve(input)
    }
}
