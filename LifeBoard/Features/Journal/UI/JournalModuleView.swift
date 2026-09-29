import AVFAudio
import CoreSpotlight
import Foundation
import LifeBoardDomain
import LocalAuthentication
import LifeBoardPersistence
import Observation
import PhotosUI
import LifeBoardDomain
import Speech
import SwiftUI
import LifeBoardTranscription
import UIKit
import UniformTypeIdentifiers
import LifeBoardContracts

struct JournalModuleView: View {
    private enum BackupOperation: String, Identifiable {
        case create
        case importArchive
        var id: String { rawValue }
    }

    private struct PhotoEditRequest: Identifiable {
        let id = UUID()
        var dayID: UUID
        var mediaID: UUID
        var payload: Data
    }

    @State var store: JournalStore
    @State var privacy: JournalPrivacyController
    let router: AppRouter?
    let reflectionWeekDate: Date
    @State private var showsTextComposer = false
    @State private var startsNewEntry = false
    /// One receipt for the whole module, shown under the lens picker so it
    /// appears on the lens where the change was made. A title edited from
    /// Library or Calendar used to set a receipt that only Today drew, so it
    /// surfaced later, out of context.
    @State private var receipt: JournalReceipt?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var showsMood = false
    @State private var mood: JournalMood = .none
    @State private var calendarMonth = Date()
    @State private var selectedCalendarDayID: UUID?
    @State private var showsPrompts = false
    /// Set when a prompt is chosen; the composer opens once the prompt sheet
    /// has actually finished dismissing, not after a guessed delay.
    @State private var opensComposerAfterPrompts = false
    @State private var chosenPrompt: JournalPrompt?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showsRecorder = false
    @State private var showsVoiceSearch = false
    @State private var showsPrivacy = false
    @State var reflectionDevelopProgress = 1.0
    @State var developedReflectionID: UUID?
    @State var showsTakeawayEditor = false
    @State var takeawayDraft = ""
    @State var shareReceipt: JournalExportReceipt?
    @State var confirmsReflectionDeletion = false
    @State private var photoEditRequest: PhotoEditRequest?
    @State private var backupOperation: BackupOperation?
    @State private var backupPassphrase = ""
    @State private var backupPassphraseConfirmation = ""
    @State private var pendingImportURL: URL?
    @State private var importDuplicatePolicy: JournalBackupDuplicatePolicy = .keepExisting
    @State private var showsBackupImporter = false
    @State private var showsWatchRecovery = false
    /// A held watch capture the person asked to remove; removal is permanent,
    /// so it waits for a confirmation that says what is lost.
    @State private var recoveryPendingRemoval: WatchCaptureRecoveryRecord?
    @State private var backupOperationTask: Task<Void, Never>?
    @Environment(PresentationPreferences.self) private var preferences
    // Light-only `palette(for:)` painted light-appearance ink (#6F6252)
    // on the dark canvas; the palette has to follow the appearance.
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private let initialText: String?

