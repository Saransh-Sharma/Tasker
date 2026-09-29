import Foundation
import LifeBoardDomain
import LifeBoardPersistence
import LifeBoardContracts

extension JournalStore {
    func loadReflections(weekContaining date: Date) async {
        reflectionPreviewWeek = date
        guard let reflectionRepository else {
            refreshReflectionPreview()
            reportProblem(String(localized: "Week summaries aren’t available on this device."))
            return
        }
        do {
            let reports = try await reflectionRepository.reports(weekContaining: date)
            reflectionReports = reports
            selectedReflectionID = reports.first?.id
            refreshReflectionPreview()
            reflectionSourceSelection = reports.first?.sourceSelection.includedEntryIDs
                ?? reflectionPreview?.sourceSelection.includedEntryIDs
                ?? []
        } catch is CancellationError {
            return
        } catch {
            refreshReflectionPreview()
            reportProblem(String(localized: "Couldn’t load past summaries.")) { [weak self] in
                await self?.loadReflections(weekContaining: date)
            }
        }
    }

    func selectReflection(id: UUID) {
        guard let report = reflectionReports.first(where: { $0.id == id }) else { return }
        selectedReflectionID = id
        reflectionSourceSelection = report.sourceSelection.includedEntryIDs
    }

    func toggleReflectionSource(_ entryID: UUID) {
        if reflectionSourceSelection.contains(entryID) {
            reflectionSourceSelection.remove(entryID)
        } else {
            reflectionSourceSelection.insert(entryID)
        }
    }

    func regenerateReflection(weekContaining date: Date) async {
        guard let reflectionRepository else { return }
        do {
            let selectedEntries = allDays
                .map(JournalEntrySnapshot.init(day:))
                .filter { reflectionSourceSelection.contains($0.id) }
            var report = WeeklyReflectionService.makeReport(
                entries: selectedEntries,
                weekContaining: date,
                previousVersions: reflectionReports
            )
            report.sourceSelection = WeeklyReflectionSourceSelection(
                includedEntryIDs: reflectionSourceSelection,
                excludesSensitiveEntries: true
            )
            try await reflectionRepository.save(report)
            await loadReflections(weekContaining: date)
            selectReflection(id: report.id)
        } catch is CancellationError {
            return
        } catch {
            reportProblem(String(localized: "Couldn’t save summary.")) { [weak self] in
                await self?.regenerateReflection(weekContaining: date)
            }
        }
    }

    func saveReflectionTakeaway(_ text: String) async {
        guard var report = selectedReflection, let reflectionRepository else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        report.takeaway = trimmed.isEmpty ? nil : trimmed
        do {
            try await reflectionRepository.save(report)
            replaceReflection(report)
        } catch {
            reportProblem(String(localized: "Couldn’t save takeaway.")) { [weak self] in
                await self?.saveReflectionTakeaway(text)
            }
        }
    }

    func setReflectionDismissed(_ isDismissed: Bool) async {
        guard var report = selectedReflection, let reflectionRepository else { return }
        report.dismissedAt = isDismissed ? Date() : nil
        do {
            try await reflectionRepository.save(report)
            replaceReflection(report)
        } catch {
            reportProblem(String(localized: "Couldn’t update summary.")) { [weak self] in
                await self?.setReflectionDismissed(isDismissed)
            }
        }
    }

    func deleteSelectedReflection(weekContaining date: Date) async {
        guard let report = selectedReflection, let reflectionRepository else { return }
        do {
            try await reflectionRepository.delete(id: report.id)
            await loadReflections(weekContaining: date)
        } catch {
            reportProblem(String(localized: "Couldn’t delete this version.")) { [weak self] in
                await self?.deleteSelectedReflection(weekContaining: date)
            }
        }
    }

    func startReflectionExport(format: JournalExportFormat, includesSensitiveFields: Bool) {
        guard let report = selectedReflection, let exportService else {
            exportPhase = .recoverableFailure(.init(message: String(localized: "Export isn’t available on this device."), recovery: .retry))
            return
        }
        exportTask?.cancel()
        lastExportFormat = format
        lastExportIncludedSensitiveFields = includesSensitiveFields
        exportPhase = .running(progress: nil)
        let entries = allDays.map(JournalEntrySnapshot.init(day:))
        exportTask = Task {
            do {
                let receipt = try await exportService.export(.init(
                    report: report,
                    entries: entries,
                    format: format,
                    includesSensitiveFields: includesSensitiveFields
                ))
                try Task.checkCancellation()
                exportPhase = .success(receipt: receipt)
            } catch is CancellationError {
                exportPhase = .cancelled
            } catch {
                exportPhase = .recoverableFailure(.init(message: String(localized: "Couldn’t prepare export."), recovery: .retry))
            }
        }
    }

    func cancelReflectionExport() {
        exportTask?.cancel()
        exportTask = nil
        exportPhase = .cancelled
    }

    func retryReflectionExport() {
        guard let lastExportFormat else { return }
        startReflectionExport(
            format: lastExportFormat,
            includesSensitiveFields: lastExportIncludedSensitiveFields
        )
    }

    func resetReflectionExport() {
        exportPhase = .idle
    }

    private func replaceReflection(_ report: WeeklyReflectionReport) {
        if let index = reflectionReports.firstIndex(where: { $0.id == report.id }) {
            reflectionReports[index] = report
        }
    }
}
