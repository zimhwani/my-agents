import SwiftUI
import PhotosUI

// Shared bits for Pro mode: week maths, payout sums, the status action button,
// the decline sheet, the service editor and the availability editor.

// MARK: - Weeks and money

enum ProWeek {
    /// Monday at midnight for whatever week `date` sits in.
    static func monday(of date: Date) -> Date {
        let day = date.startOfDay
        let offset = Weekday.week.firstIndex(of: day.weekday) ?? 0
        return day.adding(days: -offset)
    }

    static func days(from monday: Date) -> [Date] { (0..<7).map { monday.adding(days: $0) } }

    static func contains(_ date: Date, weekOf monday: Date) -> Bool {
        date >= monday && date < monday.adding(days: 7)
    }
}

enum ProMoney {
    /// Bookings that have actually earned her something.
    static func earning(_ bookings: [Booking]) -> [Booking] { bookings.filter { $0.status.isFinished } }

    static func payout(_ bookings: [Booking], from: Date, to: Date) -> Int {
        earning(bookings).filter { $0.start >= from && $0.start < to }.reduce(0) { $0 + $1.price.proPayoutCents }
    }

    static func payout(_ bookings: [Booking], on day: Date) -> Int {
        let start = day.startOfDay
        return payout(bookings, from: start, to: start.adding(days: 1))
    }

    static func payout(_ bookings: [Booking], weekOf monday: Date) -> Int {
        payout(bookings, from: monday, to: monday.adding(days: 7))
    }

    /// What a service price becomes after the 12%.
    static func afterFee(_ cents: Int) -> Int {
        cents - Int((Double(cents) * Fees.platformRate).rounded())
    }

    static func dollars(_ text: String) -> Int {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        return Int(((Double(cleaned) ?? 0) * 100).rounded())
    }

    static func dollarsText(_ cents: Int) -> String {
        cents % 100 == 0 ? String(cents / 100) : String(format: "%.2f", Double(cents) / 100)
    }
}

// MARK: - The next thing she taps

enum ProFlow {
    /// The one button for the job's current state.
    static func nextStep(for status: BookingStatus) -> (title: String, next: BookingStatus)? {
        switch status {
        case .confirmed: return ("On my way", .onHerWay)
        case .onHerWay: return ("I'm here", .arrived)
        case .arrived: return ("Start", .inProgress)
        case .inProgress: return ("Mark done", .done)
        default: return nil
        }
    }

    static let declineReasons = [
        "That time doesn't work for me",
        "Too far for me to travel",
        "I don't do that service",
        "I'm fully booked that day",
        "Something else"
    ]

    /// "Reply by 11:40 am or it lapses.", or "About to lapse." once it's up.
    static func autoDeclineLine(for booking: Booking) -> String {
        let deadline = booking.createdAt.adding(hours: Fees.autoDeclineHours)
        let minutes = Int(deadline.timeIntervalSinceNow / 60)
        if minutes <= 0 { return "About to lapse." }
        return "Reply by \(deadline.clock) or it lapses."
    }

    /// "today", "tomorrow" or "Tue 24 Sep", for the middle of a sentence.
    static func inSentence(_ date: Date) -> String {
        let friendly = date.friendlyDay
        return friendly == date.shortDay ? friendly : friendly.lowercased()
    }

    /// A stable seed for a client's avatar tint. `hashValue` changes every launch; this doesn't.
    static func seed(for id: String) -> Int {
        id.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    static func greeting(for name: String, at date: Date = Date()) -> String {
        switch date.hourOfDay {
        case 5..<12: return "Morning, \(name)."
        case 12..<17: return "Afternoon, \(name)."
        case 17..<21: return "Evening, \(name)."
        default: return "Late one, \(name)."
        }
    }
}

// MARK: - Status action button

/// "On my way" → "I'm here" → "Start" → "Mark done". Marking done asks first, because it charges her.
struct StatusActionButton: View {
    @Environment(AppState.self) private var app
    var booking: Booking
    var clientName: String
    @State private var busy = false
    @State private var confirmDone = false

