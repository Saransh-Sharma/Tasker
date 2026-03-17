//
//  Data.swift
//
//

import SwiftUI
import SwiftData
import MLXLMCommon
import Security

enum LLMPersistedModelSelection {
    struct State: Equatable {
        let installedModels: [String]
        let currentModelName: String?
    }

    static let installedModelsKey = "installedModels"
    static let currentModelKey = "currentModelName"
    static let unsupportedLegacyModelNames: Set<String> = [
        "mlx-community/gemma-3-270m-it-4bit",
        "mlx-community/Llama-3.2-1B-Instruct-4bit",
        "mlx-community/Llama-3.2-3B-Instruct-4bit",
        "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
        "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-8bit",
        "mlx-community/Qwen3-4B-4bit",
        "mlx-community/Qwen3-8B-4bit",
        "mlx-community/Qwen3.5-0.8B-MLX-4bit",
        "mlx-community/Qwen3.5-0.8B-4bit",
        "mlx-community/Qwen3.5-0.8B-6bit"
    ]

    @discardableResult
    static func normalize(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ) -> State {
        let rawInstalledModels = loadInstalledModels(defaults: defaults)
        let supportedModels = Set(ModelConfiguration.availableModels.map(\.name))
        let state = normalizedState(
            installedModels: rawInstalledModels,
            currentModelName: defaults.string(forKey: currentModelKey)
        )

        persistInstalledModels(state.installedModels, defaults: defaults)
        if let currentModelName = state.currentModelName {
            defaults.set(currentModelName, forKey: currentModelKey)
        } else {
            defaults.removeObject(forKey: currentModelKey)
        }

        let unsupportedInstalledModels = Array(
            Set(
                rawInstalledModels.filter { modelName in
                    unsupportedLegacyModelNames.contains(modelName) || supportedModels.contains(modelName) == false
                }
            )
        )
        for modelName in unsupportedInstalledModels {
            removeCachedModelFiles(
                for: modelName,
                fileManager: fileManager,
                applicationSupportDirectory: applicationSupportDirectory
            )
        }

        return state
    }

    static func normalizedState(installedModels: [String], currentModelName: String?) -> State {
        let supportedModels = Set(ModelConfiguration.availableModels.map(\.name))
        var seen = Set<String>()
        let normalizedInstalledModels = installedModels.filter { modelName in
            guard seen.insert(modelName).inserted else { return false }
            guard unsupportedLegacyModelNames.contains(modelName) == false else { return false }
            return supportedModels.contains(modelName)
        }

        let normalizedCurrentModelName: String?
        if let currentModelName,
           normalizedInstalledModels.contains(currentModelName),
           LLMRuntimeSupportMatrix.compatibility(for: currentModelName)?.canActivate == true {
            normalizedCurrentModelName = currentModelName
        } else {
            normalizedCurrentModelName = AppManager.preferredActiveModelName(from: normalizedInstalledModels)
        }

        return State(
            installedModels: normalizedInstalledModels,
            currentModelName: normalizedCurrentModelName
        )
    }

    static func loadInstalledModels(defaults: UserDefaults = .standard) -> [String] {
        if let jsonData = defaults.data(forKey: installedModelsKey),
           let decodedArray = try? JSONDecoder().decode([String].self, from: jsonData) {
            return decodedArray
        }
        return []
    }

    static func persistInstalledModels(_ installedModels: [String], defaults: UserDefaults = .standard) {
        if let jsonData = try? JSONEncoder().encode(installedModels) {
            defaults.set(jsonData, forKey: installedModelsKey)
        }
    }

    static func removeCachedModelFiles(
        for model: String,
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ) {
        guard let folder = modelFolderURL(for: model, applicationSupportDirectory: applicationSupportDirectory),
              fileManager.fileExists(atPath: folder.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: folder)
        } catch {
            logError("Failed to delete model files for \(model): \(error)")
        }
    }

    static func modelFolderURL(for model: String, applicationSupportDirectory: URL?) -> URL? {
        guard let applicationSupportDirectory else { return nil }
        return applicationSupportDirectory
            .appendingPathComponent("MLXLM")
            .appendingPathComponent(model)
    }
}

