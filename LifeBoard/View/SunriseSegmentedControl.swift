import SwiftUI

struct SunriseSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let accessibilityIdentifier: (Option) -> String
    let action: (Option) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    action(option)
                } label: {
                    Text(title(option))
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(selection == option ? LBColorTokens.violetDeep : LBColorTokens.navyMuted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(LBColorTokens.glassStrong)
                                    .shadow(color: LBColorTokens.elevationShadow, radius: 12, x: 0, y: 6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityValue(selection == option ? "selected" : "not selected")
                .accessibilityAddTraits(selection == option ? .isSelected : [])
                .accessibilityIdentifier(accessibilityIdentifier(option))
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(LBColorTokens.glass.opacity(0.66))
                .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
                .overlay(Capsule().stroke(LBColorTokens.hairline.opacity(0.42), lineWidth: 1))
        }
    }
}
