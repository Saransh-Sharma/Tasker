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

struct TrackerHistoryView: View {
    let tracker: TrackerDefinitionValue
    let entries: [TrackerEntryValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (TrackerEntryValue, TrackerValue, String?) async -> Bool
    @State private var correcting: TrackerEntryValue?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No entries yet", systemImage: "chart.xyaxis.line")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            historySummary
                                .padding(.bottom, 24)

                            HStack {
                                Text("Entries")
                                    .font(Typography.sectionTitle())
                                Spacer()
                                Text("Tap to correct")
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            .padding(.bottom, 8)

                            ForEach(sortedEntries.prefix(30)) { entry in
                                HStack(spacing: 12) {
                                    Button {
                                        Haptic.pick.play()
                                        correcting = entry
                                    } label: {
                                        ViewThatFits(in: .horizontal) {
                                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                                historyValue(entry)
                                                Spacer(minLength: 8)
                                                historyTimestamp(entry)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                historyValue(entry)
                                                historyTimestamp(entry)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Menu {
                                        Button("Correct entry", systemImage: "pencil") {
                                            correcting = entry
                                        }
                                        if let receipt = activeReceipt(entry.id) {
                                            Button("Undo correction", systemImage: "arrow.uturn.backward") {
                                                Task { await onUndo(receipt) }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("Actions for entry from \(entry.timestamp.formatted())")
                                }
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color(SemanticColorTokens.foundationHairline))
                                        .frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(tracker.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $correcting) { entry in
                TrackerValueCaptureView(
                    tracker: tracker,
                    entry: entry,
                    title: "Correct entry"
                ) { value, note, _ in
                    let succeeded = await onCorrect(entry, value, note)
                    if succeeded { correcting = nil }
                    return succeeded
                }
            }
        }
        .presentationCornerRadius(28)
    }

    private var sortedEntries: [TrackerEntryValue] {
        entries.sorted { $0.timestamp > $1.timestamp }
    }

    private var hasChartData: Bool {
        (recentMagnitudes?.isEmpty == false)
    }

    /// The sweep draws once, when valid data first appears. An empty or
    /// unavailable history never sweeps: a reveal animation implies data
    /// arrived.
    @State private var chartRevealProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var historySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("^[\(entries.count) entry](inflect: true)")
                        .font(Typography.sectionTitle().weight(.bold))
                        .contentTransition(.numericText())
                    Text(lastRecordedDescription)
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer()
                Label(tracker.effectiveAggregation.displayName, systemImage: "function")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }

            if let magnitudes = recentMagnitudes, magnitudes.isEmpty == false {
                if magnitudes.count == 1, let entry = sortedEntries.first {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(SemanticColorTokens.foundationSageInk))
                            .frame(width: 9, height: 9)
                        Text("First value")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        Spacer()
                        Text(value(entry))
                            .font(.body.weight(.semibold).monospacedDigit())
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(
                        Color(SemanticColorTokens.foundationSurfaceRecessed),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                } else {
                    GeometryReader { proxy in
                        let maximum = max(magnitudes.max() ?? 1, 1)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(Array(magnitudes.enumerated()), id: \.offset) { _, magnitude in
                                // Ink: a bar is a mark on paper, and the pale
                                // accent fell below 3:1 against the card.
                                Capsule()
                                    .fill(Color(SemanticColorTokens.foundationSageInk))
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: 6,
                                        maxHeight: max(6, proxy.size.height * CGFloat(magnitude / maximum))
                                    )
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 64 : 78)
                    // Driven, not pinned. Hardcoding `progress: 1` left this
                    // chart permanently settled, so its reveal could never play
                    // — the effect was wired but inert.
                    .lifeboardChartRevealSweep(progress: chartRevealProgress)
                    // Hidden from VoiceOver, this chart's evidence simply did
                    // not exist for anyone using it. `DESIGN.md` asks charts for
                    // a prose or table equivalent.
                    .accessibilityElement()
                    .accessibilityLabel("Recent entries, newest last")
                    // The values the bars draw, oldest to newest. `entries`
                    // is newest-first, so `suffix(7)` read the oldest seven.
                    .accessibilityValue(
                        recentChartEntries.map(value).joined(separator: ", ")
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .onAppear { chartRevealProgress = hasChartData ? 1 : 0 }
        .onChange(of: hasChartData) { _, nowHasData in
            guard nowHasData, chartRevealProgress == 0 else { return }
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { chartRevealProgress = 1 }
        }
        .privacySensitive(tracker.effectivePrivacyClass != .standard)
        .accessibilityIdentifier("track.tracker.history.summary")
    }

    private var lastRecordedDescription: String {
        guard let latest = sortedEntries.first else { return String(localized: "Nothing logged yet") }
        let when = latest.timestamp.formatted(.relative(presentation: .named))
        return String(localized: "Last logged \(when)")
    }

    /// The entries behind the bars, oldest first.
    private var recentChartEntries: [TrackerEntryValue] {
        sortedEntries.prefix(12).reversed().filter { magnitude($0) != nil }
    }

    private var recentMagnitudes: [Double]? {
        let values = sortedEntries.prefix(12).reversed().compactMap { magnitude($0) }
        return values.isEmpty ? nil : values
    }

    private func magnitude(_ entry: TrackerEntryValue) -> Double? {
        if let value = entry.value {
            switch value {
            case .boolean(let flag): return flag ? 1 : 0
            case .count(let count): return Double(count)
            case .quantity(let number, _), .rating(let number): return max(0, number)
            case .duration(let seconds): return max(0, seconds)
            case .text, .choice, .timestamp: return nil
            }
        }
        if let number = entry.numericValue { return max(0, number) }
        if let flag = entry.booleanValue { return flag ? 1 : 0 }
        return nil
    }

    private func historyValue(_ entry: TrackerEntryValue) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value(entry))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            if let note = entry.note, note.isEmpty == false {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .lineLimit(2)
            }
        }
    }

    private func historyTimestamp(_ entry: TrackerEntryValue) -> some View {
        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
    }

    private func value(_ entry: TrackerEntryValue) -> String {
        if let value = entry.value {
            switch value {
            case .boolean(let value): return value ? String(localized: "Yes") : String(localized: "No")
            case .count(let value): return value.formatted()
            case .quantity(let value, let unit):
                return [value.formatted(), unit].compactMap { $0 }.joined(separator: " ")
            case .rating(let value): return value.formatted()
            case .duration(let seconds):
                return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes]))
            case .text(let value), .choice(let value): return value
            case .timestamp(let value): return value.formatted(date: .abbreviated, time: .shortened)
            }
        }
        if let number = entry.numericValue { return [number.formatted(), tracker.unitLabel].compactMap { $0 }.joined(separator: " ") }
        if let boolean = entry.booleanValue { return boolean ? String(localized: "Done") : String(localized: "Not done") }
        return entry.note ?? String(localized: "Logged")
    }
}
