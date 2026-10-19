import SwiftUI

/// "Get receipt" on a paid booking: the receipt split by who's charging (her, with her ABN; Hair Done,
/// with ours), "Total paid", the card and when, and the small print. Not GST registered, so it's a
/// receipt and says "No GST included". "Email it to me" sends the same thing; Share sends it as text.
/// Mockup: docs/design/mockups/12-receipt-sheet.png.
struct ReceiptSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var booking: Booking

    @State private var details: ReceiptDetails? = nil
    @State private var emailing = false
    @State private var problem: String? = nil

    private var pro: Pro? { app.pro(booking.proID) }
    private var proFirst: String { pro?.firstName ?? "Your pro" }
    private var proName: String { pro?.displayName ?? proFirst }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            .padding(.horizontal, Space.gutter - 12)
            .padding(.top, Space.s)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Receipt · \(booking.reference)").labelStyle()
                    Text(booking.receiptTitle(proName: proName))
                        .font(HDFont.titleSmall)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.s)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(booking.start.shortDay), \(booking.start.clock)\n\(booking.address.full)")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xs)

                    from(proName, abn: details?.proABN)
                    ForEach(booking.receiptProLines(proFirst: proFirst), id: \.self, content: line)
                    from(HairDoneBusiness.name, abn: HairDoneBusiness.abn)
                    ForEach(booking.receiptHairDoneLines, id: \.self, content: line)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Total paid").font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                        Spacer(minLength: Space.m)
                        Text(Money.format(booking.price.clientTotalCents, alwaysCents: true))
                            .font(HDFont.priceTotal)
                            .foregroundStyle(Palette.ink)
                    }
                    .padding(.top, Space.l)
                    .accessibilityElement(children: .combine)

                    if let paid = details?.paidLine {
                        Text(paid).font(HDFont.sub).foregroundStyle(Palette.inkSoft).padding(.top, Space.xs)
                    }

                    Text(Booking.receiptFooter(proFirst: proFirst))
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.l)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }

            VStack(spacing: Space.xs) {
                if let problem {
                    FieldMessage(text: problem).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: Space.s) {
                    if details?.canEmail ?? false {
                        InkButton(title: "Email it to me", isLoading: emailing, isEnabled: !app.isOffline) { email() }
                    }
                    ShareLink(item: booking.receiptText(proName: proName, proFirst: proFirst, details: details),
                              subject: Text("Hair Done receipt \(booking.reference)")) {
                        Text("Share")
                            .font(HDFont.bodyStrong)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                .strokeBorder(Palette.ink, lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    }
                    .frame(maxWidth: details?.canEmail ?? false ? 120 : .infinity)
                    .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                }
            }
            .screenGutter()
            .padding(.bottom, Space.s)
        }
        .paperBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .task { details = await app.receiptDetails(booking) }
    }

    private func from(_ who: String, abn: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("From \(who)").font(HDFont.subStrong).foregroundStyle(Palette.ink)
            Spacer(minLength: Space.s)
            if let abn { Text("ABN \(abn)").font(HDFont.caption.monospacedDigit()).foregroundStyle(Palette.inkSoft) }
        }
        .padding(.top, Space.l)
        .accessibilityElement(children: .combine)
    }

    private func line(_ l: ReceiptLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.name).font(HDFont.body).foregroundStyle(Palette.ink)
                if !l.note.isEmpty {
                    Text(l.note).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: Space.s)
            Text(l.amount).font(HDFont.price).foregroundStyle(Palette.ink)
        }
        .padding(.vertical, Space.s + 2)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
        .accessibilityElement(children: .combine)
    }

    private func email() {
        problem = nil
        emailing = true
        Task {
            defer { emailing = false }
            do {
                let to = try await app.data.emailReceipt(bookingID: booking.id)
                Haptics.success()
                app.show("Sent to \(to).")
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
