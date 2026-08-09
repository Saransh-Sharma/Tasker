import SwiftUI
import SwiftData
import TranscriptionKit
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
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Text("Add \(descriptor.title) to Home")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Choose how much this card should reveal. You can resize or move it any time.")
                            .font(.body)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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

                    HStack(spacing: 10) {
                        Image(systemName: "hand.draw")
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Text("LifeBoard will use the first open position. Your existing cards never move unless you choose to edit Home.")
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    .padding(14)
                    .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(22)
            }
            .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(selectedSize)
                } label: {
                    Label("Add to Home", systemImage: "rectangle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(LifeBoardColorTokens.inkPrimary))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("home.placement.add")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var sizeButtons: some View {
        ForEach(WidgetSizePreset.allCases.filter(descriptor.supportedSizes.contains), id: \.self) { size in
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)) {
                    selectedSize = size
                }
                UISelectionFeedbackGenerator().selectionChanged()
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
                  ? Color(LifeBoardColorTokens.inkPrimary)
                  : Color(LifeBoardColorTokens.inkSecondary))
            .accessibilityLabel(size.title)
            .accessibilityHint("Uses (size.canonicalGridSpan.columns) columns and (size.canonicalGridSpan.rows) rows")
            .accessibilityValue(selectedSize == size ? "Selected" : "")
        }
    }

    private var homeMiniature: some View {
        let span = selectedSize.canonicalGridSpan
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("My Home preview", systemImage: "house")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectedSize.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            GeometryReader { proxy in
                let gap: CGFloat = 7
                let unit = (proxy.size.width - (gap * 3)) / 4
                ZStack(alignment: .topLeading) {
                    ForEach(0..<16, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(LifeBoardColorTokens.foundationCanvas))
                            .frame(width: unit, height: unit * 0.58)
                            .offset(
                                x: CGFloat(index % 4) * (unit + gap),
                                y: CGFloat(index / 4) * ((unit * 0.58) + gap)
                            )
                    }
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(LifeBoardColorTokens.foundationSunAccent))
                        .overlay(alignment: .topLeading) {
                            Label(descriptor.title, systemImage: descriptor.systemImage)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .padding(10)
                        }
                        .frame(
                            width: (unit * CGFloat(span.columns)) + (gap * CGFloat(span.columns - 1)),
                            height: max(unit * 0.58, (unit * 0.58 * CGFloat(span.rows)) + (gap * CGFloat(span.rows - 1)))
                        )
                        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.18), radius: 10, y: 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 245)
            .clipped()
        }
        .padding(16)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
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
            HStack(spacing: 10) {
                Image(systemName: preview.destination.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Color(LifeBoardColorTokens.foundationSunAccent).opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review before applying")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Text(preview.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                }
                Spacer(minLength: 0)
                Text(preview.destination.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(preview.changes.enumerated()), id: \.offset) { _, change in
                    Label(change, systemImage: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                }
                ForEach(Array(preview.warnings.enumerated()), id: \.offset) { _, warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                Button("Not now", action: onNotNow)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 6)
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(LifeBoardColorTokens.inkPrimary))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(15)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.14), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeThread.preview")
    }
}

struct ComposerReceiptView: View {
    let receipt: ActionReceipt
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
            Text(receipt.message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
            if receipt.canUndo {
                Button("Undo", action: onUndo)
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Dismiss receipt")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .lifeBoardGlassSurface(cornerRadius: 22, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
            Text(receipt.title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("View", action: onView)
                .font(.subheadline.weight(.semibold))
            Button("Undo", action: onUndo)
                .font(.subheadline)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .lifeBoardGlassSurface(cornerRadius: 22, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.2), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.addCard.receipt")
    }
}
