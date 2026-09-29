import SwiftUI

// MARK: - Commit bar

/// The failure banner and commit control that close every composer.
///
/// The backing is Regular Liquid Glass rather than a raw system material. That is
/// not a cosmetic swap: a commit bar is navigation and control chrome, which is
/// precisely — and only — what the glass law reserves glass for, and routing it
/// through `lifeBoardSystemGlass` is what makes it honour Reduce Transparency
/// and the Clear-Glass ban along with the rest of the chrome layer.
public struct ComposerCommitBar: View {
    private let title: String
    private let runningTitle: String
    private let successTitle: String
    private let phase: LifeBoardComposerPhase
    private let isEnabled: Bool
    private let identifier: String?
    private let action: () -> Void

    @State private var firstLightTrigger = 0
    /// Identifies this bar's commits, so the shell's fired notification can
    /// be matched to the capture that earned it.
    @State private var commitmentToken = UUID().uuidString

    public init(
        title: String,
        runningTitle: String = "Saving",
        successTitle: String = "Saved",
        phase: LifeBoardComposerPhase,
        isEnabled: Bool = true,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.runningTitle = runningTitle
        self.successTitle = successTitle
        self.phase = phase
        self.isEnabled = isEnabled
        self.identifier = identifier
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 8) {
            if case .recoverableFailure(let failure) = phase {
                Label(failure.message, systemImage: "exclamationmark.circle")
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            CommitControl(
                title: title,
                runningTitle: runningTitle,
                successTitle: successTitle,
                phase: phase,
                isEnabled: isEnabled,
                action: action
            )
            // Identity only, never `accessibilityElement(children:)`. The
            // commit control has to keep reporting as a `Button`, because the
            // Track suite drives `app.buttons["track.*.commit"]` throughout;
            // wrapping it in a container would hide the button inside it.
            .modifier(FieldIdentity(identifier: identifier))
        }
        // ⌘Return commits from anywhere in the composer, the one hardware
        // keyboard path to the primary action. Hidden rather than on the
        // control itself: `CommitControl` is a custom view, and the shortcut
        // must follow the same enabled/running rules the control does.
        .background {
            Button("", action: action)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isEnabled == false || isRunning || isSucceeded)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            Color.clear
                .lifeBoardSystemGlass(.regular, in: Rectangle())
                .ignoresSafeArea(edges: .bottom)
        }
        // `firstLight` is reserved for the first daily commitment. A capture
        // reports the commitment and the shell claims the gate, as habits and
        // tasks do: this bar used to claim it itself, so a capture never got
        // the "First one done." caption or the Calm and energy checks.
        .lifeboardFirstLight(
            trigger: firstLightTrigger,
            tint: Color(SemanticColorTokens.foundationSunAccent)
        )
        .onChange(of: isSucceeded) { _, succeeded in
            guard succeeded else { return }
            NotificationCenter.default.post(
                name: .lifeboardDailyCommitment,
                object: nil,
                userInfo: [
                    FirstLightCommitment.sourceKey: FirstLightCommitment.Source.composer.rawValue,
                    FirstLightCommitment.tokenKey: commitmentToken
                ]
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .lifeboardFirstLightFired)) { notification in
            guard FirstLightCommitment.token(of: notification) == commitmentToken else { return }
            firstLightTrigger &+= 1
        }
    }

    private var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    private var isSucceeded: Bool {
        if case .success = phase { return true }
        return false
    }

}
