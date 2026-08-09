import SwiftUI
import SwiftData
import TranscriptionKit
import UIKit
import VisionKit

struct JournalDayRouteView: View {
    let id: UUID
    let repository: (any PhaseIIRepository)?
    @State private var state: RouteLoadState<JournalDayValue> = .loading

    var body: some View {
        EntityRouteScaffold(title: "Journal", systemImage: "book.closed", state: state) { day in
            VStack(alignment: .leading, spacing: 14) {
                Text(day.day.formatted(date: .complete, time: .omitted)).font(.title2.weight(.semibold))
                if let summary = day.summary, summary.isEmpty == false { Text(summary).font(.headline) }
                ForEach(day.blocks) { block in
                    if let text = block.text, text.isEmpty == false { Text(text).font(.body) }
                    if let mood = block.mood { Label(mood.title, systemImage: "face.smiling") }
                }
                if day.media.isEmpty == false { Label("\(day.media.count) private attachments", systemImage: "paperclip") }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Journal data is unavailable."); return }
        do { state = try await repository.fetchJournalDays(search: nil, starredOnly: false, mood: nil).first(where: { $0.id == id }).map(RouteLoadState.loaded) ?? .missing }
        catch { state = .failed(error.localizedDescription) }
    }
}

struct NoteRouteView: View {
    let id: UUID
    let repository: (any PhaseIIRepository)?
    @State private var state: RouteLoadState<KnowledgeNoteValue> = .loading

    var body: some View {
        EntityRouteScaffold(title: "Note", systemImage: "note.text", state: state) { note in
            VStack(alignment: .leading, spacing: 14) {
                Text(note.title).font(.title2.weight(.semibold))
                ForEach(note.blocks) { block in
                    if block.kind == .divider { Divider() }
                    else { Text(block.text).font(block.kind == .heading1 ? .title3.weight(.semibold) : .body) }
                }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Notes data is unavailable."); return }
        do { state = try await repository.fetchKnowledgeNotes(search: nil, spaceID: nil).first(where: { $0.id == id }).map(RouteLoadState.loaded) ?? .missing }
        catch { state = .failed(error.localizedDescription) }
    }
}