    var body: some View {
        if let step = ProFlow.nextStep(for: booking.status) {
            PrimaryButton(title: step.title, isLoading: busy) {
                if step.next == .done { confirmDone = true } else { Task { await move(to: step.next) } }
            }
            .confirmationDialog("Mark it done?", isPresented: $confirmDone, titleVisibility: .visible) {
                Button("Yes, done") { Task { await move(to: .done) } }
                Button("Not yet", role: .cancel) {}
            } message: {
                Text("This charges \(clientName) \(Money.format(booking.price.clientTotalCents)). \(Money.format(booking.price.proPayoutCents)) comes to you after the 12%.")
            }
        } else if booking.status == .done {
            HStack(spacing: 8) {
                ProgressView().tint(Palette.inkSoft)
                Text("Done. \(Money.format(booking.price.proPayoutCents)) to you tomorrow.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityElement(children: .combine)
        }
    }

    private func move(to status: BookingStatus) async {
        busy = true
        defer { busy = false }
        guard let updated = await app.update(booking, to: status) else { return }
        switch status {
        case .onHerWay: app.show("She's been told you're on your way.")
        case .arrived: app.show("She's been told you're here.")
        case .inProgress: app.show("Started. Tap Mark done when you're finished.")
        case .done:
            Haptics.success()
            app.show("Done. \(Money.format(updated.price.proPayoutCents)) to you tomorrow.")
        default: break
        }
    }
}

// MARK: - Decline sheet

struct DeclineSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var booking: Booking
    var clientName: String
    @State private var picked: Int? = nil
    @State private var other = ""
    @State private var busy = false

    private var isOther: Bool { picked == ProFlow.declineReasons.count - 1 }
    private var canSend: Bool {
        guard let picked else { return false }
        if isOther { return !other.trimmingCharacters(in: .whitespaces).isEmpty }
        return picked >= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Reason", subtitle: "She'll see this. Keep it kind.", onClose: { dismiss() })
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(ProFlow.declineReasons.enumerated()), id: \.offset) { i, reason in
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.spring) { picked = i }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: picked == i ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundStyle(picked == i ? Palette.lacquer : Palette.inkFaint)
                                Text(reason).font(HDFont.body).foregroundStyle(Palette.ink)
                                Spacer()
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(picked == i ? .isSelected : [])
                        if i < ProFlow.declineReasons.count - 1 { Hairline() }
                    }
                    if isOther {
                        HDTextField(label: "", placeholder: "One line. She'll read it.", text: $other, axis: .vertical)
                            .padding(.top, Space.m)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .screenGutter()
                .padding(.top, Space.s)
            }
            VStack(spacing: Space.s) {
                PrimaryButton(title: "Decline", isLoading: busy, isEnabled: canSend) { Task { await decline() } }
                Text("\(clientName)'s hold is released the moment you tap.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func decline() async {
        guard let picked else { return }
        busy = true
        defer { busy = false }
        let reason = isOther ? other.trimmingCharacters(in: .whitespacesAndNewlines) : ProFlow.declineReasons[picked]
        if await app.update(booking, to: .declined, reason: reason) != nil {
            app.show("Declined. She's been told and her hold's released.")
            dismiss()
        }
    }
}

// MARK: - Small booking row

/// One line of a day: time, client, what, status. Used on Today and in Calendar.
struct ProBookingRow: View {
    var booking: Booking
    var clientName: String
    var showDay = false

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(booking.start.clock).font(HDFont.subStrong).foregroundStyle(Palette.ink).monospacedDigit()
                Text(booking.minutes.minutesLabel).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            .frame(width: 66, alignment: .trailing)
            Rectangle().fill(booking.status.color).frame(width: 3, height: 36).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(showDay ? "\(clientName) · \(booking.start.friendlyDay)" : clientName)
                    .font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                Text(booking.servicesLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 4)
            StatusBadge(status: booking.status)
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the booking")
    }
}

/// A gear or similar drawn like `IconButton`, for use inside a `NavigationLink`.
struct IconGlyph: View {
    var symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Palette.ink)
            .frame(width: 40, height: 40)
            .background(Palette.card, in: Circle())
            .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
    }
}

// MARK: - Work photos

extension WorkItem {
    /// A brand-new tile with placeholder art. Real image data comes later.
    static func placeholder(category: Category, caption: String = "") -> WorkItem {
        WorkItem(id: UUID().uuidString.lowercased(), category: category, caption: caption, seed: Int.random(in: 1...9_999))
    }
}

/// A `PhotosPicker` dressed as the primary button.
struct AddPhotosButton: View {
    @Binding var selection: [PhotosPickerItem]
    var title = "Add photos"
    var maxCount = 10
    var quiet = false

