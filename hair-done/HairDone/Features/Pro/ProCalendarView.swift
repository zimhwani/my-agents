import SwiftUI

/// Her week, and the hours she works. Blocking a day saves at once (with Undo); changes to her
/// usual hours wait for Save, which slides up only once something's changed.
struct ProCalendarView: View {
    @Environment(AppState.self) private var app

    private enum Segment: String, CaseIterable { case week = "Week", hours = "Hours" }
    private enum DayItem: Identifiable {
        case booking(Booking)
        case free(Int, Int)
        var id: String {
            switch self {
            case .booking(let b): return b.id
            case .free(let a, let z): return "free_\(a)_\(z)"
            }
        }
        var startMinute: Int {
            switch self {
            case .booking(let b): return b.start.hourOfDay * 60 + b.start.minuteOfHour
            case .free(let a, _): return a
            }
        }
    }

    @State private var segment: Segment = .week
    @State private var weekStart: Date = ProWeek.monday(of: Date())
    @State private var selectedDay: Date = Date().startOfDay
    @State private var blocking = false
    @State private var hoursDraft = HoursDraft()
    @State private var hoursLoaded = false
    @State private var savingHours = false
    @State private var hoursFailed = false
    private let unsavedID = "calendar.hours"
    private var savedHours: HoursDraft { HoursDraft(app.proSelf) }
    private var hoursDirty: Bool { hoursLoaded && hoursDraft != savedHours }
    /// The day just blocked or unblocked, for Undo.
    @State private var undo: UndoDay? = nil

    private struct UndoDay: Equatable {
        let day: Date
        let wasBlocked: Bool
        let line: String
    }

    private var availability: WeeklyAvailability { app.proSelf?.availability ?? .standard }
    /// Kept in `AppState`, so switching to booking and back lands on the same screen.
    private var path: Binding<NavigationPath> { app.path(for: ProTab.calendar) }
    private var isCurrentWeek: Bool { weekStart == ProWeek.monday(of: Date()) }

