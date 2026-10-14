import SwiftUI

// MARK: - HDTextField

/// An underline field, like Home's search: label SF 13 inkSoft above, SF 17 text, a 1pt `line` rule
/// under it that turns into a 2pt ink rule while focused. With an `error`, the rule turns warn and
/// the message shows under it in ink with a 6pt warn dot (never lacquer, never red).
/// A `caption` is a quiet hint under the field when there's no error.
///
///     HDTextField(label: "Postcode", placeholder: "3000", text: $postcode, keyboard: .numberPad,
///                 error: postcodeError)
struct HDTextField: View {
    var label: String
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType
    var contentType: UITextContentType?
    var axis: Axis
    var caption: String?
    var error: String?

    @FocusState private var focused: Bool

    init(
        label: String,
        placeholder: String = "",
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        axis: Axis = .horizontal,
        caption: String? = nil,
        error: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
        self.contentType = contentType
        self.axis = axis
        self.caption = caption
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !label.isEmpty {
                Text(label)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.bottom, Space.xs)
            }
            TextField(placeholder, text: $text, axis: axis)
                .font(HDFont.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.ink)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .focused($focused)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(ruleColor)
                        .frame(height: focused ? 2 : 1)
                        .animation(Motion.gentle, value: focused)
                }
            if let error {
                FieldMessage(text: error)
                    .padding(.top, Space.s)
            } else if let caption {
                Text(caption)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, Space.s)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(error ?? "")
    }

    private var ruleColor: Color {
        if error != nil { return Palette.warn }
        return focused ? Palette.ink : Palette.line
    }
}

/// An inline problem under a field or control: a 6pt warn dot, then SF 13 ink.
struct FieldMessage: View {
    var text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Circle().fill(Palette.warn).frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
                .accessibilityHidden(true)
            Text(text)
                .font(HDFont.caption)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - HDSwitch

/// An ink switch: a squared 40x24 track (6pt corners), `line` when off and ink when on, with an
/// 18pt paper knob at 4pt corners. No lacquer, no green.
///
///     Toggle("Instant book", isOn: $instant).toggleStyle(.hd)
///     HDSwitch(title: "Taking bookings", subtitle: "Off hides you from search.", isOn: $open)
struct HDSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.spring) { configuration.isOn.toggle() }
        } label: {
            HStack(alignment: .center, spacing: Space.m) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(configuration.isOn ? Palette.ink : Palette.line)
                        .frame(width: 40, height: 24)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Palette.paper)
                        .frame(width: 18, height: 18)
                        .padding(3)
                }
                .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

extension ToggleStyle where Self == HDSwitchStyle {
    /// The ink switch. See `HDSwitchStyle`.
    static var hd: HDSwitchStyle { HDSwitchStyle() }
}

/// A settings row with an ink switch: title SF 17, optional subtitle SF 15 inkSoft.
struct HDSwitch: View {
    var title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HDFont.body).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.hd)
    }
}

// MARK: - HDStepper

/// A value in SF 17 monospaced between two bare 44pt `minus` and `plus` glyphs in ink.
/// The glyph at a limit fades to inkFaint and stops.
///
///     HDStepper(title: "Buffer between jobs", value: $buffer, in: 0...60, step: 15) { "\($0) min" }
struct HDStepper: View {
    var title: String?
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int
    var format: (Int) -> String

    init(title: String? = nil, value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1,
         format: @escaping (Int) -> String = { "\($0)" }) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        HStack(spacing: 0) {
            if let title {
                Text(title).font(HDFont.body).foregroundStyle(Palette.ink)
                Spacer(minLength: Space.m)
            }
            glyph("minus", label: "Less", enabled: value - step >= range.lowerBound) { value = max(range.lowerBound, value - step) }
            Text(format(value))
                .font(HDFont.price)
                .foregroundStyle(Palette.ink)
                .frame(minWidth: 56)
                .contentTransition(.numericText())
            glyph("plus", label: "More", enabled: value + step <= range.upperBound) { value = min(range.upperBound, value + step) }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title ?? "Value")
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func glyph(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            Haptics.selection()
            withAnimation(Motion.gentle) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(enabled ? Palette.ink : Palette.inkFaint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct FieldsPreview: View {
    @State private var name = "Kiara"
    @State private var postcode = "30"
    @State private var instant = true
    @State private var buffer = 15
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HDTextField(label: "First name", text: $name, caption: "It's what clients see.")
            HDTextField(label: "Postcode", placeholder: "3000", text: $postcode, keyboard: .numberPad, error: "Four digits. Try again.")
            HDSwitch(title: "Instant book", subtitle: "Clients book without waiting on you.", isOn: $instant)
            HDStepper(title: "Buffer", value: $buffer, in: 0...60, step: 15) { "\($0) min" }
        }
        .padding(20)
        .paperBackground()
    }
}

#Preview("Fields") { FieldsPreview() }