enum AssistantChatMode: String, CaseIterable {
    case ask
    case plan
}

class AppManager: ObservableObject {
    static let defaultSystemPrompt = "You are Eva, a task and planning assistant. Help the user plan their day, week, tasks, projects, and life areas. Be brief, clear, and helpful. Use simple markdown and casual dates. Use only provided context. Do not invent details."
    static let legacyBuiltInSystemPrompts: Set<String> = [
        "You are Eva, the user's upbeat and clever personal assistant, here to keep tasks and calendars in perfect harmony. Your responses sparkle with tidy markdown-bold headers, sleek italics, sharp lists, and clear tables. Always refer to dates casually-Today, Yesterday, next Thursday. Stay brief and witty, unless the user invites you to dive into details. Use the provided task and project details to keep their day breezy and productive.",
        "You are Eva, the user's upbeat and clever personal assistant, here to keep tasks and calendars in perfect harmony. Your responses sparkle with tidy markdown—bold headers, sleek italics, sharp lists, and clear tables. Always refer to dates casually—Today, Yesterday, next Thursday. Stay brief and witty, unless the user invites you to dive into details. Use the provided task and project details to keep their day breezy and productive.",
        "You are Eva, a clever personal assistant. Keep tasks and priorities aligned. Be brief, clear, and helpful. Use simple markdown, short lists, and casual dates. Use only provided context. Do not invent details."
    ]

    @AppStorage("systemPrompt") var systemPrompt = defaultSystemPrompt
    @AppStorage("currentModelName") var currentModelName: String?
    @AppStorage("shouldPlayHaptics") var shouldPlayHaptics = true
    @AppStorage("numberOfVisits") var numberOfVisits = 0
    @AppStorage("numberOfVisitsOfLastRequest") var numberOfVisitsOfLastRequest = 0
    @AppStorage("assistantChatMode") var assistantChatMode = AssistantChatMode.ask.rawValue
    
    var userInterfaceIdiom: LayoutType {
        #if os(visionOS)
        return .vision
        #elseif os(macOS)
        return .mac
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #else
        return .unknown
        #endif
    }
    
    var availableMemory: Double {
        let ramInBytes = ProcessInfo.processInfo.physicalMemory
        let ramInGB = Double(ramInBytes) / (1024 * 1024 * 1024)
        return ramInGB
    }

    enum LayoutType {
        case mac, phone, pad, vision, unknown
    }
        
    @Published var installedModels: [String] = [] {
        didSet {
            saveInstalledModelsToUserDefaults()
        }
    }
    
    /// Initializes a new instance.
    init() {
        migrateBuiltInSystemPromptIfNeeded()
        loadInstalledModelsFromUserDefaults()
        let normalized = LLMPersistedModelSelection.normalize()
        installedModels = normalized.installedModels
        currentModelName = normalized.currentModelName
    }

    static func migratedBuiltInSystemPrompt(_ storedPrompt: String?) -> String? {
        guard let storedPrompt else { return nil }
        guard legacyBuiltInSystemPrompts.contains(storedPrompt) else { return nil }
        guard storedPrompt != defaultSystemPrompt else { return nil }
        return defaultSystemPrompt
    }

    func migrateBuiltInSystemPromptIfNeeded(defaults: UserDefaults = .standard) {
        guard let migratedPrompt = Self.migratedBuiltInSystemPrompt(defaults.string(forKey: "systemPrompt")) else {
            return
        }
        systemPrompt = migratedPrompt
    }

    func resetSystemPromptToDefault() {
        systemPrompt = Self.defaultSystemPrompt
    }
    
    /// Executes incrementNumberOfVisits.
    func incrementNumberOfVisits() {
        numberOfVisits += 1
        logDebug("app visits: \(numberOfVisits)")
    }
    
    // Function to save the array to UserDefaults as JSON
    /// Executes saveInstalledModelsToUserDefaults.
    private func saveInstalledModelsToUserDefaults() {
        LLMPersistedModelSelection.persistInstalledModels(installedModels)
    }
    
