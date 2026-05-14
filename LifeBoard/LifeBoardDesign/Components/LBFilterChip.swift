import SwiftUI

struct LBFilterChip: View {
    struct Model: Identifiable, Equatable {
        let id: String
        let title: String
        let systemImage: String
        let isSelected: Bool
        let showsIndicator: Bool
        let hidesTitle: Bool
        let accessibilityID: String?

        init(
            id: String,
            title: String,
            systemImage: String,
            isSelected: Bool,
            showsIndicator: Bool = false,
            hidesTitle: Bool = false,
            accessibilityID: String?
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.isSelected = isSelected
            self.showsIndicator = showsIndicator
            self.hidesTitle = hidesTitle
            self.accessibilityID = accessibilityID
        }
    }

    let model: Model
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: model.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                    if model.hidesTitle == false {
                        Text(model.title)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(model.isSelected ? Color.white : LBColorTokens.navy)
                .frame(minHeight: 34)
                .padding(.horizontal, model.hidesTitle ? 12 : 10)
                .background {
                    Group {
                        if model.isSelected {
                            LinearGradient(
                                colors: [LBColorTokens.violetFill, LBColorTokens.violetFillDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            LinearGradient(colors: [LBColorTokens.glassStrong, LBColorTokens.glass], startPoint: .top, endPoint: .bottom)
                        }
                    }
                    .clipShape(Capsule())
                }
                .overlay {
                    Capsule()
                        .stroke(model.isSelected ? LBColorTokens.whiteStroke : LBColorTokens.hairline.opacity(0.70), lineWidth: 1)
                }

                if model.showsIndicator {
                    Circle()
                        .fill(LBColorTokens.sunriseGold)
                        .frame(width: 8, height: 8)
                        .overlay {
                            Circle().stroke(LBColorTokens.whiteStroke, lineWidth: 1)
                        }
                        .offset(x: 1, y: -1)
                }
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(model.accessibilityID ?? "home.sunrise.filter.\(model.id)")
        .accessibilityLabel(model.title)
    }
}
