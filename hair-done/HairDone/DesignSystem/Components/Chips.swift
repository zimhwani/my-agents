import SwiftUI

/// Deprecated: the pill chip is gone. Now draws a compact `OptionBox` (6pt, 1pt line border,
/// ink fill when selected). `symbol` and `tint` are ignored: no icons, no category tints.
/// Replace with `TextTabs` (a filter or segment), `OptionBox` (a choice) or a text link (an action).
struct Chip: View {
    var title: String
    var symbol: String? = nil
    var isSelected = false
    var tint: Color? = nil
    var action: () -> Void

    var body: some View {
        OptionBox(title: title, isSelected: isSelected, action: action)
            .fixedSize()
    }
}

/// Booking status as an eyebrow: a 6pt dot in the status colour, then tracked caps in ink.
/// Cancelled and declined have no dot and sit in inkSoft. No pill, no fill.
struct StatusBadge: View {
    var status: BookingStatus
    /// True on the pro side: the pro's words ("Waiting on you", "Client cancelled").
    var forPro: Bool = false
    private var text: String { forPro ? status.proLabel : status.label }
    var body: some View {
        HStack(spacing: 6) {
            if !status.isCancelled {
                Circle().fill(status.color).frame(width: 6, height: 6)
            }
            Text(text)
                .eyebrowStyle(color: status.isCancelled ? Palette.inkSoft : Palette.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(text)")
    }
}

/// "ID checked", in plain inkSoft text. No seal, no green.
struct VerifiedBadge: View {
    /// Kept for old call sites; both forms say "ID checked", compact in caption size.
    var compact = false
    var body: some View {
        Text("ID checked")
            .font(compact ? HDFont.caption : HDFont.sub)
            .foregroundStyle(Palette.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("ID checked")
    }
}

/// A tag is text: "POPULAR", "DEFAULT", "PINNED" as a 12pt tracked eyebrow in inkSoft, beside or
/// above the thing. Never on a photo, never in a pill. `color` and `background` are ignored
/// (kept so old call sites compile).
struct Tag: View {
    var text: String
    var color: Color = Palette.inkSoft
    var background: Color = Palette.line
    var body: some View {
        Text(text)
            .eyebrowStyle()
            .lineLimit(1)
            .fixedSize()
    }
}

#Preview("Tags and status") {
    VStack(alignment: .leading, spacing: 16) {
        StatusBadge(status: .confirmed)
        StatusBadge(status: .requested)
        StatusBadge(status: .cancelledByClient)
        HStack { Text("BIAB overlay").font(HDFont.body); Tag(text: "Popular") }
        HStack { Text("Kiara M.").font(HDFont.name); VerifiedBadge(compact: true) }
        HStack { Chip(title: "15 km", isSelected: true) {}; Chip(title: "25 km") {} }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .paperBackground()
}
