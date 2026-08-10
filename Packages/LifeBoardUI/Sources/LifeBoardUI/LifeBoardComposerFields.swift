import SwiftUI
import UIKit
import LifeBoardTokens
// MARK: - Text field

/// Text entry carved into the clay.
///
/// This wraps a genuine `TextField` rather than painting a `Button` to look like
/// one. That is a test contract as much as an accessibility one: the tracker
/// flow drives `app.textFields["track.tracker.name"]` and
/// `app.textFields["track.tracker.value.numeric"]` by element *type*, and a
/// button dressed as a field reports as `.button` and takes the suite down with
/// it. It is also simply correct — dictation, autocorrect, the caret, the
/// selection handles and the keyboard are all free only if the field is real.
///
/// Focus lifts the surface from `.well` to `.resting` and adds a focus ring. The
/// *surface* animates; the text never does. Animating the content of a field
/// someone is actively typing into is the fastest way to make a premium control
/// feel unstable.
public struct ComposerField: View {
    public enum Shape: Equatable, Sendable {
        /// One line, submits on return.
        case line
        /// Wrapping prose that grows between the given line bounds.
        case prose(lineLimit: ClosedRange<Int>)
    }

    private let label: String
    private let prompt: String?
    private let shape: Shape
    private let submitLabel: SubmitLabel
    private let keyboard: UIKeyboardType
    private let identifier: String?
    private let showsLabel: Bool
    @Binding private var text: String

    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        prompt: String? = nil,
        text: Binding<String>,
        shape: Shape = .line,
        submitLabel: SubmitLabel = .done,
        keyboard: UIKeyboardType = .default,
        showsLabel: Bool = true,
        identifier: String? = nil
    ) {
        self.label = label
        self.prompt = prompt
        self._text = text
        self.shape = shape
        self.submitLabel = submitLabel
        self.keyboard = keyboard
        self.showsLabel = showsLabel
        self.identifier = identifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsLabel {
                Text(label)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            field
                .font(.lifeboard(.body))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .focused($isFocused)
                .submitLabel(submitLabel)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minHeight: 44, alignment: .topLeading)
                .lifeBoardClaySurface(
                    isFocused ? .resting : .well,
                    cornerRadius: Radius.compact + 2
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: Radius.compact + 2,
                        style: .continuous
                    )
                    .stroke(
                        Color.lifeboard(.actionFocus).opacity(isFocused ? 1 : 0),
                        lineWidth: 2
                    )
                }
                .lifeBoardMotion(.controlMorph, value: isFocused)
                .modifier(FieldIdentity(identifier: identifier))
                .accessibilityLabel(Text(label))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var field: some View {
        switch shape {
        case .line:
            TextField(prompt ?? label, text: $text)
        case .prose(let lineLimit):
            TextField(prompt ?? label, text: $text, axis: .vertical)
                .lineLimit(lineLimit)
        }
    }
}

/// Applies an accessibility identifier only when one was supplied, so a field
/// without one does not become an opaque container in the accessibility tree.
public struct FieldIdentity: ViewModifier {
    let identifier: String?

    public init(identifier: String?) {
        self.identifier = identifier
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

// MARK: - Number field

/// A compact numeric field for secondary values, with a keyboard dismissal that
/// actually exists.
///
/// `.decimalPad` has no return key. Every decimal field in the app before this
/// stranded the keyboard over the commit bar with no way back except a scroll
/// gesture that many people never discover, so the accessory `Done` is part of
/// the control rather than something each call site remembers.
public struct ComposerNumberField: View {
    private let label: String
    private let prompt: String?
    private let unit: String?
    private let format: FloatingPointFormatStyle<Double>
    private let identifier: String?
    @Binding private var value: Double

    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        prompt: String? = nil,
        value: Binding<Double>,
        format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...2)),
        unit: String? = nil,
        identifier: String? = nil
    ) {
        self.label = label
        self.prompt = prompt
        self._value = value
        self.format = format
        self.unit = unit
        self.identifier = identifier
    }

    public var body: some View {
        ComposerRow(label, detail: unit) {
            HStack(spacing: 6) {
                TextField(prompt ?? label, value: $value, format: format)
                    .font(.lifeboard(.bodyStrong))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .frame(minWidth: 64)
                    .modifier(FieldIdentity(identifier: identifier))
                    .accessibilityLabel(Text(label))
                if let unit {
                    Text(unit)
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .lifeBoardClaySurface(
                isFocused ? .resting : .well,
                cornerRadius: Radius.compact
            )
            .lifeBoardMotion(.controlMorph, value: isFocused)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isFocused = false }
            }
        }
    }
}

