import SwiftUI
import PhotosUI
import CoreLocation

/// The six steps, in order. One decision per step, the price always in view.
enum BookingStep: Int, CaseIterable {
    case services, time, place, notes, review, booked

    var canGoBack: Bool { self != .services && self != .booked }

    /// Steps she moves through before she's booked (the "2 OF 5" count).
    static let countedSteps = 5
}

/// What can go wrong at the pay step, and the way back from each.
enum BookingFlowError: Equatable {
    case declined
    case slotTaken(Date)
    /// She isn't taking bookings (paused, closed, or payouts not on). Nothing's been charged.
    case proUnavailable
    case other(String)

    var message: String {
        switch self {
        case .declined: return "That card didn't go through. Nothing's been charged. Try another, or Apple Pay."
        case .slotTaken(let start): return "Someone just took \(start.clock). Here's what's still free."
        case .proUnavailable: return "She's not taking bookings right now. Nothing's been charged."
        case .other(let line): return line
        }
    }
}

/// Book a pro: services → time → where → notes and photos → check it over → you're booked.
/// Presented as a full-screen cover from her profile. The profile's ink Book bar carries through
/// every step; the ground turns to ink when she checks it over.
struct BookingFlowView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pro: Pro
    var preselected: [Service] = []
    var onBooked: ((Booking) -> Void)? = nil
    /// "See who's free" after she's told this pro isn't taking bookings. The flow closes first.
    var onSeeWhosFree: (() -> Void)? = nil

    @State private var draft: BookingDraft
    @State private var step: BookingStep = .services
    @State private var goingForward = true
    @State private var showLeaveConfirm = false
    @State private var booked: Booking? = nil
    @State private var isPaying = false
    @State private var payError: BookingFlowError? = nil
    @State private var askForPush = false
    @State private var slotReload = 0

    init(pro: Pro, preselected: [Service] = [], onBooked: ((Booking) -> Void)? = nil, onSeeWhosFree: (() -> Void)? = nil) {
        self.pro = pro
        self.preselected = preselected
        self.onBooked = onBooked
        self.onSeeWhosFree = onSeeWhosFree
        var d = BookingDraft(pro: pro)
        d.services = preselected
        _draft = State(initialValue: d)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if app.isOffline && step != .booked {
                OfflineBar()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background {
            // Paper for browsing, ink for committing: the ground turns to ink on review and booked.
            ZStack {
                Palette.paper
                Palette.inkGround.opacity(isInk ? 1 : 0)
            }
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : Motion.gentle, value: isInk)
        }
        .animation(Motion.gentle, value: app.isOffline)
        .interactiveDismissDisabled(hasChosenAnything)
        .confirmSheet(
            isPresented: $showLeaveConfirm,
            title: "Leave it here?",
            message: "Nothing's booked yet, and your picks won't be kept.",
            confirmTitle: "Leave",
            cancelTitle: "Keep going"
        ) { dismiss() }
        .sheet(isPresented: $askForPush) { PushPrePrompt(side: .client) }
        .holdsPushRoutes()
    }

    // MARK: Header

    private var isInk: Bool { step == .review || step == .booked }

    @ViewBuilder
    private var header: some View {
        switch step {
        case .review:
            HDNavHeader("Check it over", tone: .ink, onBack: { goBack() }) {
                IconButton(symbol: "xmark", label: "Close", tint: Palette.onInkSoft) { close() }
            }
            .padding(.top, Space.s)
        case .booked:
            // The booked step carries its own "Done".
            EmptyView()
        case .services, .time, .place, .notes:
            FlowHeader(
                step: step.rawValue,
                total: BookingStep.countedSteps,
                canGoBack: step.canGoBack,
                onBack: { goBack() },
                onClose: { close() }
            )
        }
    }

    // MARK: Steps

    private var content: some View {
        ZStack {
            Group {
                switch step {
                case .services:
                    ServicesStep(pro: pro, selected: $draft.services)
                case .time:
                    TimeStep(pro: pro, minutes: draft.minutes, start: $draft.start, reload: slotReload)
                case .place:
                    WhereStep(pro: pro, address: $draft.address)
                case .notes:
                    NotesStep(notes: $draft.notes, photos: $draft.inspoPhotos)
                case .review:
                    ReviewStep(
                        draft: $draft,
                        error: payError,
                        onEdit: { go(to: $0) },
                        onPickAnotherTime: {
                            draft.start = nil
                            payError = nil
                            slotReload += 1
                            go(to: .time)
                        },
                        onTryAgain: { pay() },
                        onSeeWhosFree: seeWhosFree,
                        isPaying: isPaying,
                        onPay: { pay() }
                    )
                case .booked:
                    if let booked {
                        BookedStep(booking: booked, pro: pro, photosPicked: draft.inspoPhotos.count, onMessage: messageHer, onDone: finish)
                    }
                }
            }
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    // MARK: Footer: the ink bar from her profile

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .services:
            BookBar(
                name: pro.firstName,
                summary: draft.services.isEmpty ? nil : priceSummary,
                detail: draft.services.isEmpty ? "Pick at least one." : servicesCount,
                actionTitle: "Pick a time",
                isEnabled: !draft.services.isEmpty
            ) { go(to: .time) }
        case .time:
            BookBar(
                name: pro.firstName,
                summary: priceSummary,
                detail: draft.start.map { "\($0.friendlyDay), \($0.clock)" } ?? "Pick a time",
                actionTitle: "Next",
                isEnabled: draft.start != nil
            ) { go(to: .place) }
        case .place:
            BookBar(
                name: pro.firstName,
                summary: priceSummary,
                detail: draft.address?.labelled ?? "Pick a spot",
                actionTitle: "Next",
                isEnabled: canLeaveWhere
            ) { go(to: .notes) }
        case .notes:
            BookBar(
                name: pro.firstName,
                summary: priceSummary,
                detail: notesSummary ?? "Optional. Skip it if you like.",
                actionTitle: "Review"
            ) { go(to: .review) }
        case .review, .booked:
            // The pay buttons live on the ink ticket itself.
            EmptyView()
        }
    }

    // MARK: Derived

    private var priceSummary: String {
        "\(Money.format(draft.servicesCents)) · \(ShortDuration.label(draft.minutes))"
    }

    private var servicesCount: String {
        draft.services.count == 1 ? "1 service" : "\(draft.services.count) services"
    }

    private var notesSummary: String? {
        let photos = draft.inspoPhotos.count
        let photoLine = photos == 0 ? nil : (photos == 1 ? "1 photo" : "\(photos) photos")
        let noteLine = draft.notes.isEmpty ? nil : "Notes added"
        let parts = [noteLine, photoLine].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var canLeaveWhere: Bool {
        guard let address = draft.address else { return false }
        return pro.comesTo(address) && !WhereStep.needsDoorNote(address)
    }

    private var hasChosenAnything: Bool {
        if step == .booked { return false }
        return draft.services != preselected
            || draft.start != nil
            || draft.address != nil
            || !draft.notes.isEmpty
            || !draft.inspoPhotos.isEmpty
    }

    // MARK: Moving about

    private func go(to next: BookingStep) {
        goingForward = next.rawValue > step.rawValue
        withAnimation(reduceMotion ? nil : Motion.spring) { step = next }
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

    /// Straight to her thread, on the Inbox tab.
    private func messageHer() {
        let thread = booked.flatMap { app.thread(for: $0) }
        dismiss()
        if let booked { onBooked?(booked) }
        app.selectedTab = .inbox
        if let thread { app.pendingRoute = .thread(thread.id) }
    }

    private func seeWhosFree() {
        dismiss()
        if let onSeeWhosFree {
            onSeeWhosFree()
        } else {
            app.selectedTab = .home
        }
    }

    /// Her first booking is the moment notifications explain themselves. After the check has drawn.
    private func askForPushSoon() {
        Task { @MainActor in
            guard await app.shouldAskForPush(.client) else { return }
            try? await Task.sleep(for: .seconds(1.4))
            if step == .booked { askForPush = true }
        }
    }

    // MARK: Paying

    private func pay() {
        guard !isPaying, draft.isComplete else { return }
        guard !app.isOffline else {
            withAnimation(Motion.spring) { payError = .other(DataError.offline.errorDescription ?? "") }
            return
        }
        withAnimation(Motion.gentle) { payError = nil }
        isPaying = true
        Task { @MainActor in
            defer { isPaying = false }
            do {
                let booking = try await app.book(draft)
                booked = booking
                go(to: .booked)
                askForPushSoon()
            } catch PaymentError.declined {
                withAnimation(Motion.spring) { payError = .declined }
            } catch PaymentError.proNotReady {
                withAnimation(Motion.spring) { payError = .proUnavailable }
            } catch DataError.notFound {
                // The server says pro_not_found when she isn't bookable (paused, closed, or blocked).
                withAnimation(Motion.spring) { payError = .proUnavailable }
            } catch DataError.slotTaken {
                withAnimation(Motion.spring) { payError = .slotTaken(draft.start ?? Date()) }
            } catch {
                withAnimation(Motion.spring) { payError = .other(error.localizedDescription) }
            }
        }
    }
}

// MARK: - Step 1: Services

/// Her price list, the same rows as on her profile: name and detail on the left, duration and price
/// on the right, hairlines between, an ink check on what's picked.
struct ServicesStep: View {
    var pro: Pro
    @Binding var selected: [Service]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                StepTitle(title: "Services", sub: "Pick as many as you like. She'll do them in one visit.")
                VStack(spacing: 0) {
                    Hairline(strong: true)
                    ForEach(pro.services) { service in
                        OptionBox(isSelected: isPicked(service), style: .row, action: { toggle(service) }) {
                            ServicePriceRow(service: service, isSelected: isPicked(service))
                        }
                        .accessibilityHint(isPicked(service) ? "Takes it off your booking" : "Adds it to your booking")
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

/// One line of a price list. "POPULAR" as an eyebrow, never a capsule.
struct ServicePriceRow: View {
    var service: Service
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                if service.isPopular {
                    Text("Popular").eyebrowStyle()
                }
                Text(service.name)
                    .font(HDFont.body)
                    .fontWeight(isSelected ? Font.Weight.semibold : Font.Weight.regular)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !service.detail.isEmpty {
                    Text(service.detail)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            Text(ShortDuration.label(service.minutes))
                .font(HDFont.priceSmall)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize()
            Text(service.priceLabel)
                .font(isSelected ? HDFont.priceStrong : HDFont.price)
                .foregroundStyle(Palette.ink)
                .fixedSize()
                .frame(minWidth: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(service.name), \(service.minutes.minutesLabel), \(service.priceLabel)" + (service.isPopular ? ", popular" : ""))
    }
}

// MARK: - Step 2: Time

struct TimeStep: View {
    var pro: Pro
    var minutes: Int
    @Binding var start: Date?
    var reload: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    StepTitle(title: "When", sub: "These are her real free slots.")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: pro.instantBook ? "bolt" : "clock")
                            .font(.system(size: 13, weight: .regular))
                            .accessibilityHidden(true)
                        Text(pro.instantBook ? "Confirmed as soon as you pay" : "\(pro.firstName) confirms, usually within \(pro.replyWindow)")
                            .font(HDFont.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Palette.inkSoft)
                }
                .screenGutter()

                SlotPicker(pro: pro, minutes: minutes, selected: $start, reload: reload)
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

    /// Finding where she is, for "Use my location".
    private enum Here: Equatable {
        case idle
        case finding
        /// The street we think she's on, waiting for "Right?".
        case confirm(Address)
        case failed(String)
    }

    @State private var access = ""
    @State private var showEditor = false
    @State private var here: Here = .idle

    private var saved: [Address] { app.client?.addresses ?? [] }
    private var isHere: Bool { address?.id == WhereStep.hereID }
    static let hereID = "addr_here"

    /// A spot from "Use my location" with no street number needs a unit or door note before she goes on.
    static func needsDoorNote(_ address: Address) -> Bool {
        address.id == hereID
            && !address.line1.contains(where: \.isNumber)
            && address.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hereHasNumber: Bool { address.map { $0.line1.contains(where: \.isNumber) } ?? true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                StepTitle(title: "Where", sub: "She'll come to you. Somewhere with a power point and decent light is ideal.")

                VStack(spacing: 0) {
                    Hairline(strong: true)
                    OptionBox(isSelected: isHere, style: .row, action: useLocation) {
                        placeRow(symbol: "location", title: "Use my location", line: hereLine)
                    }
                    hereFollowUp
                    if !saved.isEmpty {
                        ForEach(saved) { a in
                            OptionBox(isSelected: address?.id == a.id, style: .row, action: { pick(a) }) {
                                placeRow(symbol: a.label == "Work" ? "briefcase" : "house", title: a.label, line: a.short, note: a.instructions)
                            }
                        }
                    }
                    HairlineRow(title: "Add an address", symbol: "plus", chevron: false) { showEditor = true }
                }

                if let address, !pro.comesTo(address) {
                    InlineNote(text: "That's outside where \(pro.firstName) travels. She comes to \(pro.travelAreaLine).", tone: .warn)
                        .transition(.opacity)
                }

                if address != nil {
                    accessField
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .screenGutter()
            .padding(.bottom, Space.xl)
            .animation(Motion.spring, value: address?.id)
            .animation(Motion.spring, value: here)
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

    private var hereLine: String {
        if isHere, let address { return address.short }
        if here == .finding { return "Finding you…" }
        return "Around \(app.location.suburbGuess). We'll check the street with you."
    }

    @ViewBuilder
    private var accessField: some View {
        if isHere && !hereHasNumber {
            HDTextField(
                label: "Unit or door",
                placeholder: "Unit 4, the green gate, buzz 12",
                text: $access,
                axis: .vertical,
                caption: "There's no street number here, so tell her which door."
            )
            .lineLimit(1...3)
        } else {
            HDTextField(label: "Getting in", placeholder: "Parking, buzzer, dogs. Anything she should know getting in.", text: $access, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    /// "12 Smith St, Fitzroy. Right?" with Yes and a way to type it instead.
    @ViewBuilder
    private var hereFollowUp: some View {
        switch here {
        case .idle, .finding:
            EmptyView()
        case .confirm(let found):
            VStack(alignment: .leading, spacing: Space.m) {
                Text(verbatim: "\(found.short). Right?")
                    .font(HDFont.quote)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.m) {
                    InkButton(title: "Yes", compact: true) {
                        here = .idle
                        pick(found)
                    }
                    OutlineButton(title: "No, type it", compact: true) {
                        here = .idle
                        showEditor = true
                    }
                }
            }
            .padding(.vertical, Space.l)
            .overlay(alignment: .bottom) { Hairline(strong: true) }
            .transition(.opacity)
        case .failed(let why):
            VStack(alignment: .leading, spacing: Space.xs) {
                FieldMessage(text: why)
                TertiaryButton(title: "Add the address", tint: Palette.ink) {
                    here = .idle
                    showEditor = true
                }
                .padding(.horizontal, -8)
            }
            .padding(.vertical, Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Hairline(strong: true) }
            .transition(.opacity)
        }
    }

    private func placeRow(symbol: String, title: String, line: String, note: String = "") -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Palette.ink)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(HDFont.body).foregroundStyle(Palette.ink)
                Text(verbatim: line).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if !note.isEmpty {
                    Text(verbatim: note).font(HDFont.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
            }
        }
    }

    private func pick(_ a: Address) {
        withAnimation(Motion.spring) { address = a }
        access = a.instructions
    }

    /// Finds the street she's on and asks her to confirm it, so the pro gets a door, not a GPS point.
    private func useLocation() {
        if isHere { return }
        here = .finding
        app.location.request()
        Task { @MainActor in
            // Give a first fix a moment to land after the prompt or a fresh request.
            var waited = 0
            while !app.location.isUsingRealLocation && waited < 12 {
                if app.location.hasAsked && !app.location.isAllowed { break }
                try? await Task.sleep(for: .milliseconds(250))
                waited += 1
            }
            guard app.location.isAllowed, app.location.isUsingRealLocation else {
                here = .failed(app.location.hasAsked && !app.location.isAllowed
                    ? "Location's off for Hair Done. Add the address instead."
                    : "Couldn't find you just now. Add the address instead.")
                return
            }
            let c = app.location.coordinate
            let mark = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: c.latitude, longitude: c.longitude)).first
            guard let mark, let street = mark.thoroughfare else {
                here = .failed("Couldn't find a street where you are. Add the address instead.")
                return
            }
            let line1 = [mark.subThoroughfare, street].compactMap { $0 }.joined(separator: " ")
            let found = Address(
                id: WhereStep.hereID,
                label: "",
                line1: line1,
                suburb: mark.locality ?? mark.subLocality ?? app.location.suburbGuess,
                state: "VIC",
                postcode: mark.postalCode ?? "",
                latitude: c.latitude,
                longitude: c.longitude,
                instructions: ""
            )
            here = .confirm(found)
        }
    }

    private func save(_ new: Address) {
        guard var c = app.client else { return }
        c.addresses.append(new)
        app.client = c
        Task { @MainActor in try? await app.data.updateClient(c) }
    }
}

// MARK: - Step 4: Notes and inspo

/// Notes in her words, and up to three photos. The photos are made upload-ready here (2000px, JPEG)
/// and go up with the booking once it's made.
struct NotesStep: View {
    @Binding var notes: String
    @Binding var photos: [Data]

    /// A photo still being read, or one that couldn't be.
    private struct Pending: Identifiable {
        let id = UUID()
        var item: PhotosPickerItem
        var failed = false
    }

    @State private var picked: [PhotosPickerItem] = []
    @State private var pending: [Pending] = []
    @State private var thumbs: [UIImage?] = []
    private let limit = 3

    private var count: Int { photos.count + pending.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                StepTitle(title: "Notes and photos", sub: "Optional, but she'll thank you.")

                HDTextField(label: "Anything she should know?", placeholder: "What you're after. Hair length, colours you like, what the event is.", text: $notes, axis: .vertical)
                    .lineLimit(3...7)

                VStack(alignment: .leading, spacing: Space.m) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Inspo").font(HDFont.name).foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text("\(photos.count) of \(limit)").font(HDFont.caption.monospacedDigit()).foregroundStyle(Palette.inkSoft)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Space.s) {
                            ForEach(Array(photos.indices), id: \.self) { index in
                                UploadTile(image: thumb(at: index), state: .done, onRemove: { remove(at: index) })
                            }
                            ForEach(pending) { p in
                                UploadTile(image: nil, state: p.failed ? .failed : .uploading(0.5),
                                           onRetry: { retry(p.id) },
                                           onRemove: { pending.removeAll { $0.id == p.id } })
                            }
                            if count < limit {
                                PhotosPicker(selection: $picked, maxSelectionCount: limit - count, matching: .images) {
                                    AddPhotoTile()
                                }
                                .buttonStyle(PressLift(scale: 0.96))
                            }
                        }
                    }
                    if photos.count >= limit {
                        Text("Three's the limit. Keep your favourites.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    } else {
                        Text("They go to her with the booking.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            .screenGutter()
            .padding(.bottom, Space.xl)
            .animation(Motion.spring, value: photos.count)
            .animation(Motion.spring, value: pending.count)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { rebuildThumbs() }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            let room = max(0, limit - count)
            let fresh = items.prefix(room).map { Pending(item: $0) }
            picked = []
            pending.append(contentsOf: fresh)
            for p in fresh { prepare(p.id) }
        }
    }

    private func thumb(at index: Int) -> UIImage? {
        thumbs.indices.contains(index) ? thumbs[index] : nil
    }

    private func rebuildThumbs() {
        thumbs = photos.map { InspoPhoto.thumbnail(from: $0) }
    }

    /// Reads the photo and makes the JPEG. A failure stays on screen with "Tap to try again".
    private func prepare(_ id: UUID) {
        guard let p = pending.first(where: { $0.id == id }) else { return }
        Task { @MainActor in
            let jpeg = await InspoPhoto.jpeg(from: p.item)
            guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
            if let jpeg, photos.count < limit {
                pending.remove(at: i)
                photos.append(jpeg)
                thumbs.append(InspoPhoto.thumbnail(from: jpeg))
            } else {
                pending[i].failed = true
            }
        }
    }

    private func retry(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[i].failed = false
        prepare(id)
    }

    private func remove(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
        if thumbs.indices.contains(index) { thumbs.remove(at: index) }
    }
}

/// The "Add photos" tile: same size as a photo, a 1pt line border and an outline plus. No dashes, no fill.
/// At accessibility text sizes the words move under the tile (which stays photo-sized) so they never clip.
struct AddPhotoTile: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    private var label: some View {
        Text("Add photos")
            .font(HDFont.caption.weight(.medium))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        VStack(spacing: Space.s) {
            VStack(spacing: Space.s) {
                Image(systemName: "plus").font(.system(size: 19, weight: .light))
                if !typeSize.isAccessibilitySize { label }
            }
            .frame(width: 104, height: 130)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.photo, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 1)
            )
            if typeSize.isAccessibilitySize {
                label.frame(width: 104)
            }
        }
        .foregroundStyle(Palette.ink)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add photos")
        .accessibilityAddTraits(.isButton)
    }
}

/// Serif title and a soft sub-line at the top of each step.
struct StepTitle: View {
    var title: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(HDFont.title).foregroundStyle(Palette.ink)
            if let sub {
                Text(sub).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.l)
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
