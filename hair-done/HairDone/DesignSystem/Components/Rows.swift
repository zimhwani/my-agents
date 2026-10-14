import SwiftUI

// MARK: - HairlineRow

/// The list row for paper screens, in place of cards and `List(.insetGrouped)`: an optional outline
/// glyph, title SF 17, optional sub SF 15 inkSoft, an optional value or trailing view, an optional
/// bare chevron, and a 0.5pt `lineStrong` hairline under it. Stack them in a plain `VStack(spacing: 0)`
/// at the screen gutter.
///
///     HairlineRow(title: "Addresses", value: "2") { showAddresses = true }
///     HairlineRow(title: "Monday", trailing: Text("9:00 am to 5:00 pm").font(HDFont.priceSmall)) { editHours(.monday) }
///
/// `trailing` is a view value, not a closure, so the trailing closure is always the action.
struct HairlineRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var value: String?
    var symbol: String?
    var chevron: Bool
    var showsHairline: Bool
    var action: (() -> Void)?
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        symbol: String? = nil,
        chevron: Bool = true,
        showsHairline: Bool = true,
        trailing: Trailing,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.symbol = symbol
        self.chevron = chevron
        self.showsHairline = showsHairline
        self.action = action
        self.trailing = trailing
    }

    var body: some View {
        if let action {
            Button(action: { Haptics.light(); action() }) { row }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
        } else {
            row.accessibilityElement(children: .combine)
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: Space.m) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HDFont.body).foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            if let value {
                Text(value).font(HDFont.sub).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            trailing
            if chevron && action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.inkFaint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.m)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if showsHairline { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        }
    }
}

extension HairlineRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        symbol: String? = nil,
        chevron: Bool = true,
        showsHairline: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.init(title: title, subtitle: subtitle, value: value, symbol: symbol, chevron: chevron,
                  showsHairline: showsHairline, trailing: EmptyView(), action: action)
    }
}

// MARK: - ChecklistRow

/// One thing to do on a setup list (pro onboarding, Today's "Before you go live"): an ink tick
/// when it's done, or a `Do it` ink text link when it isn't. Hairline under.
///
///     ChecklistRow(title: "Payouts", subtitle: "So your money has somewhere to land.", isDone: payoutsOn) { setUpPayouts() }
struct ChecklistRow: View {
    var title: String
    var subtitle: String? = nil
    var isDone: Bool
    var actionTitle: String = "Do it"
    var action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HDFont.body).foregroundStyle(isDone ? Palette.inkSoft : Palette.ink)
                if let subtitle {
                    Text(subtitle).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Done")
            } else {
                TertiaryButton(title: actionTitle, tint: Palette.ink, action: action)
            }
        }
        .padding(.vertical, Space.s)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ProEyebrow

/// The pro-side marker above every pro tab root's serif title: "PRO · KIARA M." in the eyebrow
/// style. Client tab roots carry the suburb instead.
///
///     ProEyebrow(name: pro.displayName)
///     Text("Today.").font(HDFont.display)
struct ProEyebrow: View {
    var name: String
    /// An extra fact after the name: "PRO · KIARA M. · 2 REQUESTS".
    var detail: String? = nil
    var color: Color = Palette.inkSoft

    var body: some View {
        Text(([ "Pro", name ] + (detail.map { [$0] } ?? [])).joined(separator: " · "))
            .eyebrowStyle(color: color)
            .lineLimit(1)
            .accessibilityLabel("Pro mode, \(name)" + (detail.map { ", \($0)" } ?? ""))
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Rows") {
    VStack(alignment: .leading, spacing: 0) {
        ProEyebrow(name: "Kiara M.")
        Text("Today.").font(HDFont.display).foregroundStyle(Palette.ink).padding(.bottom, 24)
        HairlineRow(title: "Your details", value: "Tash") {}
        HairlineRow(title: "Notifications", symbol: "bell", action: {})
        HairlineRow(title: "Monday", trailing: Text("9:00 am to 5:00 pm").font(HDFont.priceSmall).foregroundStyle(Palette.ink)) {}
        ChecklistRow(title: "Work photos", subtitle: "Three good ones.", isDone: true) {}
        ChecklistRow(title: "Payouts", subtitle: "So your money has somewhere to land.", isDone: false) {}
    }
    .padding(20)
    .paperBackground()
}