    init(
        repository: any PhaseIIRepository,
        initialSection: JournalStore.Section = .today,
        reflectionWeekDate: Date = Date(),
        router: AppRouter? = nil,
        initialText: String? = nil,
        startsWithTextComposer: Bool = false
    ) {
        _store = State(initialValue: JournalStore(repository: repository, initialSection: initialSection))
        _privacy = State(initialValue: JournalPrivacyController(initiallyUnlocked: router?.isJournalAccessUnlocked == true))
        _showsTextComposer = State(initialValue: startsWithTextComposer)
        self.reflectionWeekDate = reflectionWeekDate
        self.router = router
        self.initialText = initialText
    }

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        let surface = AnyView(journalSurface(palette: palette))
        let captureSheets = AnyView(surface.sheet(isPresented: $showsTextComposer, onDismiss: { startsNewEntry = false; chosenPrompt = nil }) {
            JournalTextComposer(
                prompt: currentPrompt,
                initialText: initialText ?? store.draft?.text ?? "",
                onDraftChanged: { text, editPosition in
                    Task { await store.saveDraftText(text, promptID: currentPrompt.id, editPosition: editPosition) }
                },
                // "New entry" marks the first block so the day reads as two
                // sittings even when they are minutes apart.
                onSave: { await store.appendText($0, promptID: startsNewEntry ? JournalEntryGrouping.breakMarker : currentPrompt.id) }
            )
        }.sheet(isPresented: $showsMood) {
            JournalMoodDialSheet(selectedMood: $mood) { energy, reasons in
                Task {
                    // Persistence first: the haptic and the receipt wait
                    // for the check-in to reach disk.
                    guard let entry = await store.appendMood(mood, energy: energy, reasons: reasons) else {
                        Haptic.fail.play()
                        return
                    }
                    Haptic.commit.play()
                    showReceipt(JournalReceipt(message: ReceiptCopy.moodSaved) {
                        await store.undoMood(entry)
                    })
                }
            }
        }.sheet(isPresented: $showsPrompts, onDismiss: {
            guard opensComposerAfterPrompts else { return }
            opensComposerAfterPrompts = false
            showsTextComposer = true
        }) {
            promptsSheet
        }.sheet(isPresented: $showsRecorder) {
            JournalAudioCapture { path, duration, transcription in
                await store.appendAudio(relativePath: path, duration: duration, transcription: transcription)
            } onTranscription: { path, transcription in
                await store.updateAudioTranscription(relativePath: path, text: transcription)
            } onDiscard: { path in
                await store.discardAudio(relativePath: path)
            }
        }.sheet(isPresented: $showsVoiceSearch) {
            JournalAudioCapture(purpose: .search) { path, _, transcription in
                defer { try? JournalAudioFiles.delete(relativePath: path) }
                if let transcription = transcription?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !transcription.isEmpty {
                    store.searchText = transcription
                }
                return true
            }
        })
        let auxiliarySheets = AnyView(captureSheets.sheet(isPresented: $showsPrivacy) {
            JournalPrivacySettingsView(
                controller: privacy,
                onCreateBackup: {
                    showsPrivacy = false
                    backupOperation = .create
                },
                onImportBackup: {
                    showsPrivacy = false
                    showsBackupImporter = true
                }
            )
        }.sheet(isPresented: $showsTakeawayEditor) {
            takeawayEditor
        }.sheet(item: $shareReceipt, onDismiss: { store.resetReflectionExport() }) { receipt in
            JournalExportShareSheet(url: receipt.fileURL)
        }.sheet(item: $photoEditRequest) { request in
            JournalPhotoEditor(payload: request.payload) { editedPayload in
                photoEditRequest = nil
                Task { await store.updatePhoto(dayID: request.dayID, mediaID: request.mediaID, payload: editedPayload) }
            }
        }.sheet(item: $backupOperation, onDismiss: resetBackupPresentation) { operation in
            backupPassphraseSheet(operation: operation)
        }.sheet(isPresented: $showsWatchRecovery) {
            watchRecoverySheet
        }.fileImporter(
            isPresented: $showsBackupImporter,
            allowedContentTypes: [UTType(filenameExtension: "lifeboardjournal") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                pendingImportURL = urls.first
                if pendingImportURL != nil { backupOperation = .importArchive }
            case .failure:
                store.reportProblem(String(localized: "Couldn’t open backup file. Choose it again.")) {
                    showsBackupImporter = true
                }
            }
        })
        return auxiliarySheets.confirmationDialog(
            "Delete this version?",
            isPresented: $confirmsReflectionDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete version", role: .destructive) {
                Task { await store.deleteSelectedReflection(weekContaining: reflectionWeekDate) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your entries stay. Only this summary version is deleted.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsPrivacy = true } label: { Image(systemName: "lock.shield") }
                    .accessibilityLabel("Journal privacy")
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            if let retry = store.errorRetry {
                Button("Try again") {
                    store.errorRetry = nil
                    Task { await retry() }
                }
            }
            Button("OK", role: .cancel) { store.errorRetry = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var sectionPicker: some View {
        LensPicker(
            "Journal section",
            selection: $store.section,
            values: JournalStore.Section.allCases,
            identifierPrefix: "journal.section",
            title: \.title,
            identifier: \.rawValue
        )
    }

    private func showReceipt(_ value: JournalReceipt?) {
        withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
            receipt = value
        }
    }

    private func journalSurface(palette: DaypartPalette) -> some View {
        VStack(spacing: 0) {
            // Five lenses do not fit one iPhone row at larger text sizes; the
            // row scrolls rather than truncating "Calendar" to "Calen…".
            ViewThatFits(in: .horizontal) {
                sectionPicker
                ScrollView(.horizontal) { sectionPicker.fixedSize(horizontal: true, vertical: false) }
                    .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .featureHeaderArtwork(.journal, enabled: privacy.state == .unlocked)

            if let receipt {
                ReceiptBar(
                    receipt.presentation,
                    undo: {
                        showReceipt(nil)
                        Task { _ = await receipt.undo() }
                    },
                    destination: nil,
                    onDismiss: { showReceipt(nil) }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !store.watchRecoveryRecords.isEmpty {
                watchRecoveryBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            switch store.section {
            case .today: today(palette: palette)
            case .library: library(palette: palette)
            case .calendar: calendarLens(palette: palette)
            case .gallery: JournalMediaGalleryLens(days: store.allDays, palette: palette)
            case .insights: insights(palette: palette)
            }
        }
        // Declared as a container, or the workspace identifier is stamped
        // onto whichever lens scroll view comes first and hides its own
        // identifier (the Gallery lens vanished from XCUITest this way).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.workspace")
        .overlay {
            if privacy.state != .unlocked { journalPrivacyGate }
        }
        .task {
            await privacy.authenticateIfNeeded()
            guard privacy.state == .unlocked else { return }
            router?.journalDidUnlock()
            await store.load()
            if store.section == .insights { await store.loadReflections(weekContaining: reflectionWeekDate) }
        }
        .onChange(of: store.section) {
            // A receipt belongs to the lens it was made on.
            if receipt != nil { showReceipt(nil) }
        }
        .task(id: store.section) {
            guard store.section == .insights, privacy.state == .unlocked else { return }
            await store.loadReflections(weekContaining: reflectionWeekDate)
        }
        .task(id: store.searchText) {
            do {
                try await Task.sleep(for: .milliseconds(180))
                await store.search()
            } catch is CancellationError {
                return
            } catch {
                // `search()` reports its own failures in the search status.
                return
            }
        }
        .onChange(of: store.starredOnly) { _, _ in store.applyVisibleDays() }
        .onChange(of: store.moodFilter) { _, _ in store.applyVisibleDays() }
        .onChange(of: privacy.state) { _, state in
            if state == .unlocked {
                router?.journalDidUnlock()
            } else if privacy.policy.requiresAuthentication {
                router?.journalDidLock()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            privacy.lock()
            router?.journalDidLock()
        }
        .onChange(of: photoSelection) { _, items in
            Task {
                var payloads: [Data] = []
                do {
                    for item in items {
                        if let data = try await item.loadTransferable(type: Data.self) { payloads.append(data) }
                    }
                    await store.appendPhotos(payloads)
                } catch {
                    store.reportProblem(String(localized: "Couldn’t add photo. It may still be downloading from iCloud.")) {
                        await store.appendPhotos(payloads)
                    }
                }
                photoSelection = []
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lifeboardJournalWatchCaptureNeedsAttention)) { _ in
            Task { await store.loadWatchRecovery() }
        }
    }

    private var watchRecoveryBanner: some View {
        Button { showsWatchRecovery = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .frame(width: 36, height: 36)
                    .background(Color.lifeboard(.statusWarning).opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn’t sync from Watch")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(store.watchRecoveryRecords.count == 1 ? "1 entry waiting" : "\(store.watchRecoveryRecords.count) entries waiting")
                        .font(.caption)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(12)
            .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.lifeboard(.statusWarning).opacity(0.34), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Watch recovery")
    }

    private var watchRecoverySheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.watchRecoveryRecords) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(watchRecoveryTitle(record.reason), systemImage: watchRecoverySymbol(record.reason))
                                .font(.headline)
                            Text(watchRecoveryMessage(record.reason))
                                .font(.subheadline)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                            Text(record.receivedAtUTC, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                            HStack(spacing: 12) {
                                if record.isRetryable {
                                    Button("Try again") { Task { await store.retryWatchRecovery() } }
                                        .buttonStyle(.lifeBoardPrimaryCompact)
                                        .minimumHitTarget()
                                }
                                Button("Remove…", role: .destructive) {
                                    recoveryPendingRemoval = record
                                }
                                .buttonStyle(.lifeBoardChip)
                                .minimumHitTarget()
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .contain)
                    }
                } header: {
                    Text("Waiting entries")
                }
            }
            .lifeBoardFormSurface()
            .confirmationDialog(
                "Remove this entry?",
                isPresented: Binding(
                    get: { recoveryPendingRemoval != nil },
                    set: { if $0 == false { recoveryPendingRemoval = nil } }
                ),
                titleVisibility: .visible,
                presenting: recoveryPendingRemoval
            ) { record in
                Button("Remove entry", role: .destructive) {
                    recoveryPendingRemoval = nil
                    Task { await store.discardWatchRecoveryRecord(id: record.id) }
                }
                Button("Keep it", role: .cancel) { recoveryPendingRemoval = nil }
            } message: { _ in
                Text("It won’t reach your journal. This can’t be undone.")
            }
            .navigationTitle("Watch recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsWatchRecovery = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var takeawayEditor: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $takeawayDraft)
                        .frame(minHeight: 140)
                        .accessibilityIdentifier("journal.reflection.takeaway")
                }
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            .lifeBoardFormSurface()
            .navigationTitle("Takeaway")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsTakeawayEditor = false }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showsTakeawayEditor = false
                        Task { await store.saveReflectionTakeaway(takeawayDraft) }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func backupPassphraseSheet(operation: BackupOperation) -> some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Passphrase", text: $backupPassphrase)
                        .textContentType(.password)
                    if operation == .create {
                        SecureField("Confirm passphrase", text: $backupPassphraseConfirmation)
                            .textContentType(.password)
                    }
                } header: {
                    Text(operation == .create ? "Protect this backup" : "Unlock this backup")
                } footer: {
                    Text("If you lose this passphrase, the backup can’t be recovered.")
                }

                if operation == .importArchive {
                    Section("Duplicates") {
                        Picker("If an entry exists", selection: $importDuplicatePolicy) {
                            Text("Keep existing").tag(JournalBackupDuplicatePolicy.keepExisting)
                            Text("Replace existing").tag(JournalBackupDuplicatePolicy.replaceExisting)
                            Text("Keep both").tag(JournalBackupDuplicatePolicy.duplicateWithNewIDs)
                        }
                    }
                }

                Section {
                    backupAction(operation: operation)
                    backupStatus(operation: operation)
                }
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            .lifeBoardFormSurface()
            .navigationTitle(operation == .create ? "Encrypted backup" : "Import backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isBackupBusy {
                        Button("Cancel", role: .cancel) {
                            backupOperationTask?.cancel()
                            backupOperationTask = nil
                        }
                        .keyboardShortcut(.cancelAction)
                    } else {
                        Button("Close") { backupOperation = nil }
                            .keyboardShortcut(.cancelAction)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isBackupBusy)
    }

    @ViewBuilder
    private func backupAction(operation: BackupOperation) -> some View {
        let phase = operation == .create ? backupPhaseForControl : importPhaseForControl
        AsyncActionControl(
            title: operation == .create ? String(localized: "Create backup") : String(localized: "Import backup"),
            runningTitle: operation == .create ? String(localized: "Encrypting") : String(localized: "Importing"),
            successTitle: operation == .create ? String(localized: "Backup ready") : String(localized: "Imported"),
            phase: phase
        ) {
            guard backupPassphrase.count >= 8 else { return }
            if operation == .create {
                guard backupPassphrase == backupPassphraseConfirmation else { return }
                backupOperationTask?.cancel()
                backupOperationTask = Task {
                    await store.createEncryptedBackup(passphrase: backupPassphrase)
                    backupOperationTask = nil
                }
            } else if let pendingImportURL {
                backupOperationTask?.cancel()
                backupOperationTask = Task {
                    let hasSecurityScope = pendingImportURL.startAccessingSecurityScopedResource()
                    defer {
                        if hasSecurityScope { pendingImportURL.stopAccessingSecurityScopedResource() }
                    }
                    await store.importEncryptedBackup(
                        fileURL: pendingImportURL,
                        passphrase: backupPassphrase,
                        duplicatePolicy: importDuplicatePolicy
                    )
                    backupOperationTask = nil
                }
            }
        }
        .disabled(
            backupPassphrase.count < 8
                || (operation == .create && backupPassphrase != backupPassphraseConfirmation)
                || (operation == .importArchive && pendingImportURL == nil)
                || isBackupBusy
        )
    }

    @ViewBuilder
    private func backupStatus(operation: BackupOperation) -> some View {
        if operation == .create, case .success(let receipt) = store.backupPhase {
            ShareLink(item: receipt.fileURL) {
                Label("Share backup", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        } else if operation == .importArchive, case .success(let receipt) = store.importPhase {
            Label(
                "Imported \(receipt.insertedDayIDs.count), replaced \(receipt.replacedDayIDs.count), skipped \(receipt.skippedDayIDs.count)",
                systemImage: "checkmark.shield.fill"
            )
            .font(.footnote)
        } else if let failure = backupFailure(operation: operation) {
            Label(failure.message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Color.lifeboard(.statusDanger))
        }
    }

    private func backupFailure(operation: BackupOperation) -> AsyncActionFailure? {
        if operation == .create, case .recoverableFailure(let failure) = store.backupPhase { return failure }
        if operation == .importArchive, case .recoverableFailure(let failure) = store.importPhase { return failure }
        return nil
    }

    private var backupPhaseForControl: AsyncActionPhase<Bool> {
        switch store.backupPhase {
        case .idle: .idle
        case .running(let progress): .running(progress: progress)
        case .success: .success(receipt: true)
        case .recoverableFailure(let failure): .recoverableFailure(failure)
        case .cancelled: .cancelled
        }
    }

    private var importPhaseForControl: AsyncActionPhase<Bool> {
        switch store.importPhase {
        case .idle: .idle
        case .running(let progress): .running(progress: progress)
        case .success: .success(receipt: true)
        case .recoverableFailure(let failure): .recoverableFailure(failure)
        case .cancelled: .cancelled
        }
    }

    private var isBackupBusy: Bool {
        if case .running = store.backupPhase { return true }
        if case .running = store.importPhase { return true }
        return false
    }

    private func resetBackupPresentation() {
        backupOperationTask?.cancel()
        backupOperationTask = nil
        backupPassphrase = ""
        backupPassphraseConfirmation = ""
        pendingImportURL = nil
        importDuplicatePolicy = .keepExisting
        store.resetBackupPhases()
    }

    private var journalPrivacyGate: some View {
        ZStack {
            Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .lifeboardFont(.heroDisplay)
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                Text("Journal locked")
                    .font(.title2.weight(.semibold))
                Group {
                    switch privacy.state {
                    case .authenticating:
                        ProgressView("Unlocking…")
                    case .recoveryRequired(let message):
                        Text(message)
                    case .locked:
                        EmptyView()
                    case .unlocked:
                        EmptyView()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .multilineTextAlignment(.center)
                if privacy.state != .authenticating {
                    Button("Unlock", systemImage: "faceid") {
                        Task {
                            await privacy.authenticateIfNeeded()
                            if privacy.state == .unlocked {
                                router?.journalDidUnlock()
                                await store.load()
                            }
                        }
                    }
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .controlSize(.large)
                }
                if case .recoveryRequired = privacy.state {
                    Button("Privacy settings", systemImage: "gearshape") { showsPrivacy = true }
                        .buttonStyle(.lifeBoardChip)
                        .accessibilityHint("Opens Journal privacy")
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.privacy.lock")
    }

    private var currentPrompt: JournalPrompt {
        chosenPrompt ?? .contextual(daypart: preferences.resolvedDaypart(), hasEntry: store.today?.blocks.isEmpty == false)
    }

    /// The prompt library, by intent. Choosing one opens the composer with it;
    /// the block keeps the prompt's id.
    private var promptsSheet: some View {
        NavigationStack {
            List {
                ForEach(JournalPromptLibrary.sets) { set in
                    Section {
                        ForEach(set.prompts) { prompt in
                            Button {
                                chosenPrompt = prompt
                                opensComposerAfterPrompts = true
                                showsPrompts = false
                            } label: {
                                Text(prompt.title).font(.body)
                                    .frame(minHeight: 44, alignment: .leading)
                            }
                            .accessibilityIdentifier("journal.prompts.\(prompt.id)")
                        }
                    } header: {
                        Label(set.title, systemImage: set.systemImage)
                    }
                }
            }
            .navigationTitle("Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { showsPrompts = false }.keyboardShortcut(.cancelAction) }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("journal.prompts.sheet")
    }

    private func calendarLens(palette: DaypartPalette) -> some View {
        JournalCalendarLens(days: store.allDays, palette: palette, month: $calendarMonth, selectedDayID: $selectedCalendarDayID) { day in
            journalDayCard(day, palette: palette, onDelete: { Task { await store.delete(day) } })
        }
    }

    private func today(palette: DaypartPalette) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                journalHero(palette: palette)
                captureActions(palette: palette)
                JournalOnThisDayRow(matches: JournalOnThisDay.matches(in: store.allDays), palette: palette) { day in
                    // Travels to the day rather than cutting to another lens.
                    Haptic.pick.play()
                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                        calendarMonth = day.day
                        selectedCalendarDayID = day.id
                        store.section = .calendar
                    }
                }
                if let today = store.today, !today.blocks.isEmpty {
                    journalDayCard(today, palette: palette, onDelete: nil)
                } else {
                    Text("No entry today")
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func journalHero(palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(currentPrompt.title)
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                if let mood = store.today?.latestMood, mood != .none {
                    Image(mood.largeAssetName).resizable().scaledToFit().frame(width: 72, height: 72)
                        .accessibilityLabel("\(mood.displayName) mood")
                }
            }
            Button { showsTextComposer = true } label: {
                Text(store.draft == nil ? (store.today == nil ? "Start writing" : "Add more") : "Continue draft")
                    .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
            }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .tint(palette.color(for: .foreground))
        }
        .padding(20)
        .lifeBoardPaperCard()
    }

    /// One row when the chips fit at their natural width; otherwise a
    /// wrapping grid, so no chip truncates on a narrow iPhone or at large
    /// text sizes.
    private func captureActions(palette: DaypartPalette) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                captureActionItems(palette: palette)
            }
            .fixedSize(horizontal: true, vertical: false)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                captureActionItems(palette: palette)
            }
        }
    }

    @ViewBuilder
    private func captureActionItems(palette: DaypartPalette) -> some View {
        captureAction("Mood", symbol: "face.smiling") { showsMood = true }
        captureAction("Prompts", symbol: "text.quote") { showsPrompts = true }
            .accessibilityIdentifier("journal.prompts.open")
        if store.today?.blocks.isEmpty == false {
            captureAction("New entry", symbol: "text.append") {
                startsNewEntry = true
                showsTextComposer = true
            }
            .accessibilityIdentifier("journal.day.newEntry")
        }
        captureAction("Voice", symbol: "waveform") { showsRecorder = true }
        PhotosPicker(selection: $photoSelection, maxSelectionCount: 5, matching: .images) {
            Label("Photo", systemImage: "photo")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.lifeBoardChip)
        .tint(palette.color(for: .foreground))
    }

    private func captureAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
            .buttonStyle(.lifeBoardChip)
    }

    private func library(palette: DaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    TextField("Search journal", text: $store.searchText, prompt: Text("Search journal").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                        .accessibilityLabel("Search journal")
                    Button { showsVoiceSearch = true } label: {
                        Image(systemName: "mic.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Voice search")
                    Menu {
                        Toggle("Starred only", isOn: $store.starredOnly)
                        Button("All moods") { store.moodFilter = nil }
                        ForEach(JournalMood.allCases.filter { $0 != .none }) { mood in
                            Button(mood.displayName) { store.moodFilter = mood }
                        }
                        if store.hasActiveFilters {
                            Divider()
                            Button("Clear filters", systemImage: "xmark.circle") { store.clearFilters() }
                        }
                    } label: {
                        // Filled while a filter is on, so a narrowed library
                        // never looks like the whole journal.
                        Image(systemName: store.hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Journal filters")
                    .accessibilityValue(filterAccessibilityValue)
                }
                searchStatus(palette: palette)
                if store.days.isEmpty {
                    // "Try another search" is wrong advice when nothing was
                    // searched for. `DESIGN.md`: a successful-empty state offers
                    // one relevant next step, and no-record is its own state.
                    // Filtered-to-nothing is a third state: the journal is not
                    // empty, the filters are.
                    if store.hasActiveFilters && store.allDays.isEmpty == false {
                        StatusSurface(
                            state: .empty,
                            title: String(localized: "No matching entries"),
                            message: filterSummary,
                            actionTitle: String(localized: "Clear filters"),
                            action: { store.clearFilters() }
                        )
                        .padding(.top, 40)
                    } else if store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        StatusSurface(
                            state: .noRecord,
                            title: String(localized: "No entries yet"),
                            message: "",
                            actionTitle: String(localized: "New entry"),
                            action: { showsTextComposer = true }
                        )
                        .padding(.top, 40)
                    } else {
                        StatusSurface(state: .empty, title: String(localized: "No results"), message: String(localized: "Try another search."))
                            .padding(.top, 40)
                    }
                } else {
                    ForEach(store.days) { day in
                        journalDayCard(day, palette: palette, onDelete: { Task { await store.delete(day) } })
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private var filterSummary: String {
        var parts: [String] = []
        if store.starredOnly { parts.append(String(localized: "Starred")) }
        if let mood = store.moodFilter { parts.append(String(localized: "\(mood.displayName) mood")) }
        return parts.joined(separator: " · ")
    }

    private var filterAccessibilityValue: String {
        store.hasActiveFilters ? String(localized: "On") + ". " + filterSummary : String(localized: "Off")
    }

    private func journalDayCard(
        _ day: JournalDayValue,
        palette: DaypartPalette,
        onDelete: (() -> Void)?
    ) -> some View {
        JournalDayCard(
            day: day,
            palette: palette,
            onStar: { Task { await store.toggleStar(day) } },
            onDelete: onDelete,
            onEditPhoto: { media in
                guard let payload = media.payload else { return }
                photoEditRequest = .init(dayID: day.id, mediaID: media.id, payload: payload)
            },
            onMoveBlock: { blockID, offset in
                Task { await store.moveBlock(dayID: day.id, blockID: blockID, offset: offset) }
            },
            onDeleteBlock: { blockID in
                Task { await store.deleteBlock(dayID: day.id, blockID: blockID) }
            },
            onEditText: { blockID, text in
                await store.updateBlockText(dayID: day.id, blockID: blockID, text: text)
            },
            onSetAIExclusion: V2FeatureFlags.journalParityV1Enabled
                ? { exclusion in Task { await store.setAIExclusion(exclusion, for: day) } }
                : nil,
            onAskEva: router.map { router in
                {
                    router.presentEva(
                        context: EvaLaunchContext(kind: .journalDay, recordIDs: [day.id], date: day.day, summary: day.summary),
                        prompt: nil
                    )
                }
            },
            onEditTitle: { title in
                let previous = day.summary ?? ""
                let dayID = day.id
                let saved = await store.setTitle(title, for: day)
                if saved {
                    Haptic.commit.play()
                    showReceipt(JournalReceipt(message: ReceiptCopy.journalTitle(cleared: title.isEmpty)) {
                        // Today's record may not be in `allDays` yet on the
                        // first save of the day; `today` is the freshest copy.
                        let current = store.today?.id == dayID ? store.today : store.allDays.first(where: { $0.id == dayID })
                        guard let current else { return false }
                        return await store.setTitle(previous, for: current)
                    })
                }
                return saved
            }
        )
    }

    @ViewBuilder
    private func searchStatus(palette: DaypartPalette) -> some View {
        switch store.searchState {
        case .idle:
            EmptyView()
        case .searching:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("Searching…")
            }
            .font(.caption)
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case .building(let progress, let message):
            HStack(spacing: 12) {
                JournalWorkIndicator(isActive: true, progress: progress)
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                    Text(message)
                }
            }
            .font(.caption)
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .frame(maxWidth: .infinity, alignment: .leading)
        case .ready(let references):
            if !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(references.isEmpty ? "No results" : (references.count == 1 ? "1 result" : "\(references.count) results"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .unavailable(let reason), .failed(let reason):
            Label(reason, systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func insights(palette: DaypartPalette) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                let snapshot = store.insights
                HStack(spacing: 12) {
                    insightTile("Days", value: "\(snapshot.daysWritten)", symbol: "calendar", palette: palette)
                    insightTile("Words", value: "\(snapshot.totalWords)", symbol: "text.word.spacing", palette: palette)
                }
                if store.proactiveInsights.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionHeader("Noticed", symbol: "sparkles")
                            Spacer(minLength: 8)
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.lifeboard(.accentPrimary))
                                .accessibilityHidden(true)
                        }
                        ForEach(store.proactiveInsights.prefix(3)) { insight in
                            proactiveInsightCard(insight, palette: palette)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if store.savedProactiveInsights.isEmpty == false {
                    DisclosureGroup {
                        VStack(spacing: 12) {
                            ForEach(store.savedProactiveInsights) { insight in
                                proactiveInsightCard(insight, palette: palette)
                            }
                        }
                        .padding(.top, 12)
                    } label: {
                        Label(
                            "Saved (\(store.savedProactiveInsights.count))",
                            systemImage: "bookmark.fill"
                        )
                        .font(.headline)
                    }
                    .padding(16)
                    .lifeBoardPaperCard()
                }
                // The preview is built by the store when the days or saved
                // versions change; this body only reads it.
                if let report = store.selectedReflection ?? store.reflectionPreview {
                    weeklyReflection(report: report, palette: palette)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .onAppear { store.refreshReflectionPreview() }
                }
                Text("Worked out on \(DeviceNoun.this) from your entries.")
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            .padding(20)
        }
    }
}

/// A journal receipt and the one thing its Undo does.
private struct JournalReceipt {
    let presentation: ActionReceiptPresentation
    let undo: () async -> Bool

    init(message: String, undo: @escaping () async -> Bool) {
        presentation = ActionReceiptPresentation(message: message)
        self.undo = undo
    }
}
