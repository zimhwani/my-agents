import SwiftUI

/// Pill filter chip. Selected = ink fill.
struct Chip: View {
    var title: String
    var symbol: String? = nil
    var isSelected = false
    var tint: Color? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .medium)) }
                Text(title).font(HDFont.subStrong)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .foregroundStyle(isSelected ? Palette.paper : Palette.ink)
            .background(isSelected ? Palette.ink : (tint ?? Palette.card), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressLift(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Status for bookings: a small dot in the status colour and tracked text. Cancelled has no dot.
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
                .fixedSize()
        }
        .foregroundStyle(status.isCancelled ? Palette.inkSoft : Palette.ink)
        .accessibilityLabel("Status: \(status.label)")
    }
}

/// Small "ID checked" mark next to a name.
struct VerifiedBadge: View {
    var compact = false
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: compact ? 12 : 13, weight: .semibold))
            if !compact { Text("ID checked").font(HDFont.label) }
        }
        .foregroundStyle(Palette.success)
        .accessibilityLabel("ID checked")
    }
}

/// Tiny tag: "Instant book", "Popular", "Pinned".
struct Tag: View {
    var text: String
    var color: Color = Palette.inkSoft
    var background: Color = Palette.line
    var body: some View {
        Text(text)
            .font(HDFont.label)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }
}
