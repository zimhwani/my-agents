import SwiftUI
import PhotosUI

/// Everything a client sees about her, editable. Pushed from the gear on Today.
struct ProProfileEditView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Pro? = nil
    @State private var feeText = ""
    @State private var editingService: Service? = nil
    @State private var addingService = false
    @State private var photoPick: [PhotosPickerItem] = []
    @State private var saving = false

    private var isDirty: Bool {
        guard let draft, let saved = app.proSelf else { return false }
        return !same(draft, saved)
    }

    var body: some View {
        Group {
            if let binding = Binding($draft) {
                form(binding)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .paperBackground()
        .navigationTitle("Your profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .onAppear {
            if draft == nil, let p = app.proSelf {
                draft = p
                feeText = ProMoney.dollarsText(p.travelFeeCents)
            }
        }
        .sheet(isPresented: $addingService) {
            ServiceEditorSheet(categories: draft?.specialties ?? []) { s in
                withAnimation(Motion.spring) { draft?.services.append(s) }
            }
        }
        .sheet(item: $editingService) { s in
            ServiceEditorSheet(existing: s, categories: draft?.specialties ?? []) { updated in
                if let i = draft?.services.firstIndex(where: { $0.id == s.id }) { draft?.services[i] = updated }
            }
        }
    }

    private func form(_ pro: Binding<Pro>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                // Photo and name
                card("Profile photo") {
                    HStack(spacing: Space.l) {
                        Avatar(name: pro.wrappedValue.firstName, seed: pro.wrappedValue.seed, size: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("A clear one of your face, natural light.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                            AddPhotosButton(selection: $photoPick, title: "Change photo", maxCount: 1, quiet: true)
                        }
                    }
                    .onChange(of: photoPick) { _, new in
                        guard !new.isEmpty else { return }
                        pro.wrappedValue.seed = Int.random(in: 1...9_999)
                        photoPick = []
                        app.show("Photo updated. Save to keep it.")
                    }
                    HStack(spacing: Space.s) {
                        HDTextField(label: "First name", placeholder: "Kiara", text: pro.firstName, contentType: .givenName)
                        HDTextField(label: "Last initial", placeholder: "M", text: Binding(
                            get: { pro.wrappedValue.lastInitial },
                            set: { pro.wrappedValue.lastInitial = String($0.prefix(1)).uppercased() }
                        ))
                        .frame(width: 96)
                    }
                    NavigationLink(value: Route.pro(pro.wrappedValue)) {
                        HStack(spacing: 6) {
                            Text("See it as a client").font(HDFont.subStrong).foregroundStyle(Palette.lacquer)
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.lacquer)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }

                // Words
                card("About you") {
                    HDTextField(label: "Headline", placeholder: "Nails, done properly, at your kitchen table.", text: pro.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        HDTextField(label: "Bio", placeholder: "A few lines in your own words. How long you've been doing this, what you're known for. Emoji are fine here.",
                                    text: Binding(get: { pro.wrappedValue.bio }, set: { pro.wrappedValue.bio = String($0.prefix(300)) }), axis: .vertical)
                        Text("\(pro.wrappedValue.bio.count)/300").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                // Specialties
                card("Specialty") {
                    Text("Pick everything you do. The first one's your main label.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    FlowChips(categories: Category.allCases, selected: pro.specialties)
                }

                // Services
                card("Services and prices") {
                    Text("Your price is what she sees. Our 12% comes out of your side, and she pays a $3 booking fee on top.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    if pro.wrappedValue.services.isEmpty {
                        Text("Nothing yet. Your top three is enough to start.").font(HDFont.sub).foregroundStyle(Palette.inkSoft).padding(.vertical, Space.s)
                    }
                    ForEach(pro.wrappedValue.services) { s in
                        ServiceEditRow(service: s, onEdit: { editingService = s }, onRemove: {
                            withAnimation(Motion.spring) { pro.wrappedValue.services.removeAll { $0.id == s.id } }
                        })
                        if s.id != pro.wrappedValue.services.last?.id { Hairline() }
                    }
                    SecondaryButton(title: "Add a service", symbol: "plus") { addingService = true }
                }

                // Travel
                card("Where you'll go") {
                    HDTextField(label: "Your base", placeholder: "Suburb or postcode", text: pro.suburb)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("How far you'll go").font(HDFont.subStrong).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("\(Int(pro.wrappedValue.travelRadiusKm)) km").font(HDFont.price).foregroundStyle(Palette.ink)
                        }
                        Slider(value: pro.travelRadiusKm, in: 2...25, step: 1)
                            .tint(Palette.lacquer)
                            .accessibilityLabel("How far you'll go")
                            .accessibilityValue("\(Int(pro.wrappedValue.travelRadiusKm)) kilometres")
                        Text("From \(pro.wrappedValue.suburb.isEmpty ? "your base" : pro.wrappedValue.suburb). Clients outside this won't see you.")
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HDTextField(label: "Travel fee", placeholder: "15", text: $feeText, keyboard: .decimalPad)
                            .onChange(of: feeText) { _, new in pro.wrappedValue.travelFeeCents = ProMoney.dollars(new) }
                        Text("Flat, per booking, shown on your profile. $0 is fine.").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    }
                }

                // Instant book
                card("Instant book") {
                    Toggle(isOn: pro.instantBook) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Instant book").font(HDFont.body).foregroundStyle(Palette.ink)
                            Text("On, and clients book your open slots without asking. Off, and you accept each one.")
                                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .tint(Palette.lacquer)
                }

                // ID and ABN
                card("ID and ABN") {
                    HStack(spacing: Space.m) {
                        Image(systemName: pro.wrappedValue.isVerified ? "checkmark.seal.fill" : "person.text.rectangle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(pro.wrappedValue.isVerified ? Palette.success : Palette.inkSoft)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pro.wrappedValue.isVerified ? "ID checked" : "ID not checked yet").font(HDFont.body).foregroundStyle(Palette.ink)
                            Text(pro.wrappedValue.isVerified ? "The badge is on your profile." : "Once, and you get the badge. Clients look for it.")
                                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        if pro.wrappedValue.isVerified { VerifiedBadge() }
                    }
                    .accessibilityElement(children: .combine)
                    HDTextField(label: "ABN", placeholder: "11 digits", text: pro.abn, keyboard: .numberPad)
                    if !pro.wrappedValue.abn.isEmpty && pro.wrappedValue.abn.filter(\.isNumber).count != 11 {
                        Text("An ABN is 11 digits. Have another look.").font(HDFont.caption).foregroundStyle(Palette.warn)
                    }
                }

                // Taking bookings
                card("Taking bookings") {
                    Toggle(isOn: pro.isActive) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pro.wrappedValue.isActive ? "Taking bookings" : "Paused").font(HDFont.body).foregroundStyle(Palette.ink)
                            Text(pro.wrappedValue.isActive ? "You're in searches and can be booked." : "Hidden from searches. Bookings you already have still stand.")
                                .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .tint(Palette.lacquer)
                    if pro.wrappedValue.reliabilityScore < 1 {
                        Hairline()
                        HStack {
                            Text("Reliability").font(HDFont.body).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("\(Int((pro.wrappedValue.reliabilityScore * 100).rounded()))% of bookings kept").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                PrimaryButton(title: "Save", isLoading: saving, isEnabled: isDirty && canSave(pro.wrappedValue)) { Task { await save(pro.wrappedValue) } }
                if !canSave(pro.wrappedValue) {
                    Text("A first name, one specialty and one service, and you're set.")
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(title).font(HDFont.heading).foregroundStyle(Palette.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func canSave(_ p: Pro) -> Bool {
        !p.firstName.trimmingCharacters(in: .whitespaces).isEmpty && !p.specialties.isEmpty && !p.services.isEmpty
            && (p.abn.isEmpty || p.abn.filter(\.isNumber).count == 11)
    }

    /// `Pro ==` only compares ids, so compare the fields she can edit here.
    private func same(_ a: Pro, _ b: Pro) -> Bool {
        a.firstName == b.firstName && a.lastInitial == b.lastInitial && a.headline == b.headline && a.bio == b.bio
            && a.specialties == b.specialties && a.services == b.services && a.suburb == b.suburb
            && a.travelRadiusKm == b.travelRadiusKm && a.travelFeeCents == b.travelFeeCents && a.instantBook == b.instantBook
            && a.abn == b.abn && a.isActive == b.isActive && a.seed == b.seed
    }

    private func save(_ p: Pro) async {
        saving = true
        defer { saving = false }
        var cleaned = p
        cleaned.firstName = p.firstName.trimmingCharacters(in: .whitespaces)
        cleaned.suburb = p.suburb.trimmingCharacters(in: .whitespaces)
        await app.saveProSelf(cleaned)
        Haptics.success()
        app.show("Saved.")
        dismiss()
    }
}

/// Wrapping multi-select chips for categories. Keeps the order she tapped them in, so the first is her main label.
struct FlowChips: View {
    var categories: [Category]
    @Binding var selected: [Category]

    var body: some View {
        let rows = [Array(categories.prefix(3)), Array(categories.dropFirst(3))]
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: Space.s) {
                    ForEach(rows[r]) { c in
                        Chip(title: c.label, symbol: c.symbol, isSelected: selected.contains(c), tint: c.tint) {
                            withAnimation(Motion.spring) {
                                if let i = selected.firstIndex(of: c) { selected.remove(at: i) } else { selected.append(c) }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("Profile edit") {
    NavigationStack { ProProfileEditView().hdDestinations() }
        .environment(previewApp(mode: .pro))
}
