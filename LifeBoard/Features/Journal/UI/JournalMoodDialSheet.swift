import SwiftUI
import LifeBoardDomain

extension JournalMood {
    /// A neutral one- or two-word descriptor. The mood dials show the mood
    /// word only; this stays for callers outside Journal that still read it.
    var supportiveCopy: String {
        switch self {
        case .none: return String(localized: "Even")
        case .happy: return String(localized: "Upbeat")
        case .calm: return String(localized: "Settled")
        case .grateful: return String(localized: "Thankful")
        case .excited: return String(localized: "Energized")
        case .tired: return String(localized: "Low energy")
        case .anxious: return String(localized: "On edge")
        case .sad: return String(localized: "Down")
        case .angry: return String(localized: "Frustrated")
        }
    }

    var largeAssetName: String {
        "LifeBoardJournal/\(assetStem)_Large"
    }

    var faceAssetName: String {
        let name: String
        switch self {
        case .none: name = "Neutral_face"
        case .tired: name = "Sleepy_face"
        default: name = "\(assetStem)_face"
        }
        return "LifeBoardJournal/\(name)"
    }

    var glowAssetName: String {
        switch self {
        case .angry, .sad, .anxious, .tired: return "LifeBoardJournal/Difficult_Glow"
        case .none: return "LifeBoardJournal/Neutral_Glow"
        case .calm, .grateful, .happy, .excited: return "LifeBoardJournal/Positive_Glow"
        }
    }

    private var assetStem: String {
        switch self {
        case .none: return "NoMood_Neutral"
        default: return rawValue.capitalized
        }
    }
}

struct JournalMoodDialSheet: View {
    @Binding var selectedMood: JournalMood
    /// Energy (if given) and the chosen reason ids.
    let onSave: (Int?, [String]) -> Void
    @State private var reasons: [String] = []

    @Environment(\.dismiss) private var dismiss
    // Light-only `palette(for:)` painted light-appearance ink (#6F6252)
    // on the dark canvas; the palette has to follow the appearance.
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The current daypart, so the sheet matches the screen it rose from
    /// rather than always painting afternoon.
    @Environment(\.lifeBoardAtmosphereSnapshot) private var atmosphere
    @State private var draftMood: JournalMood
    @State private var stage: Stage = .mood
    @State private var energy = 3.0
    @State private var includesEnergy = false

    /// Two steps: the mood with an optional energy level inline, then the
    /// optional reasons. Energy used to be its own step behind a toggle.
    private enum Stage { case mood, reasons }

    /// Home's quick mood dial has nowhere to keep reasons, so it skips the stage.
    private let offersReasons: Bool

