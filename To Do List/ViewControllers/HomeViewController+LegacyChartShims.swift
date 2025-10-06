//
//  HomeViewController+LegacyChartShims.swift
//  To Do List
//
//  Created by Cascade on 28/06/25.
//
//  Temporary compatibility shims that forward legacy DGCharts-related
//  calls to the new SwiftUI `TaskProgressCard` implementation so the
//  codebase continues to compile while the remaining migration work
//  is completed.
//
//  IMPORTANT: All usages of these legacy methods should eventually be
//  removed. These stubs are purely to restore the build.
//

import UIKit
import DGCharts

extension HomeViewController {
    /// Legacy call-site wrapper. Simply forwards to the new SwiftUI chart update.
    @objc func updateLineChartData() {
        // Phase 7: The horizontally scrollable chart cards handle their own data calculation. Just refresh them.
        updateChartCardsScrollView()
    }

    /// Legacy no-op. Animation is now handled natively inside the SwiftUI view.
    /// Provided only so existing callers compile.
    @objc func animateLineChart(chartView: LineChartView) {
        // No longer applicable – the SwiftUI chart animates internally.
    }

    /// Legacy placeholder. Chart setup is now done in `setupSwiftUIChartCard()`.
    /// This stub prevents unresolved symbol errors from older call-sites.
    @objc func setupChartsInBackdrop() {
        // Ensure the SwiftUI card is present once.
        if swiftUIChartContainer == nil {
            setupSwiftUIChartCard()
        }
    }
}
