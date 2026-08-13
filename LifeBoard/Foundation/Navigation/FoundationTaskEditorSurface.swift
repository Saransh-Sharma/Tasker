import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

extension View {
    func taskEditorSurface() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
            }
    }
}
