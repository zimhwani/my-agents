import SwiftUI
import PhotosUI
import CoreLocation

/// The six steps, in order. One decision per step, the price always in view.
enum BookingStep: Int, CaseIterable {
    case services, time, place, notes, review, booked

    var canGoBack: Bool { self != .services && self != .booked }
}

/// What can go wrong at the pay step, and the way back from each.
enum BookingFlowError: Equatable {
    case declined
    case slotTaken(Date)
    case other(String)

    var message: String {
        switch self {
        case .declined: return "That card didn't go through. Nothing's been charged. Try another, or Apple Pay."
        case .slotTaken(let start): return "Someone just took \(start.clock). Here's what's still free."
        case .other(let line): return line
        }
    }
}

/// Book a pro: services → time → where → notes and photos → check it over → you're booked.
/// Presented as a full-screen cover from her profile.
struct BookingFlowView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var pro: Pro
    var preselected: [Service] = []
    var onBooked: ((Booking) -> Void)? = nil

    @State private var draft: BookingDraft
    @State private var step: BookingStep = .services
    @State private var goingForward = true
    @State private var showLeaveConfirm = false
    @State private var booked: Booking? = nil
    @State private var isPaying = false
    @State private var payError: BookingFlowError? = nil

    init(pro: Pro, preselected: [Service] = [], onBooked: ((Booking) -> Void)? = nil) {
        self.pro = pro
        self.preselected = preselected
        self.onBooked = onBooked
        var d = BookingDraft(pro: pro)
        d.services = preselected
        _draft = State(initialValue: d)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .paperBackground()
        .interactiveDismissDisabled(hasChosenAnything)
        .confirmationDialog("Leave it here?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Nothing's booked yet, and your picks won't be kept.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Space.m) {
            if step.canGoBack {
                IconButton(symbol: "chevron.left", label: "Back") { goBack() }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
            FlowProgress(current: step.rawValue, total: BookingStep.allCases.count)
            IconButton(symbol: "xmark", label: step == .booked ? "Done" : "Close") { close() }
        }
        .screenGutter()
        .padding(.top, Space.l)
        .padding(.bottom, Space.s)
    }

    // MARK: Steps

    private var content: some View {
        ZStack {
            Group {
                switch step {
                case .services:
                    ServicesStep(pro: pro, selected: $draft.services)
                case .time:
                    TimeStep(pro: pro, minutes: draft.minutes, start: $draft.start)
                case .place:
                    WhereStep(pro: pro, address: $draft.address)
                case .notes:
                    NotesStep(pro: pro, notes: $draft.notes, seeds: $draft.inspoSeeds)
                case .review:
                    ReviewStep(
                        draft: $draft,
                        error: payError,
                        onEdit: { go(to: $0) },
                        onPickAnotherTime: {
                            draft.start = nil
                            payError = nil
                            go(to: .time)
                        },
                        onTryAgain: { pay() }
                    )
                case .booked:
                    if let booked {
                        BookedStep(booking: booked, pro: pro, onMessage: messageHer, onDone: finish)
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .services:
            StickyBar(title: "Pick a time", isEnabled: !draft.services.isEmpty, action: { go(to: .time) }) {
                footerLine(
                    draft.services.isEmpty ? "Pick at least one." : servicesSummary,
                    strong: !draft.services.isEmpty
                )
            }
        case .time:
            StickyBar(title: "Next", isEnabled: draft.start != nil, action: { go(to: .place) }) {
                if let start = draft.start {
                    footerLine("\(start.friendlyDay), \(start.clock) · \(draft.minutes.minutesLabel)", strong: true)
                } else {
                    footerLine("Pick a time", strong: false)
                }
            }
        case .place:
            StickyBar(title: "Next", isEnabled: canLeaveWhere, action: { go(to: .notes) }) {
                if let address = draft.address {
                    footerLine(address.labelled, strong: true)
                } else {
                    footerLine("Pick a spot", strong: false)
                }
            }
        case .notes:
            StickyBar(title: "Review", action: { go(to: .review) }) {
                if draft.notes.isEmpty && draft.inspoSeeds.isEmpty {
                    TertiaryButton(title: "Skip for now") { go(to: .review) }
                } else {
                    footerLine(notesSummary, strong: false)
                }
            }
        case .review:
            StickyBar(title: payTitle, isLoading: isPaying, isEnabled: draft.paymentMethod != nil, action: { pay() }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Money.format(draft.price.clientTotalCents))
                        .font(HDFont.priceLarge)
                        .foregroundStyle(Palette.ink)
                    Text(isPaying ? "Sorting it." : "Held now, charged when she's done.")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                }
                .accessibilityElement(children: .combine)
            }
        case .booked:
            EmptyView()
        }
    }

    private func footerLine(_ text: String, strong: Bool) -> some View {
        Text(text)
            .font(strong ? HDFont.subStrong : HDFont.sub)
            .foregroundStyle(strong ? Palette.ink : Palette.inkSoft)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Derived

    private var servicesSummary: String {
        let n = draft.services.count
        let count = n == 1 ? "1 service" : "\(n) services"
        return "\(count) · \(draft.minutes.minutesLabel) · \(Money.format(draft.servicesCents))"
    }

    private var notesSummary: String {
        let photos = draft.inspoSeeds.count
        let photoLine = photos == 0 ? nil : (photos == 1 ? "1 photo" : "\(photos) photos")
        let noteLine = draft.notes.isEmpty ? nil : "Notes added"
        return [noteLine, photoLine].compactMap { $0 }.joined(separator: " · ")
    }

    private var canLeaveWhere: Bool {
        guard let address = draft.address else { return false }
        return pro.comesTo(address)
    }

    private var payTitle: String {
        let price = Money.format(draft.price.clientTotalCents)
        return pro.instantBook ? "Pay \(price)" : "Request · \(price)"
    }

    private var hasChosenAnything: Bool {
        if step == .booked { return false }
        return draft.services != preselected
            || draft.start != nil
            || draft.address != nil
            || !draft.notes.isEmpty
            || !draft.inspoSeeds.isEmpty
    }

    // MARK: Moving about

    private func go(to next: BookingStep) {
        goingForward = next.rawValue > step.rawValue
        withAnimation(Motion.spring) { step = next }
    }

    private func goBack() {
        guard let previous = BookingStep(rawValue: step.rawValue - 1) else { return }
        go(to: previous)
    }

    private func close() {
        if step == .booked { finish(); return }
        if hasChosenAnything { showLeaveConfirm = true } else { dismiss() }
    }

    private func finish() {
        dismiss()
        if let booked { onBooked?(booked) }
    }

    private func messageHer() {
        dismiss()
        app.selectedTab = .inbox
    }

    // MARK: Paying

    private func pay() {
        guard !isPaying, draft.isComplete else { return }
        withAnimation(Motion.gentle) { payError = nil }
        isPaying = true
        Task { @MainActor in
            defer { isPaying = false }
            do {
                let booking = try await app.book(draft)
                booked = booking
                go(to: .booked)
            } catch PaymentError.declined {
                withAnimation(Motion.spring) { payError = .declined }
            } catch DataError.slotTaken {
                withAnimation(Motion.spring) { payError = .slotTaken(draft.start ?? Date()) }
            } catch {
                withAnimation(Motion.spring) { payError = .other(error.localizedDescription) }
            }
        }
    }
}

// MARK: - Step 1: Services

struct ServicesStep: View {
    var pro: Pro
    @Binding var selected: [Service]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                StepTitle(title: "Services", sub: "Pick as many as you like. She'll do them in one visit.")
                VStack(spacing: Space.m) {
                    ForEach(pro.services) { service in
                        SelectableCard(isSelected: isPicked(service), action: { toggle(service) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                                    Text(service.name).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                                    if service.isPopular { Tag(text: "Popular") }
                                }
                                if !service.detail.isEmpty {
                                    Text(service.detail).font(HDFont.caption).foregroundStyle(Palette.inkSoft).lineLimit(2)
                                }
                                HStack(spacing: Space.s) {
                                    Text(service.durationLabel).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                                    Text("·").foregroundStyle(Palette.inkFaint)
                                    Text(service.priceLabel).font(HDFont.price).foregroundStyle(Palette.ink)
                                }
                            }
                        }
                    }
                }
            }
            .screenGutter()
            .padding(.bottom, Space.xl)
        }
    }

    private func isPicked(_ service: Service) -> Bool { selected.contains { $0.id == service.id } }

    private func toggle(_ service: Service) {
        withAnimation(Motion.spring) {
            if let i = selected.firstIndex(where: { $0.id == service.id }) {
                selected.remove(at: i)
            } else {
                selected.append(service)
            }
        }
    }
}