    var body: some View {
        NavigationStack(path: path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }
                    ProTabHeader("Calendar.") {
                        TextTabs(selection: $segment, options: Segment.allCases) { $0.rawValue }
                    }
                    .padding(.top, Space.s)
                    if app.proSideLoadFailed && app.proBookings.isEmpty && segment == .week {
                        ErrorState { Task { await app.loadProSide() } }
                            .padding(.horizontal, -Space.gutter)
                    } else if app.showsProSideSkeleton && segment == .week {
                        // Before the first load: not "Free all day." yet.
                        VStack(alignment: .leading, spacing: Space.l) {
                            SkeletonBlock(height: 72, radius: Radius.card)
                            SkeletonBlock(width: 160, height: 26)
                            VStack(spacing: 0) { RowSkeleton(); RowSkeleton() }
                        }
                        .padding(.top, Space.xl)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Loading")
                    } else {
                        switch segment {
                        case .week: weekView.padding(.top, Space.xl)
                        case .hours: ProHoursPanel(draft: $hoursDraft).padding(.top, Space.xl)
                        }
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section + 60)
            }
            .paperBackground()
            .refreshable { await app.loadProSide() }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .overlay(alignment: .bottom) { undoBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { hoursSaveBar }
            .animation(Motion.spring, value: hoursDirty)
            .proSideBanner()
        }
        .onAppear {
            if !hoursLoaded { hoursDraft = savedHours; hoursLoaded = true }
            takeCalendarDay()
        }
        // A cell in Today's strip: open on that day.
        .onChange(of: app.calendarDay) { _, _ in takeCalendarDay() }
        .onChange(of: hoursDirty) { _, dirty in
            ProUnsavedWork.shared.update(unsavedID, dirty: dirty, save: { await saveHours() }, discard: { discardHours() })
        }
        // Her saved hours changed underneath (a refresh, another device) and she hadn't touched them here.
        .onChange(of: savedHours) { old, new in
            if hoursDraft == old { hoursDraft = new }
        }
    }

    // MARK: Hours save

    /// The ink bar: slides up only once her hours have changed, on either segment, so it can't be missed.
    @ViewBuilder
    private var hoursSaveBar: some View {
        if hoursDirty {
            VStack(alignment: .leading, spacing: Space.s) {
                if hoursFailed {
                    WarnDotLine(text: "Didn't save. Your changes are still here. Try again.", color: Palette.onInk, font: HDFont.caption)
                }
                HStack(spacing: Space.s) {
                    InkButton(title: "Save hours", isLoading: savingHours, isEnabled: !app.isOffline, tone: .onInk) { Task { _ = await saveHours() } }
                    OutlineButton(title: "Discard", tone: .onInk) { discardHours() }
                        .frame(maxWidth: 140)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)
            .background(Palette.inkGround.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Palette.inkEdge).frame(height: 0.5) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// The day another tab asked for (`AppState.calendarDay`): Week, that week, that day selected.
    private func takeCalendarDay() {
        guard let day = app.calendarDay else { return }
        app.calendarDay = nil
        segment = .week
        weekStart = ProWeek.monday(of: day)
        selectedDay = day.startOfDay
        if !path.wrappedValue.isEmpty { path.wrappedValue = NavigationPath() }
    }

    private func discardHours() {
        withAnimation(Motion.spring) { hoursDraft = savedHours; hoursFailed = false }
        ProUnsavedWork.shared.clear(unsavedID)
    }

    @MainActor
    private func saveHours() async -> Bool {
        guard var p = app.proSelf else { return false }
        savingHours = true
        defer { savingHours = false }
        hoursFailed = false
        hoursDraft.apply(to: &p)
        guard await app.saveProSelf(p) else {
            hoursFailed = true
            return false
        }
        Haptics.success()
        app.show("Saved.")
        ProUnsavedWork.shared.clear(unsavedID)
        return true
    }

    // MARK: Week

    private var weekView: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(spacing: 0) {
                IconButton(symbol: "chevron.left", label: "Previous week") { move(by: -7) }
                    .padding(.leading, -12)
                Spacer()
                VStack(spacing: 0) {
                    Text("Week of \(weekStart.shortDay)").font(HDFont.sub).foregroundStyle(Palette.ink)
                    if !isCurrentWeek {
                        TertiaryButton(title: "Today", tint: Palette.ink) {
                            withAnimation(Motion.spring) { weekStart = ProWeek.monday(of: Date()); selectedDay = Date().startOfDay }
                        }
                    }
                }
                Spacer()
                IconButton(symbol: "chevron.right", label: "Next week") { move(by: 7) }
                    .padding(.trailing, -12)
            }
            dayStrip
            dayDetail
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 2) {
            ForEach(ProWeek.days(from: weekStart), id: \.self) { day in
                let count = bookings(on: day).count
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                let isToday = Calendar.current.isDateInToday(day)
                let off = availability.ranges(on: day).isEmpty
                Button {
                    Haptics.selection()
                    withAnimation(Motion.spring) { selectedDay = day }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.weekday.short).font(HDFont.caption)
                            .foregroundStyle(isSelected ? Palette.onInkSoft : Palette.inkSoft)
                        Text(day.dayNumber)
                            .font(HDFont.sans(20, relativeTo: .title3).monospacedDigit())
                            .foregroundStyle(isSelected ? Palette.onInk : Palette.ink)
                            .opacity(off && !isSelected ? 0.45 : 1)
                            .padding(.bottom, 2)
                            .overlay(alignment: .bottom) {
                                if isToday && !isSelected { Rectangle().fill(Palette.ink).frame(height: 1) }
                            }
                        HStack(spacing: 2) {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Circle().fill(isSelected ? Palette.onInk : Palette.inkSoft).frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, Space.s)
                    // The ink ground (not `Palette.ink`, cream in dark) with an ink edge: invisible in
                    // light, a cream line in dark, where the ground is darker than the paper.
                    .background(isSelected ? Palette.inkGround : Color.clear, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(isSelected ? Palette.ink : Color.clear, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day.friendlyDay), \(ProFlow.count(count, "booking", "bookings"))\(off ? ", off" : "")")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    @ViewBuilder
    private var dayDetail: some View {
        let items = dayItems(for: selectedDay)
        let blocked = availability.isOff(selectedDay)
        let off = availability.ranges(on: selectedDay).isEmpty
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDay.weekday.long).font(HDFont.titleSmall).foregroundStyle(Palette.ink)
                Text(selectedDay.shortDay).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                Spacer()
                if blocked { Tag(text: "Blocked") } else if off { Tag(text: "Off") }
            }
            .padding(.bottom, Space.xs)
            if items.isEmpty {
                Text(blocked ? "Blocked. Nobody can book you." : (off ? "Off. Nothing booked." : "Free all day."))
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, Space.m)
            } else {
                ForEach(items) { item in
                    switch item {
                    case .booking(let b):
                        NavigationLink(value: Route.proBooking(b.id)) {
                            ProBookingRow(booking: b, clientName: app.clientName(b.clientID), nameKnown: app.isClientNameKnown(b.clientID))
                        }
                        .buttonStyle(.plain)
                    case .free(let a, let z):
                        Text("Free \(TimeRange(startMinutes: a, endMinutes: z).label)")
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            .padding(.vertical, Space.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
                    }
                }
            }
            blockControl.padding(.top, Space.l)
        }
    }

    @ViewBuilder
    private var blockControl: some View {
        let day = selectedDay.startOfDay
        let blocked = availability.isOff(day)
        let isPast = day < Date().startOfDay
        if !isPast {
            VStack(alignment: .leading, spacing: Space.s) {
                if blocked {
                    OutlineButton(title: "Unblock \(day.shortDay)", isLoading: blocking, isEnabled: !app.isOffline, compact: true) {
                        Task { await setBlocked(day, false) }
                    }
                } else {
                    let clash = bookings(on: day).first { $0.status.isUpcoming }
                    OutlineButton(title: clash == nil ? "Block \(day.shortDay)" : "Block anyway", isLoading: blocking, isEnabled: !app.isOffline, compact: true) {
                        Task { await setBlocked(day, true) }
                    }
                    if let clash {
                        let name = app.clientName(clash.clientID)
                        WarnDotLine(text: name.isEmpty
                                    ? "You've got a booking at \(clash.start.clock). Blocking won't cancel it."
                                    : "You've got \(name) at \(clash.start.clock). Blocking won't cancel her.", font: HDFont.caption)
                    } else {
                        Text("Nobody can book you that day. Bookings you've got still stand.")
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
    }

    private func move(by days: Int) {
        withAnimation(Motion.spring) {
            weekStart = weekStart.adding(days: days)
            selectedDay = selectedDay.adding(days: days)
        }
    }

    private func bookings(on day: Date) -> [Booking] {
        app.proBookings
            .filter { Calendar.current.isDate($0.start, inSameDayAs: day) && !$0.status.isCancelled }
            .sorted { $0.start < $1.start }
    }

    /// Bookings for the day, with the quiet gaps of half an hour or more inside her working hours.
    private func dayItems(for day: Date) -> [DayItem] {
        let booked = bookings(on: day)
        var free: [DayItem] = []
        for r in availability.ranges(on: day) {
            var cursor = r.startMinutes
            for b in booked {
                let bs = b.start.hourOfDay * 60 + b.start.minuteOfHour
                let be = bs + b.minutes
                if be <= cursor || bs >= r.endMinutes { continue }
                if bs - cursor >= 30 { free.append(.free(cursor, bs)) }
                cursor = max(cursor, be)
            }
            if r.endMinutes - cursor >= 30 && !booked.isEmpty { free.append(.free(cursor, r.endMinutes)) }
        }
        return (booked.map { DayItem.booking($0) } + free).sorted { $0.startMinute < $1.startMinute }
    }

    // MARK: Blocking, saved at once

    private func setBlocked(_ day: Date, _ on: Bool, isUndo: Bool = false) async {
        guard var p = app.proSelf else { return }
        blocking = true
        defer { blocking = false }
        if on {
            guard !p.availability.isOff(day) else { return }
            p.availability.daysOff.append(day)
        } else {
            p.availability.daysOff.removeAll { Calendar.current.isDate($0, inSameDayAs: day) }
        }
        guard await app.saveProSelf(p) else { return }
        Haptics.success()
        if isUndo {
            withAnimation(Motion.gentle) { undo = nil }
            app.show(on ? "Blocked again." : "Unblocked.")
        } else {
            showUndo(UndoDay(day: day, wasBlocked: on, line: on ? "Blocked \(day.shortDay)." : "Unblocked \(day.shortDay)."))
        }
    }

    private func showUndo(_ u: UndoDay) {
        withAnimation(Motion.spring) { undo = u }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if undo == u { withAnimation(Motion.gentle) { undo = nil } }
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let u = undo {
            HStack(spacing: Space.m) {
                Text(u.line).font(HDFont.sub).foregroundStyle(Palette.onInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    Task { await setBlocked(u.day, !u.wasBlocked, isUndo: true) }
                } label: {
                    Text("Undo").font(HDFont.subMedium).foregroundStyle(Palette.onInk).underline()
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, Space.l)
            .padding(.trailing, Space.s)
            .background(Palette.inkGround, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.inkEdge, lineWidth: 0.5))
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Hours

/// Her usual week, buffer and notice, and the days she's blocked. The draft and its Save live in
/// `ProCalendarView`, so Save can sit pinned at the bottom.
struct ProHoursPanel: View {
    @Environment(AppState.self) private var app
    @Binding var draft: HoursDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Your usual week").font(HDFont.section).foregroundStyle(Palette.ink)
                Text("Clients only see times inside these hours. Block a one-off day from Week.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if app.proSelf?.instantBook == true {
                    WarnDotLine(text: "Instant book is on. Anything you leave open can be booked without asking you.", font: HDFont.caption)
                        .padding(.top, Space.xs)
                }
            }
            ProHoursForm(hours: $draft.hours, bufferMinutes: $draft.bufferMinutes, noticeMinutes: $draft.noticeMinutes)
            daysOff
        }
    }

    @ViewBuilder
    private var daysOff: some View {
        let upcoming = (app.proSelf?.availability.daysOff ?? []).filter { $0 >= Date().startOfDay }.sorted()
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Days blocked").labelStyle().padding(.bottom, Space.xs)
                ForEach(upcoming, id: \.self) { day in
                    HairlineRow(title: day.friendlyDay, subtitle: day.longDate, chevron: false,
                                trailing: TertiaryButton(title: "Unblock", tint: Palette.ink) { Task { await unblock(day) } })
                }
            }
        }
    }

    private func unblock(_ day: Date) async {
        guard var p = app.proSelf else { return }
        p.availability.daysOff.removeAll { Calendar.current.isDate($0, inSameDayAs: day) }
        if await app.saveProSelf(p) { app.show("Unblocked \(day.shortDay).") }
    }
}

/// The hours she can change in one go (days off save on their own).
struct HoursDraft: Equatable {
    var hours: [Weekday: [TimeRange]] = WeeklyAvailability.standard.hours
    var bufferMinutes: Int = 30
    var noticeMinutes: Int = 90

    init() {}

    init(_ pro: Pro?) {
        guard let pro else { return }
        hours = pro.availability.hours
        bufferMinutes = pro.availability.bufferMinutes
        noticeMinutes = pro.noticeMinutes
    }

    func apply(to pro: inout Pro) {
        pro.availability.hours = hours
        pro.availability.bufferMinutes = bufferMinutes
        pro.noticeMinutes = noticeMinutes
    }
}

/// The same hours, pushed on their own (from Profile, or Today's checklist), with Save in the header
/// and a question on Back if she hasn't saved.
struct ProHoursScreen: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft = HoursDraft()
    @State private var loaded = false
    @State private var saving = false
    @State private var failed = false
    @State private var confirmLeave = false

    private let unsavedID = "profile.hours"
    private var saved: HoursDraft { HoursDraft(app.proSelf) }
    private var isDirty: Bool { loaded && draft != saved }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Hours.").font(HDFont.title).foregroundStyle(Palette.ink)
                    Text("Your usual week. Clients only see times inside it.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
                if failed { FieldMessage(text: "Didn't save. Your changes are still here. Try again.") }
                ProHoursForm(hours: $draft.hours, bufferMinutes: $draft.bufferMinutes, noticeMinutes: $draft.noticeMinutes)
            }
            .screenGutter()
            .padding(.bottom, Space.section)
        }
        .paperBackground()
        .hdNavHeader(nil, onBack: back) {
            Button {
                Task { if await save() { dismiss() } }
            } label: {
                Group {
                    if saving { ProgressView().tint(Palette.ink) } else { Text("Save").font(HDFont.subMedium) }
                }
                .foregroundStyle(isDirty && !app.isOffline ? Palette.ink : Palette.inkSoft)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isDirty || saving || app.isOffline)
        }
        .onAppear { if !loaded { draft = saved; loaded = true } }
        .onChange(of: isDirty) { _, dirty in
            ProUnsavedWork.shared.update(unsavedID, dirty: dirty, save: { await save() }, discard: { draft = saved })
        }
        .onDisappear { ProUnsavedWork.shared.clear(unsavedID) }
        .confirmSheet(isPresented: $confirmLeave, title: "Leave without saving?", message: "Your changes to your hours go.",
                      confirmTitle: "Leave", cancelTitle: "Keep editing") {
            draft = saved
            dismiss()
        }
    }

    private func back() {
        if isDirty { confirmLeave = true } else { dismiss() }
    }

    @MainActor
    private func save() async -> Bool {
        guard var p = app.proSelf else { return false }
        saving = true
        defer { saving = false }
        failed = false
        draft.apply(to: &p)
        guard await app.saveProSelf(p) else {
            failed = true
            return false
        }
        Haptics.success()
        app.show("Saved.")
        ProUnsavedWork.shared.clear(unsavedID)
        return true
    }
}

#Preview("Calendar") {
    ProCalendarView().environment(previewApp(mode: .pro))
}
