import SwiftUI

/// Filter chip: a hairline soft rectangle, no fill. Selected = ink fill, paper text.
/// A `tint` (Pro-mode category chips) fills the unselected state instead of the hairline.
struct Chip: View {
    var title: String
    var symbol: String? = nil
    var isSelected = false
    var tint: Color? = nil
    var action: () -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.chip, style: .continuous) }

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .regular)) }
                Text(title).font(HDFont.sub.weight(.medium))
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .foregroundStyle(isSelected ? Palette.paper : Palette.ink)
            .background(isSelected ? Palette.ink : (tint ?? Color.clear), in: shape)
            .overlay(shape.strokeBorder((isSelected || tint != nil) ? Color.clear : Palette.inkFaint, lineWidth: 1))
        }
        .buttonStyle(PressLift(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Booking status: a 5pt dot in the status colour and the word, tracked. Cancelled gets no dot.
struct StatusBadge: View {
    var status: BookingStatus
    var body: some View {
        HStack(spacing: 6) {
            if !status.isCancelled {
                Circle().fill(status.color).frame(width: 5, height: 5)
            }
            Text(status.label)
                .font(HDFont.label)
                .textCase(.uppercase)
                .tracking(1.2)
                .lineLimit(1)
        }
        .foregroundStyle(status.isCancelled ? Palette.inkSoft : Palette.ink)
        .accessibilityLabel("Status: \(status.label)")
    }
}

/// Small "ID checked" mark next to a name. Ink, not green: it's a fact, not a reward.
struct VerifiedBadge: View {
    var compact = false
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal").font(.system(size: compact ? 11 : 12, weight: .regular))
            if !compact {
                Text("ID checked").font(HDFont.label).textCase(.uppercase).tracking(1.2)
            }
        }
        .foregroundStyle(Palette.inkSoft)
        .accessibilityLabel("ID checked")
    }
}

/// Tiny tag: "Instant book", "Popular", "Pinned". Tracked text; a background only when the caller
/// passes one (tags sitting on a photo pass paper).
struct Tag: View {
    var text: String
    var color: Color = Palette.inkSoft
    var background: Color = Color.clear
    var body: some View {
        Text(text)
            .font(HDFont.label)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(background, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}
