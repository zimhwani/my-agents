import SwiftUI
import PhotosUI

/// Seven short steps to a pro profile. Presented full screen from the client side.
///
/// She can leave from any step (the xmark), and what she's done is kept: every step she leaves is
/// saved on the phone (`ProOnboardingDraft`), and once there's enough for a row, as a draft pro
/// (`isOnboarded = false`) that clients can't see. Finishing sends it (`isOnboarded = true`); she's
/// live once payouts are on and a person has checked her ID.
struct ProOnboardingFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    var onFinished: () -> Void

    private let totalSteps = ProOnboardingDraft.totalSteps
    private let doneStep = ProOnboardingDraft.totalSteps + 1

    @State private var step = 0
    @State private var loaded = false
    @State private var resumeStep: Int? = nil
    @State private var wasOnboarded = false
    @State private var draftID = "pro_\(UUID().uuidString.prefix(8).lowercased())"
    @State private var seed = Int.random(in: 1...9_999)

    @State private var specialties: [Category] = []
    @State private var services: [Service] = []
    @State private var seededFor: Set<Category> = []
    @State private var editingService: Service? = nil
    @State private var addingService = false
    @State private var base = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var radiusKm: Double = 10
    @State private var feeText = "15"
    @State private var hours = HoursDraft()
    @State private var work: [WorkItem] = []
    @State private var uploads: [PickedWorkPhoto] = []
    @State private var picks: [PhotosPickerItem] = []
    @State private var abn = ""
    @State private var payoutsOn = false
    @State private var fetchingURL = false
    @State private var saving = false
    /// A save that didn't go through. Shown above the button; a toast would sit under this cover.
    @State private var problem: String? = nil
    @State private var confirmLeave = false
    /// Draft saves, one at a time, so two can't race and duplicate her service rows.
    @State private var drafts = DraftSaves()

    private var userID: String { app.client?.id ?? "" }
    private var abnDigits: String { abn.filter(\.isNumber) }
    private var abnOK: Bool { abnDigits.isEmpty || abnDigits.count == 11 }
    private var suburb: String {
        let typed = base.trimmingCharacters(in: .whitespaces)
        return typed.isEmpty ? app.location.suburbGuess : typed
    }
    private var idSent: Bool { app.proSelf?.idSubmitted == true || app.proSelf?.isVerified == true }
    /// A specialty and a service: enough for a pro row.
    private var enoughForRow: Bool { !specialties.isEmpty && !services.isEmpty }
    private var hasAnswers: Bool { !specialties.isEmpty || !work.isEmpty || !abn.isEmpty || !base.isEmpty }

    private var canContinue: Bool {
        switch step {
        case 1: return !specialties.isEmpty
        case 2: return !services.isEmpty
        case 4: return hours.hours.values.contains { !$0.isEmpty }
        case 5: return work.count >= 3
        case 6: return abnOK
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if step < doneStep { chrome }
            if app.isOffline { OfflineBar() }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    switch step {
                    case 0: intro
                    case 1: specialtyStep
                    case 2: servicesStep
                    case 3: travelStep
                    case 4: hoursStep
                    case 5: workStep
                    case 6: idStep
                    case 7: payoutsStep
                    default: finishedStep
                    }
                }
                .screenGutter()
                .padding(.top, Space.l)
                .padding(.bottom, Space.xl)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .paperBackground()
        .animation(Motion.spring, value: step)
        .onAppear(perform: restore)
        // Stripe tells the server when payouts are on; the app hears about it on the way back.
        .onChange(of: app.proSelf?.payoutsConnected) { _, on in
            if on == true { withAnimation(Motion.spring) { payoutsOn = true } }
        }
        .onChange(of: picks) { _, new in
            guard !new.isEmpty else { return }
            let items = new
            picks = []
            Task { await addPhotos(items) }
        }
        .sheet(isPresented: $addingService) {
            ServiceEditorSheet(categories: specialties) { s in withAnimation(Motion.spring) { services.append(s) } }
        }
        .sheet(item: $editingService) { s in
            ServiceEditorSheet(existing: s, categories: specialties, onRemove: {
                withAnimation(Motion.spring) { services.removeAll { $0.id == s.id } }
            }) { updated in
                if let i = services.firstIndex(where: { $0.id == s.id }) { services[i] = updated }
            }
        }
        .confirmSheet(isPresented: $confirmLeave, title: "Finish later?",
                      message: "Everything so far is saved. Clients can't see you until it's done.",
                      confirmTitle: "Finish later", cancelTitle: "Keep going") {
            leave()
        }
        .onChange(of: step) { _, _ in problem = nil }
        .payoutNoticeAlert()
        .holdsPushRoutes()
    }

    // MARK: Chrome

    private var chrome: some View {
        VStack(spacing: 0) {
            ZStack {
                if step >= 1 {
                    Text("\(step) of \(totalSteps)").labelStyle()
                        .accessibilityLabel("Step \(step) of \(totalSteps)")
                }
                HStack(spacing: 0) {
                    if step >= 1 {
                        IconButton(symbol: "chevron.left", label: "Back") { back() }
                    }
                    Spacer()
                    IconButton(symbol: "xmark", label: "Close") { close() }
                }
                .padding(.horizontal, Space.gutter - 12)
            }
            .frame(minHeight: 44)
            .padding(.top, Space.s)
            ProgressLine(fraction: Double(step) / Double(totalSteps))
                .opacity(step >= 1 ? 1 : 0)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if step < doneStep {
            VStack(alignment: .leading, spacing: Space.xs) {
                if let problem { FieldMessage(text: problem).padding(.bottom, Space.xs) }
                InkButton(title: footerTitle, isLoading: saving || fetchingURL, isEnabled: canContinue && !(step == 7 && app.isOffline)) { primary() }
                if step == 0 && resumeStep != nil {
                    TertiaryButton(title: "Start from the top") { go(to: 1) }
                        .frame(maxWidth: .infinity)
                } else if step == 6 && !idSent {
                    TertiaryButton(title: "Do this later") { go(to: 7) }
                        .frame(maxWidth: .infinity)
                } else if step == 7 && !payoutsOn {
                    TertiaryButton(title: "Do this later") { Task { await finish() } }
                        .frame(maxWidth: .infinity)
                        .disabled(saving || app.isOffline)
                }
            }
            .screenGutter()
            .padding(.vertical, Space.l)
            .background(Palette.paper)
            .overlay(alignment: .top) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        }
    }

    private var footerTitle: String {
        switch step {
        case 0: return resumeStep == nil ? "Start" : "Keep going"
        case 5: return work.count >= 3 ? "Next" : "\(work.count) of 3"
        case 7: return payoutsOn ? "Finish" : "Set up payouts"
        default: return "Next"
        }
    }

    private func primary() {
        switch step {
        case 0: go(to: resumeStep ?? 1)
        case 7: Task { if payoutsOn { await finish() } else { await setUpPayouts() } }
        default:
            if step == 1 { seedServices() }
            go(to: step + 1)
        }
    }

    private func back() {
        go(to: max(step - 1, 0))
    }

    /// Moves to a step, saving as she leaves this one.
    private func go(to next: Int) {
        withAnimation(Motion.spring) { step = next }
        persist()
    }

    private func close() {
        if hasAnswers && step < doneStep {
            confirmLeave = true
        } else {
            dismiss()
        }
    }

    private func leave() {
        persist()
        dismiss()
    }

    // MARK: Keeping her place

    private func restore() {
        guard !loaded else { return }
        loaded = true
        let existing = app.proSelf
        wasOnboarded = existing?.isOnboarded ?? false
        if let id = existing?.id { draftID = id } else if app.isLive, let id = app.client?.id { draftID = id }
        if let s = existing?.seed { seed = s }
        latitude = app.location.coordinate.latitude
        longitude = app.location.coordinate.longitude
        payoutsOn = existing?.payoutsConnected ?? false

        if let d = ProOnboardingDraft.load(userID: userID) {
            specialties = d.specialties
            services = d.services
            seededFor = Set(d.specialties)
            base = d.base
            if let lat = d.latitude, let lng = d.longitude { latitude = lat; longitude = lng }
            radiusKm = d.radiusKm
            feeText = d.feeText
            hours.hours = d.hours
            hours.bufferMinutes = d.bufferMinutes
            hours.noticeMinutes = d.noticeMinutes
            work = d.work
            abn = d.abn
            resumeStep = d.step >= 1 ? min(d.step, totalSteps) : nil
        } else if let p = existing {
            // A draft from another phone, or a closed profile coming back: start from what's kept.
            specialties = p.specialties
            services = p.services
            seededFor = Set(p.specialties)
            base = p.suburb
            latitude = p.latitude
            longitude = p.longitude
            radiusKm = p.travelRadiusKm
            feeText = ProMoney.dollarsText(p.travelFeeCents)
            hours = HoursDraft(p)
            work = p.work
            abn = p.abn
            if !p.isOnboarded || p.isClosed { resumeStep = firstUnfinished }
        }
    }

    private var firstUnfinished: Int {
        if specialties.isEmpty { return 1 }
        if services.isEmpty { return 2 }
        if work.count < 3 { return 5 }
        return 7
    }

    /// On the phone always; as a draft pro once there's enough for a row. A failed draft save is
    /// quiet: the phone copy has it, and the next step tries again.
    private func persist() {
        let reached = min(max(step, resumeStep ?? 0, 1), totalSteps)
        if step < doneStep {
            ProOnboardingDraft(step: reached, specialties: specialties, services: services, base: base,
                               latitude: latitude, longitude: longitude, radiusKm: radiusKm, feeText: feeText,
                               hours: hours.hours, bufferMinutes: hours.bufferMinutes, noticeMinutes: hours.noticeMinutes,
                               work: work, abn: abnDigits).save(userID: userID)
        }
        guard enoughForRow, !app.isOffline else { return }
        // One save at a time: while one's going, only the newest waits behind it.
        drafts.save(draftPro(onboarded: wasOnboarded)) { pro in
            do {
                app.proSelf = try await app.data.updatePro(pro)
            } catch {
                // Kept on the phone; nothing to tell her yet.
            }
        }
    }

    /// The draft pro, saved and waited for (payouts and the ID check need a row to hang off).
    /// Waits for any quiet save first, so the two never overlap.
    private func saveDraftNow() async -> Bool {
        guard enoughForRow else { return false }
        await drafts.settle()
        return await app.saveProSelf(draftPro(onboarded: wasOnboarded))
    }

    // MARK: Steps

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Get booked.").font(HDFont.display).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if let resumeStep {
                Text("Pick up where you left off. Step \(resumeStep) of \(totalSteps).")
                    .font(HDFont.quote).foregroundStyle(Palette.ink)
            }
            Text("Seven short steps, about ten minutes. You'll need a photo of your ID and three photos of your work, and your ABN if you have one.")
                .font(HDFont.body).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text("Leave whenever you like. What you've done is kept, and clients can't see you until it's finished.")
                .font(HDFont.body).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.section)
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(t).font(HDFont.title).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(sub).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var specialtyStep: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            title("What do you do?", "Pick everything you offer. The first one you pick is your main label.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.m, alignment: .top), count: 3), spacing: Space.l) {
                ForEach([Category.hair, .nails, .makeup, .lashes, .brows]) { c in
                    specialtyTile(c)
                }
            }
            if let main = specialties.first {
                Text("Main label: \(main.specialtyTitle)").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func specialtyTile(_ c: Category) -> some View {
        let on = specialties.contains(c)
        return Button {
            Haptics.selection()
            withAnimation(Motion.spring) {
                if let i = specialties.firstIndex(of: c) { specialties.remove(at: i) } else { specialties.append(c) }
            }
        } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                // A picture of the category, not anyone's work: stock is fine on the live backend too.
                WorkTile(item: WorkItem(id: "specialty_\(c.rawValue)", category: c, caption: c.label, seed: 11),
                         cornerRadius: Radius.photo, isIllustration: true)
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .opacity(on ? 1 : 0.45)
                HStack(spacing: 4) {
                    Text(c.specialtyTitle).font(HDFont.categoryWord).foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if on {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .regular)).foregroundStyle(Palette.ink)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.97))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(c.specialtyTitle)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private var servicesStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("Services and prices", "Your price is what clients see. Hair Done's 12% comes out of your side, and they pay a $3 booking fee on top.")
            VStack(spacing: 0) {
                if services.isEmpty {
                    Text("Nothing yet. Your top three is enough to start.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(services) { s in
                    ServiceEditRow(service: s) { editingService = s }
                }
            }
            OutlineButton(title: "Add a service", symbol: "plus", compact: true) { addingService = true }
            Text("We've started you with common ones for \(specialties.map { $0.specialtyTitle.lowercased() }.joined(separator: " and ")). Change anything.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var travelStep: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            title("Where you'll go", "Your base and how far from it you'll travel.")
            ProTravelArea(base: $base, latitude: $latitude, longitude: $longitude, radiusKm: $radiusKm, placeholder: app.location.suburbGuess)
            HDTextField(label: "Travel fee", placeholder: "15", text: $feeText, keyboard: .decimalPad,
                        caption: "Flat, per booking, shown on your profile. $0 is fine.")
        }
    }

    private var hoursStep: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            title("When you work", "Your usual week. Change any day later from Calendar.")
            ProHoursForm(hours: $hours.hours, bufferMinutes: $hours.bufferMinutes, noticeMinutes: $hours.noticeMinutes, showsCopyMonday: true)
        }
    }

    private var workStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("Show your work", "At least three. Your photos of your own work, close and in daylight if you can. No screenshots. This is what gets you booked.")
            if !work.isEmpty || !uploads.isEmpty {
                ProFlowLayout(spacing: Space.s) {
                    ForEach(work) { item in
                        UploadTile(state: .done, onRemove: {
                            withAnimation(Motion.spring) { work.removeAll { $0.id == item.id } }
                        }) {
                            WorkTile(item: item, cornerRadius: 0)
                        }
                    }
                    ForEach(uploads) { u in
                        UploadTile(image: u.image, state: u.state, onRetry: { Task { await upload(u.id) } },
                                   onRemove: u.state == .failed ? removeUpload(u.id) : nil)
                    }
                }
            }
            PhotosPicker(selection: $picks, maxSelectionCount: 10, matching: .images) {
                Text("Add photos")
                    .font(HDFont.bodyStrong)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressLift())
            .disabled(app.isOffline)
            Text(work.count < 3 ? "\(work.count) of 3 minimum" : "\(ProFlow.count(work.count, "photo", "photos")). Tag each one from Work once you're on.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            Text("Your own work only. Anyone else's and your profile comes down.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    private func removeUpload(_ id: String) -> () -> Void {
        { withAnimation(Motion.spring) { uploads.removeAll { $0.id == id } } }
    }

    private var idStep: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            title("Who you are", "Clients only book pros a person has checked. Someone from Hair Done does it by hand; nothing's automatic.")
            ProIDCheckView(prepare: { await saveDraftNow() })
            HDTextField(label: "ABN (optional)", placeholder: "11 digits", text: $abn, keyboard: .numberPad,
                        caption: "If you have one, it goes on your clients' receipts.",
                        error: abnOK ? nil : "An ABN is 11 digits. Have another look.")
        }
    }

    private var payoutsStep: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            title("Getting paid", "Payouts go to your bank daily through Stripe. Stripe asks for your details on its own page; we never see your bank login.")
            VStack(alignment: .leading, spacing: 0) {
                row("Hair Done takes", "12% of what you charge")
                row("Clients pay", "a $3 booking fee on top")
                row("Tips", "all yours")
                // Money in SF monospaced, never serif.
                (Text("A $150 set with a $15 travel fee pays you ") + Text("$145.20").font(HDFont.priceStrong) + Text("."))
                    .font(HDFont.body).monospacedDigit().foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.l)
            }
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(payoutsOn ? "Payouts on." : "Not set up yet.").font(HDFont.name).foregroundStyle(Palette.ink)
                Text(payoutsOn ? "Daily, to your bank." : "About two minutes. Clients can't book you until it's done. You'll land back here when you're finished.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(HDFont.body).foregroundStyle(Palette.ink)
            Spacer()
            Text(value).font(HDFont.sub).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
    }

    // MARK: Finished

    private var finishedStep: some View {
        let pro = app.proSelf
        let payouts = pro?.payoutsConnected == true || payoutsOn
        let id = pro?.idSubmitted == true || pro?.isVerified == true
        let live = payouts && pro?.isVerified == true
        let titleText: String
        let line: String
        if live {
            titleText = "You're on."
            line = "Your profile's live in \(suburb). The first request could be today."
        } else if !payouts && !id {
            titleText = "Sent."
            line = "You're not live yet. Finish payouts and we'll check your ID, then clients can book you."
        } else if !payouts {
            titleText = "Sent."
            line = "You're not live yet. Finish payouts, then clients can book you."
        } else if !id {
            titleText = "Sent."
            line = "You're not live yet. Send your ID and we'll check it, then clients can book you."
        } else {
            titleText = "Sent."
            line = "Someone from Hair Done checks your ID by hand, usually within a day. Then clients can book you."
        }
        return VStack(alignment: .leading, spacing: Space.l) {
            if live { LacquerCheck(size: 56).padding(.top, Space.section) } else { Spacer().frame(height: Space.section) }
            Text(titleText).font(HDFont.display).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(line).font(HDFont.body).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if !live {
                Text("Today shows what's left.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            }
            InkButton(title: "Go to Today") {
                Haptics.success()
                onFinished()
            }
            .padding(.top, Space.l)
        }
    }

    // MARK: Work photos

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        var fresh: [PickedWorkPhoto] = []
        for item in items {
            guard let image = await PhotoData.image(from: item), let jpeg = PhotoData.jpeg(from: image) else { continue }
            fresh.append(PickedWorkPhoto(image: image, jpeg: jpeg))
        }
        guard !fresh.isEmpty else {
            problem = "Those photos couldn't be read. Try others."
            return
        }
        withAnimation(Motion.spring) { uploads.append(contentsOf: fresh) }
        for photo in fresh { await upload(photo.id) }
    }

    private func upload(_ id: String) async {
        guard let i = uploads.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(Motion.gentle) { uploads[i].state = .uploading(0.4) }
        let jpeg = uploads[i].jpeg
        let url = await app.uploadWorkPhoto(jpeg)
        guard let j = uploads.firstIndex(where: { $0.id == id }) else { return }
        guard let url else {
            withAnimation(Motion.gentle) { uploads[j].state = .failed }
            return
        }
        let item = WorkItem(id: UUID().uuidString.lowercased(), category: specialties.first ?? .hair, caption: "",
                            seed: Int.random(in: 1...9_999), imageURL: url)
        withAnimation(Motion.spring) {
            uploads.remove(at: j)
            work.append(item)
        }
    }

    // MARK: Saving

    private func seedServices() {
        for c in specialties where !seededFor.contains(c) {
            services.append(contentsOf: SuggestedServices.starters(for: c))
            seededFor.insert(c)
        }
        services.removeAll { !specialties.contains($0.category) }
    }

    private func setUpPayouts() async {
        guard !fetchingURL else { return }
        fetchingURL = true
        defer { fetchingURL = false }
        problem = nil
        // The payout link belongs to a pro profile, so she's saved as a (hidden) draft first.
        guard await saveDraftNow() else {
            withAnimation(Motion.gentle) { problem = "Didn't save. Everything's still here. Try again." }
            return
        }
        // A failure here puts up "Stripe didn't open" (PayoutNoticeAlert).
        guard let url = await app.payoutLink() else { return }
        openURL(url) { accepted in
            if !accepted { Task { @MainActor in app.payoutNotice = .didntOpen } }
        }
        // The sample data says yes straight away; the real answer comes back from Stripe.
        if !app.isLive { withAnimation(Motion.spring) { payoutsOn = true } }
    }

    /// Sends it: `isOnboarded = true`. Clients still can't see her until payouts are on and her ID's checked.
    private func finish() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        problem = nil
        // A draft save landing after this one would put her back to a draft.
        await drafts.settle()
        if app.proSelf?.isClosed == true {
            guard await app.reopenProProfile() else {
                withAnimation(Motion.gentle) { problem = "Didn't send. Everything's saved. Try again." }
                return
            }
        }
        guard await app.saveProSelf(draftPro(onboarded: true)) else {
            withAnimation(Motion.gentle) { problem = "Didn't send. Everything's saved. Try again." }
            return
        }
        ProOnboardingDraft.clear(userID: userID)
        Haptics.success()
        withAnimation(Motion.spring) { step = doneStep }
    }

    /// Her profile as the steps have it so far. Fields set elsewhere (photo, ID, payouts, reviews) are kept.
    private func draftPro(onboarded: Bool) -> Pro {
        let client = app.client
        let existing = app.proSelf
        var availability = existing?.availability ?? WeeklyAvailability.standard
        hours.apply(to: &availability)
        let firstName = existing.map(\.firstName).flatMap { $0.isEmpty ? nil : $0 } ?? client?.firstName ?? ""
        let headline = existing.map(\.headline).flatMap { $0.isEmpty ? nil : $0 }
            ?? "\(specialties.first?.specialtyTitle ?? "Pro") in \(suburb)."
        var pro = Pro(
            id: draftID,
            firstName: firstName,
            lastInitial: existing?.lastInitial ?? String(client?.lastName.prefix(1) ?? "").uppercased(),
            specialties: specialties,
            headline: headline,
            bio: existing?.bio ?? "",
            suburb: suburb,
            latitude: latitude,
            longitude: longitude,
            travelRadiusKm: radiusKm,
            travelFeeCents: ProMoney.dollars(feeText),
            rating: existing?.rating ?? 0,
            reviewCount: existing?.reviewCount ?? 0,
            isVerified: existing?.isVerified ?? false,
            instantBook: existing?.instantBook ?? false,
            yearsExperience: existing?.yearsExperience ?? 0,
            responseMinutes: existing?.responseMinutes ?? 60,
            joined: existing?.joined ?? Date(),
            services: services,
            work: work,
            reviews: existing?.reviews ?? [],
            availability: availability,
            seed: seed
        )
        pro.isActive = existing?.isActive ?? true
        pro.completedBookings = existing?.completedBookings ?? 0
        pro.reliabilityScore = existing?.reliabilityScore ?? 1
        pro.abn = abnDigits
        pro.payoutsConnected = (existing?.payoutsConnected ?? false) || payoutsOn
        pro.noticeMinutes = hours.noticeMinutes
        pro.isOnboarded = onboarded
        pro.isClosed = existing?.isClosed ?? false
        pro.idSubmitted = existing?.idSubmitted ?? false
        pro.avatarURL = existing?.avatarURL
        return pro
    }
}

/// Pro setup's draft saves, one at a time. A save asked for while one's going waits; a newer one
/// replaces it, so at most one waits and it's always the latest. `settle()` drops the waiting one
/// and waits out the one going, before a save that must land last (Finish, payouts, ID).
@MainActor
private final class DraftSaves {
    private var running: Task<Void, Never>? = nil
    private var waiting: Pro? = nil

    func save(_ pro: Pro, with write: @escaping @MainActor (Pro) async -> Void) {
        waiting = pro
        guard running == nil else { return }
        running = Task { @MainActor in
            while let next = self.waiting {
                self.waiting = nil
                await write(next)
            }
            self.running = nil
        }
    }

    func settle() async {
        waiting = nil
        if let running { await running.value }
    }
}

private extension HoursDraft {
    func apply(to availability: inout WeeklyAvailability) {
        availability.hours = hours
        availability.bufferMinutes = bufferMinutes
    }
}

#Preview("Pro onboarding") {
    ProOnboardingFlow(onFinished: {}).environment(previewApp(mode: .client))
}
