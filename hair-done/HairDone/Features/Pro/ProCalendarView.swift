import SwiftUI

/// Week view of her bookings, and the usual week she works. Days off live here too.
struct ProCalendarView: View {
    @Environment(AppState.self) private var app

    private enum Segment: String, CaseIterable { case week = "Week", availability = "Availability" }
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
    @State private var draft: WeeklyAvailability = .standard
    @State private var loaded = false
    @State private var saving = false
    @State private var dayOffPick: Date = Date().adding(days: 1).startOfDay

    private var availability: WeeklyAvailability { app.proSelf?.availability ?? .standard }
    private var isCurrentWeek: Bool { weekStart == ProWeek.monday(of: Date()) }
    private var isDirty: Bool { draft != availability }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Text("Calendar").font(HDFont.hero).foregroundStyle(Palette.ink)
                    Picker("Section", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch segment {
                    case .week: weekView
                    case .availability: availabilityView
                    }
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .refreshable { await app.loadProSide() }
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .onAppear { if !loaded { draft = availability; loaded = true } }
        }
    }

    // MARK: Week

    private var weekView: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Previous week") { move(by: -7) }
                Spacer()
                VStack(spacing: 2) {
                    Text("Week of \(weekStart.shortDay)").font(HDFont.heading).foregroundStyle(Palette.ink)
                    if !isCurrentWeek {
                        TertiaryButton(title: "Today", tint: Palette.lacquer) {
                            withAnimation(Motion.spring) { weekStart = ProWeek.monday(of: Date()); selectedDay = Date().startOfDay }
                        }
                    }
                }
                Spacer()
                IconButton(symbol: "chevron.right", label: "Next week") { move(by: 7) }
            }
            dayStrip
            dayDetail
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 4) {
            ForEach(ProWeek.days(from: weekStart), id: \.self) { day in
                let count = bookings(on: day).count
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                let isToday = Calendar.current.isDateInToday(day)
                let off = availability.ranges(on: day).isEmpty
                Button {
                    Haptics.selection()
                    withAnimation(Motion.spring) { selectedDay = day }
                } label: {
                    VStack(spacing: 6) {
                        Text(day.weekday.short).font(HDFont.caption).foregroundStyle(isSelected ? Palette.paper : Palette.inkSoft)
                        Text(day.dayNumber)
                            .font(isToday ? HDFont.bodyStrong : HDFont.body)
                            .foregroundStyle(isSelected ? Palette.paper : (isToday ? Palette.lacquer : (off ? Palette.inkFaint : Palette.ink)))
                            .monospacedDigit()
                        HStack(spacing: 2) {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Circle().fill(isSelected ? Palette.paper : Palette.lacquer).frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? Palette.ink : Color.clear, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day.friendlyDay), \(count == 1 ? "1 booking" : "\(count) bookings")\(off ? ", off" : "")")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
    }

    @ViewBuilder
    private var dayDetail: some View {
        let items = dayItems(for: selectedDay)
        let off = availability.ranges(on: selectedDay).isEmpty
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDay.friendlyDay).font(HDFont.heading).foregroundStyle(Palette.ink)
                if selectedDay.friendlyDay != selectedDay.shortDay {
                    Text(selectedDay.shortDay).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                if off { Tag(text: "Off") }
            }
            if items.isEmpty {
                Text(off ? "Off. Nothing booked." : "Free all day.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, Space.m)
            } else {
                ForEach(items) { item in
                    switch item {
                    case .booking(let b):
                        NavigationLink(value: Route.proBooking(b.id)) {
                            ProBookingRow(booking: b, clientName: app.clientName(b.clientID))
                        }
                        .buttonStyle(.plain)
                    case .free(let a, let z):
                        HStack(spacing: Space.m) {
                            Text("Free").font(HDFont.caption).foregroundStyle(Palette.inkFaint).frame(width: 66, alignment: .trailing)
                            Rectangle().fill(Palette.line).frame(width: 3, height: 18).clipShape(Capsule())
                            Text(TimeRange(startMinutes: a, endMinutes: z).label).font(HDFont.caption).foregroundStyle(Palette.inkFaint)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                    }
                    Hairline()
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

    // MARK: Availability

    private var availabilityView: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your usual week").font(HDFont.heading).foregroundStyle(Palette.ink)
                Text("Clients only see slots inside these hours. Block a day below for one-offs.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                if app.proSelf?.instantBook == true {
                    Text("Instant book is on. Anything you leave open can be booked without asking you.")
                        .font(HDFont.caption).foregroundStyle(Palette.warn).padding(.top, 2)
                }
            }

            AvailabilityEditor(hours: $draft.hours)
                .card()

            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Between jobs").font(HDFont.body).foregroundStyle(Palette.ink)
                        Text("\(draft.bufferMinutes) min to pack up and drive.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Stepper("Between jobs", value: $draft.bufferMinutes, in: 0...60, step: 15).labelsHidden()
                }
            }
            .card()

            VStack(alignment: .leading, spacing: Space.m) {
                Text("Block a day off").font(HDFont.heading).foregroundStyle(Palette.ink)
                DatePicker("Day", selection: $dayOffPick, in: Date().startOfDay..., displayedComponents: .date)
                    .tint(Palette.lacquer)
                    .font(HDFont.body)
                SecondaryButton(title: "Block it", symbol: "moon.zzz") { block(dayOffPick) }
                let clash = bookings(on: dayOffPick).first { $0.status.isUpcoming }
                if let clash {
                    Text("You've got \(app.clientName(clash.clientID)) at \(clash.start.clock) in there. Move her first.")
                        .font(HDFont.caption).foregroundStyle(Palette.warn)
                }
                let upcoming = draft.daysOff.filter { $0 >= Date().startOfDay }.sorted()
                if !upcoming.isEmpty {
                    Hairline()
                    ForEach(upcoming, id: \.self) { day in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.friendlyDay).font(HDFont.body).foregroundStyle(Palette.ink)
                                Text(day.longDate).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            TertiaryButton(title: "Unblock") {
                                withAnimation(Motion.spring) { draft.daysOff.removeAll { Calendar.current.isDate($0, inSameDayAs: day) } }
                            }
                        }
                    }
                }
            }
            .card()

            PrimaryButton(title: "Save", isLoading: saving, isEnabled: isDirty) { Task { await save() } }
        }
    }

    private func block(_ day: Date) {
        let start = day.startOfDay
        guard !draft.isOff(start) else { return }
        withAnimation(Motion.spring) { draft.daysOff.append(start) }
    }

    private func save() async {
        guard var pro = app.proSelf else { return }
        saving = true
        defer { saving = false }
        pro.availability = draft
        await app.saveProSelf(pro)
        app.show("Saved.")
    }
}

#Preview("Calendar") {
    ProCalendarView().environment(previewApp(mode: .pro))
}
