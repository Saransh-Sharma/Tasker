import SwiftUI
import SwiftData
import TranscriptionKit
import UIKit
import VisionKit

struct InsightMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(13)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct EvidenceRow: View {
    let event: NormalizedLifeEvent
    let onOpenEvidence: (EvidenceReference) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationFocusRing))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                Text(event.provenance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if event.evidence.isEmpty == false {
                    HStack(spacing: 6) {
                        ForEach(event.evidence, id: \.self) { evidence in
                            Button(evidence.display) { onOpenEvidence(evidence) }
                                .font(.caption2.weight(.semibold))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if let value = event.numericValue { Text(value.formatted()).font(.headline.monospacedDigit()) }
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().opacity(0.55) }
        .accessibilityElement(children: .contain)
    }
}