    // Function to load the array from UserDefaults
    /// Executes loadInstalledModelsFromUserDefaults.
    private func loadInstalledModelsFromUserDefaults() {
        self.installedModels = LLMPersistedModelSelection.loadInstalledModels()
    }
    
    /// Executes playHaptic.
    func playHaptic() {
        if shouldPlayHaptics {
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            #endif
        }
    }
    
    /// Executes removeInstalledModel.
    func removeInstalledModel(_ model: String) {
        // Remove from list if present
        if let idx = installedModels.firstIndex(of: model) {
            installedModels.remove(at: idx)
        }
        LLMPersistedModelSelection.removeCachedModelFiles(for: model)
    }
    
    /// Returns the expected local folder URL where the model is stored, based on MLXLMCommon's default.
    /// Adjust this path if the underlying library changes its cache location.
    private func modelFolderURL(for model: String) -> URL? {
        LLMPersistedModelSelection.modelFolderURL(
            for: model,
            applicationSupportDirectory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        )
    }
    
    /// Executes addInstalledModel.
    func addInstalledModel(_ model: String) {
        if !installedModels.contains(model) {
            installedModels.append(model)
        }
    }

    func setActiveModel(_ modelName: String?) {
        guard let normalizedModelName = normalizedInstalledModelName(for: modelName) else {
            currentModelName = nil
            return
        }
        guard LLMRuntimeSupportMatrix.compatibility(for: normalizedModelName)?.canActivate == true else {
            currentModelName = Self.preferredActiveModelName(from: installedModels)
            return
        }
        currentModelName = normalizedModelName
    }

    static func preferredActiveModelName(from installedModelNames: [String]) -> String? {
        let installedSet = Set(installedModelNames)
        let preferredOrder = ModelConfiguration.availableModels.map(\.name)
        for candidate in preferredOrder
        where installedSet.contains(candidate)
            && LLMRuntimeSupportMatrix.compatibility(for: candidate)?.canActivate == true {
            return candidate
        }
        return nil
    }

    func preferredFallbackModelName(excluding removedModelName: String? = nil) -> String? {
        Self.preferredActiveModelName(from: installedModels.filter { $0 != removedModelName })
    }

    private func normalizedInstalledModelName(for modelName: String?) -> String? {
        guard let trimmedModelName = modelName?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmedModelName.isEmpty == false else {
            return nil
        }
        if installedModels.contains(trimmedModelName) {
            return trimmedModelName
        }
        return installedModels.first { installedModelName in
            installedModelName.caseInsensitiveCompare(trimmedModelName) == .orderedSame
        }
    }

    /// Executes modelDisplayName.
    func modelDisplayName(_ modelName: String) -> String {
        if let model = ModelConfiguration.getModelByName(modelName) {
            return model.displayName.lowercased()
        }
        return modelName.replacingOccurrences(of: "mlx-community/", with: "").lowercased()
    }

    func compactModelDisplayName(_ modelName: String) -> String {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            return modelName
                .replacingOccurrences(of: "mlx-community/", with: "")
                .replacingOccurrences(of: "nexveridian/", with: "")
                .replacingOccurrences(of: "jackrong/", with: "")
                .lowercased()
        }