// MARK: - Step 2: Time

struct TimeStep: View {
    var pro: Pro
    var minutes: Int
    @Binding var start: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    StepTitle(title: "When", sub: "These are her real free slots.")
                    HStack(spacing: 6) {
                        Image(systemName: pro.instantBook ? "bolt.fill" : "clock")
                            .font(.system(size: 12, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(pro.instantBook ? "Confirmed as soon as you pay" : "\(pro.firstName) confirms, usually within \(pro.replyWindow)")
                            .font(HDFont.caption)
                    }
                    .foregroundStyle(pro.instantBook ? Palette.lacquer : Palette.inkSoft)
                }
                .screenGutter()

                SlotPicker(pro: pro, minutes: minutes, selected: $start)
            }
            .padding(.bottom, Space.xl)
        }
    }
}

// MARK: - Step 3: Where

struct WhereStep: View {
    @Environment(AppState.self) private var app
    var pro: Pro
    @Binding var address: Address?

    @State private var access = ""
    @State private var showEditor = false

    private var saved: [Address] { app.client?.addresses ?? [] }
    private var isHere: Bool { address?.id == WhereStep.hereID }
    private static let hereID = "addr_here"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                StepTitle(title: "Where", sub: "She'll come to you. Somewhere with a power point and decent light is ideal.")

