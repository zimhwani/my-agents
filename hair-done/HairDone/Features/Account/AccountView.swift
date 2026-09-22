import SwiftUI

/// The You tab: who you are, where she comes to, how you pay, who you'd book again, and the switch to Pro mode.
struct AccountView: View {
    @Environment(AppState.self) private var app
    @State private var path = NavigationPath()

    @State private var showDetails = false
    @State private var showAddresses = false
    @State private var showPayments = false
    @State private var showNotifications = false
    @State private var showHelp = false
    @State private var showLegal = false
    @State private var showProOnboarding = false
    @State private var confirmLogout = false

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Text("You")
                        .font(HDFont.hero)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, Space.s)
                        .accessibilityAddTraits(.isHeader)

                    if let client = app.client {
                        profileHeader(client)
                        settingsCard(client)
                        favouritesCard
                        aboutCard
                        proModeCard
                    }

                    TertiaryButton(title: "Log out") { confirmLogout = true }
                        .frame(maxWidth: .infinity)
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .confirmationDialog("Log out?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Log out", role: .destructive) { app.signOut() }
                Button("Stay", role: .cancel) {}
            } message: {
                Text("Your bookings stay put. You'll need a new code to get back in.")
            }
            .sheet(isPresented: $showDetails) { AccountDetailsSheet().presentationDragIndicator(.visible) }
            .sheet(isPresented: $showAddresses) { AccountAddressesSheet().presentationDragIndicator(.visible) }
            .sheet(isPresented: $showPayments) { AccountPaymentsSheet().presentationDragIndicator(.visible) }
            .sheet(isPresented: $showNotifications) { AccountNotificationsSheet().presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showHelp) { AccountHelpSheet().presentationDragIndicator(.visible) }
            .sheet(isPresented: $showLegal) { AccountLegalSheet().presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
            .fullScreenCover(isPresented: $showProOnboarding) {
                ProOnboardingFlow {
                    showProOnboarding = false
                    app.switchMode(.pro)
                }
            }
        }
    }

    // MARK: Header

    private func profileHeader(_ client: Client) -> some View {
        HStack(spacing: Space.l) {
            Avatar(name: client.fullName, seed: client.seed, size: 72)
            VStack(alignment: .leading, spacing: 3) {
                Text(client.fullName).font(HDFont.heading).foregroundStyle(Palette.ink)
                Text(client.phone).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                Text("Booking since \(client.joined.monthShort) \(String(client.joined.yearNumber))")
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkFaint)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Settings

    private func settingsCard(_ client: Client) -> some View {
        VStack(spacing: 0) {
            NavRow(symbol: "person", title: "Your details", value: client.firstName) { showDetails = true }
            Hairline()
            NavRow(symbol: "house", title: "Addresses", value: "\(client.addresses.count)") { showAddresses = true }
            Hairline()
            NavRow(symbol: "creditcard", title: "Payment methods", value: client.defaultPayment?.label) { showPayments = true }
            Hairline()
            NavRow(symbol: "bell", title: "Notifications", value: client.notificationsOn ? "On" : "Off") { showNotifications = true }
            Hairline()
            NavRow(symbol: "questionmark.circle", title: "Help") { showHelp = true }
        }
        .card(padding: Space.cardPadding)
    }

    // MARK: Favourites

    private var favouritesCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "Favourites", subtitle: app.favouritePros.isEmpty ? nil : "Tap to book her again")
            if app.favouritePros.isEmpty {
                Text("No favourites yet. Tap Save on a pro you'd book again.")
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.m, alignment: .top)], alignment: .leading, spacing: Space.l) {
                    ForEach(app.favouritePros) { pro in
                        ProMiniTile(pro: pro, line: pro.specialtyLine) { path.append(Route.pro(pro)) }
                    }
                }
            }
        }
        .card()
    }

    // MARK: About

    private var aboutCard: some View {
        VStack(spacing: 0) {
            NavRow(symbol: "doc.text", title: "Terms and privacy") { showLegal = true }
            Hairline()
            HStack {
                Text("Hair Done \(version)").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                Spacer()
            }
            .frame(minHeight: 44)
        }
        .card()
    }

    // MARK: Pro mode

    private var proModeCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                DropMark(size: 22)
                Text("Pro mode").font(HDFont.heading).foregroundStyle(Palette.ink)
            }
            Text("For hair stylists, nail techs, makeup artists, lash and brow artists.")
                .font(HDFont.sub)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if app.proSelf != nil {
                SecondaryButton(title: "Switch to Pro mode", symbol: "arrow.left.arrow.right") { app.switchMode(.pro) }
            } else {
                SecondaryButton(title: "Set up Pro mode", symbol: "sparkles") { showProOnboarding = true }
            }
        }
        .padding(Space.cardPadding)
        .background(Palette.lacquerSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.lacquer.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Your details

/// First name, last name, email, mobile.
struct AccountDetailsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var first = ""
    @State private var last = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var saving = false

    private var canSave: Bool { !first.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Your details", onClose: { dismiss() })
            ScrollView {
                VStack(spacing: Space.l) {
                    HStack(spacing: Space.m) {
                        HDTextField(label: "First name", text: $first, contentType: .givenName)
                        HDTextField(label: "Last name", text: $last, contentType: .familyName)
                    }
                    HDTextField(label: "Mobile", text: $phone, keyboard: .phonePad, contentType: .telephoneNumber)
                    VStack(alignment: .leading, spacing: 6) {
                        HDTextField(label: "Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress)
                        Text("Receipts go here.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
            PrimaryButton(title: "Save", isLoading: saving, isEnabled: canSave) { save() }
                .screenGutter()
                .padding(.bottom, Space.l)
        }
        .paperBackground()
        .onAppear {
            guard let c = app.client else { return }
            first = c.firstName; last = c.lastName; email = c.email; phone = c.phone
        }
    }

    private func save() {
        guard var c = app.client else { return }
        c.firstName = first.trimmingCharacters(in: .whitespaces)
        c.lastName = last.trimmingCharacters(in: .whitespaces)
        c.email = email.trimmingCharacters(in: .whitespaces)
        c.phone = phone.trimmingCharacters(in: .whitespaces)
        saving = true
        Task {
            try? await app.data.updateClient(c)
            app.client = c
            saving = false
            dismiss()
        }
    }
}

// MARK: - Addresses

/// Where she comes to. Add, edit, swipe to delete.
struct AccountAddressesSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Address? = nil
    @State private var adding = false

    private var addresses: [Address] { app.client?.addresses ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Addresses", subtitle: addresses.isEmpty ? nil : "First one's your default.", onClose: { dismiss() })
            if addresses.isEmpty {
                EmptyState(symbol: "house", title: "No saved addresses.", message: "Add one and booking's two taps quicker.")
                Spacer()
            } else {
                List {
                    ForEach(addresses) { address in
                        Button { editing = address } label: {
                            HStack(alignment: .top, spacing: Space.m) {
                                Image(systemName: address.label.lowercased() == "work" ? "building.2" : "house")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(address.label).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                                        if address.id == addresses.first?.id { Tag(text: "Default") }
                                    }
                                    Text(address.full).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                                    if !address.instructions.isEmpty {
                                        Text(address.instructions).font(HDFont.caption).foregroundStyle(Palette.inkFaint).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.card)
                        .listRowSeparatorTint(Palette.line)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Edits this address")
                    }
                    .onDelete { offsets in remove(at: offsets) }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            SecondaryButton(title: "Add an address", symbol: "plus") { adding = true }
                .screenGutter()
                .padding(.bottom, Space.l)
        }
        .paperBackground()
        .sheet(item: $editing) { address in
            AddressEditor(address: address) { saved in upsert(saved); editing = nil }
        }
        .sheet(isPresented: $adding) {
            AddressEditor(address: nil) { saved in upsert(saved); adding = false }
        }
    }

    private func upsert(_ address: Address) {
        guard var c = app.client else { return }
        if let i = c.addresses.firstIndex(where: { $0.id == address.id }) { c.addresses[i] = address } else { c.addresses.append(address) }
        app.client = c
        Task { try? await app.data.updateClient(c) }
    }

    private func remove(at offsets: IndexSet) {
        guard var c = app.client else { return }
        c.addresses.remove(atOffsets: offsets)
        Haptics.light()
        app.client = c
        Task { try? await app.data.updateClient(c) }
    }
}

// MARK: - Payment methods

/// Cards and Apple Pay. One's the default.
struct AccountPaymentsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var removing: PaymentMethod? = nil

    private var methods: [PaymentMethod] { app.client?.paymentMethods ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Payment methods", subtitle: "We hold the amount when you book and charge it when she's done.", onClose: { dismiss() })
            if methods.isEmpty {
                EmptyState(symbol: "creditcard", title: "No cards yet.", message: "Apple Pay works without one.")
                Spacer()
            } else {
                List {
                    ForEach(methods) { method in
                        HStack(spacing: Space.m) {
                            Image(systemName: method.kind == .applePay ? "apple.logo" : "creditcard")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(method.label).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                                if method.kind == .card, !method.expiry.isEmpty {
                                    Text("Expires \(method.expiry)").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                                }
                            }
                            Spacer(minLength: 0)
                            if method.isDefault {
                                Tag(text: "Default", color: Palette.success, background: Palette.successSoft)
                            } else {
                                Button { makeDefault(method) } label: {
                                    Text("Make default").font(HDFont.subStrong).foregroundStyle(Palette.lacquer)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Palette.card)
                        .listRowSeparatorTint(Palette.line)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if method.kind == .card {
                                Button(role: .destructive) { removing = method } label: { Label("Remove", systemImage: "trash") }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(method.label)\(method.isDefault ? ", default" : "")")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            SecondaryButton(title: "Add a card", symbol: "plus") { adding = true }
                .screenGutter()
                .padding(.bottom, Space.l)
        }
        .paperBackground()
        .sheet(isPresented: $adding) {
            AddCardSheet { added in
                guard var c = app.client else { return }
                var new = added
                if c.paymentMethods.isEmpty { new.isDefault = true }
                c.paymentMethods.append(new)
                app.client = c
                Task { try? await app.data.updateClient(c) }
                adding = false
            }
        }
        .confirmationDialog(
            "Remove \(removing?.brand ?? "card") ending \(removing?.last4 ?? "")?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { if let m = removing { remove(m) } }
            Button("Cancel", role: .cancel) { removing = nil }
        }
    }

    private func makeDefault(_ method: PaymentMethod) {
        guard var c = app.client else { return }
        for i in c.paymentMethods.indices { c.paymentMethods[i].isDefault = c.paymentMethods[i].id == method.id }
        Haptics.light()
        app.client = c
        Task { try? await app.data.updateClient(c) }
    }

    private func remove(_ method: PaymentMethod) {
        guard var c = app.client else { return }
        c.paymentMethods.removeAll { $0.id == method.id }
        if method.isDefault, !c.paymentMethods.isEmpty { c.paymentMethods[0].isDefault = true }
        app.client = c
        removing = nil
        Task { try? await app.data.updateClient(c) }
    }
}

// MARK: - Notifications

/// What we'll tell you about. Booking updates stay on; they're the useful ones.
struct AccountNotificationsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notify.messages") private var messages = true
    @AppStorage("notify.reminders") private var reminders = true
    @AppStorage("notify.whosFree") private var whosFree = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Notifications", onClose: { dismiss() })
            ScrollView {
                VStack(spacing: 0) {
                    toggleRow("Booking updates", sub: "Can't turn these off, sorry. They're the useful ones.", isOn: .constant(true), locked: true)
                    Hairline()
                    toggleRow("Messages", isOn: $messages)
                    Hairline()
                    toggleRow("Day-before reminders", isOn: $reminders)
                    Hairline()
                    toggleRow("Who's free near you", sub: "Now and then. Never before 9 am.", isOn: $whosFree)
                }
                .card()
                .screenGutter()
                .padding(.top, Space.s)
            }
        }
        .paperBackground()
        .onChange(of: messages) { _, _ in syncMaster() }
        .onChange(of: reminders) { _, _ in syncMaster() }
        .onChange(of: whosFree) { _, _ in syncMaster() }
    }

    private func toggleRow(_ title: String, sub: String? = nil, isOn: Binding<Bool>, locked: Bool = false) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HDFont.body).foregroundStyle(Palette.ink)
                if let sub { Text(sub).font(HDFont.caption).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true) }
            }
        }
        .tint(Palette.lacquer)
        .disabled(locked)
        .padding(.vertical, Space.m)
        .onChange(of: isOn.wrappedValue) { _, _ in Haptics.selection() }
    }

    /// `client.notificationsOn` mirrors the optional ones: on if any of them is.
    private func syncMaster() {
        guard var c = app.client else { return }
        let on = messages || reminders || whosFree
        guard c.notificationsOn != on else { return }
        c.notificationsOn = on
        app.client = c
        Task { try? await app.data.updateClient(c) }
    }
}

