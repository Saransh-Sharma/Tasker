import Foundation

struct TaskIconOption: Identifiable, Equatable, Hashable, Decodable, Sendable {
    let symbolName: String
    let displayName: String
    let searchTerms: [String]
    let aliases: [String]
    let categories: [String]

    var id: String { symbolName }
}

enum TaskIconSelectionSource: Equatable, Sendable {
    case auto
    case manual
}

enum TaskIconFallbackReason: String, Equatable, Sendable {
    case semantic
    case project
    case category
    case checklist
}

struct TaskIconResolution: Equatable, Sendable {
    let selectedSymbolName: String
    let autoSuggestedSymbolName: String?
    let rankedSuggestions: [TaskIconOption]
    let confidence: Double
    let didUseFallback: Bool
    let fallbackReason: TaskIconFallbackReason
}

protocol TaskIconResolver: Sendable {
    func warmIfNeeded()
    func resolve(
        title: String,
        projectName: String?,
        projectIconSymbolName: String?,
        lifeAreaName: String?,
        category: TaskCategory,
        currentSymbolName: String?,
        selectionSource: TaskIconSelectionSource
    ) -> TaskIconResolution
    func search(query: String, preferredSymbols: [String], limit: Int) -> [TaskIconOption]
    func option(for symbolName: String) -> TaskIconOption?
}

final class DefaultTaskIconResolver: TaskIconResolver, @unchecked Sendable {
    static let shared = DefaultTaskIconResolver()

    private struct Storage: Sendable {
        let options: [TaskIconOption]
        let optionsBySymbol: [String: TaskIconOption]
        let optionIndexBySymbol: [String: Int]
        let searchableFieldsBySymbol: [String: [String]]
        let searchIndex: [String: [Int]]
    }

    private let buildQueue = DispatchQueue(label: "lifeboard.task-icon-resolver", qos: .userInitiated)
    private let lock = NSLock()
    private var storage: Storage?

    private init() {}

    func warmIfNeeded() {
        buildQueue.async { [weak self] in
            _ = self?.loadStorage()
        }
    }

    func option(for symbolName: String) -> TaskIconOption? {
        let storage = loadStorage()
        return storage.optionsBySymbol[symbolName] ?? Self.syntheticOption(symbolName: symbolName)
    }