        switch model {
        case .qwen_3_0_6b_4bit:
            return "qwen3 0.6B"
        case .qwen_3_5_0_8b_optiq_4bit:
            return "qwen3.5 0.8B"
        case .qwen_3_5_0_8b_nexveridian_4bit:
            return "qwen3.5 0.8B"
        case .qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit:
            return "qwen3.5 0.8B"
        default:
            return model.displayName
                .replacingOccurrences(of: " 4bit", with: "")
                .replacingOccurrences(of: " 4-bit", with: "")
                .lowercased()
        }
    }
    
    /// Executes getMoonPhaseIcon.
    func getMoonPhaseIcon() -> String {
        // Get current date
        let currentDate = Date()
        
        // Define a base date (known new moon date)
        let baseDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 6))!
        
        // Difference in days between the current date and the base date
        let daysSinceBaseDate = Calendar.current.dateComponents([.day], from: baseDate, to: currentDate).day!
        
        // Moon phase repeats approximately every 29.53 days
        let moonCycleLength = 29.53
        let daysIntoCycle = Double(daysSinceBaseDate).truncatingRemainder(dividingBy: moonCycleLength)
        
        // Determine the phase based on how far into the cycle we are
        switch daysIntoCycle {
        case 0..<1.8457:
            return "moonphase.new.moon" // New Moon
        case 1.8457..<5.536:
            return "moonphase.waxing.crescent" // Waxing Crescent
        case 5.536..<9.228:
            return "moonphase.first.quarter" // First Quarter
        case 9.228..<12.919:
            return "moonphase.waxing.gibbous" // Waxing Gibbous
        case 12.919..<16.610:
            return "moonphase.full.moon" // Full Moon
        case 16.610..<20.302:
            return "moonphase.waning.gibbous" // Waning Gibbous
        case 20.302..<23.993:
            return "moonphase.last.quarter" // Last Quarter
        case 23.993..<27.684:
            return "moonphase.waning.crescent" // Waning Crescent
        default:
            return "moonphase.new.moon" // New Moon (fallback)
        }
    }
}

struct LLMPersonalMemoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

enum LLMPersonalMemorySection: String, CaseIterable, Codable, Identifiable {
    case preferences
    case routines
    case currentGoals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preferences:
            return "preferences"
        case .routines:
            return "routines"
        case .currentGoals:
            return "current goals"
        }
    }
}

struct LLMPersonalMemoryStoreV1: Codable, Equatable {
    static let maxEntriesPerSection = 4
    static let maxEntryCharacters = 120

    var preferences: [LLMPersonalMemoryEntry]
    var routines: [LLMPersonalMemoryEntry]
    var currentGoals: [LLMPersonalMemoryEntry]

    init(
        preferences: [LLMPersonalMemoryEntry] = [],
        routines: [LLMPersonalMemoryEntry] = [],
        currentGoals: [LLMPersonalMemoryEntry] = []
    ) {
        self.preferences = preferences
        self.routines = routines
        self.currentGoals = currentGoals
    }

    func entries(for section: LLMPersonalMemorySection) -> [LLMPersonalMemoryEntry] {
        switch section {
        case .preferences:
            return preferences
        case .routines:
            return routines
        case .currentGoals:
            return currentGoals
        }
    }

    mutating func setEntries(_ entries: [LLMPersonalMemoryEntry], for section: LLMPersonalMemorySection) {
        let normalized = Self.normalized(entries)
        switch section {
        case .preferences:
            preferences = normalized
        case .routines:
            routines = normalized
        case .currentGoals:
            currentGoals = normalized
        }
    }

    var isEmpty: Bool {
        LLMPersonalMemorySection.allCases.allSatisfy { entries(for: $0).isEmpty }
    }

    static func normalized(_ entries: [LLMPersonalMemoryEntry]) -> [LLMPersonalMemoryEntry] {
        let cleaned = entries.compactMap { entry -> LLMPersonalMemoryEntry? in
            let normalizedText = String(
                entry.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(maxEntryCharacters)
            )
            guard normalizedText.isEmpty == false else { return nil }
            return LLMPersonalMemoryEntry(id: entry.id, text: normalizedText)
        }
        return Array(cleaned.prefix(maxEntriesPerSection))
    }
}

struct LLMSecureBlobStore {
    let service: String
    let account: String

    static let personalMemory = LLMSecureBlobStore(
        service: (Bundle.main.bundleIdentifier ?? "Tasker") + ".secureStorage",
        account: LLMPersonalMemoryDefaultsStore.key
    )

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }

    func loadData() -> Data? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            logError("Failed to load secure blob \(account): \(status)")
            return nil
        }
    }

    @discardableResult
    func saveData(_ data: Data) -> Bool {
        let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logWarning("Failed to replace secure blob \(account): \(deleteStatus)")
        }

        var attributes = baseQuery
        attributes[kSecValueData] = data
        #if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
        attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

        let saveStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard saveStatus == errSecSuccess else {
            logError("Failed to save secure blob \(account): \(saveStatus)")
            return false
        }
        return true
    }

    func clear() {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logWarning("Failed to clear secure blob \(account): \(status)")
        }
    }
}