// MARK: - Clay toggle

/// The house switch.
///
/// Deliberately a `ToggleStyle` and not a custom `Button`. The habit-resilience
/// flow asserts `app.switches["Allow recovery completions"]` at accessibility
/// XXXL, and only a real `Toggle` reports as `.switch` to XCUITest and carries
/// the toggle trait to VoiceOver. Restyling the control keeps every one of those
/// guarantees; replacing it throws them away for a shape.
///
/// The on state moves the knob, tints the track *and* fills the knob's notch, so
/// it survives greyscale, Differentiate Without Colour, and the screenshot of a
/// screenshot someone will inevitably send.
public struct ClayToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var knob

    public init() {}

    private var trackWidth: CGFloat { 52 }
    private var knobSide: CGFloat { 26 }

    public func makeBody(configuration: Configuration) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        return layout {
            configuration.label
                .font(.lifeboard(.body))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            track(isOn: configuration.isOn)
        }
        .frame(minHeight: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.pick.play()
            configuration.isOn.toggle()
        }
        .lifeBoardMotion(.controlMorph, value: configuration.isOn)
    }

    private func track(isOn: Bool) -> some View {
        HStack(spacing: 0) {
            if isOn { Spacer(minLength: 0) }
            ZStack {
                Circle()
                    .fill(Color(SemanticColorTokens.foundationSurfaceSolid))
                Image(systemName: isOn ? "checkmark" : "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        Color(isOn
                            ? SemanticColorTokens.inkPrimary
                            : SemanticColorTokens.inkTertiary)
                    )
            }
            .frame(width: knobSide, height: knobSide)
            .matchedGeometryEffect(id: "lifeboard.clayToggle.knob", in: knob)
            .shadow(
                color: Color(SemanticColorTokens.foundationWarmShadow).opacity(0.7),
                radius: 3,
                y: 1
            )
            if isOn == false { Spacer(minLength: 0) }
        }
        .padding(3)
        .frame(width: trackWidth, height: knobSide + 6)
        .lifeBoardClaySurface(
            .well,
            cornerRadius: Radius.pill,
            // Apricot, not `foundationSageAccent`: despite the name, sage
            // resolves to #C9C6BA, a warm grey. An "on" track in it reads as
            // disabled, and it matched the off state closely enough that the
            // knob position was doing all the work.
            fill: isOn
                ? Color(SemanticColorTokens.foundationApricotAccent)
                : Color(SemanticColorTokens.foundationSurfaceRecessed)
        )
    }
}

public extension ToggleStyle where Self == ClayToggleStyle {
    static var lifeBoardClay: ClayToggleStyle { ClayToggleStyle() }
}

// MARK: - Menu row

/// A clay row that opens a native `Menu`, for closed sets too large for a rail.
///
/// The menu itself stays native on purpose. Its presentation, keyboard
/// navigation, pointer hover, dismissal and right-to-left behaviour are all
/// correct for free, and it reports as `.button` — exactly what `Picker(.menu)`
/// reported before, so nothing that referenced it needs to change. Only the row
/// becomes ours.
public struct MenuRow<Value: Hashable>: View {
    private let label: String
    private let values: [Value]
    private let title: (Value) -> String
    private let systemImage: ((Value) -> String)?
    private let identifier: String?
    @Binding private var selection: Value

    public init(
        _ label: String,
        selection: Binding<Value>,
        values: [Value],
        title: @escaping (Value) -> String,
        systemImage: ((Value) -> String)? = nil,
        identifier: String? = nil
    ) {
        self.label = label
        self._selection = selection
        self.values = values
        self.title = title
        self.systemImage = systemImage
        self.identifier = identifier
    }