    var body: some View {
        PhotosPicker(selection: $selection, maxSelectionCount: maxCount, matching: .images) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text(title)
            }
            .font(HDFont.bodyStrong)
            .foregroundStyle(quiet ? Palette.ink : Palette.onLacquer)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(quiet ? Palette.card : Palette.lacquer, in: Capsule())
            .overlay(Capsule().strokeBorder(quiet ? Palette.line : Color.clear, lineWidth: 1))
        }
        .buttonStyle(PressLift())
        .accessibilityLabel(title)
    }
}

// MARK: - Suggested services

enum SuggestedServices {
    static func starters(for category: Category) -> [Service] {
        let rows: [(String, Int, Int, String)]
        switch category {
        case .hair: rows = [
            ("Blow-dry", 8000, 45, "Wash and blow-dry, sleek or bouncy."),
            ("Waves or curls", 9000, 50, "On dry hair. Soft or glam."),
            ("Event updo", 13000, 60, "Pinned to last the night.")]
        case .nails: rows = [
            ("Gel manicure", 6500, 60, "Shape, cuticles, gel colour."),
            ("BIAB overlay", 9500, 90, "Builder gel on the natural nail."),
            ("Removal + tidy", 4000, 30, "Soak-off, shape, cuticle oil.")]
        case .makeup: rows = [
            ("Event makeup", 14000, 60, "Full face with lashes."),
            ("Bridal makeup", 22000, 90, "Long-wear, photographed, with a trial option."),
            ("Makeup lesson", 15000, 75, "Your face, your kit, at your mirror.")]
        case .lashes: rows = [
            ("Classic set", 11000, 90, "One lash per lash. Natural."),
            ("Hybrid set", 13000, 100, "Classic and volume mixed."),
            ("Infill", 7500, 60, "Top-up within three weeks.")]
        case .brows: rows = [
            ("Brow lamination", 8500, 45, "Brushed up and set for six weeks."),
            ("Thread + tint", 5500, 30, "Shape and colour."),
            ("Henna brows", 6000, 40, "Stains the skin, lasts two weeks.")]
        case .theLot: rows = [
            ("Hair + makeup", 24000, 100, "Blow-dry or waves, plus a full face."),
            ("Hair + nails", 16000, 120, "Two things, one visit."),
            ("The lot", 32000, 180, "Hair, makeup and nails. Event ready.")]
        }
        return rows.map { Service(id: UUID().uuidString.lowercased(), name: $0.0, category: category, priceCents: $0.1, minutes: $0.2, detail: $0.3) }
    }
}

// MARK: - Service editor

struct ServiceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var categories: [Category]
    var onSave: (Service) -> Void
    private let existingID: String?
    @State private var name: String
    @State private var category: Category
    @State private var priceText: String
    @State private var minutes: Int
    @State private var detail: String
    @State private var isPopular: Bool

    init(existing: Service? = nil, categories: [Category], onSave: @escaping (Service) -> Void) {
        self.categories = categories.isEmpty ? [.hair] : categories
        self.onSave = onSave
        existingID = existing?.id
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? categories.first ?? .hair)
        _priceText = State(initialValue: existing.map { ProMoney.dollarsText($0.priceCents) } ?? "")
        _minutes = State(initialValue: existing?.minutes ?? 60)
        _detail = State(initialValue: existing?.detail ?? "")
        _isPopular = State(initialValue: existing?.isPopular ?? false)
    }

    private var priceCents: Int { ProMoney.dollars(priceText) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && priceCents > 0 }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: existingID == nil ? "Add a service" : "Edit service", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HDTextField(label: "Service", placeholder: "Full set, French tip", text: $name)
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("Category").font(HDFont.subStrong).foregroundStyle(Palette.ink)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                ForEach(categories) { c in
                                    Chip(title: c.label, isSelected: category == c, tint: c.tint) { category = c }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HDTextField(label: "Price", placeholder: "95", text: $priceText, keyboard: .decimalPad)
                        if priceCents > 0 {
                            Text("You get \(Money.format(ProMoney.afterFee(priceCents)))")
                                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("How long").font(HDFont.subStrong).foregroundStyle(Palette.ink)
                            Text(minutes.minutesLabel).font(HDFont.sub).foregroundStyle(Palette.inkSoft).monospacedDigit()
                        }
                        Spacer()
                        Stepper("How long", value: $minutes, in: 15...300, step: 15).labelsHidden()
                    }
                    HDTextField(label: "What's included", placeholder: "Optional", text: $detail, axis: .vertical)
                    Toggle(isOn: $isPopular) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mark as popular").font(HDFont.body).foregroundStyle(Palette.ink)
                            Text("Shows a small tag on your profile.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .tint(Palette.lacquer)
                }
                .screenGutter()
                .padding(.vertical, Space.l)
            }
            PrimaryButton(title: "Save", isEnabled: canSave) {
                onSave(Service(id: existingID ?? UUID().uuidString.lowercased(), name: name.trimmingCharacters(in: .whitespaces),
                               category: category, priceCents: priceCents, minutes: minutes, detail: detail, isPopular: isPopular))
                dismiss()
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .presentationDragIndicator(.visible)
    }
}

