import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct HomeCardPlacementRequest: Identifiable {
    let kind: DashboardWidgetKind
    let destination: Destination
    var id: String { "\(destination.rawValue):\(kind.rawValue)" }
}

struct HomeCardPlacementSheet: View {
    let descriptor: DashboardWidgetDescriptor
    let destination: Destination
    let onCancel: () -> Void
    let onAdd: (WidgetSizePreset) -> Void

    @State private var selectedSize: WidgetSizePreset
    @State private var previewContentWidth: CGFloat = 353
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        descriptor: DashboardWidgetDescriptor,
        destination: Destination,
        onCancel: @escaping () -> Void,
        onAdd: @escaping (WidgetSizePreset) -> Void
    ) {
        self.descriptor = descriptor
        self.destination = destination
        self.onCancel = onCancel
        self.onAdd = onAdd
        _selectedSize = State(initialValue: descriptor.defaultSize)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("From \(destination.title)", systemImage: destination.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        Text("Add \(descriptor.title) to Home")
                            .lifeboardFont(.heroDisplay)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sample preview")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HomeCardSamplePreview(descriptor: descriptor, preset: selectedSize)
                            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : HomeCardPresentationStyle.cardWidth(
                                contentWidth: previewContentWidth, preset: selectedSize, regular: horizontalSizeClass == .regular))
                            .frame(maxWidth: .infinity)
                    }

                    homeMiniature

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Size")
                            .font(.headline)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { sizeButtons }
                            VStack(spacing: 8) { sizeButtons }
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "hand.draw")
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        Text("Goes in the first open spot without moving other cards.")
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    .padding(14)
                    .background(Color(SemanticColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                }
                .padding(22)
            }
            .background(Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(selectedSize)
                } label: {
                    Label("Add to Home", systemImage: "rectangle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .tint(Color(SemanticColorTokens.inkPrimary))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color(SemanticColorTokens.foundationSurfaceRaised))
                .accessibilityIdentifier("home.placement.add")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .presentationDetents([.large])
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            // Measure the container, never the child whose width this controls.
            // Home's 20pt margins determine the corresponding card width.
            previewContentWidth = max(0, width - 40)
        }
    }

    @ViewBuilder
    private var sizeButtons: some View {
        ForEach(WidgetSizePreset.allCases.filter(descriptor.supportedSizes.contains), id: \.self) { size in
            Button {
                withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                    selectedSize = size
                }
                Haptic.pick.play()
            } label: {
                VStack(spacing: 3) {
                    Text(size.title).font(.subheadline.weight(.semibold))
                    Text("\(size.canonicalGridSpan.columns)×\(size.canonicalGridSpan.rows)")
                        .font(.caption2.monospacedDigit())
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .tint(selectedSize == size
                  ? Color(SemanticColorTokens.inkPrimary)
                  : Color(SemanticColorTokens.inkSecondary))
            .accessibilityLabel(size.title)
            .accessibilityHint("\(size.canonicalGridSpan.columns) columns, \(size.canonicalGridSpan.rows) rows")
            .accessibilityValue(selectedSize == size ? "Selected" : "")
        }
    }

    private var homeMiniature: some View {
        let span = selectedSize.canonicalGridSpan
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your Home", systemImage: "house")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectedSize.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            GeometryReader { proxy in
                let gap: CGFloat = 7
                let unit = (proxy.size.width - (gap * 3)) / 4
                ZStack(alignment: .topLeading) {
                    ForEach(0..<16, id: \.self) { index in
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                            .fill(Color(SemanticColorTokens.foundationCanvas))
                            .frame(width: unit, height: unit * 0.58)
                            .offset(
                                x: CGFloat(index % 4) * (unit + gap),
                                y: CGFloat(index / 4) * ((unit * 0.58) + gap)
                            )
                    }
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .fill(Color(SemanticColorTokens.foundationSunAccent))
                        .overlay(alignment: .topLeading) {
                            Label(descriptor.title, systemImage: descriptor.systemImage)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .padding(12)
                        }
                        .frame(
                            width: (unit * CGFloat(span.columns)) + (gap * CGFloat(span.columns - 1)),
                            height: max(unit * 0.58, (unit * 0.58 * CGFloat(span.rows)) + (gap * CGFloat(span.rows - 1)))
                        )
                        .lifeboardElevation(.e2, cornerRadius: Radius.row, includesBorder: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 245)
            .clipped()
        }
        .padding(16)
        .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
                .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
        }
    }
}

struct ComposerPreviewCard: View {
    let preview: TransactionPreview
    let onApply: () -> Void
    let onEdit: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: preview.destination.systemImage)
                    .lifeboardFont(.headline)
                    .frame(width: 32, height: 32)
                    .background(Color(SemanticColorTokens.foundationSunAccent).opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Text(preview.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                }
                Spacer(minLength: 0)
                Text(preview.destination.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(preview.changes.enumerated()), id: \.offset) { _, change in
                    Label(change, systemImage: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                }
                ForEach(Array(preview.warnings.enumerated()), id: \.offset) { _, warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                Button("Not now", action: onNotNow)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 8)
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                Button("Apply", action: onApply)
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .tint(Color(SemanticColorTokens.inkPrimary))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(15)
        .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
        }
        .lifeboardElevation(.e2, cornerRadius: Radius.card, includesBorder: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeThread.preview")
    }
}

struct ComposerReceiptView: View {
    let receipt: ActionReceipt
    let onUndo: () -> Void
    let onDismiss: () -> Void
    var onOpen: (() -> Void)? = nil

    /// The shared `ReceiptBar`, not a composer-only capsule: one receipt
    /// language across the app (Open, Undo, dismiss; stacked at accessibility
    /// sizes; never auto-dismissed, because Undo must stay reachable).
    var body: some View {
        ReceiptBar(
            ActionReceiptPresentation(id: receipt.id, message: receipt.message),
            undo: receipt.canUndo ? onUndo : nil,
            destination: onOpen.flatMap { open in
                receipt.taskID == nil ? nil : ReceiptBar.Destination(title: "Open", action: open)
            },
            onDismiss: onDismiss
        )
        .accessibilityIdentifier("lifeThread.receipt")
    }
}

struct HomeCardPlacementReceipt: Identifiable {
    let id = UUID()
    let title: String
    let transaction: HomeLayoutTransaction
}

struct HomeCardPlacementReceiptView: View {
    let receipt: HomeCardPlacementReceipt
    let onView: () -> Void
    let onUndo: () -> Void
    let onDismiss: () -> Void

    /// The shared receipt: one silhouette, Undo and View, never on a timer.
    var body: some View {
        ReceiptBar(
            ActionReceiptPresentation(id: receipt.id, message: receipt.title),
            undo: onUndo,
            destination: .init(title: "View", action: onView),
            onDismiss: onDismiss
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.addCard.receipt")
    }
}
