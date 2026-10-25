import SwiftUI

/// Move a booking to another of her real free slots. The same day strip and squared slots as the
/// booking flow, with the ink bar at the bottom. Under 24 hours it can't move, so the sheet says so
/// up front and points to Message (or cancelling from the booking) instead of a dead end.
struct RescheduleSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var booking: Booking

    @State private var newStart: Date? = nil
    @State private var isMoving = false
    @State private var problem: String? = nil
    @State private var reload = 0

    /// A placed card hold (`hold_state` 'held') can't stretch past six days from now
    /// (`reschedule_booking` says `too_far_to_move`). Then the strip is seven columns (today plus
    /// six) and the last day's times stop at exactly now + 6 days. Otherwise the normal two weeks.
    private static let heldDays = 7
    private static let normalDays = 14
    private static let holdLimit: TimeInterval = 6 * 24 * 60 * 60

    private var isHeld: Bool { booking.holdState == "held" }
    private var daysAhead: Int { isHeld ? RescheduleSheet.heldDays : RescheduleSheet.normalDays }

    /// The latest start the server will take while the hold is placed; nil when there's no limit.
    /// Computed on each render so it never goes stale.
    private var latestStart: Date? { isHeld ? Date().addingTimeInterval(RescheduleSheet.holdLimit) : nil }

    private var tooLate: Bool { booking.hoursUntil < Double(Fees.freeCancellationHours) }

    var body: some View {
        Group {
            if let pro = app.pro(booking.proID) {
                if tooLate {
                    tooLateContent(pro)
                } else {
                    content(pro)
                }
            } else {
                VStack(spacing: 0) {
                    SheetHeader(title: "Pick a new time", onClose: { dismiss() })
                    EmptyState(title: "We couldn't find them.", message: "Try again from your bookings.")
                    Spacer(minLength: 0)
                }
                .paperBackground()
            }
        }
        .presentationBackground(Palette.paper)
        .holdsPushRoutes()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Under 24 hours

    private func tooLateContent(_ pro: Pro) -> some View {
        let charge = booking.cancellationChargeCents
        return VStack(spacing: 0) {
            SheetHeader(title: "Too close to move", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text("It's under 24 hours away, so it can't move now. Message \(pro.firstName) to sort something out, or cancel from the booking.")
                        .font(HDFont.body)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if charge > 0 {
                        Text("Cancelling now costs \(Money.format(charge)). They've already turned down other work for you.")
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: Space.xs) {
                        InkButton(title: "Message \(pro.firstName)") { message() }
                        TertiaryButton(title: "Back to the booking") { dismiss() }
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, Space.s)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.xl)
            }
        }
        .paperBackground()
    }

    // MARK: Picking a new time

    private func content(_ pro: Pro) -> some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Pick a new time",
                subtitle: "Free with more than 24 hours' notice.",
                onClose: { dismiss() }
            )
            if app.isOffline { OfflineBar() }

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Booked for \(booking.start.friendlyDayInSentence) at \(booking.start.clock) · \(booking.minutes.minutesLabel)")
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(pro.firstName)'s told straight away. Nothing changes on your card.")
                            .font(HDFont.caption)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .screenGutter()

                    SlotPicker(pro: pro, minutes: booking.minutes, selected: $newStart, days: daysAhead, reload: reload, latestStart: latestStart)

                    if let problem {
                        FieldMessage(text: problem)
                            .screenGutter()
                            .transition(.opacity)
                    }
                }
                .padding(.top, Space.m)
                .padding(.bottom, Space.xl)
                .animation(Motion.spring, value: problem)
            }

            BookBar(
                name: pro.firstName,
                summary: nil,
                detail: newStart.map { "\($0.friendlyDay), \($0.clock)" } ?? "Pick a time",
                actionTitle: "Move it",
                isEnabled: canMove,
                isLoading: isMoving
            ) { move(pro) }
        }
        .paperBackground()
        .animation(Motion.gentle, value: app.isOffline)
    }

    private var canMove: Bool {
        guard let newStart, !app.isOffline else { return false }
        if let latestStart, newStart > latestStart { return false }
        return newStart != booking.start
    }

    private func move(_ pro: Pro) {
        guard let start = newStart, !isMoving else { return }
        isMoving = true
        withAnimation(Motion.gentle) { problem = nil }
        Task { @MainActor in
            let moved = await app.reschedule(booking, to: start)
            isMoving = false
            guard moved else {
                let why = app.lastError ?? "That didn't move. Your booking's still at \(booking.start.clock). Try again."
                withAnimation(Motion.spring) { problem = why }
                // Someone took it, or it's past the hold: show what's free now.
                newStart = nil
                reload += 1
                return
            }
            dismiss()
            app.show("Moved to \(start.friendlyDayInSentence) at \(start.clock). \(pro.firstName)'s been told.")
        }
    }

    /// Her thread, on the Inbox tab.
    private func message() {
        let thread = app.thread(for: booking)
        dismiss()
        app.selectedTab = .inbox
        if let thread { app.pendingRoute = .thread(thread.id) }
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