    func search(query: String, preferredSymbols: [String], limit: Int = 48) -> [TaskIconOption] {
        let storage = loadStorage()
        let normalizedQuery = Self.normalize(query)
        guard normalizedQuery.isEmpty == false else {
            return defaultSearchResults(preferredSymbols: preferredSymbols, storage: storage, limit: limit)
        }

        let queryTokens = Self.tokens(from: normalizedQuery, removingStopWords: false)
        var scored: [(TaskIconOption, Int)] = []
        let candidateIndices = candidateIndices(for: queryTokens, storage: storage)

        for index in candidateIndices {
            let option = storage.options[index]
            let score = searchScore(
                option: option,
                searchableFields: storage.searchableFieldsBySymbol[option.symbolName] ?? [],
                query: normalizedQuery,
                queryTokens: queryTokens
            )
            guard score > 0 else { continue }
            scored.append((option, score))
        }

        scored.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.displayName.localizedCaseInsensitiveCompare(rhs.0.displayName) == .orderedAscending
        }
        return dedupeSymbols(scored.map(\.0)).prefix(limit).map { $0 }
    }

    func resolve(
        title: String,
        projectName: String?,
        projectIconSymbolName: String?,
        lifeAreaName: String?,
        category: TaskCategory,
        currentSymbolName: String?,
        selectionSource: TaskIconSelectionSource
    ) -> TaskIconResolution {
        let storage = loadStorage()
        let normalizedTitle = Self.normalize(title)
        let titleTokens = Self.tokens(from: normalizedTitle)
        let contextTokens = Self.tokens(from: [projectName, lifeAreaName, category.displayName].compactMap { $0 }.joined(separator: " "))
        let candidateIndices = candidateIndices(for: titleTokens + contextTokens, storage: storage)
        var scored: [(TaskIconOption, Int)] = []

        for index in candidateIndices {
            let option = storage.options[index]
            guard isEligibleAutoSymbol(option) else { continue }
            let score = resolutionScore(
                option: option,
                searchableFields: storage.searchableFieldsBySymbol[option.symbolName] ?? [],
                title: normalizedTitle,
                titleTokens: titleTokens,
                contextTokens: contextTokens,
                category: category
            )
            guard score > 0 else { continue }
            scored.append((option, score))
        }

        scored.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.displayName.localizedCaseInsensitiveCompare(rhs.0.displayName) == .orderedAscending
        }

        let bestSemantic = scored.first
        let currentAutoScore = currentSymbolName.flatMap { symbolName in
            scored.first(where: { $0.0.symbolName == symbolName })?.1
        } ?? 0
        let resolvedSemanticSymbol = stabilizedAutoSymbol(
            bestSemanticSymbol: bestSemantic?.0.symbolName,
            bestScore: bestSemantic?.1 ?? 0,
            currentSymbolName: currentSymbolName,
            currentScore: currentAutoScore,
            selectionSource: selectionSource
        )
        let bestConfidence = confidence(bestScore: bestSemantic?.1 ?? 0, runnerUpScore: scored.dropFirst().first?.1 ?? 0)
        let semanticSuggestions = dedupeSymbols(scored.prefix(10).map(\.0))

        if selectionSource == .manual, let currentSymbolName {
            let combinedSuggestions = dedupeSymbols(
                [currentSymbolName]
                    .compactMap(option(for:))
                    + semanticSuggestions
                    + defaultPreferredOptions(storage: storage)
            )
            return TaskIconResolution(
                selectedSymbolName: currentSymbolName,
                autoSuggestedSymbolName: bestSemantic?.0.symbolName,
                rankedSuggestions: Array(combinedSuggestions.prefix(12)),
                confidence: bestConfidence,
                didUseFallback: false,
                fallbackReason: .semantic
            )
        }

        let fallbackReason: TaskIconFallbackReason
        let selectedSymbolName: String

        if let resolvedSemanticSymbol, bestConfidence >= Self.minimumConfidence {
            selectedSymbolName = resolvedSemanticSymbol
            fallbackReason = .semantic
        } else if let projectIconSymbolName {
            selectedSymbolName = projectIconSymbolName
            fallbackReason = .project
        } else if let categorySymbol = Self.categoryFallbackSymbolName(for: category) {
            selectedSymbolName = categorySymbol
            fallbackReason = .category
        } else {
            selectedSymbolName = Self.defaultFallbackSymbolName
            fallbackReason = .checklist
        }

        let combinedSuggestions = dedupeSymbols(
            [selectedSymbolName]
                .compactMap(option(for:))
                + semanticSuggestions
                + defaultPreferredOptions(storage: storage)
        )

        return TaskIconResolution(
            selectedSymbolName: selectedSymbolName,
            autoSuggestedSymbolName: resolvedSemanticSymbol ?? bestSemantic?.0.symbolName,
            rankedSuggestions: Array(combinedSuggestions.prefix(12)),
            confidence: bestConfidence,
            didUseFallback: fallbackReason != .semantic,
            fallbackReason: fallbackReason
        )
    }

    private func loadStorage() -> Storage {
        lock.lock()
        if let storage {
            lock.unlock()
            return storage
        }
        lock.unlock()

        let interval = LifeBoardPerformanceTrace.begin("TaskIconManifestWarm")
        let options = dedupeSymbols(TaskIconSymbolManifest.options)
        var optionsBySymbol: [String: TaskIconOption] = [:]
        var optionIndexBySymbol: [String: Int] = [:]
        var searchableFieldsBySymbol: [String: [String]] = [:]
        var searchIndex: [String: [Int]] = [:]

        for (index, option) in options.enumerated() {
            optionsBySymbol[option.symbolName] = option
            optionIndexBySymbol[option.symbolName] = index

            let searchableFields = dedupeStrings(
                [
                    option.displayName,
                    option.symbolName.replacingOccurrences(of: ".", with: " "),
                    option.symbolName.replacingOccurrences(of: ".", with: ""),
                    option.searchTerms.joined(separator: " "),
                    option.aliases.joined(separator: " "),
                    option.categories.joined(separator: " ")
                ] + (Self.curatedKeywordBoosts[option.symbolName] ?? [])
            )
            searchableFieldsBySymbol[option.symbolName] = searchableFields

            let indexTokens = Set(Self.tokens(from: searchableFields.joined(separator: " "), removingStopWords: false))
            for token in indexTokens where token.isEmpty == false {
                searchIndex[token, default: []].append(index)
            }
        }

        let resolved = Storage(
            options: options,
            optionsBySymbol: optionsBySymbol,
            optionIndexBySymbol: optionIndexBySymbol,
            searchableFieldsBySymbol: searchableFieldsBySymbol,
            searchIndex: searchIndex
        )

        lock.lock()
        if storage == nil {
            storage = resolved
        }
        let cached = storage ?? resolved
        lock.unlock()

        LifeBoardPerformanceTrace.end(interval)
        logDebug(
            event: "task_icon_manifest_warmed",
            message: "Prepared task icon manifest and search index",
            fields: ["symbol_count": String(cached.options.count)]
        )
        return cached
    }

    private func defaultSearchResults(preferredSymbols: [String], storage: Storage, limit: Int) -> [TaskIconOption] {
        let defaults = preferredSymbols.compactMap { symbolName in
            storage.optionsBySymbol[symbolName] ?? Self.syntheticOption(symbolName: symbolName)
        } + defaultPreferredOptions(storage: storage)
        return Array(dedupeSymbols(defaults).prefix(limit))
    }

    private func defaultPreferredOptions(storage: Storage) -> [TaskIconOption] {
        Self.defaultPreferredSymbolNames.compactMap { storage.optionsBySymbol[$0] ?? Self.syntheticOption(symbolName: $0) }
    }

    private func candidateIndices(for tokens: [String], storage: Storage) -> [Int] {
        guard tokens.isEmpty == false else { return Array(storage.options.indices) }
        var merged = Set<Int>()
        for token in tokens {
            for index in storage.searchIndex[token] ?? [] {
                merged.insert(index)
            }
        }
        return merged.isEmpty ? Array(storage.options.indices) : Array(merged)
    }

    private func searchScore(
        option: TaskIconOption,
        searchableFields: [String],
        query: String,
        queryTokens: [String]
    ) -> Int {
        let haystack = searchableFields.joined(separator: " ").lowercased()
        var score = 0

        if option.symbolName.lowercased() == query { score += 240 }
        if option.displayName.lowercased() == query { score += 220 }
        if option.displayName.lowercased().hasPrefix(query) { score += 140 }
        if haystack.contains(query) { score += 70 }

        for token in queryTokens {
            if option.displayName.lowercased().contains(token) { score += 28 }
            if option.aliases.contains(where: { $0.lowercased().contains(token) }) { score += 22 }
            if option.searchTerms.contains(where: { $0.lowercased().contains(token) }) { score += 18 }
            if option.categories.contains(where: { $0.lowercased().contains(token) }) { score += 10 }
        }

        if isEligibleAutoSymbol(option) == false {
            score -= 12
        }
        return score
    }

    private func resolutionScore(
        option: TaskIconOption,
        searchableFields: [String],
        title: String,
        titleTokens: [String],
        contextTokens: [String],
        category: TaskCategory
    ) -> Int {
        let haystack = searchableFields.joined(separator: " ").lowercased()
        var score = 0

        if title.isEmpty == false {
            if option.displayName.lowercased() == title { score += 240 }
            if haystack.contains(title) { score += 90 }
        }

        for token in titleTokens {
            if option.searchTerms.contains(where: { $0.lowercased() == token }) { score += 42 }
            if option.aliases.contains(where: { $0.lowercased() == token }) { score += 40 }
            if option.displayName.lowercased().contains(token) { score += 34 }
            if haystack.contains(token) { score += 12 }
        }

        for token in contextTokens {
            if haystack.contains(token) { score += 6 }
        }

        for boostedToken in Self.curatedKeywordBoosts[option.symbolName] ?? [] where titleTokens.contains(boostedToken) {
            score += 26
        }

        if Self.categoryBoosts[category]?.contains(option.symbolName) == true {
            score += 16
        }

        if option.categories.contains("multicolor") {
            score -= 4
        }
        if option.categories.contains("whatsnew") {
            score -= 4
        }
        if Self.genericAutoPenaltySymbols.contains(option.symbolName) {
            score -= 18
        }
        if option.categories.contains("indices") || option.categories.contains("variable") {
            score -= 60
        }

        return score
    }

    private func stabilizedAutoSymbol(
        bestSemanticSymbol: String?,
        bestScore: Int,
        currentSymbolName: String?,
        currentScore: Int,
        selectionSource: TaskIconSelectionSource
    ) -> String? {
        guard selectionSource == .auto else { return bestSemanticSymbol }
        guard let bestSemanticSymbol else { return currentSymbolName }
        guard let currentSymbolName, currentSymbolName != bestSemanticSymbol, currentScore > 0 else {
            return bestSemanticSymbol
        }
        return bestScore >= currentScore + Self.hysteresisMargin ? bestSemanticSymbol : currentSymbolName
    }

    private func confidence(bestScore: Int, runnerUpScore: Int) -> Double {
        guard bestScore > 0 else { return 0 }
        let normalized = min(Double(bestScore) / 120, 1)
        let spread = max(0, Double(bestScore - runnerUpScore) / 40)
        return min(1, normalized * 0.7 + spread * 0.3)
    }

    private func isEligibleAutoSymbol(_ option: TaskIconOption) -> Bool {
        if option.symbolName.hasPrefix("0") || option.symbolName.hasPrefix("1.") {
            return false
        }
        if option.symbolName.hasSuffix(".ar")
            || option.symbolName.hasSuffix(".he")
            || option.symbolName.hasSuffix(".hi")
            || option.symbolName.hasSuffix(".ja")
            || option.symbolName.hasSuffix(".ko")
            || option.symbolName.hasSuffix(".rtl")
            || option.symbolName.hasSuffix(".th")
            || option.symbolName.hasSuffix(".zh") {
            return false
        }
        return true
    }

    private func dedupeSymbols(_ options: [TaskIconOption]) -> [TaskIconOption] {
        var seen = Set<String>()
        return options.filter { option in
            seen.insert(option.symbolName).inserted
        }
    }

    private func dedupeStrings(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            let normalized = trimmed.lowercased()
            guard seen.insert(normalized).inserted else { return nil }
            return trimmed
        }
    }

    private static func syntheticOption(symbolName: String) -> TaskIconOption {
        TaskIconOption(
            symbolName: symbolName,
            displayName: humanizedDisplayName(for: symbolName),
            searchTerms: [],
            aliases: [],
            categories: []
        )
    }

    static func humanizedDisplayName(for symbolName: String) -> String {
        symbolName
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                let raw = String(token)
                if raw.uppercased() == raw {
                    return raw
                }
                return raw.prefix(1).uppercased() + raw.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let cleaned = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " {
                return Character(scalar)
            }
            return " "
        }
        return String(cleaned).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func tokens(from text: String, removingStopWords: Bool = true) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { token in
                guard token.count > 1 else { return false }
                guard removingStopWords else { return true }
                return stopWords.contains(token) == false
            }
    }

    private static func categoryFallbackSymbolName(for category: TaskCategory) -> String? {
        switch category {
        case .work:
            return "briefcase.fill"
        case .health:
            return "heart.fill"
        case .personal:
            return "person.fill"
        case .learning:
            return "book.fill"
        case .creative:
            return "paintpalette.fill"
        case .social:
            return "person.2.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .shopping:
            return "cart.fill"
        case .finance:
            return "dollarsign.circle.fill"
        case .general:
            return nil
        }
    }

    private static let defaultFallbackSymbolName = "checklist"
    private static let minimumConfidence = 0.52
    private static let hysteresisMargin = 18

    private static let stopWords: Set<String> = [
        "a", "an", "and", "at", "before", "by", "for", "from", "in", "into", "of",
        "on", "or", "the", "to", "with", "after", "my", "our", "your", "this", "that"
    ]

    private static let genericAutoPenaltySymbols: Set<String> = [
        "checklist", "list.bullet", "square.grid.2x2", "circle.dashed", "questionmark.circle", "sparkles"
    ]

    private static let defaultPreferredSymbolNames: [String] = [
        "checklist", "calendar", "calendar.badge.clock", "clock.badge", "square.and.pencil",
        "doc.text.fill", "phone.fill", "envelope.fill", "cart.fill", "briefcase.fill",
        "heart.fill", "airplane", "figure.run", "dumbbell.fill", "broom.fill"
    ]

    private static let categoryBoosts: [TaskCategory: Set<String>] = [
        .work: ["briefcase.fill", "doc.text.fill", "calendar.badge.clock", "tray.full.fill"],
        .health: ["heart.fill", "cross.case.fill", "stethoscope", "figure.run"],
        .personal: ["person.fill", "house.fill", "sparkles", "book.fill"],
        .learning: ["book.fill", "graduationcap.fill", "doc.text.fill"],
        .creative: ["paintpalette.fill", "pencil.and.outline", "camera.fill"],
        .social: ["person.2.fill", "bubble.left.and.bubble.right.fill", "phone.fill"],
        .maintenance: ["wrench.and.screwdriver.fill", "hammer.fill", "broom.fill"],
        .shopping: ["cart.fill", "bag.fill", "shippingbox.fill", "basket.fill"]
        ,
        .finance: ["dollarsign.circle.fill", "creditcard.fill", "chart.line.uptrend.xyaxis"]
    ]

    private static let curatedKeywordBoosts: [String: [String]] = [
        "phone.fill": ["call", "phone", "dial", "voicemail", "ring"],
        "envelope.fill": ["email", "mail", "reply", "inbox", "send"],
        "calendar.badge.clock": ["appointment", "book", "booking", "schedule", "meeting"],
        "doc.text.fill": ["report", "document", "read", "review", "proposal", "deck"],
        "square.and.pencil": ["write", "draft", "edit", "journal", "note"],
        "cart.fill": ["buy", "shop", "shopping", "grocery", "groceries", "order"],
        "briefcase.fill": ["work", "client", "sprint", "board", "roadmap"],
        "heart.fill": ["health", "selfcare", "wellness"],
        "stethoscope": ["doctor", "dentist", "checkup", "clinic"],
        "cross.case.fill": ["medicine", "medication", "pharmacy", "pill"],
        "figure.run": ["run", "jog", "walk", "cardio"],
        "dumbbell.fill": ["workout", "gym", "lift", "exercise", "strength"],
        "airplane": ["flight", "travel", "trip", "vacation"],
        "fork.knife": ["dinner", "lunch", "breakfast", "meal", "cook"],
        "broom.fill": ["clean", "tidy", "laundry", "vacuum", "declutter"],
        "dollarsign.circle.fill": ["budget", "invoice", "pay", "tax", "bill"],
        "person.2.fill": ["team", "sync", "interview", "friends", "family"],
        "book.fill": ["read", "study", "learn", "course"],
        "checkmark.circle.fill": ["submit", "finish", "complete"]
    ]
}
