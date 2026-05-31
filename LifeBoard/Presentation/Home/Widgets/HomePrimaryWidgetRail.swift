//
//  HomePrimaryWidgetRail.swift
//  LifeBoard
//

import SwiftUI
import UIKit

enum HomePrimaryWidgetKind: String, Equatable, CaseIterable, Identifiable {
    case focusNow
    case weeklyOperating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusNow:
            return "Focus Now"
        case .weeklyOperating:
            return "This week"
        }
    }

    var indicatorTitle: String {
        switch self {
        case .focusNow:
            return "Focus"
        case .weeklyOperating:
            return "Weekly"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .focusNow:
            return "home.primaryWidget.page.focusNow"
        case .weeklyOperating:
            return "home.primaryWidget.page.weeklyOperating"
        }
    }

    var indicatorAccessibilityIdentifier: String {
        switch self {
        case .focusNow:
            return "home.primaryWidget.indicator.focusNow"
        case .weeklyOperating:
            return "home.primaryWidget.indicator.weeklyOperating"
        }
    }
}

struct HomePrimaryWidgetRailState: Equatable {
    let widgets: [HomePrimaryWidgetKind]

    static func build(
        tasksSnapshot: HomeTasksSnapshot,
        chromeSnapshot: HomeChromeSnapshot
    ) -> HomePrimaryWidgetRailState {
        var widgets: [HomePrimaryWidgetKind] = []

        if !tasksSnapshot.focusNowSectionState.rows.isEmpty {
            widgets.append(.focusNow)
        }

        if tasksSnapshot.activeQuickView == .today,
           chromeSnapshot.weeklySummary != nil {
            widgets.append(.weeklyOperating)
        }

        return HomePrimaryWidgetRailState(widgets: widgets)
    }

    var isVisible: Bool { !widgets.isEmpty }
    var isSingleWidget: Bool { widgets.count <= 1 }
}

enum HomePrimaryWidgetDefaultPolicy {
    static func resolve(
        availableWidgets: [HomePrimaryWidgetKind],
        currentSelection: HomePrimaryWidgetKind?,
        userHasInteracted: Bool
    ) -> HomePrimaryWidgetKind? {
        guard !availableWidgets.isEmpty else { return nil }

        if userHasInteracted,
           let currentSelection,
           availableWidgets.contains(currentSelection) {
            return currentSelection
        }

        if availableWidgets.contains(.focusNow) {
            return .focusNow
        }

        if availableWidgets.contains(.weeklyOperating) {
            return .weeklyOperating
        }

        return availableWidgets.first
    }
}

private struct HomePrimaryWidgetPage: Identifiable {
    let kind: HomePrimaryWidgetKind
    let content: AnyView

    var id: HomePrimaryWidgetKind { kind }
}

private struct HomePrimaryWidgetHostedPage: Identifiable {
    let kind: HomePrimaryWidgetKind
    let content: AnyView

    var id: HomePrimaryWidgetKind { kind }
}

