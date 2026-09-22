import SwiftUI

/// Move a booking to another of her real free slots. Reuses the flow's day strip and slot grid.
struct RescheduleSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var booking: Booking

    @State private var newStart: Date? = nil
    @State private var isMoving = false
    @State private var problem: String? = nil

    var body: some View {
        Group {
            if let pro = app.pro(booking.proID) {
                content(pro)
            } else {
                EmptyState(symbol: "person.crop.circle.badge.questionmark", title: "We couldn't find her.", message: "Try again from your bookings.")
                    .paperBackground()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func content(_ pro: Pro) -> some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Pick a new time",
                subtitle: "Free with more than 24 hours' notice. Inside that, it counts as a cancel.",
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Booked for \(booking.start.friendlyDayInSentence) at \(booking.start.clock) · \(booking.minutes.minutesLabel)")
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                        if !pro.instantBook {
                            Text("\(pro.firstName) confirms each booking herself, so a new time goes back to her to say yes.")
                                .font(HDFont.caption)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .screenGutter()

                    SlotPicker(pro: pro, minutes: booking.minutes, selected: $newStart)

                    if let problem {
                        InlineNote(text: problem, tone: .warn)
                            .screenGutter()
                            .transition(.opacity)
                    }
                }
                .padding(.top, Space.m)
                .padding(.bottom, Space.xl)
                .animation(Motion.spring, value: problem)
            }

            StickyBar(title: ctaTitle(pro), isLoading: isMoving, isEnabled: canMove, action: { move(pro) }) {
                if let newStart {
                    Text("\(newStart.friendlyDay), \(newStart.clock)")
                        .font(HDFont.subStrong)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Pick a time")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .paperBackground()
    }

    private var canMove: Bool {
        guard let newStart else { return false }
        return newStart != booking.start
    }

    private func ctaTitle(_ pro: Pro) -> String {
        guard newStart != nil else { return "Move it" }
        return pro.instantBook ? "Move it" : "Ask \(pro.firstName)"
    }

    private func move(_ pro: Pro) {
        guard let start = newStart, !isMoving else { return }
        isMoving = true
        withAnimation(Motion.gentle) { problem = nil }
        Task { @MainActor in
            await app.reschedule(booking, to: start)
            isMoving = false
            let moved = app.bookings.first { $0.id == booking.id }?.start == start
                || app.proBookings.first { $0.id == booking.id }?.start == start
            guard moved else {
                withAnimation(Motion.spring) { problem = "That didn't work. Try again." }
                return
            }
            dismiss()
            if pro.instantBook {
                app.show("Moved to \(start.friendlyDayInSentence) at \(start.clock).")
            } else {
                app.show("Asked. \(pro.firstName) usually replies within \(pro.replyWindow).")
            }
        }
    }
}

#Preview("Reschedule") {
    let app = previewApp()
    return Group {
        if let booking = app.upcomingBookings.first {
            Color.clear
                .sheet(isPresented: .constant(true)) { RescheduleSheet(booking: booking) }
        }
    }
    .environment(app)
}
