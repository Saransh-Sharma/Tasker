import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// Where each root rests relative to the one on screen.
///
/// A root change should read as travelling along the dock rather than as one
/// screen dissolving into another, so a root waits on the side it occupies in
/// the dock order: roots to the left of the current one wait on the left, roots
/// to the right wait on the right. Moving from Home to Track therefore carries
/// the eye left-to-right, the same direction the selected well travels.
///
/// The distance is deliberately short. A full-width page slide would fight the
/// dock's own selection movement and make every root change feel like a journey.
enum RootTransition {
    /// Far enough to give the change a direction, near enough to stay calm.
    static let slideDistance: CGFloat = 24

    /// Horizontal resting offset for `destination` while `selected` is on screen.
    ///
    /// The sign comes from dock order, and the magnitude is capped: roots three
    /// slots away are no further off than roots one slot away, because they are
    /// invisible either way and a longer throw only makes the arrival slower.
    static func offset(
        for destination: Destination,
        selected: Destination,
        distance: CGFloat = slideDistance
    ) -> CGFloat {
        guard destination != selected else { return 0 }
        let order = Destination.allCases
        guard let from = order.firstIndex(of: destination),
              let to = order.firstIndex(of: selected) else { return 0 }
        return from < to ? -distance : distance
    }

    /// Which way the arriving root is travelling: -1 leftward, +1 rightward.
    ///
    /// Feeds `lifeboardRootTravel`'s shear, so it must agree in sign with
    /// `offset` above — a shear that leans against the slide reads as the
    /// surface fighting itself rather than flexing with the motion.
    static func direction(from previous: Destination?, to selected: Destination) -> Double {
        guard let previous, previous != selected else { return 0 }
        let order = Destination.allCases
        guard let from = order.firstIndex(of: previous),
              let to = order.firstIndex(of: selected) else { return 0 }
        return from < to ? 1 : -1
    }

    /// The departing slot's x-centre in unit space, so the shear falls off from
    /// where the finger actually was.
    ///
    /// The dock lays five equal slots edge to edge, so slot `i` is centred at
    /// `(i + 0.5) / 5`. This mirrors `dockSelectionCenter` in the shell layout,
    /// which computes the same figure for the glass refraction lens.
    static func originUnitX(for destination: Destination?) -> Double {
        let order = Destination.allCases
        guard let destination, let index = order.firstIndex(of: destination), order.isEmpty == false else {
            return 0.5
        }
        return (Double(index) + 0.5) / Double(order.count)
    }
}

/// Which roots exist in the compact shell's stack, and which survive a change.
///
/// These are two different questions, and conflating them is what put a blank
/// frame between Home and Plan. The stack used to render a root only once
/// `visitedRoots` contained it, but that set is written from `onChange`, which
/// runs *after* the render pass that observed the new selection. So the first
/// pass after "Open Plan" drew a Plan that did not exist yet and a Home already
/// faded to zero — no visible root at all, and the system's white window
/// backing showed through for as long as Plan's stores took to build.
///
/// Selection is therefore sufficient on its own to render a root, and the
/// visited set answers only the second question: what stays behind afterwards.
enum RootRetention {
    /// True when `destination` belongs in the stack this render pass.
    ///
    /// Being selected is enough. There is no transaction in which the selected
    /// root is absent, so there is no interval with nothing on screen.
    static func isRendered(
        _ destination: Destination,
        selected: Destination,
        visited: Set<Destination>
    ) -> Bool {
        destination == selected || visited.contains(destination)
    }

    /// The visited set after a selection change.
    ///
    /// Dashboard roots accumulate so their scroll position and navigation depth
    /// survive. Eva is dropped on the way out because its chat runtime owns
    /// visibility-scoped work that should not keep running off screen — it is
    /// still rendered while selected, so eviction never blanks it either.
    static func retained(
        visited: Set<Destination>,
        previous: Destination?,
        selected: Destination
    ) -> Set<Destination> {
        var next = visited
        next.insert(selected)
        if previous == .eva, selected != .eva {
            next.remove(.eva)
        }
        return next
    }
}

// MARK: - Display panel
