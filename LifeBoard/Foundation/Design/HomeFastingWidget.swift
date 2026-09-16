import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

struct HomeFastingWidget: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let palette: DaypartPalette
    let onOpen: () -> Void

    var body: some View {
        if let fast = lifeOSStore.activeFast {
            ActiveVisibleTimeline(every: 1) { context in
                let elapsed = fast.elapsed(at: context.date)
                let progress = fast.targetDuration.map { $0 > 0 ? min(1, elapsed / $0) : 0 } ?? 0
                HomeFastingCardContent(
                    elapsed: HomeSectionCopy.duration(elapsed),
                    finish: fast.targetDuration.map {
                        elapsed >= $0 ? "Planned duration reached" : "\(HomeSectionCopy.duration($0-elapsed)) until your planned finish"
                    } ?? "End whenever it feels right",
                    progress: progress, palette: palette, onOpen: onOpen,
                    onEnd: { Task { await lifeOSStore.endActiveFast() } }
                )
            }
        } else {
            HomeFastingCardContent(elapsed: nil, finish: "", progress: 0, palette: palette, onOpen: onOpen)
        }
    }
}