// MARK: - Help

/// A few answers, and a person if they're not enough.
struct AccountHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var open: Set<String> = []

    private let faqs: [(String, String)] = [
        ("How holds and charges work", "When you book, we hold the total on your card. Nothing's taken until she marks the booking done, then it's charged and the receipt lands in your inbox. If the booking doesn't happen, the hold drops off in a few days."),
        ("Cancelling and rescheduling", "Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. Rescheduling with more than 24 hours' notice is free too; inside that, it counts as a cancel."),
        ("What if she's late", "She'll message you from the thread if she's running behind. If she's more than 20 minutes late with no word, message us from here and a person will sort it, usually the same day."),
        ("Safety", "Every pro has had her ID checked before she's listed, and reviews only come from finished, paid bookings. Phone numbers stay hidden until she's confirmed. If anything feels off, report the pro from her profile or the conversation and we'll look at it."),
        ("Reporting a pro", "Open her profile or the conversation and tap Report. Tell us what happened in a line or two. A person reads every one."),
        ("Deleting your account", "Message us from here and say you'd like your account gone. Profile, addresses and cards go. Past receipts stay in your email. It can't be undone.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Help", subtitle: "A person replies, usually the same day.", onClose: { dismiss() })
            ScrollView {
                VStack(spacing: Space.l) {
                    VStack(spacing: 0) {
                        ForEach(Array(faqs.enumerated()), id: \.offset) { i, faq in
                            faqRow(faq.0, answer: faq.1)
                            if i < faqs.count - 1 { Hairline() }
                        }
                    }
                    .card()
                    SecondaryButton(title: "Message us", symbol: "bubble.left") {
                        if let url = URL(string: "mailto:hello@hairdone.app?subject=Help") { UIApplication.shared.open(url) }
                    }
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
        }
        .paperBackground()
    }

    private func faqRow(_ title: String, answer: String) -> some View {
        let isOpen = open.contains(title)
        return VStack(alignment: .leading, spacing: Space.s) {
            Button {
                Haptics.light()
                withAnimation(Motion.spring) {
                    if isOpen { open.remove(title) } else { open.insert(title) }
                }
            } label: {
                HStack {
                    Text(title).font(HDFont.body).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.inkFaint)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint(isOpen ? "Hides the answer" : "Shows the answer")
            if isOpen {
                Text(answer)
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.m)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Terms and privacy

struct AccountLegalSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Terms and privacy", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text("The short version").font(HDFont.heading).foregroundStyle(Palette.ink)
                    Text("Hair Done connects you with a mobile pro and takes payment for the booking. The pro is her own business; the work is hers, the booking terms are ours. We charge you what's on the review screen and nothing else.")
                        .font(HDFont.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    Text("Your data").font(HDFont.heading).foregroundStyle(Palette.ink)
                    Text("We keep your name, mobile, email, addresses and bookings so the app works. Your address goes to a pro only once she's confirmed. Your card details go to Stripe, not to us. Location is used only while you're in the app, to show who's near.")
                        .font(HDFont.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    Text("The full terms and privacy policy are on hairdone.app. Questions go to Help.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
        }
        .paperBackground()
    }
}

#Preview("You") {
    AccountView().environment(previewApp())
}

#Preview("Addresses") {
    AccountAddressesSheet().environment(previewApp())
}

#Preview("Payment methods") {
    AccountPaymentsSheet().environment(previewApp())
}
