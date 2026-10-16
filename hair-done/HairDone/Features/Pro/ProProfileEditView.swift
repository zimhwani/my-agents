import SwiftUI
import PhotosUI

/// Which part of Profile edit to open at.
enum ProEditSection: String, Hashable {
    case services, travel, id
}

/// Everything a client sees about her, editable, led by what they see first: her cover with her
/// name on it. Save is the ink bar that slides up once something's changed; Back asks first.
struct ProProfileEditView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var focus: ProEditSection? = nil

    @State private var draft: Pro? = nil
    @State private var feeText = ""
    @State private var editingService: Service? = nil
    @State private var addingService = false
    @State private var saving = false
    @State private var failed = false
    @State private var confirmLeave = false
    @State private var showIDCheck = false

    @State private var coverPick: PhotosPickerItem? = nil
    @State private var coverUpload: UploadState? = nil
    @State private var coverImage: UIImage? = nil
    @State private var facePick: PhotosPickerItem? = nil
    @State private var faceUpload: UploadState? = nil
    @State private var faceImage: UIImage? = nil
    @State private var faceJPEG: Data? = nil
    @Environment(\.dynamicTypeSize) private var typeSize

    private let unsavedID = "profile.edit"
    /// Debug probe (`-hdProbe YES`): changes if this screen is rebuilt from scratch; how many times
    /// the draft's radius changed; how many times the body ran.
    @State private var probeID = String(UUID().uuidString.prefix(4))
    @State private var probeChanges = 0

    private var isDirty: Bool {
        guard let draft, let saved = app.proSelf else { return false }
        return !same(draft, saved)
    }

    var body: some View {
        let _ = ProbeCount.bump("edit")
        Group {
            if let current = draft {
                // Straight off the state's own binding through a key path, so every field reads and
                // writes `draft` where it lives. `Binding($draft)` (and a get/set closure after it)
                // left the km boxes, How far and Instant book not reaching `draft` on iOS 26.
                form($draft[orElse: current])
            } else {
                ListSkeleton(rows: 3).padding(.top, Space.xl)
            }
        }
        .paperBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        .animation(Motion.spring, value: isDirty)
        .hdNavHeader("Your profile", onBack: back) { EmptyView() }
        .onAppear {
            if draft == nil, let p = app.proSelf {
                draft = p
                feeText = ProMoney.dollarsText(p.travelFeeCents)
            }
            // Back from "See it as a client" with edits still here.
            register()
        }
        .onChange(of: isDirty) { _, _ in register() }
        .onChange(of: draft?.travelRadiusKm) { _, _ in probeChanges += 1 }
        .onDisappear { ProUnsavedWork.shared.clear(unsavedID) }
        .sheet(isPresented: $addingService) {
            ServiceEditorSheet(categories: draft?.specialties ?? []) { s in
                withAnimation(Motion.spring) { draft?.services.append(s) }
            }
        }
        .sheet(item: $editingService) { s in
            ServiceEditorSheet(existing: s, categories: draft?.specialties ?? [], onRemove: {
                withAnimation(Motion.spring) { draft?.services.removeAll { $0.id == s.id } }
            }) { updated in
                if let i = draft?.services.firstIndex(where: { $0.id == s.id }) { draft?.services[i] = updated }
            }
        }
        .sheet(isPresented: $showIDCheck) { ProIDCheckSheet() }
        .confirmSheet(isPresented: $confirmLeave, title: "Leave without saving?",
                      message: "Your changes here go.", confirmTitle: "Leave", cancelTitle: "Keep editing") {
            discard()
            dismiss()
        }
        .onChange(of: coverPick) { _, item in
            guard let item else { return }
            coverPick = nil
            Task { await changeCover(item) }
        }
        .onChange(of: facePick) { _, item in
            guard let item else { return }
            facePick = nil
            Task {
                guard let image = await PhotoData.image(from: item), let jpeg = PhotoData.jpeg(from: image) else { return }
                faceImage = image
                faceJPEG = jpeg
                await uploadFace()
            }
        }
    }

    /// Tells a switch to booking there's something unsaved here.
    private func register() {
        ProUnsavedWork.shared.update(unsavedID, dirty: isDirty, save: {
            guard let d = draft else { return false }
            return await save(d)
        }, discard: { discard() })
    }

    private var canTapSave: Bool { isDirty && !app.isOffline && (draft.map(canSave) ?? false) }

    /// The ink bar, once something's changed.
    @ViewBuilder
    private var saveBar: some View {
        if isDirty {
            VStack(alignment: .leading, spacing: Space.s) {
                if app.isOffline {
                    Text("You're offline. Save when you're back.").font(HDFont.caption).foregroundStyle(Palette.onInkSoft)
                }
                HStack(spacing: Space.s) {
                    InkButton(title: "Save", isLoading: saving, isEnabled: canTapSave, tone: .onInk) {
                        Task { if let d = draft, await save(d) { dismiss() } }
                    }
                    OutlineButton(title: "Discard", tone: .onInk) { discard() }
                        .frame(maxWidth: 140)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)
            .background(Palette.inkGround.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Palette.inkEdge).frame(height: 0.5) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func back() {
        if isDirty { confirmLeave = true } else { dismiss() }
    }

    // MARK: Form

    private func form(_ pro: Binding<Pro>) -> some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if app.isOffline { OfflineBar() }
                    cover(pro.wrappedValue)
                    VStack(alignment: .leading, spacing: Space.section) {
                        if failed { FieldMessage(text: "Didn't save. Your changes are still here. Try again.") }
                        if !canSave(pro.wrappedValue) {
                            FieldMessage(text: "A first name, one specialty and one service, and you're set.")
                        }
                        nameSection(pro)
                        faceSection(pro.wrappedValue)
                        aboutSection(pro)
                        specialtySection(pro)
                        servicesSection(pro).id(ProEditSection.services)
                        travelSection(pro).id(ProEditSection.travel)
                        if DebugSwitch.on("hdProbe") {
                            Text("probe screen=\(probeID) draft=\(Int(pro.wrappedValue.travelRadiusKm)) instant=\(pro.wrappedValue.instantBook) dirty=\(isDirty) changes=\(probeChanges) bodies=\(ProbeCount.value("edit"))")
                                .font(.caption2).accessibilityIdentifier("probe-edit")
                        }
                        section("Instant book") {
                            HDSwitch(title: "Instant book", subtitle: "On, and clients book your open slots without asking. Off, and you accept each one.", isOn: pro.instantBook)
                        }
                        idSection(pro).id(ProEditSection.id)
                    }
                    .screenGutter()
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.section)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                guard let focus else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(Motion.gentle) { reader.scrollTo(focus, anchor: .top) }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(title).labelStyle().accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Cover

    private func cover(_ pro: Pro) -> some View {
        ZStack(alignment: .bottomLeading) {
            Palette.photoGround
            if let coverImage {
                Image(uiImage: coverImage).resizable().scaledToFill()
            } else if let item = pro.proCoverItem {
                WorkTile(item: item, cornerRadius: 0)
            }
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            HStack(alignment: .lastTextBaseline) {
                Text(pro.firstName.isEmpty ? "Your name" : pro.displayName)
                    .font(HDFont.heroName)
                    .foregroundStyle(Palette.onPhoto)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: Space.s)
                PhotosPicker(selection: $coverPick, matching: .images) {
                    Text(coverUpload == nil ? "Change cover" : "Uploading")
                        .font(HDFont.subMedium).foregroundStyle(Palette.onPhoto)
                        .underline()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(app.isOffline || coverUpload != nil)
                .accessibilityLabel("Change cover")
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
            if case .uploading(let p) = coverUpload {
                GeometryReader { proxy in
                    Rectangle().fill(Palette.onPhoto).frame(width: proxy.size.width * CGFloat(p), height: 2)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .aspectRatio(4 / 5, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .contain)
    }

    private func changeCover(_ item: PhotosPickerItem) async {
        guard let image = await PhotoData.image(from: item), let jpeg = PhotoData.jpeg(from: image) else { return }
        coverImage = image
        withAnimation(Motion.gentle) { coverUpload = .uploading(0.4) }
        guard let url = await app.uploadWorkPhoto(jpeg) else {
            withAnimation(Motion.gentle) { coverUpload = nil; coverImage = nil }
            return
        }
        withAnimation(Motion.gentle) { coverUpload = nil }
        guard var d = draft else { return }
        let fresh = WorkItem(id: UUID().uuidString.lowercased(), category: d.primaryCategory, caption: "", seed: Int.random(in: 1...9_999), imageURL: url, isPinned: true)
        // Pinned and first, so it's the cover. Four pins at most: the oldest pin steps down.
        let pinned = d.work.filter(\.isPinned)
        if pinned.count >= 4, let last = pinned.last, let i = d.work.firstIndex(where: { $0.id == last.id }) {
            d.work[i].isPinned = false
        }
        d.work.insert(fresh, at: 0)
        draft = d
        app.show("New cover. Save to keep it.")
    }

    // MARK: Sections

    private func nameSection(_ pro: Binding<Pro>) -> some View {
        // Side by side; one under the other at the accessibility sizes, where "Last initial" won't fit.
        let fields = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.l))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Space.l))
        return section("Name") {
            fields {
                HDTextField(label: "First name", placeholder: "Kiara", text: pro.firstName, contentType: .givenName,
                            caption: "This is your name on both sides.")
                HDTextField(label: "Last initial", placeholder: "M", text: Binding(
                    get: { pro.wrappedValue.lastInitial },
                    set: { pro.wrappedValue.lastInitial = String($0.prefix(1)).uppercased() }
                ))
                .frame(minWidth: 80, maxWidth: typeSize.isAccessibilitySize ? CGFloat.infinity : 110)
            }
            NavigationLink(value: Route.pro(pro.wrappedValue)) {
                HStack(spacing: 6) {
                    Text("See it as a client")
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .regular))
                }
                .font(HDFont.subMedium)
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func faceSection(_ pro: Pro) -> some View {
        section("Your photo") {
            HStack(alignment: .center, spacing: Space.l) {
                if let faceImage, let state = faceUpload {
                    UploadTile(image: faceImage, state: state, size: CGSize(width: 72, height: 90), onRetry: { Task { await uploadFace() } })
                } else {
                    ProFacePhoto(pro: pro).frame(width: 72, height: 90)
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("A clear one of your face, in natural light. Clients see it in their messages.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    PhotosPicker(selection: $facePick, matching: .images) {
                        Text(pro.avatarURL == nil ? "Add a photo" : "Change photo")
                            .font(HDFont.subMedium).foregroundStyle(Palette.ink)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(app.isOffline || faceUpload == .uploading(0.5))
                }
            }
        }
    }

    private func uploadFace() async {
        guard let jpeg = faceJPEG else { return }
        withAnimation(Motion.gentle) { faceUpload = .uploading(0.5) }
        if await app.uploadAvatar(jpeg) != nil {
            withAnimation(Motion.gentle) { faceUpload = .done }
            app.show("Photo saved.")
        } else {
            withAnimation(Motion.gentle) { faceUpload = .failed }
        }
    }

    private func aboutSection(_ pro: Binding<Pro>) -> some View {
        section("About you") {
            HDTextField(label: "Headline", placeholder: "Nails, done properly, at your kitchen table.", text: pro.headline)
            HDTextField(label: "Bio", placeholder: "A few lines in your own words. How long you've been doing this, what you're known for. Emoji are fine here.",
                        text: Binding(get: { pro.wrappedValue.bio }, set: { pro.wrappedValue.bio = String($0.prefix(300)) }),
                        axis: .vertical, caption: "\(pro.wrappedValue.bio.count)/300")
        }
    }

    private func specialtySection(_ pro: Binding<Pro>) -> some View {
        section("Specialty") {
            Text("Pick everything you do. The first one's your main label.")
                .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            ProFlowLayout {
                ForEach(Category.allCases) { c in
                    OptionBox(title: c.label, isSelected: pro.wrappedValue.specialties.contains(c)) {
                        withAnimation(Motion.spring) {
                            if let i = pro.wrappedValue.specialties.firstIndex(of: c) {
                                pro.wrappedValue.specialties.remove(at: i)
                            } else {
                                pro.wrappedValue.specialties.append(c)
                            }
                        }
                    }
                }
            }
            if let main = pro.wrappedValue.specialties.first {
                Text("Main label: \(main.specialtyTitle)").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func servicesSection(_ pro: Binding<Pro>) -> some View {
        section("Services and prices") {
            Text("Your price is what she sees. Hair Done's 12% comes out of your side, and she pays a $3 booking fee on top.")
                .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                if pro.wrappedValue.services.isEmpty {
                    Text("Nothing yet. Your top three is enough to start.").font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Space.s)
                }
                ForEach(pro.wrappedValue.services) { s in
                    ServiceEditRow(service: s) { editingService = s }
                }
            }
            OutlineButton(title: "Add a service", symbol: "plus", compact: true) { addingService = true }
        }
    }

    private func travelSection(_ pro: Binding<Pro>) -> some View {
        section("Where you'll go") {
            ProTravelArea(base: pro.suburb, latitude: pro.latitude, longitude: pro.longitude, radiusKm: pro.travelRadiusKm)
            HDTextField(label: "Travel fee", placeholder: "15", text: $feeText, keyboard: .decimalPad,
                        caption: "Flat, per booking, shown on your profile. $0 is fine.")
                .onChange(of: feeText) { _, new in pro.wrappedValue.travelFeeCents = ProMoney.dollars(new) }
        }
    }

    private func idSection(_ pro: Binding<Pro>) -> some View {
        let abnDigits = pro.wrappedValue.abn.filter(\.isNumber)
        return section("ID and ABN") {
            if pro.wrappedValue.isVerified {
                VerifiedBadge()
                Text("A person at Hair Done has checked it. The badge is on your profile.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            } else if app.proSelf?.idSubmitted == true {
                Text("Sent. Someone from Hair Done checks it by hand, usually within a day.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not sent yet. Clients only book pros a person has checked.")
                    .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                TertiaryButton(title: "Add photo ID and a selfie", tint: Palette.ink) { showIDCheck = true }
                    .padding(.leading, -8)
            }
            HDTextField(label: "ABN", placeholder: "11 digits", text: pro.abn, keyboard: .numberPad,
                        caption: "Sole trader is fine.",
                        error: !abnDigits.isEmpty && abnDigits.count != 11 ? "An ABN is 11 digits. Have another look." : nil)
        }
    }

    // MARK: Saving

    private func canSave(_ p: Pro) -> Bool {
        !p.firstName.trimmingCharacters(in: .whitespaces).isEmpty && !p.specialties.isEmpty && !p.services.isEmpty
            && (p.abn.isEmpty || p.abn.filter(\.isNumber).count == 11)
    }

    /// `Pro ==` only compares ids, so compare the fields she can edit here.
    private func same(_ a: Pro, _ b: Pro) -> Bool {
        a.firstName == b.firstName && a.lastInitial == b.lastInitial && a.headline == b.headline && a.bio == b.bio
            && a.specialties == b.specialties && a.services == b.services && a.suburb == b.suburb
            && a.latitude == b.latitude && a.longitude == b.longitude
            && a.travelRadiusKm == b.travelRadiusKm && a.travelFeeCents == b.travelFeeCents && a.instantBook == b.instantBook
            && a.abn == b.abn && a.work == b.work
    }

    private func discard() {
        if let p = app.proSelf {
            draft = p
            feeText = ProMoney.dollarsText(p.travelFeeCents)
        }
        coverImage = nil
        failed = false
        ProUnsavedWork.shared.clear(unsavedID)
    }

    /// True only when it saved. On a failure the edits stay and the line at the top says so.
    @MainActor
    private func save(_ d: Pro) async -> Bool {
        guard var p = app.proSelf, canSave(d) else { return false }
        saving = true
        defer { saving = false }
        failed = false
        // Only what this screen edits; anything changed elsewhere meanwhile (photo, pause, payouts) stands.
        p.firstName = d.firstName.trimmingCharacters(in: .whitespaces)
        p.lastInitial = d.lastInitial
        p.headline = d.headline
        p.bio = d.bio
        p.specialties = d.specialties
        p.services = d.services
        p.suburb = d.suburb.trimmingCharacters(in: .whitespaces)
        p.latitude = d.latitude
        p.longitude = d.longitude
        p.travelRadiusKm = d.travelRadiusKm
        p.travelFeeCents = d.travelFeeCents
        p.instantBook = d.instantBook
        p.abn = d.abn.filter(\.isNumber)
        p.work = d.work
        guard await app.saveProSelf(p) else {
            withAnimation(Motion.gentle) { failed = true }
            return false
        }
        Haptics.success()
        app.show("Saved.")
        if let fresh = app.proSelf {
            draft = fresh
            feeText = ProMoney.dollarsText(fresh.travelFeeCents)
        }
        coverImage = nil
        ProUnsavedWork.shared.clear(unsavedID)
        return true
    }
}

#Preview("Profile edit") {
    NavigationStack { ProProfileEditView().hdDestinations() }
        .environment(previewApp(mode: .pro))
}
