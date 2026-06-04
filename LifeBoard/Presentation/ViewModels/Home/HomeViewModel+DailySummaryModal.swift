//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    public func taskSnapshot(for taskID: UUID) -> TaskDefinition? {
        currentTaskSnapshot(for: taskID)
    }

    public func loadDailySummaryModal(
        kind: LifeBoardDailySummaryKind,
        dateStamp: String?,
        completion: @escaping @Sendable (Result<DailySummaryModalData, Error>) -> Void
    ) {
        let date = Self.summaryDate(from: dateStamp) ?? Date()
        let normalizedDateStamp = Self.summaryDateStamp(from: date)

        getDailySummaryModalUseCase.execute(kind: kind, date: date) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let summary):
                    self?.trackHomeInteraction(
                        action: "daily_summary_modal_opened",
                        metadata: [
                            "kind": kind.rawValue,
                            "date_stamp": normalizedDateStamp,
                            "source": "notification",
                            "snapshot": summary.analyticsSnapshot.metadataValue
                        ]
                    )
                    completion(.success(summary))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func trackDailySummaryCTA(
        kind: LifeBoardDailySummaryKind,
        cta: String,
        countsSnapshot: DailySummaryAnalyticsSnapshot
    ) {
        trackHomeInteraction(
            action: "daily_summary_cta_tapped",
            metadata: [
                "kind": kind.rawValue,
                "cta": cta,
                "counts_snapshot": countsSnapshot.metadataValue
            ]
        )
    }

    public func trackDailySummaryActionResult(cta: String, success: Bool, error: Error?) {
        trackDailySummaryActionResult(cta: cta, success: success, errorDescription: error?.localizedDescription)
    }

    public func trackDailySummaryActionResult(cta: String, success: Bool, errorDescription: String?) {
        var metadata: [String: Any] = [
            "cta": cta,
            "success": success
        ]
        if let errorDescription {
            metadata["error"] = errorDescription
        }
        trackHomeInteraction(
            action: "daily_summary_action_result",
            metadata: metadata
        )
    }
}
