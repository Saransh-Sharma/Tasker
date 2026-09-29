import Foundation
import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

struct KnowledgeGraphView: View {
    let notes: [KnowledgeNoteValue]
    let links: [KnowledgeLinkValue]
    let folders: [KnowledgeFolderValue]
    let tags: [KnowledgeTagValue]
    let onOpen: (KnowledgeNoteValue) -> Void
    // Committed zoom and pan, plus the in-flight gesture on top of them. The
    // gesture values used to replace the view's transform outright, so every
    // new pinch or drag started from 1x at the origin and the graph snapped
    // back; now each gesture continues from where the last one ended.
    @State private var committedScale: CGFloat = 1
    @State private var committedOffset = CGSize.zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var pan = CGSize.zero
    private static let scaleRange: ClosedRange<CGFloat> = 0.5...3
    @State private var searchText = ""
    @State private var selectedFolderID: UUID?
    @State private var selectedTagID: UUID?
    @State private var prefersList = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Past this many notes the labels collide, so only pinned notes keep
    /// theirs until the person zooms in.
    private static let labelledNoteLimit = 12
    private static let labelZoomThreshold: CGFloat = 1.6

    private var filteredNotes: [KnowledgeNoteValue] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return notes.filter { note in
            (query.isEmpty || note.title.lowercased().contains(query) || note.plainText.lowercased().contains(query))
                && (selectedFolderID == nil || note.folderID == selectedFolderID)
                && (selectedTagID.map { note.tagIDs.contains($0) } ?? true)
        }
    }

    private var filteredLinks: [KnowledgeLinkValue] {
        let ids = Set(filteredNotes.map(\.id))
        return links.filter { ids.contains($0.sourceNoteID) && ids.contains($0.destinationNoteID) }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search graph", text: $searchText, prompt: Text("Search graph").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                .textFieldStyle(.plain)
                // Clay well, not the system rounded border: that drew a pure white
                // box on warm paper and a pure black one in dark appearance.
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                .padding(.horizontal, 20)
            HStack {
                filterMenu(title: "Folder", selection: $selectedFolderID, values: folders.map { ($0.id, $0.title) })
                filterMenu(title: "Tag", selection: $selectedTagID, values: tags.map { ($0.id, $0.name) })
                Spacer()
                if isTransformed && prefersList == false && voiceOverEnabled == false {
                    Button("Reset view", systemImage: "arrow.counterclockwise") {
                        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                            committedScale = 1
                            committedOffset = .zero
                        }
                    }
                    .labelStyle(.iconOnly)
                    .minimumHitTarget()
                    .accessibilityLabel("Reset graph view")
                }
                Button(prefersList ? "Graph" : "List", systemImage: prefersList ? "point.3.connected.trianglepath.dotted" : "list.bullet") {
                    prefersList.toggle()
                }
            }
            .padding(.horizontal, 20)
            if prefersList || voiceOverEnabled {
                List(filteredNotes) { note in
                    Button { onOpen(note) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title.isEmpty ? "Untitled" : note.title).font(.headline)
                            Text(note.plainText).font(.caption).foregroundStyle(Color.lifeboard(.textSecondary)).lineLimit(2)
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                graph
            }
        }
    }

    private var graph: some View {
        GeometryReader { proxy in
            if filteredNotes.isEmpty {
                ContentUnavailableView("No connections yet", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Link notes to see them here.").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
            } else {
                let positions = graphPositions(for: filteredNotes, in: proxy.size)
                let showsAllLabels = filteredNotes.count <= Self.labelledNoteLimit
                    || Self.clampedScale(committedScale * pinch) >= Self.labelZoomThreshold
                ZStack {
                    Canvas { context, _ in
                        for link in filteredLinks {
                            guard let start = positions[link.sourceNoteID], let end = positions[link.destinationNoteID] else { continue }
                            var path = Path(); path.move(to: start); path.addLine(to: end)
                            context.stroke(path, with: .color(Color.lifeboard(.textPrimary).opacity(0.24)), lineWidth: 1.5)
                        }
                    }
                    ForEach(filteredNotes) { note in
                        if let position = positions[note.id] {
                            Button { onOpen(note) } label: {
                                VStack(spacing: 4) {
                                    Circle().fill(.tint).frame(width: note.isPinned ? 34 : 26, height: note.isPinned ? 34 : 26)
                                    Text(note.title.isEmpty ? "Untitled" : note.title)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .frame(width: 88)
                                        .opacity(showsAllLabels || note.isPinned ? 1 : 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(note.title.isEmpty ? "Untitled" : note.title)
                            .position(position)
                        }
                    }
                }
                .scaleEffect(Self.clampedScale(committedScale * pinch))
                .offset(
                    x: committedOffset.width + pan.width,
                    y: committedOffset.height + pan.height
                )
                .gesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            committedScale = Self.clampedScale(committedScale * value.magnification)
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .updating($pan) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            committedOffset.width += value.translation.width
                            committedOffset.height += value.translation.height
                        }
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Graph: \(filteredNotes.count) notes, \(filteredLinks.count) links")
            }
        }
        .padding(12)
    }

    private var isTransformed: Bool {
        committedScale != 1 || committedOffset != .zero
    }

    private static func clampedScale(_ value: CGFloat) -> CGFloat {
        min(scaleRange.upperBound, max(scaleRange.lowerBound, value))
    }

    private func graphPositions(for notes: [KnowledgeNoteValue], in size: CGSize) -> [UUID: CGPoint] {
        let radius = max(70, min(size.width, size.height) * 0.34)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // The first dozen share the inner ring and the rest the outer one,
        // each spread evenly around its own ring. Both used to share one
        // angle sequence, which bunched the inner ring into an arc.
        let innerCount = min(notes.count, Self.labelledNoteLimit)
        let outerCount = max(0, notes.count - innerCount)
        return Dictionary(uniqueKeysWithValues: notes.enumerated().map { index, note in
            let isInner = index < innerCount
            let slot = isInner ? index : index - innerCount
            let slots = isInner ? innerCount : outerCount
            let angle = (Double(slot) / Double(max(1, slots))) * .pi * 2 - .pi / 2
            let ring = isInner && outerCount > 0 ? radius * 0.62 : radius
            return (note.id, CGPoint(x: center.x + cos(angle) * ring, y: center.y + sin(angle) * ring))
        })
    }

    private func filterMenu(
        title: String,
        selection: Binding<UUID?>,
        values: [(id: UUID, title: String)]
    ) -> some View {
        Menu {
            Button("All") { selection.wrappedValue = nil }
            ForEach(values, id: \.id) { value in
                Button(value.title) { selection.wrappedValue = value.id }
            }
        } label: {
            Label(title, systemImage: selection.wrappedValue == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .buttonStyle(.lifeBoardChip)
    }
}
