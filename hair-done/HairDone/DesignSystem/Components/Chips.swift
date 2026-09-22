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

/// Status pill for bookings.
struct StatusBadge: View {
    var status: BookingStatus
    var body: some View {
        Text(status.label)
            .font(HDFont.label)
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.softColor, in: Capsule())
            .accessibilityLabel("Status: \(status.label)")
    }
}

/// Small "Verified" mark next to a name.
struct VerifiedBadge: View {
    var compact = false
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: compact ? 12 : 13, weight: .semibold))
            if !compact { Text("Verified").font(HDFont.label) }
        }
        .foregroundStyle(Palette.success)
        .accessibilityLabel("Verified pro")
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }
}
