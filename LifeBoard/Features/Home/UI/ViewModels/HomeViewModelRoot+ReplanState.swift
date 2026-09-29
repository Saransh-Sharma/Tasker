extension HomeViewModel {
    // Projects
    var needsReplanCandidates: [HomeReplanCandidate] {
        get { needsReplanViewModel.passiveCandidates }
        set { needsReplanViewModel.passiveCandidates = newValue }
    }

    var activeReplanCandidates: [HomeReplanCandidate] {
        get { needsReplanViewModel.activeCandidates }
        set { needsReplanViewModel.activeCandidates = newValue }
    }

    var replanUndoStack: [HomeReplanUndoEntry] {
        get { needsReplanViewModel.undoStack }
        set { needsReplanViewModel.undoStack = newValue }
    }

    var replanApplyingAction: HomeReplanApplyingAction? {
        get { needsReplanViewModel.applyingAction }
        set { needsReplanViewModel.applyingAction = newValue }
    }
}