    init(selectedMood: Binding<JournalMood>, offersReasons: Bool = true, onSave: @escaping (Int?, [String]) -> Void) {
        _selectedMood = selectedMood
        _draftMood = State(initialValue: selectedMood.wrappedValue)
        self.offersReasons = offersReasons
        self.onSave = onSave
    }

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: atmosphere.semanticDaypart, colorScheme: colorScheme)
        ZStack {
            LinearGradient(
                colors: [palette.color(for: .canvas), palette.color(for: .canvasSecondary)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header(palette: palette)
                switch stage {
                case .mood:
                    moodStage(palette: palette)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .reasons:
                    reasonsStage(palette: palette)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .foregroundStyle(palette.color(for: .foreground))
        .interactiveDismissDisabled()
        .accessibilityIdentifier("journal.moodDial.sheet")
    }

    private func header(palette: DaypartPalette) -> some View {
        HStack {
            // Back between steps, so a mood chosen too quickly can be changed
            // without abandoning the whole check-in.
            Button(stage == .mood ? "Cancel" : "Back") {
                switch stage {
                case .mood: dismiss()
                case .reasons:
                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { stage = .mood }
                }
            }
            .frame(minWidth: 56, minHeight: 44)
            .accessibilityIdentifier(stage == .mood ? "journal.moodDial.cancel" : "journal.moodDial.back")
            Spacer()
            Text(stage == .mood ? "How are you feeling?" : "What shaped it?")
                .font(.headline)
            Spacer()
            Button(isFinalStage ? "Done" : "Next") {
                if isFinalStage {
                    commit()
                } else {
                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { stage = .reasons }
                }
            }
            .accessibilityIdentifier(isFinalStage ? "journal.moodDial.done" : "journal.moodDial.next")
            .fontWeight(.semibold)
            .frame(minWidth: 56, minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var isFinalStage: Bool {
        stage == .reasons || offersReasons == false
    }

    private func moodStage(palette: DaypartPalette) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                ZStack {
                    Image(draftMood.glowAssetName)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.52)
                        .accessibilityHidden(true)
                    Image(draftMood.largeAssetName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(28)
                        .accessibilityHidden(true)
                }
                .frame(
                    width: min(proxy.size.width * 0.62, includesEnergy ? 200 : 280),
                    height: min(proxy.size.width * 0.48, includesEnergy ? 150 : 220)
                )

                Text(draftMood.displayName)
                    .lifeboardFont(.screenTitle)

                JournalMoodWheel(selectedMood: $draftMood, palette: palette)
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: .infinity)

                energyRow(palette: palette)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
    }

    /// Energy, inline and optional: off until asked for, then five levels
    /// one tap apart. It used to be a whole step with a toggle and a dial.
    private func energyRow(palette: DaypartPalette) -> some View {
        VStack(spacing: 10) {
            Toggle(isOn: $includesEnergy.animation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add energy")
                        .font(.headline)
                    Text(includesEnergy ? energyLabel : "Optional")
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
            }
            .frame(minHeight: 44)
            if includesEnergy {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        let isOn = Int(energy.rounded()) == level
                        Button {
                            Haptic.pick.play()
                            energy = Double(level)
                        } label: {
                            Text("\(level)")
                                .font(.body.weight(isOn ? .semibold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    isOn
                                        ? Color(SemanticColorTokens.foundationSurfaceSelected)
                                        : Color(SemanticColorTokens.foundationSurfaceRecessed).opacity(0.6),
                                    in: Capsule()
                                )
                                .overlay {
                                    if isOn { Capsule().strokeBorder(Color(SemanticColorTokens.foundationApricotInk), lineWidth: 1.5) }
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Self.energyLabel(for: level))
                        .accessibilityAddTraits(isOn ? [.isSelected] : [])
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Energy")
                .accessibilityIdentifier("journal.mood.energy.dial")
                .transition(.opacity)
            }
        }
        .padding(14)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    /// Optional, a few taps: why the mood was what it was. Stored as chips on
    /// the mood block, never counted as AI evidence without the day's consent.
    private func reasonsStage(palette: DaypartPalette) -> some View {
        VStack(spacing: 16) {
            Text(reasons.isEmpty ? String(localized: "Pick any that apply.") : JournalMoodReasons.titles(for: reasons).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(JournalMoodReasons.catalog) { reason in
                    let isOn = reasons.contains(reason.id)
                    Button {
                        Haptic.pick.play()
                        if isOn { reasons.removeAll { $0 == reason.id } } else { reasons.append(reason.id) }
                    } label: {
                        Label(reason.title, systemImage: reason.systemImage)
                            .font(.subheadline.weight(isOn ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .background(
                        (isOn ? Color(SemanticColorTokens.foundationSurfaceSelected) : Color(SemanticColorTokens.foundationSurfaceRecessed)).opacity(isOn ? 1 : 0.6),
                        in: Capsule()
                    )
                    .overlay {
                        if isOn { Capsule().strokeBorder(Color(SemanticColorTokens.foundationApricotInk), lineWidth: 1.5) }
                    }
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                    .accessibilityIdentifier("journal.mood.reason.\(reason.id)")
                }
            }
            Button("Save without reasons") { reasons = []; commit() }
                .frame(minHeight: 44)
            Spacer()
        }
        .padding(24)
    }

    private func commit() {
        selectedMood = draftMood
        onSave(includesEnergy ? Int(energy.rounded()) : nil, reasons)
        // No commit haptic here: the check-in has not been saved yet. The
        // host plays it once the save succeeds.
        dismiss()
    }

    private var energyLabel: String {
        Self.energyLabel(for: Int(energy.rounded()))
    }

    private static func energyLabel(for level: Int) -> String {
        switch level {
        case 1: return "Very low energy"
        case 2: return "Low energy"
        case 3: return "Steady energy"
        case 4: return "High energy"
        default: return "Very high energy"
        }
    }
}

private struct JournalMoodWheel: View {
    @Binding var selectedMood: JournalMood
    let palette: DaypartPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let diameter = max(420, proxy.size.width * 1.36)
            let center = CGPoint(x: proxy.size.width / 2, y: diameter / 2 + 62)
            ZStack {
                ForEach(Array(JournalMood.dialOrder.enumerated()), id: \.element.id) { index, mood in
                    let angle = angleDegrees(for: index)
                    let radians = angle * .pi / 180
                    Button {
                        select(mood)
                    } label: {
                        Image(mood.faceAssetName)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: mood == selectedMood ? 58 : 48, height: mood == selectedMood ? 58 : 48)
                            .padding(12)
                            .background(
                                mood == selectedMood
                                    ? palette.color(for: .celestialPrimary)
                                    : palette.color(for: .layerTwo).opacity(0.86),
                                in: Circle()
                            )
                            .overlay(Circle().stroke(Color.lifeboard(.textInverse).opacity(0.62), lineWidth: 1))
                            .shadow(
                                color: Color(SemanticColorTokens.foundationWarmShadow).opacity(mood == selectedMood ? 0.2 : 0.08),
                                radius: mood == selectedMood ? 10 : 4,
                                y: 3
                            )
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: center.x + cos(radians) * diameter * 0.37,
                        y: center.y + sin(radians) * diameter * 0.37
                    )
                    .accessibilityLabel(mood.displayName)
                }

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.title2)
                    .foregroundStyle(palette.color(for: .foreground))
                    .position(x: proxy.size.width / 2, y: 22)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in select(nearestMood(to: value.location, center: center)) }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mood dial")
            .accessibilityValue(selectedMood.displayName)
            .accessibilityAdjustableAction { direction in
                let current = JournalMood.dialOrder.firstIndex(of: selectedMood) ?? 4
                let next: Int
                switch direction {
                case .increment: next = min(current + 1, JournalMood.dialOrder.count - 1)
                case .decrement: next = max(current - 1, 0)
                @unknown default: return
                }
                select(JournalMood.dialOrder[next])
            }
        }
    }

    private func angleDegrees(for index: Int) -> Double {
        205 + Double(index) * (130 / Double(max(1, JournalMood.dialOrder.count - 1)))
    }

    private func nearestMood(to point: CGPoint, center: CGPoint) -> JournalMood {
        let raw = atan2(point.y - center.y, point.x - center.x) * 180 / .pi
        let normalized = raw < 0 ? raw + 360 : raw
        let index = JournalMood.dialOrder.indices.min {
            abs(angleDegrees(for: $0) - normalized) < abs(angleDegrees(for: $1) - normalized)
        } ?? 4
        return JournalMood.dialOrder[index]
    }

    private func select(_ mood: JournalMood) {
        guard mood != selectedMood else { return }
        if reduceMotion {
            selectedMood = mood
        } else {
            withAnimation(LifeBoardAnimation.roleLocalState) { selectedMood = mood }
        }
        Haptic.pick.play()
    }
}
