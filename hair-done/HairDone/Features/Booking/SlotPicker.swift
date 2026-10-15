import SwiftUI

/// Day strip + real slots for one pro. Shared by the booking flow's time step and the reschedule sheet.
/// Owns the day, the fetch, the loading state and the "she's off Sundays" note; the caller owns the pick.
/// Change `reload` to fetch the day again (after "someone just took that time", say).
/// `latestStart` drops every slot after it (the reschedule sheet's card-hold limit), so nothing on
/// offer is a time the server will refuse.
struct SlotPicker: View {
    @Environment(AppState.self) private var app
    var pro: Pro
    var minutes: Int
    @Binding var selected: Date?
    var days: Int = 14
    var reload: Int = 0
    var latestStart: Date? = nil

    @State private var day: Date
    @State private var slots: [TimeSlot] = []
    @State private var isLoading = true
    @State private var note: String? = nil
    @State private var loadFailed = false

    init(pro: Pro, minutes: Int, selected: Binding<Date?>, days: Int = 14, reload: Int = 0, latestStart: Date? = nil) {
        self.pro = pro
        self.minutes = minutes
        self._selected = selected
        self.days = days
        self.reload = reload
        self.latestStart = latestStart
        _day = State(initialValue: (selected.wrappedValue ?? Date()).startOfDay)
    }

    private struct LoadKey: Hashable { var day: Date; var reload: Int }

    /// The day's slots up to `latestStart`.
    private var offered: [TimeSlot] {
        guard let latestStart else { return slots }
        return slots.filter { $0.start <= latestStart }
    }

    /// True when the cut-off took some of this day's times away.
    private var isTrimmed: Bool { offered.count < slots.count }

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
                    SlotSkeleton()
                        .screenGutter()
                } else if loadFailed {
                    ErrorState(title: "Couldn't load her times.", message: nil, actionTitle: "Try again") {
                        Task { @MainActor in await load() }
                    }
                } else if offered.isEmpty && isTrimmed {
                    EmptyState(title: "That's as far as it goes.", message: cutoffLine)
                } else if offered.isEmpty {
                    EmptyState(title: day.nothingFreeLine, message: "Try another day. The faded ones are days she's off.")
                } else {
                    VStack(alignment: .leading, spacing: Space.l) {
                        if !offered.contains(where: \.isAvailable) {
                            Text(day.nothingFreeLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                        if isTrimmed {
                            Text(cutoffLine)
                                .font(HDFont.sub)
                                .foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        SlotGrid(slots: offered, selected: $selected) { reason in
                            show(reason)
                        }
                    }
                    .screenGutter()
                }
            }
            .animation(Motion.gentle, value: isLoading)
        }
        .task(id: LoadKey(day: day, reload: reload)) { await load() }
        .onChange(of: day) { _, _ in withAnimation(Motion.gentle) { note = nil } }
    }

    private var cutoffLine: String {
        guard let latestStart else { return "" }
        return "Your card's on hold, so the new time has to be by \(latestStart.clock) on \(latestStart.friendlyDayInSentence)."
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

/// The next N days as plain columns: weekday over the date. The picked day sits in an ink square.
/// Days she doesn't work are faded; tapping one says why instead of selecting it.
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
                HStack(spacing: Space.xs) {
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
                .padding(.horizontal, Space.gutter - 4)
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

/// One column in the day strip: weekday SF 13 over the date SF 20, no box until it's picked.
struct DayCell: View {
    var date: Date
    var isSelected: Bool
    var isOff: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.weekday.short)
                    .font(HDFont.caption)
                    .foregroundStyle(isSelected ? Palette.onInkSoft : Palette.inkSoft)
                Text(date.dayNumber)
                    .font(HDFont.sans(20, relativeTo: .title3).monospacedDigit())
                    .foregroundStyle(isSelected ? Palette.onInk : Palette.ink)
            }
            .padding(.vertical, Space.s)
            .frame(minWidth: 48, minHeight: 44)
            .background(isSelected ? Palette.inkGround : Color.clear, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            // inkGround sits darker than dark paper, so the pick gets an ink edge to read in both modes.
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Palette.ink : Color.clear, lineWidth: 1)
            )
            .opacity(isOff ? 0.35 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.95))
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        let day = date.friendlyDay == date.shortDay ? "\(date.weekday.long) \(date.dayNumber)" : date.friendlyDay
        return isOff ? "\(day), she's off" : day
    }
}

/// Slots grouped into Morning, Afternoon and Evening, three to a row. Taken ones are faded and,
/// when tapped, tell the caller why instead of selecting.
struct SlotGrid: View {
    var slots: [TimeSlot]
    @Binding var selected: Date?
    var onUnavailable: ((String) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Space.s), count: typeSize.isAccessibilitySize ? 2 : 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            ForEach(TimeSlot.Period.allCases, id: \.self) { period in
                let group = slots.filter { $0.period == period }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text(period.rawValue).labelStyle()
                            .accessibilityAddTraits(.isHeader)
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

/// One time, squared: a 6pt box with a 1pt line border, ink fill when picked, faded with no border
/// when taken (still tappable, for the reason).
struct SlotChip: View {
    var slot: TimeSlot
    var isSelected: Bool
    var action: () -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.card, style: .continuous) }

    var body: some View {
        Button(action: action) {
            Text(slot.start.clock)
                .font(HDFont.price)
                .foregroundStyle(isSelected ? Palette.onInk : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Palette.inkGround : Color.clear, in: shape)
                .overlay(shape.strokeBorder(isSelected ? Palette.ink : (slot.isAvailable ? Palette.line : Color.clear), lineWidth: 1))
                .opacity(slot.isAvailable ? 1 : 0.35)
                .contentShape(shape)
        }
        .buttonStyle(PressLift(scale: 0.96))
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(slot.isAvailable ? "" : "Double tap to hear why")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        if slot.isAvailable { return "\(slot.start.clock), available" }
        let why = (slot.reason ?? "not available").lowercasedFirst
        return "\(slot.start.clock), \(why)"
    }
}

/// The slot grid loading, at its real shape.
private struct SlotSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SkeletonBlock(width: 80, height: 10)
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: Space.s) {
                    ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 44, radius: Radius.card) }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading her times")
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
