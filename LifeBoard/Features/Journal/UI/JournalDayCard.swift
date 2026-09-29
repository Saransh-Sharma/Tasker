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

struct JournalDayCard: View {
    let day: JournalDayValue
    let palette: DaypartPalette
    let onStar: () -> Void
    let onDelete: (() -> Void)?
    let onEditPhoto: (JournalMediaValue) -> Void
    let onMoveBlock: (UUID, Int) -> Void
    let onDeleteBlock: (UUID) -> Void
    var onEditText: ((UUID, String) async -> Bool)? = nil
    @State private var blockPendingDeletion: UUID?
    @State private var editingBlock: JournalBlockValue?
    var onSetAIExclusion: ((JournalAIExclusion) -> Void)?
    /// Saves the day's title (`JournalDayValue.summary`); the host receipts it.
    /// Eva over this day; hidden when the day is kept out of AI.
    var onAskEva: (() -> Void)? = nil
    var onEditTitle: ((String) async -> Bool)? = nil
    @State private var titleDraft = ""
    @FocusState private var titleIsFocused: Bool
    @State private var confirmsDelete = false
    @State private var playback = JournalAudioPlaybackController()
    @State private var mediaRevealProgress = 0.0
    @State private var inspectedPhoto: JournalMediaValue?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let groups = JournalEntryGrouping.entries(for: day.blocks)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(day.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.headline)
                Spacer()
                if let onSetAIExclusion {
                    Menu {
                        dayMenuItems(onSetAIExclusion)
                    } label: {
                        Image(systemName: day.aiExclusion == .included ? "sparkles" : "sparkles.slash")
                            .foregroundStyle(day.aiExclusion == .included
                                ? palette.color(for: .foregroundSecondary)
                                : palette.color(for: .celestialCore))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Eva access")
                    .accessibilityValue(exclusionAccessibilityValue)
                }
                Button(action: onStar) {
                    Image(systemName: day.isStarred ? "star.fill" : "star")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(day.isStarred ? "Unstar day" : "Star day")
                .accessibilityAddTraits(day.isStarred ? [.isSelected] : [])
                if onDelete != nil {
                    Button(role: .destructive) { confirmsDelete = true } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Delete day")
                }
            }
            // The sparkles menu's actions, also on right-click and long-press:
            // on Mac and iPad a person reaches for the header itself, and the
            // small button was the only way in. The header rather than the
            // whole card, because the title field and the blocks below own
            // their long-presses (text editing, block actions). With AI
            // visibility unavailable the menu is empty and none is shown.
            .contentShape(Rectangle())
            .contextMenu {
                if let onSetAIExclusion {
                    dayMenuItems(onSetAIExclusion)
                }
            }
            // One optional line that names the day. It is the persisted
            // `summary`, which nothing wrote before; saved on Return or when
            // focus leaves, and the host answers with a receipt and Undo.
            if let onEditTitle {
                TextField("Title", text: $titleDraft, prompt: Text("Title").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .font(.headline)
                    .textFieldStyle(.plain)
                    .focused($titleIsFocused)
                    .submitLabel(.done)
                    // Return resigns focus; the focus change is the one commit,
                    // so a title is saved once and the field follows an Undo.
                    .onSubmit { titleIsFocused = false }
                    .onChange(of: titleIsFocused) { _, focused in
                        if focused == false { commitTitle(onEditTitle) }
                    }
                    .onAppear { titleDraft = day.summary ?? "" }
                    .onChange(of: day.summary) { _, summary in
                        if titleIsFocused == false { titleDraft = summary ?? "" }
                    }
                    .accessibilityLabel("Day title")
                    .accessibilityIdentifier("journal.day.title")
            } else if let summary = day.summary, summary.isEmpty == false {
                Text(summary).font(.headline)
            }
            if day.aiExclusion != .included {
                Label(
                    day.aiExclusion == .excludedFromAI
                        ? "Hidden from Eva"
                        : "Hidden from Eva and summaries",
                    systemImage: "sparkles.slash"
                )
                .font(.caption)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .accessibilityIdentifier("journal.day.exclusionBadge")
            }
            // Several sittings in one day read as separate entries: a three
            // hour gap, or "New entry", starts a new group. Storage stays one
            // record per day; the grouping is derived at read time.
            ForEach(groups) { group in
                if groups.count > 1 {
                    Text(JournalEntryGrouping.headerText(for: group))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .padding(.top, groups.first?.id == group.id ? 0 : 8)
                        .accessibilityIdentifier("journal.day.entry.\(group.id.uuidString)")
                }
                ForEach(group.blocks) { block in
                HStack(alignment: .top, spacing: 12) {
                    blockIcon(block)
                    VStack(alignment: .leading, spacing: 4) {
                        if let mood = block.mood {
                            Text("\(mood.displayName)\(block.energy.map { " · " + String(localized: "Energy \($0) of 5") } ?? "")")
                        }
                        if let reasonIDs = JournalMoodReasons.decode(block.text), reasonIDs.isEmpty == false {
                            // Why the mood was what it was, as chips.
                            HStack(spacing: 6) {
                                ForEach(reasonIDs, id: \.self) { id in
                                    Text(JournalMoodReasons.reason(id: id)?.title ?? id.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(SemanticColorTokens.foundationSurfaceRecessed).opacity(0.7), in: Capsule())
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Reasons: " + JournalMoodReasons.titles(for: reasonIDs).joined(separator: ", "))
                        } else if let text = block.text, !text.isEmpty {
                            if block.kind == .dayClose {
                                Text("Day closed").font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                            }
                            Text(text).font(.body)
                                .textSelection(.enabled)
                        } else if block.kind == .dayClose, let energy = block.energy {
                            Text("Day closed · Energy \(energy) of 5").font(.caption.weight(.semibold))
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                        if block.kind == .photo,
                           let media = day.media.first(where: { $0.id == block.mediaID }),
                           let payload = media.payload {
                            Button {
                                inspectedPhoto = media
                            } label: {
                                // Decoded off the main thread at display size
                                // and cached; a fixed height keeps the row
                                // from jumping when the image arrives.
                                JournalPhotoThumbnail(id: media.id, payload: payload, pointSide: 420)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                                    .lifeboardJournalMediaReveal(progress: mediaRevealProgress)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo")
                            .accessibilityHint("Opens full screen")
                        } else if block.kind == .photo {
                            unavailableAttachment(
                                title: String(localized: "Photo unavailable"),
                                detail: String(localized: "Restore a backup or remove it."),
                                symbol: "photo.badge.exclamationmark",
                                blockID: block.id
                            )
                        }
                        if block.kind == .audio,
                           let media = day.media.first(where: { $0.id == block.mediaID }),
                           media.relativePath?.isEmpty == false {
                            Button { playback.toggle(media) } label: {
                                Label(
                                    playback.playingMediaID == media.id ? "Stop recording" : "Play recording",
                                    systemImage: playback.playingMediaID == media.id ? "stop.circle.fill" : "play.circle.fill"
                                )
                            }
                            .buttonStyle(.borderless)
                            if let duration = media.duration {
                                Text(Self.duration(duration))
                                    .font(.caption)
                                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                            }
                        } else if block.kind == .audio {
                            unavailableAttachment(
                                title: String(localized: "Recording unavailable"),
                                detail: String(localized: "Restore a backup or remove it."),
                                symbol: "waveform.badge.exclamationmark",
                                blockID: block.id
                            )
                        }
                        Text(JournalBlockTextEdit.timestampLabel(for: block))
                            .font(.caption2)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                    Spacer(minLength: 4)
                    Menu {
                        blockMenuItems(block)
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(blockActionsLabel(block))
                }
                // Right-click and long-press on the block open the same
                // actions as its "…" menu. Selectable text inside keeps its
                // own Copy menu: the innermost context menu wins.
                .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .contextMenu { blockMenuItems(block) }
                }
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
        .sheet(item: $editingBlock) { block in
            JournalBlockTextEditor(initialText: block.text ?? "") { text in
                await onEditText?(block.id, text) ?? false
            }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { blockPendingDeletion != nil },
                set: { if $0 == false { blockPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete entry", role: .destructive) {
                if let blockID = blockPendingDeletion { onDeleteBlock(blockID) }
                blockPendingDeletion = nil
            }
            Button("Keep it", role: .cancel) { blockPendingDeletion = nil }
        } message: {
            Text("This can’t be undone.")
        }
        .confirmationDialog("Delete this day?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete day", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its text, check-ins, photos, and audio will be deleted.") }
        // `journalMediaReveal` is for media that was just committed. Replaying
        // it on every appear re-developed photos from months ago each time a
        // library row scrolled back into view, which says "this just arrived"
        // about something that did not.
        .onAppear { mediaRevealProgress = 1 }
        .onChange(of: day.blocks.count) { previous, updated in
            guard reduceMotion == false, updated > previous else { return }
            mediaRevealProgress = 0
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { mediaRevealProgress = 1 }
        }
        .onDisappear { playback.stop() }
        .sheet(item: $inspectedPhoto) { media in
            JournalPhotoInspector(media: media)
        }
    }

    private func commitTitle(_ save: @escaping (String) async -> Bool) {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (day.summary ?? "") else { return }
        Task { _ = await save(trimmed) }
    }

    @ViewBuilder
    private func blockIcon(_ block: JournalBlockValue) -> some View {
        if let mood = block.mood {
            Image(mood.faceAssetName).resizable().scaledToFit().frame(width: 28, height: 28)
                .accessibilityHidden(true)
        } else {
            Image(systemName: block.kind == .audio ? "waveform" : block.kind == .photo ? "photo" : block.kind == .dayClose ? "moon.stars" : "text.alignleft")
                .frame(width: 28)
                .accessibilityHidden(true)
        }
    }

    private func blockActionsLabel(_ block: JournalBlockValue) -> String {
        switch block.kind {
        case .photo: return String(localized: "Photo actions")
        case .audio: return String(localized: "Recording actions")
        case .mood: return String(localized: "Check-in actions")
        case .dayClose: return String(localized: "Day closed actions")
        default: return String(localized: "Entry actions")
        }
    }

    private static func duration(_ interval: TimeInterval) -> String {
        String(format: "%d:%02d", Int(interval) / 60, Int(interval) % 60)
    }

    private func unavailableAttachment(
        title: String,
        detail: String,
        symbol: String,
        blockID: UUID
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Button("Remove attachment", role: .destructive) {
                onDeleteBlock(blockID)
            }
            .font(.caption.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.color(for: .layerOne).opacity(0.22), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// The day's "…" menu content, shared by the menu button and the header's
    /// context menu so the two can never offer different actions.
    @ViewBuilder
    private func dayMenuItems(_ onSetAIExclusion: @escaping (JournalAIExclusion) -> Void) -> some View {
        Section("Eva") {
            if let onAskEva, day.aiExclusion == .included {
                Button("Ask Eva", systemImage: "bubble.left.and.text.bubble.right", action: onAskEva)
            }
            exclusionOption(.included, String(localized: "Visible to Eva"), "sparkles", onSetAIExclusion)
            exclusionOption(.excludedFromAI, String(localized: "Hide from Eva"), "sparkles.slash", onSetAIExclusion)
            exclusionOption(.excludedFromAIAndReflection, String(localized: "Hide from Eva and summaries"), "eye.slash", onSetAIExclusion)
        }
    }

    /// A block's "…" menu content, shared by the menu button and the block's
    /// context menu.
    @ViewBuilder
    private func blockMenuItems(_ block: JournalBlockValue) -> some View {
        if block.kind == .photo,
           let media = day.media.first(where: { $0.id == block.mediaID }),
           media.payload != nil {
            Button("View full screen", systemImage: "arrow.up.left.and.arrow.down.right") {
                inspectedPhoto = media
            }
            Button("Edit photo", systemImage: "crop.rotate") { onEditPhoto(media) }
        }
        if block.kind == .text, onEditText != nil {
            Button("Edit text", systemImage: "pencil") { editingBlock = block }
        }
        if day.blocks.first?.id != block.id {
            Button("Move earlier", systemImage: "arrow.up") { onMoveBlock(block.id, -1) }
        }
        if day.blocks.last?.id != block.id {
            Button("Move later", systemImage: "arrow.down") { onMoveBlock(block.id, 1) }
        }
        // Deleting a block removes the person's own words,
        // photo or audio. Deleting a whole day already asks
        // first; a single block was the one destructive path
        // here that did not. `DESIGN.md`: explain consequences
        // before a destructive action.
        Button("Delete entry", systemImage: "trash", role: .destructive) {
            blockPendingDeletion = block.id
        }
    }

    @ViewBuilder
    private func exclusionOption(
        _ exclusion: JournalAIExclusion,
        _ title: String,
        _ symbol: String,
        _ action: @escaping (JournalAIExclusion) -> Void
    ) -> some View {
        Button {
            action(exclusion)
        } label: {
            if day.aiExclusion == exclusion {
                Label(title, systemImage: "checkmark")
            } else {
                Label(title, systemImage: symbol)
            }
        }
    }

    private var exclusionAccessibilityValue: String {
        switch day.aiExclusion {
        case .included: return String(localized: "Visible to Eva")
        case .excludedFromAI: return String(localized: "Hidden from Eva")
        case .excludedFromAIAndReflection: return String(localized: "Hidden from Eva and summaries")
        }
    }
}