/// One service, as a row with edit and remove.
struct ServiceEditRow: View {
    var service: Service
    var onEdit: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(service.name).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                    if service.isPopular { Tag(text: "Popular", color: Palette.lacquer, background: Palette.lacquerSoft) }
                }
                Text("\(service.durationLabel) · \(service.category.label)").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                Text("You get \(Money.format(ProMoney.afterFee(service.priceCents)))").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(service.priceLabel).font(HDFont.price).foregroundStyle(Palette.ink)
                HStack(spacing: 0) {
                    TertiaryButton(title: "Edit", tint: Palette.lacquer, action: onEdit)
                    TertiaryButton(title: "Remove", action: onRemove)
                }
            }
        }
        .padding(.vertical, Space.s)
    }
}

// MARK: - Availability editor

/// Weekday rows: on/off, then start and end in half hours. Binds straight to the template dictionary.
struct AvailabilityEditor: View {
    @Binding var hours: [Weekday: [TimeRange]]
    private let steps = Array(stride(from: 0, through: 23 * 60 + 30, by: 30))

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Weekday.week, id: \.self) { day in
                VStack(alignment: .leading, spacing: Space.s) {
                    Toggle(isOn: onBinding(day)) {
                        HStack {
                            Text(day.long).font(HDFont.body).foregroundStyle(Palette.ink)
                            Spacer()
                            if !isOn(day) { Text("Off").font(HDFont.sub).foregroundStyle(Palette.inkSoft) }
                        }
                    }
                    .tint(Palette.lacquer)
                    if isOn(day) {
                        HStack(spacing: Space.s) {
                            timePicker("Start on \(day.long)", binding: startBinding(day))
                            Text("to").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            timePicker("Finish on \(day.long)", binding: endBinding(day))
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, Space.m)
                if day != .sunday { Hairline() }
            }
        }
        .animation(Motion.spring, value: hours)
    }

    private func timePicker(_ label: String, binding: Binding<Int>) -> some View {
        Picker(label, selection: binding) {
            ForEach(steps, id: \.self) { m in Text(TimeRange(startMinutes: m, endMinutes: m).clock(m)).tag(m) }
        }
        .pickerStyle(.menu)
        .tint(Palette.ink)
        .padding(.horizontal, 6)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .accessibilityLabel(label)
    }

    private func isOn(_ day: Weekday) -> Bool { !(hours[day] ?? []).isEmpty }
    private func range(_ day: Weekday) -> TimeRange { hours[day]?.first ?? .hours(9, 17) }

    private func onBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(get: { isOn(day) }, set: { on in hours[day] = on ? [.hours(9, 17)] : [] })
    }
    private func startBinding(_ day: Weekday) -> Binding<Int> {
        Binding(get: { range(day).startMinutes }, set: { m in
            var r = range(day)
            r.startMinutes = m
            if r.endMinutes <= m { r.endMinutes = min(m + 60, 23 * 60 + 30) }
            hours[day] = [r]
        })
    }
    private func endBinding(_ day: Weekday) -> Binding<Int> {
        Binding(get: { range(day).endMinutes }, set: { m in
            var r = range(day)
            r.endMinutes = m
            if r.startMinutes >= m { r.startMinutes = max(m - 60, 0) }
            hours[day] = [r]
        })
    }
}

// MARK: - Progress segments

struct ProgressSegments: View {
    var step: Int
    var total: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i < step ? Palette.lacquer : Palette.line).frame(height: 3)
            }
        }
        .animation(Motion.spring, value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(total)")
    }
}
