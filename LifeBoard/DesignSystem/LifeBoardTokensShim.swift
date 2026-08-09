// The token layer now lives in Packages/Tokens.
//
// Re-exported so the ~2,600 existing call sites (`Color.lifeboard(...)`,
// `ThemeStore.shared.tokens(...)`, `MotionAnimations`, …) keep
// compiling without an import churn commit. This mirrors how the repo already
// consumes JournalKit.
//
// New code may import Tokens directly; this shim exists so the module
// move is not also a 2,600-file diff.
@_exported import LifeBoardTokens
@_exported import LifeBoardUI
@_exported import LifeBoardContracts
@_exported import LifeBoardDomain