enum LLMPersonalMemoryDefaultsStore {
    static let key = "llm.personalMemory.v1"

    static func load(
        defaults: UserDefaults = .standard,
        secureStore: LLMSecureBlobStore = .personalMemory
    ) -> LLMPersonalMemoryStoreV1 {
        if let secureData = secureStore.loadData() {
            guard let decoded = try? JSONDecoder().decode(LLMPersonalMemoryStoreV1.self, from: secureData) else {
                logWarning("Failed to decode secure personal memory store.")
                return LLMPersonalMemoryStoreV1()
            }
            return decoded
        }

        guard let legacyData = defaults.data(forKey: key) else {
            return LLMPersonalMemoryStoreV1()
        }

        guard let decoded = try? JSONDecoder().decode(LLMPersonalMemoryStoreV1.self, from: legacyData) else {
            logWarning("Failed to decode legacy personal memory store.")
            defaults.removeObject(forKey: key)
            return LLMPersonalMemoryStoreV1()
        }

        if secureStore.saveData(legacyData) {
            defaults.removeObject(forKey: key)
        } else {
            logWarning("Failed to migrate legacy personal memory store into secure storage.")
        }
        return decoded
    }

    static func save(
        _ store: LLMPersonalMemoryStoreV1,
        defaults: UserDefaults = .standard,
        secureStore: LLMSecureBlobStore = .personalMemory
    ) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        guard secureStore.saveData(data) else { return }
        defaults.removeObject(forKey: key)
    }

    static func clear(
        defaults: UserDefaults = .standard,
        secureStore: LLMSecureBlobStore = .personalMemory
    ) {
        secureStore.clear()
        defaults.removeObject(forKey: key)
    }

    static func promptBlock(
        for model: MLXLMCommon.ModelConfiguration,
        defaults: UserDefaults = .standard,
        secureStore: LLMSecureBlobStore = .personalMemory
    ) -> String? {
        let store = load(defaults: defaults, secureStore: secureStore)
        guard store.isEmpty == false else { return nil }

        var lines = ["Personal memory:"]
        for section in LLMPersonalMemorySection.allCases {
            let items = store.entries(for: section)
                .map(\.text)
                .filter { $0.isEmpty == false }
            guard items.isEmpty == false else { continue }
            lines.append("\(section.title):")
            lines.append(contentsOf: items.map { "- \($0)" })
        }

        let block = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard block.isEmpty == false else { return nil }
        return LLMTokenBudgetEstimator.trimPrefix(
            block,
            toTokenBudget: model.tokenBudget.personalMemoryTokens
        )
    }
}

enum Role: String, Codable {
    case assistant
    case user
    case system
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var generatingTime: TimeInterval?
    var sourceModelName: String?
    var sortTimestamp: Date { timestamp }
    
    /// Initializes a new instance.
    @Relationship(inverse: \Thread.messages) var thread: Thread?
    
    init(
        role: Role,
        content: String,
        thread: Thread? = nil,
        generatingTime: TimeInterval? = nil,
        sourceModelName: String? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.thread = thread
        self.generatingTime = generatingTime
        self.sourceModelName = sourceModelName
    }
}

@Model
final class Thread {
    @Attribute(.unique) var id: UUID
    var title: String?
    var timestamp: Date
    
    @Relationship var messages: [Message] = []
    
    var sortedMessages: [Message] {
        return messages.sorted { $0.sortTimestamp < $1.sortTimestamp }
    }

    func sortedMessagesSnapshot() -> [Message] {
        messages.sorted { $0.sortTimestamp < $1.sortTimestamp }
    }
    
    /// Initializes a new instance.
    init() {
        self.id = UUID()
        self.timestamp = Date()
    }
}