private struct HomePrimaryWidgetHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [HomePrimaryWidgetKind: CGFloat] = [:]

    static func reduce(value: inout [HomePrimaryWidgetKind: CGFloat], nextValue: () -> [HomePrimaryWidgetKind: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct HomePrimaryWidgetRail: View {
    let pages: [HomePrimaryWidgetPage]
    let selectedKind: HomePrimaryWidgetKind?
    let onSelectionChange: (HomePrimaryWidgetKind, Bool) -> Void

    @State private var measuredHeights: [HomePrimaryWidgetKind: CGFloat] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            GeometryReader { proxy in
                let viewportWidth = max(proxy.size.width, 1)
                let pageWidth = resolvedPageWidth(for: viewportWidth)

                HomePrimaryWidgetPagerRepresentable(
                    pages: hostedPages,
                    selectedKind: selectedKind,
                    pageWidth: pageWidth,
                    pageHeight: resolvedContentHeight,
                    isScrollEnabled: pages.count > 1,
                    onSelectionChange: { kind in
                        onSelectionChange(kind, true)
                    }
                )
                .frame(height: resolvedContentHeight)
                .background(alignment: .topLeading) {
                    measurementLayer(pageWidth: pageWidth, selectedKind: selectedKind)
                }
            }
            .frame(height: resolvedContentHeight)

            indicatorRow
                .accessibilityIdentifier("home.primaryWidget.indicator")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.primaryWidgetRail")
        .onPreferenceChange(HomePrimaryWidgetHeightPreferenceKey.self) { heights in
            guard heights.isEmpty == false else { return }
            var updated = measuredHeights
            updated.merge(heights, uniquingKeysWith: { _, next in next })
            let validKinds = Set(pages.map(\.kind))
            updated = updated.filter { validKinds.contains($0.key) }
            guard updated != measuredHeights else { return }
            measuredHeights = updated
        }
    }

    private var hostedPages: [HomePrimaryWidgetHostedPage] {
        pages.enumerated().map { index, page in
            HomePrimaryWidgetHostedPage(
                kind: page.kind,
                content: AnyView(
                    pageShell(
                        for: page,
                        isActive: page.kind == selectedKind,
                        position: index + 1,
                        total: pages.count
                    )
                )
            )
        }
    }

    private var resolvedContentHeight: CGFloat {
        let measured = measuredHeights.values.max() ?? 0
        return max(measured, fallbackContentHeight)
    }

    private var fallbackContentHeight: CGFloat {
        if pages.contains(where: { $0.kind == .weeklyOperating }) {
            return 244
        }
        return 184
    }

    private func resolvedPageWidth(for viewportWidth: CGFloat) -> CGFloat {
        guard pages.count > 1 else { return viewportWidth }
        let peekInset = layoutClass.isPad ? spacing.s20 : spacing.s16
        return max(viewportWidth - (peekInset * 2), viewportWidth * 0.88)
    }

    private func pageShell(
        for page: HomePrimaryWidgetPage,
        isActive: Bool,
        position: Int,
        total: Int,
        includesAccessibility: Bool = true
    ) -> some View {
        page.content
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: corner.r3, style: .continuous)
                    .fill(Color.lifeboard.surfacePrimary.opacity(isActive ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r3, style: .continuous)
                    .stroke(
                        isActive
                            ? Color.lifeboard.accentPrimary.opacity(0.22)
                            : Color.lifeboard.strokeHairline.opacity(0.48),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isActive ? Color.lifeboard.accentPrimary.opacity(0.10) : .clear,
                radius: isActive ? 12 : 0,
                y: isActive ? 8 : 0
            )
            .scaleEffect(reduceMotion ? 1.0 : (isActive ? 1.0 : 0.988))
            .animation(reduceMotion ? nil : LifeBoardAnimation.stateChange, value: isActive)
            .modifier(
                HomePrimaryWidgetPageAccessibilityModifier(
                    page: page,
                    position: position,
                    total: total,
                    isEnabled: includesAccessibility
                )
            )
    }

    @ViewBuilder
    private func measurementLayer(pageWidth: CGFloat, selectedKind: HomePrimaryWidgetKind?) -> some View {
        if let measurementPage = page(for: selectedKind) ?? pages.first {
            pageShell(
                for: measurementPage,
                isActive: true,
                position: 1,
                total: max(pages.count, 1),
                includesAccessibility: false
            )
            .frame(width: pageWidth)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: HomePrimaryWidgetHeightPreferenceKey.self,
                        value: [measurementPage.kind: proxy.size.height]
                    )
                }
            )
            .fixedSize(horizontal: false, vertical: true)
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func page(for selectedKind: HomePrimaryWidgetKind?) -> HomePrimaryWidgetPage? {
        guard let selectedKind else { return nil }
        return pages.first(where: { $0.kind == selectedKind })
    }

    private var indicatorRow: some View {
        HStack(spacing: spacing.s8) {
            ForEach(Array(pages.indices), id: \.self) { pageIndex in
                indicatorButton(for: pages[pageIndex])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func indicatorButton(for page: HomePrimaryWidgetPage) -> some View {
        let isSelected = page.kind == selectedKind

        return Button {
            onSelectionChange(page.kind, true)
        } label: {
            Text(page.kind.indicatorTitle)
                .font(.lifeboard(.caption1).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.lifeboard.textPrimary : Color.lifeboard.textSecondary)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? Color.lifeboard.accentPrimary.opacity(0.14)
                                : Color.lifeboard.surfaceSecondary.opacity(0.8)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityIdentifier(page.kind.indicatorAccessibilityIdentifier)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}

private struct HomePrimaryWidgetPageAccessibilityModifier: ViewModifier {
    let page: HomePrimaryWidgetPage
    let position: Int
    let total: Int
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(page.kind.accessibilityIdentifier)
                .accessibilityLabel("\(page.kind.title), \(position) of \(total)")
                .accessibilityHint(total > 1 ? "Swipe horizontally to switch widgets" : "")
        } else {
            content
                .accessibilityHidden(true)
        }
    }
}

private struct HomePrimaryWidgetPagerRepresentable: UIViewControllerRepresentable {
    let pages: [HomePrimaryWidgetHostedPage]
    let selectedKind: HomePrimaryWidgetKind?
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let isScrollEnabled: Bool
    let onSelectionChange: (HomePrimaryWidgetKind) -> Void

    func makeUIViewController(context: Context) -> HomePrimaryWidgetPagerController {
        HomePrimaryWidgetPagerController(
            pages: pages,
            selectedKind: selectedKind,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            isScrollEnabled: isScrollEnabled,
            onSelectionChange: onSelectionChange
        )
    }

    func updateUIViewController(_ uiViewController: HomePrimaryWidgetPagerController, context: Context) {
        uiViewController.apply(
            pages: pages,
            selectedKind: selectedKind,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            isScrollEnabled: isScrollEnabled,
            animated: context.transaction.animation != nil
        )
    }
}

private final class HomePrimaryWidgetPagerController: UICollectionViewController {
    private enum Constants {
        static let cellReuseIdentifier = "HomePrimaryWidgetPagerCell"
    }

    private var pages: [HomePrimaryWidgetHostedPage]
    private var selectedKind: HomePrimaryWidgetKind?
    private var pageWidth: CGFloat
    private var pageHeight: CGFloat
    private var isScrollEnabledForRail: Bool
    private let onSelectionChange: (HomePrimaryWidgetKind) -> Void

    private var didApplyInitialSelection = false
    private var isProgrammaticScroll = false

    init(
        pages: [HomePrimaryWidgetHostedPage],
        selectedKind: HomePrimaryWidgetKind?,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        isScrollEnabled: Bool,
        onSelectionChange: @escaping (HomePrimaryWidgetKind) -> Void
    ) {
        self.pages = pages
        self.selectedKind = selectedKind
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.isScrollEnabledForRail = isScrollEnabled
        self.onSelectionChange = onSelectionChange
        super.init(collectionViewLayout: Self.makeLayout(
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            isScrollEnabled: isScrollEnabled
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.decelerationRate = .fast
        collectionView.isDirectionalLockEnabled = true
        collectionView.clipsToBounds = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Constants.cellReuseIdentifier)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didApplyInitialSelection else { return }
        didApplyInitialSelection = true
        scrollToSelectedKind(animated: false)
    }

    func apply(
        pages: [HomePrimaryWidgetHostedPage],
        selectedKind: HomePrimaryWidgetKind?,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        isScrollEnabled: Bool,
        animated: Bool
    ) {
        let didChangeLayout = abs(self.pageWidth - pageWidth) > 0.5
            || abs(self.pageHeight - pageHeight) > 0.5
            || self.isScrollEnabledForRail != isScrollEnabled

        self.pages = pages
        self.selectedKind = selectedKind
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.isScrollEnabledForRail = isScrollEnabled

        collectionView.isScrollEnabled = isScrollEnabled

        if didChangeLayout {
            collectionView.setCollectionViewLayout(
                Self.makeLayout(
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    isScrollEnabled: isScrollEnabled
                ),
                animated: false
            )
        }

        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        scrollToSelectedKind(animated: animated && view.window != nil)
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Constants.cellReuseIdentifier,
            for: indexPath
        )
        let page = pages[indexPath.item]
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.contentConfiguration = UIHostingConfiguration {
            page.content
        }
        .margins(.all, .zero)
        return cell
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        handleUserScrollCompletion()
    }

    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        handleUserScrollCompletion()
    }

    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isProgrammaticScroll = false
    }

    private func scrollToSelectedKind(animated: Bool) {
        guard let selectedKind,
              let itemIndex = pages.firstIndex(where: { $0.kind == selectedKind }) else { return }

        let indexPath = IndexPath(item: itemIndex, section: 0)
        guard collectionView.numberOfItems(inSection: 0) > itemIndex else { return }

        if centeredIndexPath() == indexPath {
            return
        }

        isProgrammaticScroll = animated
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
        if !animated {
            isProgrammaticScroll = false
        }
    }

    private func centeredIndexPath() -> IndexPath? {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return nil }

        let centerPoint = CGPoint(
            x: collectionView.contentOffset.x + collectionView.bounds.midX,
            y: collectionView.bounds.midY
        )

        return visibleIndexPaths.min { lhs, rhs in
            let lhsCenter = collectionView.layoutAttributesForItem(at: lhs)?.center.x ?? .zero
            let rhsCenter = collectionView.layoutAttributesForItem(at: rhs)?.center.x ?? .zero
            return abs(lhsCenter - centerPoint.x) < abs(rhsCenter - centerPoint.x)
        }
    }

    private func handleUserScrollCompletion() {
        guard !isProgrammaticScroll,
              let centeredIndexPath = centeredIndexPath(),
              centeredIndexPath.item < pages.count else { return }

        let kind = pages[centeredIndexPath.item].kind
        guard kind != selectedKind else { return }

        selectedKind = kind
        onSelectionChange(kind)
    }

    private static func makeLayout(
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        isScrollEnabled: Bool
    ) -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupWidth: NSCollectionLayoutDimension = isScrollEnabled
            ? .absolute(pageWidth)
            : .fractionalWidth(1.0)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: groupWidth,
            heightDimension: .absolute(pageHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = isScrollEnabled ? .groupPagingCentered : .none
        section.contentInsets = .zero

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(section: section, configuration: configuration)
    }
}