                SelectableCard(isSelected: isHere, action: useLocation) {
                    HStack(spacing: Space.m) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.lacquer)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use my location").font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                            Text("Around \(app.location.suburbGuess). You can add the door details below.")
                                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }

                if !saved.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text("Saved").labelStyle()
                        ForEach(saved) { a in
                            SelectableCard(isSelected: address?.id == a.id, action: { pick(a) }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.label).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                                    Text(a.short).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                                    if !a.instructions.isEmpty {
                                        Text(a.instructions).font(HDFont.caption).foregroundStyle(Palette.inkFaint).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                Button(action: { Haptics.light(); showEditor = true }) {
                    HStack(spacing: Space.s) {
                        Image(systemName: "plus.circle").font(.system(size: 18, weight: .medium))
                        Text("Add an address").font(HDFont.subStrong)
                    }
                    .foregroundStyle(Palette.lacquer)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

                if let address, !pro.comesTo(address) {
                    InlineNote(text: "That's outside where \(pro.firstName) travels. She comes to \(pro.travelAreaLine).", tone: .warn)
                        .transition(.opacity)
                }

                if address != nil {
                    HDTextField(label: "Getting in", placeholder: "Parking, buzzer, dogs. Anything she should know getting in.", text: $access, axis: .vertical)
                        .lineLimit(2...4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .screenGutter()
            .padding(.bottom, Space.xl)
            .animation(Motion.spring, value: address?.id)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { access = address?.instructions ?? "" }
        .onChange(of: access) { _, new in address?.instructions = new }
        .sheet(isPresented: $showEditor) {
            AddressEditor { new in
                save(new)
                pick(new)
            }
        }
    }

    private func pick(_ a: Address) {
        withAnimation(Motion.spring) { address = a }
        access = a.instructions
    }

    private func useLocation() {
        app.location.request()
        let c = app.location.coordinate
        let here = Address(
            id: WhereStep.hereID, label: "Here", line1: "Where you are now", suburb: app.location.suburbGuess,
            postcode: "", latitude: c.latitude, longitude: c.longitude, instructions: ""
        )
        pick(here)
    }

    private func save(_ new: Address) {
        guard var c = app.client else { return }
        c.addresses.append(new)
        app.client = c
        Task { @MainActor in try? await app.data.updateClient(c) }
    }
}

// MARK: - Step 4: Notes and inspo

struct NotesStep: View {
    var pro: Pro
    @Binding var notes: String
    @Binding var seeds: [Int]

    @State private var picked: [PhotosPickerItem] = []
    private let limit = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                StepTitle(title: "Notes and photos", sub: "Optional, but she'll thank you.")

                HDTextField(label: "Anything she should know?", placeholder: "What you're after. Hair length, colours you like, what the event is.", text: $notes, axis: .vertical)
                    .lineLimit(3...7)

                VStack(alignment: .leading, spacing: Space.m) {
                    HStack {
                        Text("Inspo").font(HDFont.heading).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(seeds.count) of \(limit)").font(HDFont.caption).foregroundStyle(Palette.inkSoft).monospacedDigit()
                    }
                    HStack(spacing: Space.s) {
                        ForEach(Array(seeds.enumerated()), id: \.offset) { index, seed in
                            InspoTile(seed: seed, category: pro.primaryCategory) { remove(at: index) }
                        }
                        if seeds.count < limit {
                            PhotosPicker(selection: $picked, maxSelectionCount: limit - seeds.count, matching: .images) {
                                AddPhotoTile()
                            }
                            .buttonStyle(PressLift(scale: 0.96))
                        }
                        if seeds.count < limit - 1 { Spacer(minLength: 0) }
                    }
                    .frame(height: 104)
                    if seeds.count >= limit {
                        Text("Three's the limit. Keep your favourites.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            .screenGutter()
            .padding(.bottom, Space.xl)
            .animation(Motion.spring, value: seeds)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            // Mock: the picker is real, the photo isn't kept. A seed stands in for it.
            for _ in items where seeds.count < limit {
                seeds.append(Int.random(in: 1...9_999))
            }
            picked = []
        }
    }

    private func remove(at index: Int) {
        guard seeds.indices.contains(index) else { return }
        seeds.remove(at: index)
    }
}

/// A picked inspo photo, drawn as placeholder art in the mock, with a remove button.
struct InspoTile: View {
    var seed: Int
    var category: Category
    var onRemove: () -> Void

    var body: some View {
        WorkTile(item: WorkItem(id: "inspo_\(seed)", category: category, caption: "Inspo", seed: seed), cornerRadius: Radius.tile)
            .frame(width: 104, height: 104)
            .overlay(alignment: .topTrailing) {
                Button(action: { Haptics.light(); onRemove() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Palette.paper.opacity(0.92), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("Remove photo")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Inspo photo")
    }
}

/// The dashed "Add photos" tile.
struct AddPhotoTile: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo.badge.plus").font(.system(size: 20, weight: .light))
            Text("Add photos").font(HDFont.caption.weight(.medium))
        }
        .foregroundStyle(Palette.inkSoft)
        .frame(width: 104, height: 104)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .accessibilityLabel("Add photos")
    }
}

/// Serif title and a soft sub-line at the top of each step.
struct StepTitle: View {
    var title: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(HDFont.title).foregroundStyle(Palette.ink)
            if let sub { Text(sub).font(HDFont.sub).foregroundStyle(Palette.inkSoft) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Booking flow") {
    BookingFlowView(pro: MockData.pros[0]).environment(previewApp())
}

#Preview("Booking flow, request to book") {
    let pro = MockData.pros.first { !$0.instantBook } ?? MockData.pros[0]
    return BookingFlowView(pro: pro, preselected: [pro.services[0]]).environment(previewApp())
}