    public var body: some View {
        ComposerRow(label) {
            Menu {
                Picker(label, selection: $selection) {
                    ForEach(values, id: \.self) { value in
                        if let systemImage {
                            Label(title(value), systemImage: systemImage(value)).tag(value)
                        } else {
                            Text(title(value)).tag(value)
                        }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                HStack(spacing: 6) {
                    Text(title(selection))
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 38)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            }
            .modifier(FieldIdentity(identifier: identifier))
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text(title(selection)))
        }
        .lifeBoardMotion(.selection, value: selection)
    }
}

// MARK: - Date capsule

/// A collapsed date or time capsule that expands its picker inline.
///
/// `minimum` and `maximum` are separate optionals rather than a range generic
/// because the call sites genuinely need all three shapes — `in: bedtime...`,
/// a closed window, and unbounded — and one initializer that assembles the range
/// internally beats three overloads that each look almost the same.
///
/// Only one capsule expands at a time within a row. Sleep has bedtime and wake
/// adjacent, and two open graphical pickers is roughly seven hundred points of
/// calendar for a question that takes two taps.
public struct DateCapsuleRow: View {
    public struct Components: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let date = Components(rawValue: 1 << 0)
        public static let time = Components(rawValue: 1 << 1)
    }

    private let label: String
    private let components: Components
    private let minimum: Date?
    private let maximum: Date?
    private let identifier: String?
    @Binding private var selection: Date

    @State private var expanded: Expansion?

    private enum Expansion: Equatable { case date, time }

    public init(
        _ label: String,
        selection: Binding<Date>,
        components: Components = [.date, .time],
        minimum: Date? = nil,
        maximum: Date? = nil,
        identifier: String? = nil
    ) {
        self.label = label
        self._selection = selection
        self.components = components
        self.minimum = minimum
        self.maximum = maximum
        self.identifier = identifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ComposerRow(label) {
                HStack(spacing: 8) {
                    if components.contains(.date) {
                        capsule(
                            text: selection.formatted(date: .abbreviated, time: .omitted),
                            expansion: .date
                        )
                    }
                    if components.contains(.time) {
                        capsule(
                            text: selection.formatted(date: .omitted, time: .shortened),
                            expansion: .time
                        )
                    }
                }
            }
            if let expanded {
                picker(for: expanded)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .modifier(FieldIdentity(identifier: identifier))
        .lifeBoardMotion(.controlMorph, value: expanded)
    }

    private func capsule(text: String, expansion: Expansion) -> some View {
        let isOpen = expanded == expansion
        return Button {
            Haptic.pick.play()
            expanded = isOpen ? nil : expansion
        } label: {
            Text(text)
                .font(.lifeboard(.bodyStrong))
                .monospacedDigit()
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .lineLimit(1)
                // Never shrink the value to preserve the row; the row gives way.
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 11)
                .frame(minHeight: 38)
                .lifeBoardClaySurface(
                    isOpen ? .raised : .well,
                    cornerRadius: Radius.pill
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(label), \(text)"))
        .accessibilityHint(Text(isOpen ? "Collapses the picker" : "Expands the picker"))
        .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
    }

    /// The two styles branch as *views*, not as a ternary on the style value:
    /// `.graphical` and `.wheel` are distinct types, so one expression cannot
    /// produce both.
    @ViewBuilder
    private func picker(for expansion: Expansion) -> some View {
        switch expansion {
        case .date:
            boundedPicker(displaying: [.date])
                .datePickerStyle(.graphical)
                .modifier(DatePickerChrome())
        case .time:
            boundedPicker(displaying: [.hourAndMinute])
                .datePickerStyle(.wheel)
                .modifier(DatePickerChrome())
        }
    }

    /// One initializer per range shape. `DatePicker` has no single initializer
    /// that accepts an optional lower and upper bound, and the call sites
    /// genuinely need all four combinations.
    @ViewBuilder
    private func boundedPicker(displaying displayed: DatePickerComponents) -> some View {
        switch (minimum, maximum) {
        case (let low?, let high?):
            DatePicker(label, selection: $selection, in: low...high, displayedComponents: displayed)
        case (let low?, nil):
            DatePicker(label, selection: $selection, in: low..., displayedComponents: displayed)
        case (nil, let high?):
            DatePicker(label, selection: $selection, in: ...high, displayedComponents: displayed)
        case (nil, nil):
            DatePicker(label, selection: $selection, displayedComponents: displayed)
        }
    }
}

private struct DatePickerChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .lifeBoardClaySurface(.well, cornerRadius: Radius.card)
    }
}

// MARK: - Danger row

/// A destructive action that looks like one.
///
/// Rendered on a `.well` and never on raised clay: raised clay is the language
/// this app uses for the thing it wants you to do, and a delete that sits proud
/// of the surface reads as an invitation. It owns its own confirmation dialog so
/// no call site can forget to explain the consequence first, which DESIGN.md
/// requires before anything destructive.
public struct DangerRow: View {
    private let title: String
    private let systemImage: String
    private let confirmationTitle: String
    private let confirmationMessage: String
    private let confirmActionTitle: String
    private let identifier: String?
    private let perform: () -> Void

