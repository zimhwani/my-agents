import SwiftUI

/// Day strip + real slots for one pro. Shared by the booking flow's time step and the reschedule sheet.
/// Owns the day, the fetch, the loading dots and the "she's off Sundays" note; the caller owns the pick.
struct SlotPicker: View {
    @Environment(AppState.self) private var app
    var pro: Pro
    var minutes: Int
    @Binding var selected: Date?
    var days: Int = 14

    @State private var day: Date
    @State private var slots: [TimeSlot] = []
    @State private var isLoading = true
    @State private var note: String? = nil
    @State private var loadFailed = false

    init(pro: Pro, minutes: Int, selected: Binding<Date?>, days: Int = 14) {
        self.pro = pro
        self.minutes = minutes
        self._selected = selected
        self.days = days
        _day = State(initialValue: (selected.wrappedValue ?? Date()).startOfDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            DayStrip(pro: pro, selected: $day, days: days) { reason in
                show(reason)
            }

            if let note {
                InlineNote(text: note)
                    .screenGutter()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Group {
                if isLoading {
                    LoadingDots()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if loadFailed {
                    EmptyState(symbol: "clock", title: "Couldn't load her times.", message: "Pull down to try again.", actionTitle: "Try again") {
                        Task { @MainActor in await load() }
                    }
                } else if slots.isEmpty {
                    EmptyState(symbol: "moon", title: day.nothingFreeLine, message: "Try another day. Her free days are the bright ones.")
                } else {
                    VStack(alignment: .leading, spacing: Space.l) {
                        if !slots.contains(where: \.isAvailable) {
                            Text(day.nothingFreeLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                        SlotGrid(slots: slots, selected: $selected) { reason in
                            show(reason)
                        }
                    }
                    .screenGutter()
                }
            }
            .animation(Motion.gentle, value: isLoading)
        }
        .task(id: day) { await load() }
        .onChange(of: day) { _, _ in withAnimation(Motion.gentle) { note = nil } }
    }

    private func show(_ reason: String) {
        withAnimation(Motion.spring) { note = reason }
    }

    @MainActor
    private func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let fetched = try await app.data.slots(for: pro, on: day, minutes: max(minutes, pro.availability.stepMinutes))
            guard !Task.isCancelled else { return }
            slots = fetched
        } catch {
            guard !Task.isCancelled else { return }
            slots = []
            loadFailed = true
        }
    }
}

/// The next N days as tappable cells: weekday letter over the day number.
/// Days she doesn't work are dimmed; tapping one explains why instead of selecting it.
struct DayStrip: View {
    var pro: Pro
    @Binding var selected: Date
    var days: Int = 14
    var onOffDay: ((String) -> Void)? = nil

    private var dates: [Date] {
        let today = Date().startOfDay
        return (0..<days).map { today.adding(days: $0) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(dates, id: \.self) { date in
                        DayCell(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selected),
                            isOff: isOff(date)
                        ) {
                            if isOff(date) {
                                onOffDay?(offReason(date))
                            } else {
                                Haptics.selection()
                                withAnimation(Motion.spring) { selected = date.startOfDay }
                            }
                        }
                        .id(date)
                    }
                }
                .screenGutter()
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(selected.startOfDay, anchor: .center) }
        }
    }

    private func isOff(_ date: Date) -> Bool { pro.availability.ranges(on: date).isEmpty }

    private func offReason(_ date: Date) -> String {
        if pro.availability.isOff(date) { return "\(pro.firstName)'s off that day." }
        return "She's off \(date.weekday.long)s."
    }
}

/// One cell in the day strip.
struct DayCell: View {
    var date: Date
    var isSelected: Bool
    var isOff: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.weekdayLetter)
                    .font(HDFont.caption)
                    .foregroundStyle(isSelected ? Palette.paper.opacity(0.8) : Palette.inkSoft)
                Text(date.dayNumber)
                    .font(HDFont.bodyStrong.monospacedDigit())
                    .foregroundStyle(isSelected ? Palette.paper : Palette.ink)
            }
            .frame(width: 48, height: 64)
            .background(isSelected ? Palette.ink : Palette.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Palette.line, lineWidth: 1)
            )
            .opacity(isOff ? 0.4 : 1)
        }
        .buttonStyle(PressLift(scale: 0.94))
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        let day = date.friendlyDay == date.shortDay ? "\(date.weekday.long) \(date.dayNumber)" : date.friendlyDay
        return isOff ? "\(day), she's off" : day
    }
}

/// Slots grouped into Morning, Afternoon and Evening. Unavailable ones look faint and,
/// when tapped, tell the caller why instead of selecting.
struct SlotGrid: View {
    var slots: [TimeSlot]
    @Binding var selected: Date?
    var onUnavailable: ((String) -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: Space.s)]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            ForEach(TimeSlot.Period.allCases, id: \.self) { period in
                let group = slots.filter { $0.period == period }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text(period.rawValue).labelStyle()
                        LazyVGrid(columns: columns, spacing: Space.s) {
                            ForEach(group) { slot in
                                SlotChip(slot: slot, isSelected: selected == slot.start) {
                                    if slot.isAvailable {
                                        Haptics.selection()
                                        withAnimation(Motion.spring) { selected = slot.start }
                                    } else {
                                        onUnavailable?(slot.reason ?? "She's booked then.")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One time chip. Three looks: free, picked, and taken (faint, still tappable for the reason).
struct SlotChip: View {
    var slot: TimeSlot
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(slot.start.clock)
                .font(HDFont.subStrong.monospacedDigit())
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(background, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressLift(scale: 0.95))
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(slot.isAvailable ? "" : "Double tap to hear why")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        if isSelected { return Palette.paper }
        return slot.isAvailable ? Palette.ink : Palette.inkFaint
    }

    private var background: Color {
        if isSelected { return Palette.ink }
        return slot.isAvailable ? Palette.card : Palette.paper
    }

    private var accessibilityText: String {
        if slot.isAvailable { return "\(slot.start.clock), available" }
        let why = (slot.reason ?? "not available").lowercasedFirst
        return "\(slot.start.clock), \(why)"
    }
}

#Preview("Slot picker") {
    struct Host: View {
        @State private var start: Date? = nil
        var body: some View {
            ScrollView {
                SlotPicker(pro: MockData.pros[0], minutes: 90, selected: $start)
                    .padding(.top, Space.xl)
            }
            .paperBackground()
        }
    }
    return Host().environment(previewApp())
}
