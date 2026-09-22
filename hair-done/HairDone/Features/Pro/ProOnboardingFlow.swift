import SwiftUI
import PhotosUI

/// Seven short steps to a live pro profile. Presented full screen from the client side.
struct ProOnboardingFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    var onFinished: () -> Void

    private enum IDState { case none, checking, checked }
    private let totalSteps = 7

    @State private var step = 0
    @State private var specialties: [Category] = []
    @State private var services: [Service] = []
    @State private var seededFor: Set<Category> = []
    @State private var editingService: Service? = nil
    @State private var addingService = false
    @State private var base = ""
    @State private var radiusKm: Double = 10
    @State private var feeText = "15"
    @State private var hours: [Weekday: [TimeRange]] = WeeklyAvailability.standard.hours
    @State private var work: [WorkItem] = []
    @State private var picks: [PhotosPickerItem] = []
    @State private var abn = ""
    @State private var idState: IDState = .none
    @State private var payoutsOn = false
    @State private var fetchingURL = false
    @State private var saving = false

    private var abnDigits: String { abn.filter(\.isNumber) }
    private var abnOK: Bool { abnDigits.isEmpty || abnDigits.count == 11 }
    private var suburb: String { base.trimmingCharacters(in: .whitespaces).isEmpty ? app.location.suburbGuess : base.trimmingCharacters(in: .whitespaces) }

    private var canContinue: Bool {
        switch step {
        case 1: return !specialties.isEmpty
        case 2: return !services.isEmpty
        case 4: return hours.values.contains { !$0.isEmpty }
        case 5: return work.count >= 3
        case 6: return abnOK
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 && step <= totalSteps { progress }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    switch step {
                    case 0: intro
                    case 1: specialtyStep
                    case 2: servicesStep
                    case 3: travelStep
                    case 4: availabilityStep
                    case 5: workStep
                    case 6: idStep
                    case 7: payoutsStep
                    default: doneStep
                    }
                }
                .screenGutter()
                .padding(.vertical, Space.l)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .paperBackground()
        .animation(Motion.spring, value: step)
        .onChange(of: picks) { _, new in
            guard !new.isEmpty else { return }
            let category = specialties.first ?? .hair
            withAnimation(Motion.spring) { work.append(contentsOf: new.map { _ in WorkItem.placeholder(category: category) }) }
            picks = []
        }
        .sheet(isPresented: $addingService) {
            ServiceEditorSheet(categories: specialties) { s in withAnimation(Motion.spring) { services.append(s) } }
        }
        .sheet(item: $editingService) { s in
            ServiceEditorSheet(existing: s, categories: specialties) { updated in
                if let i = services.firstIndex(where: { $0.id == s.id }) { services[i] = updated }
            }
        }
    }

    // MARK: Chrome

    private var progress: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back") { withAnimation(Motion.spring) { step -= 1 } }
                Spacer()
                Text("\(step) of \(totalSteps)").labelStyle()
            }
            ProgressSegments(step: step, total: totalSteps)
        }
        .screenGutter()
        .padding(.top, Space.l)
    }

    @ViewBuilder
    private var footer: some View {
        if step <= totalSteps {
            VStack(spacing: Space.xs) {
                PrimaryButton(title: footerTitle, isLoading: saving, isEnabled: canContinue) { advance() }
                if step == 6 && idState != .checked {
                    TertiaryButton(title: "Do this later") { advance(skipping: true) }
                } else if step == 7 && !payoutsOn {
                    TertiaryButton(title: "Skip for now") { advance(skipping: true) }
                }
            }
            .screenGutter()
            .padding(.vertical, Space.l)
            .background(Palette.paper)
        }
    }

    private var footerTitle: String {
        switch step {
        case 0: return "Start"
        case 5: return work.count >= 3 ? "Next" : "\(work.count) of 3"
        case 7: return payoutsOn ? "Finish" : "Set up payouts"
        default: return "Next"
        }
    }

    private func advance(skipping: Bool = false) {
        if step == 7 && !payoutsOn && !skipping {
            Task { await setUpPayouts() }
            return
        }
        if step == 1 { seedServices() }
        withAnimation(Motion.spring) { step += 1 }
    }

    // MARK: Steps

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            DropMark(size: 36).padding(.bottom, Space.s)
            Text("Your pro side").font(HDFont.hero).foregroundStyle(Palette.ink)
            Text("Seven short steps. You can come back to any of them, and take bookings before the last two are done.")
                .font(HDFont.body).foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, Space.section)
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(HDFont.title).foregroundStyle(Palette.ink)
            Text(sub).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
        }
    }

    private var specialtyStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("Your specialty", "Pick everything you do. The first one's your main label.")
            VStack(spacing: 0) {
                ForEach([Category.hair, .nails, .makeup, .lashes, .brows]) { c in
                    let on = specialties.contains(c)
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.spring) {
                            if let i = specialties.firstIndex(of: c) { specialties.remove(at: i) } else { specialties.append(c) }
                        }
                    } label: {
                        HStack(spacing: Space.m) {
                            Image(systemName: c.symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(c.tintInk)
                                .frame(width: 36, height: 36).background(c.tint, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.specialtyTitle).font(HDFont.body).foregroundStyle(Palette.ink)
                                Text(c.blurb).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            if on, specialties.first == c { Tag(text: "Main", color: Palette.lacquer, background: Palette.lacquerSoft) }
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22)).foregroundStyle(on ? Palette.lacquer : Palette.inkFaint)
                        }
                        .padding(.vertical, Space.m)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    if c != .brows { Hairline() }
                }
            }
            .card(padding: Space.l)
        }
    }

    private var servicesStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("Services and prices", "Your price is what she sees. Our 12% comes out of your side, and she pays a $3 booking fee on top.")
            if services.isEmpty {
                Text("Nothing yet. Your top three is enough to start.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            } else {
                VStack(spacing: 0) {
                    ForEach(services) { s in
                        ServiceEditRow(service: s, onEdit: { editingService = s }, onRemove: {
                            withAnimation(Motion.spring) { services.removeAll { $0.id == s.id } }
                        })
                        if s.id != services.last?.id { Hairline() }
                    }
                }
                .card(padding: Space.l)
            }
            SecondaryButton(title: "Add a service", symbol: "plus") { addingService = true }
            Text("We've started you with common ones for \(specialties.map { $0.specialtyTitle.lowercased() }.joined(separator: " and ")). Change anything.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    private var travelStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("Where you'll go", "Your base and how far from it you'll travel. Clients outside this won't see you.")
            VStack(alignment: .leading, spacing: Space.l) {
                HDTextField(label: "Your base", placeholder: app.location.suburbGuess, text: $base)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("How far").font(HDFont.subStrong).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(Int(radiusKm)) km").font(HDFont.price).foregroundStyle(Palette.ink)
                    }
                    Slider(value: $radiusKm, in: 2...25, step: 1).tint(Palette.lacquer)
                        .accessibilityLabel("How far").accessibilityValue("\(Int(radiusKm)) kilometres")
                    HStack(spacing: Space.s) {
                        ForEach([5, 10, 15, 25], id: \.self) { km in
                            Chip(title: "\(km) km", isSelected: Int(radiusKm) == km) { withAnimation(Motion.spring) { radiusKm = Double(km) } }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HDTextField(label: "Travel fee", placeholder: "15", text: $feeText, keyboard: .decimalPad)
                    Text("Flat, per booking, shown on your profile. $0 is fine.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
            }
            .card(padding: Space.l)
        }
    }

    private var availabilityStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("When you work", "Your usual week. Change any day later from Calendar.")
            AvailabilityEditor(hours: $hours).card(padding: Space.l)
            HStack {
                TertiaryButton(title: "Copy Monday to every day", tint: Palette.lacquer) {
                    let monday = hours[.monday] ?? []
                    withAnimation(Motion.spring) { for d in Weekday.week { hours[d] = monday } }
                }
                Spacer()
            }
        }
    }

    private var workStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("Your work", "At least three. Your photos, your clients, natural light if you can get it. This is what gets you booked.")
            if !work.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(work) { item in
                        WorkTile(item: item)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    Haptics.light()
                                    withAnimation(Motion.spring) { work.removeAll { $0.id == item.id } }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.ink)
                                        .frame(width: 26, height: 26).background(Palette.paper.opacity(0.92), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(6)
                                .accessibilityLabel("Remove photo")
                            }
                    }
                }
            }
            AddPhotosButton(selection: $picks, quiet: !work.isEmpty)
            Text(work.count < 3 ? "\(work.count) of 3" : "\(work.count) photos. Tag each one from Work once you're on.")
                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            Text("Your own work only. Anyone else's and your profile comes down.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    private var idStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("ID and ABN", "Once, and you get the ID checked badge. Clients look for it.")
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: 4) {
                    HDTextField(label: "ABN", placeholder: "11 digits", text: $abn, keyboard: .numberPad)
                    if !abnOK { Text("An ABN is 11 digits. Have another look.").font(HDFont.caption).foregroundStyle(Palette.warn) }
                }
                Hairline()
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Photo ID").font(HDFont.subStrong).foregroundStyle(Palette.ink)
                    Text("Licence or passport, then a quick selfie.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    switch idState {
                    case .none:
                        SecondaryButton(title: "Verify ID", symbol: "person.text.rectangle") { Task { await verifyID() } }
                    case .checking:
                        HStack(spacing: 8) {
                            ProgressView().tint(Palette.warn)
                            Text("Checking. Usually within a day.").font(HDFont.sub).foregroundStyle(Palette.warn)
                        }
                        .frame(minHeight: 44)
                    case .checked:
                        HStack(spacing: 8) {
                            VerifiedBadge()
                            Text("Checked").font(HDFont.sub).foregroundStyle(Palette.success)
                        }
                        .frame(minHeight: 44)
                    }
                }
                Text("Your ID is checked, then deleted. Only the tick stays.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            .card(padding: Space.l)
        }
    }

    private var payoutsStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            title("Getting paid", "Payouts go to your bank daily through Stripe. About two minutes to set up.")
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.m) {
                    Image(systemName: payoutsOn ? "checkmark.seal.fill" : "building.columns")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(payoutsOn ? Palette.success : Palette.inkSoft)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payoutsOn ? "Payouts on" : "Stripe Express").font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                        Text(payoutsOn ? "Daily, to your bank." : "Your bank details go to Stripe, not us. You'll land back here when you're done.")
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
                if !payoutsOn {
                    Hairline()
                    Text("You can take bookings now. You'll need this before your first payout lands.")
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
            }
            .card(padding: Space.l)
            if fetchingURL { HStack { Spacer(); LoadingDots(); Spacer() } }
        }
    }

    private var doneStep: some View {
        VStack(spacing: Space.l) {
            LacquerCheck().padding(.top, Space.section)
            Text("You're on.").font(HDFont.hero).foregroundStyle(Palette.ink)
            Text("Your profile's live in \(suburb). The first request could be today.")
                .font(HDFont.body).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
            PrimaryButton(title: "Go to Today", isLoading: saving) { Task { await finish() } }
                .padding(.top, Space.l)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Work

    private func seedServices() {
        for c in specialties where !seededFor.contains(c) {
            services.append(contentsOf: SuggestedServices.starters(for: c))
            seededFor.insert(c)
        }
        services.removeAll { !specialties.contains($0.category) }
    }

    private func verifyID() async {
        withAnimation(Motion.spring) { idState = .checking }
        try? await Task.sleep(for: .seconds(1.4))
        Haptics.success()
        withAnimation(Motion.spring) { idState = .checked }
    }

    private func setUpPayouts() async {
        fetchingURL = true
        defer { fetchingURL = false }
        do {
            let url = try await app.payments.payoutOnboardingURL(proID: app.client?.id ?? "new")
            openURL(url)
            withAnimation(Motion.spring) { payoutsOn = true }
        } catch {
            app.show("That didn't work. Try again.")
        }
    }

    private func finish() async {
        saving = true
        defer { saving = false }
        let client = app.client
        let coordinate = app.location.coordinate
        var availability = WeeklyAvailability.standard
        availability.hours = hours
        let pro = Pro(
            id: app.proSelf?.id ?? "pro_\(UUID().uuidString.prefix(6))",
            firstName: client?.firstName ?? "You",
            lastInitial: String(client?.lastName.prefix(1) ?? "").uppercased(),
            specialties: specialties,
            headline: "\(specialties.first?.specialtyTitle ?? "Pro") in \(suburb).",
            bio: "",
            suburb: suburb,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            travelRadiusKm: radiusKm,
            travelFeeCents: ProMoney.dollars(feeText),
            rating: 0,
            reviewCount: 0,
            isVerified: idState == .checked,
            instantBook: false,
            yearsExperience: 0,
            responseMinutes: 60,
            joined: Date(),
            services: services,
            work: work,
            reviews: [],
            availability: availability,
            seed: Int.random(in: 1...9_999),
            abn: abnDigits,
            payoutsConnected: payoutsOn
        )
        await app.saveProSelf(pro)
        Haptics.success()
        onFinished()
    }
}

#Preview("Pro onboarding") {
    ProOnboardingFlow(onFinished: {}).environment(previewApp(mode: .client))
}