    @State private var isConfirming = false

    public init(
        _ title: String,
        systemImage: String = "trash",
        confirmationTitle: String,
        confirmationMessage: String,
        confirmActionTitle: String = "Delete",
        identifier: String? = nil,
        perform: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.confirmationTitle = confirmationTitle
        self.confirmationMessage = confirmationMessage
        self.confirmActionTitle = confirmActionTitle
        self.identifier = identifier
        self.perform = perform
    }

    public var body: some View {
        Button {
            Haptic.decline.play()
            isConfirming = true
        } label: {
            Label(title, systemImage: systemImage)
                .font(.lifeboard(.bodyStrong))
                .foregroundStyle(Color.lifeboard(.statusDanger))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.compact + 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(FieldIdentity(identifier: identifier))
        .confirmationDialog(confirmationTitle, isPresented: $isConfirming, titleVisibility: .visible) {
            Button(confirmActionTitle, role: .destructive) {
                perform()
                Haptic.commit.play()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }
}

// MARK: - Reorderable rows

/// Clay rows you can reorder by dragging, with no edit mode.
///
/// Dropping `EditButton` removes the only Switch Control and keyboard path to
/// reordering that the list had, so the per-row "Move up" and "Move down"
/// accessibility actions here are mandatory rather than a nicety — every gesture
/// needs a non-gesture equivalent. The grip glyph is always visible for the same
/// reason: a capability discoverable only by guessing that a row is draggable is
/// not a capability.
public struct ReorderableRows<Item: Identifiable & Equatable, RowContent: View>: View {
    private let rowIdentifier: (Item) -> String
    private let accessibilityLabel: (Item) -> String
    private let row: (Item) -> RowContent
    @Binding private var items: [Item]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggingID: Item.ID?
    @State private var dragTranslation: CGFloat = 0

    /// Uniform row pitch used to convert a drag into an index displacement. Rows
    /// in these lists are single-line by construction; the drop still resolves
    /// correctly if a row is taller, it just needs slightly more travel.
    private let rowPitch: CGFloat = 56

    public init(
        items: Binding<[Item]>,
        rowIdentifier: @escaping (Item) -> String,
        accessibilityLabel: @escaping (Item) -> String,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self._items = items
        self.rowIdentifier = rowIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.row = row
    }

    public var body: some View {
        VStack(spacing: 8) {
            ForEach(items) { item in
                rowBody(item)
            }
        }
        .lifeBoardMotion(.cardReflow, value: items)
    }

    private func rowBody(_ item: Item) -> some View {
        let isDragging = draggingID == item.id
        let index = items.firstIndex(of: item) ?? 0

        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.lifeboard(.support))
                .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                .frame(width: 28, height: 44)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
            row(item)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 52)
        .lifeBoardClaySurface(
            isDragging ? .floating : .resting,
            cornerRadius: Radius.card
        )
        .offset(y: isDragging ? dragTranslation : 0)
        .zIndex(isDragging ? 1 : 0)
        .gesture(dragGesture(for: item))
        .accessibilityIdentifier(rowIdentifier(item))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel(item)))
        .accessibilityValue(Text("Position \(index + 1) of \(items.count)"))
        .accessibilityAction(named: Text("Move up")) { move(item, by: -1) }
        .accessibilityAction(named: Text("Move down")) { move(item, by: 1) }
    }

    private func dragGesture(for item: Item) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .onEnded { _ in
                draggingID = item.id
                Haptic.lift.play()
            }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { sequence in
                guard case .second(_, let drag?) = sequence else { return }
                dragTranslation = drag.translation.height
            }
            .onEnded { _ in
                defer {
                    draggingID = nil
                    dragTranslation = 0
                }
                guard items.contains(item) else { return }
                let displacement = Int((dragTranslation / rowPitch).rounded())
                guard displacement != 0 else {
                    Haptic.settle.play()
                    return
                }
                move(item, by: displacement)
            }
    }

    private func move(_ item: Item, by displacement: Int) {
        guard let current = items.firstIndex(of: item) else { return }
        let target = min(max(current + displacement, 0), items.count - 1)
        guard target != current else { return }
        var updated = items
        let moved = updated.remove(at: current)
        updated.insert(moved, at: target)
        items = updated
        Haptic.settle.play()
    }
}
