import Foundation
import LifeBoardDomain
import SwiftUI
import UIKit
import LifeBoardContracts

extension JournalModuleView {
    @ViewBuilder
    func weeklyReflection(report: WeeklyReflectionReport, palette: DaypartPalette) -> some View {
        let weekEntries = store.allDays.filter { day in
            day.day >= report.weekStart && day.day <= report.weekEnd
        }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader("Week summary")
                            .accessibilityIdentifier("journal.weeklyReflection.header")
                        Spacer()
                        if store.reflectionReports.count > 1 {
                            Menu {
                                ForEach(store.reflectionReports) { version in
                                    Button {
                                        store.selectReflection(id: version.id)
                                    } label: {
                                        Label(
                                            "Version \(version.version) · \(version.createdAt.formatted(date: .abbreviated, time: .shortened))",
                                            systemImage: version.id == report.id ? "checkmark" : "clock.arrow.circlepath"
                                        )
                                    }
                                }
                            } label: {
                                Label("Versions", systemImage: "clock.arrow.circlepath")
                                    .labelStyle(.iconOnly)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Earlier versions")
                            .accessibilityValue("Showing version \(report.version) of \(store.reflectionReports.count)")
                        }
                        Text(report.density.displayTitle)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(palette.color(for: .canvasSecondary), in: Capsule())
                    }
                    Text("\(report.weekStart.formatted(.dateTime.month(.abbreviated).day()))–\(report.weekEnd.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(report.summary)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    if let takeaway = report.takeaway, takeaway.isEmpty == false {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Takeaway").font(.caption.weight(.semibold))
                            Text(takeaway)
                        }
                        .padding(.top, 2)
                    }
                    if !report.sourceSelection.includedEntryIDs.isEmpty {
                        Label(
                            report.sourceSelection.includedEntryIDs.count == 1
                                ? String(localized: "Based on 1 day")
                                : String(localized: "Based on \(report.sourceSelection.includedEntryIDs.count) days"),
                            systemImage: "quote.bubble"
                        )
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                    if report.dismissedAt != nil {
                        Label("Hidden", systemImage: "archivebox")
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .lifeBoardPaperCard()
                .lifeboardMemoryDevelopReveal(progress: reflectionDevelopProgress)
                .onAppear { developReflectionIfNeeded(report.id) }
                .onChange(of: report.id) { _, id in developReflectionIfNeeded(id) }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Menu {
                            if weekEntries.isEmpty {
                                Text("No entries this week")
                            } else {
                                ForEach(weekEntries) { day in
                                    Button {
                                        store.toggleReflectionSource(day.id)
                                    } label: {
                                        Label(
                                            day.day.formatted(date: .abbreviated, time: .omitted),
                                            systemImage: store.reflectionSourceSelection.contains(day.id) ? "checkmark.circle.fill" : "circle"
                                        )
                                    }
                                }
                            }
                        } label: {
                            Label("Days", systemImage: "quote.bubble")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.lifeBoardChip)

                        Button {
                            Task { await store.regenerateReflection(weekContaining: reflectionWeekDate) }
                        } label: {
                            Label(store.reflectionReports.isEmpty ? "Save" : "Regenerate", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .disabled(report.density != .empty && store.reflectionSourceSelection.isEmpty)
                        .accessibilityIdentifier("journal.reflection.regenerate")
                    }

                    HStack(spacing: 12) {
                        Button {
                            takeawayDraft = report.takeaway ?? ""
                            showsTakeawayEditor = true
                        } label: {
                            Label(report.takeaway == nil ? "Add takeaway" : "Edit takeaway", systemImage: "bookmark")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.lifeBoardChip)
                        .disabled(store.selectedReflection == nil)

                        Menu {
                            ForEach(JournalExportFormat.allCases, id: \.self) { format in
                                Button(format.displayTitle) {
                                    store.startReflectionExport(
                                        format: format,
                                        includesSensitiveFields: privacy.policy.excludesSensitiveEntriesFromExport == false
                                    )
                                }
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.lifeBoardChip)
                        .disabled(store.selectedReflection == nil)

                        Menu {
                            Button(report.dismissedAt == nil ? "Hide" : "Restore") {
                                Task { await store.setReflectionDismissed(report.dismissedAt == nil) }
                            }
                            Button("Delete version", role: .destructive) { confirmsReflectionDeletion = true }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.lifeBoardChip)
                        .disabled(store.selectedReflection == nil)
                        .accessibilityLabel("More actions")
                    }
                    reflectionExportStatus(palette: palette)
                }
    }

    private func developReflectionIfNeeded(_ id: UUID) {
        guard developedReflectionID != id else { return }
        developedReflectionID = id
        reflectionDevelopProgress = 0
        withAnimation(MotionProfile.ambient.animation(reduceMotion: reduceMotion)) {
            reflectionDevelopProgress = 1
        }
    }

    @ViewBuilder
    private func reflectionExportStatus(palette: DaypartPalette) -> some View {
        switch store.exportPhase {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 12) {
                JournalWorkIndicator(isActive: true)
                Text("Exporting…").font(.caption)
                Spacer()
                Button("Cancel") { store.cancelReflectionExport() }
            }
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .accessibilityIdentifier("journal.export.running")
        case .success(let receipt):
            AsyncActionControl(
                title: "Export",
                runningTitle: "Preparing",
                successTitle: receipt.redactedSensitiveFields ? "Share redacted export" : "Share export",
                phase: store.exportPhase
            ) {
                shareReceipt = receipt
            }
            .accessibilityIdentifier("journal.export.share")
        case .recoverableFailure(let failure):
            VStack(alignment: .leading, spacing: 8) {
                Label(failure.message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                AsyncActionControl(
                    title: "Export",
                    runningTitle: "Preparing",
                    successTitle: "Share export",
                    phase: store.exportPhase,
                    action: store.retryReflectionExport
                )
            }
            .foregroundStyle(palette.color(for: .foregroundSecondary))
        case .cancelled:
            HStack {
                Text("Export cancelled").font(.caption)
                Spacer()
                Button("Dismiss") { store.resetReflectionExport() }
            }
            .foregroundStyle(palette.color(for: .foregroundSecondary))
        }
    }

    func insightTile(_ title: String, value: String, symbol: String, palette: DaypartPalette) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
            Text(value).font(.title2.weight(.semibold))
            Text(title).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .lifeBoardPaperCard()
    }

    func proactiveInsightCard(
        _ insight: ReflectionInsight,
        palette: DaypartPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: proactiveInsightSymbol(insight))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 32, height: 32)
                    .background(Color.lifeboard(.accentPrimary).opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.category.displayTitle)
                        .font(Typography.metadata())
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(insight.title)
                        .font(.headline)
                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                Spacer(minLength: 4)
                Menu {
                    Button(store.isSaved(insight) ? "Remove from saved" : "Save for later") {
                        Task { await store.toggleSaved(insight) }
                    }
                    Button("Remind me tomorrow") {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
                        Task { await store.snooze(insight, until: tomorrow) }
                    }
                    Button("Dismiss", role: .destructive) {
                        Task { await store.dismiss(insight) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Actions for \(insight.title)")
            }

            if insight.evidence.isEmpty == false {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(insight.evidence.prefix(4)) { evidence in
                            Button {
                                router?.openProtectedJournalRoute(.journalDay(evidence.entryID), in: .track)
                            } label: {
                                Label(
                                    evidence.date.formatted(.dateTime.month(.abbreviated).day()),
                                    systemImage: evidence.role == .baseline ? "clock.arrow.circlepath" : "quote.bubble"
                                )
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 11)
                                .frame(minHeight: 44)
                                .background(palette.color(for: .canvasSecondary), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the entry")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: 8) {
                Label(insight.confidence.displayTitle, systemImage: "checkmark.seal")
                Text("•")
                Text(insight.explanation)
                    .lineLimit(2)
            }
            .font(.caption2)
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .lifeBoardPaperCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.proactive.\(insight.id)")
    }

    private func proactiveInsightSymbol(_ insight: ReflectionInsight) -> String {
        switch insight.kind {
        case .decisionFollowUp: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .weeklyRecap: return "calendar.badge.clock"
        case .moodTrajectory, .moodAssociation: return "waveform.path.ecg"
        case .resurfacedThread, .quietEntity: return "point.3.connected.trianglepath.dotted"
        case .repeatedQuestion: return "questionmark.bubble"
        case .carryForward: return "leaf"
        default: return "sparkles"
        }
    }
}

// Plain words for the reflection enums the Patterns lens shows. Their raw
// values are storage keys, not copy.
private extension WeeklyReflectionReport.Density {
    var displayTitle: String {
        switch self {
        case .empty: return String(localized: "Nothing yet")
        case .light: return String(localized: "A few days")
        case .full: return String(localized: "Full week")
        }
    }
}

private extension ReflectionInsight.Category {
    var displayTitle: String {
        switch self {
        case .pattern: return String(localized: "Pattern")
        case .decision: return String(localized: "Decision follow-up")
        case .weekly: return String(localized: "This week")
        case .prompt: return String(localized: "To consider")
        }
    }
}

private extension ReflectionInsight.Confidence {
    var displayTitle: String {
        switch self {
        case .low: return String(localized: "Early sign")
        case .medium: return String(localized: "Showing up")
        case .high: return String(localized: "Clear pattern")
        }
    }
}

private extension JournalExportFormat {
    /// The raw value is the stored format key; this is the menu label.
    var displayTitle: String {
        switch self {
        case .json: return String(localized: "JSON")
        case .markdown: return String(localized: "Markdown")
        case .csv: return String(localized: "CSV")
        case .pdf: return String(localized: "PDF")
        }
    }
}
