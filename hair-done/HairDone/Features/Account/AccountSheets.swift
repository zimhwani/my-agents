import SwiftUI
import PhotosUI
import MessageUI
import UserNotifications

// The sheets behind You: Your details, Addresses, Payment methods, Notifications, Help, Terms.
// Paper, hairline rows, underline fields, ink actions. Nothing says "Saved." unless it saved.

/// "Didn't save. Your changes are still here. Try again."
private let didntSave = "Didn't save. Your changes are still here. Try again."

/// Paper sheet chrome every You sheet shares.
private struct AccountSheetChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .paperBackground()
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.paper)
    }
}

private extension View {
    func accountSheet() -> some View { modifier(AccountSheetChrome()) }
}

// MARK: - Your details

/// Photo, first name, last name, email. The mobile is how she signs in, so it changes through a
/// code sent to the new number, not by typing over it.
struct AccountDetailsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var first = ""
    @State private var last = ""
    @State private var email = ""
    @State private var saving = false
    @State private var problem: String? = nil
    @State private var emailProblem: String? = nil

    // Photo
    @State private var pick: PhotosPickerItem? = nil
    @State private var picked: UIImage? = nil
    @State private var pickedJPEG: Data? = nil
    @State private var photoState: UploadState? = nil

    // Mobile
    enum PhoneStep { case enter, code }
    @State private var phoneStep: PhoneStep? = nil
    @State private var newPhone = ""
    @State private var code = ""
    @State private var phoneWorking = false
    @State private var phoneProblem: String? = nil
    @State private var phoneDone = false

    private var client: Client? { app.client }
    private var dirty: Bool {
        guard let c = client else { return false }
        return first.trimmingCharacters(in: .whitespaces) != c.firstName
            || last.trimmingCharacters(in: .whitespaces) != c.lastName
            || EmailAddress.clean(email) != c.email.lowercased()
    }
    private var isUploading: Bool {
        if case .some(.uploading) = photoState { return true }
        return false
    }
    private var canSave: Bool { !first.trimmingCharacters(in: .whitespaces).isEmpty && dirty && !app.isOffline }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Your details", onClose: { dismiss() })
            if app.isOffline { OfflineBar() }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    photoRow
                    HDTextField(label: "First name", text: $first, contentType: .givenName,
                                caption: app.proSelf != nil ? "It's your name on both sides, booking and Pro mode." : "It's what she'll see when you book.")
                    HDTextField(label: "Last name", text: $last, contentType: .familyName, caption: "Optional")
                    HDTextField(label: "Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress,
                                caption: "Receipts go here.", error: emailProblem)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: email) { _, _ in emailProblem = nil }
                    mobile
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(alignment: .leading, spacing: Space.s) {
                if let problem { FieldMessage(text: problem) }
                InkButton(title: "Save", isLoading: saving, isEnabled: canSave) { save() }
            }
            .screenGutter()
            .padding(.top, Space.s)
            .padding(.bottom, Space.s)
        }
        .accountSheet()
        .presentationDetents([.large])
        .holdsPushRoutes()
        .onAppear {
            guard let c = app.client else { return }
            first = c.firstName; last = c.lastName; email = c.email
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await usePhoto(item) }
        }
    }

    // MARK: Photo

    private var photoRow: some View {
        HStack(spacing: Space.l) {
            ZStack {
                if let picked {
                    Image(uiImage: picked).resizable().scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .opacity(photoState == .failed ? 0.45 : 1)
                } else {
                    Avatar(name: client?.fullName ?? "", seed: client?.seed ?? 0, size: 64, url: client?.avatarURL)
                }
                if isUploading { ProgressView().tint(Palette.ink) }
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if photoState == .failed {
                    Button { retryPhoto() } label: {
                        FieldMessage(text: "Didn't upload. Tap to try again.")
                    }
                    .buttonStyle(.plain)
                } else {
                    PhotosPicker(selection: $pick, matching: .images) {
                        Text(client?.avatarURL == nil && picked == nil ? "Add a photo" : "Change photo")
                            .font(HDFont.subMedium)
                            .foregroundStyle(Palette.ink)
                            .frame(minHeight: 44)
                    }
                    .disabled(app.isOffline || isUploading)
                }
                Text("Optional.")
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
    }

    private func usePhoto(_ item: PhotosPickerItem) async {
        guard let loaded = await AccountPhotoData.load(item) else {
            photoState = .failed
            return
        }
        picked = loaded.image
        pickedJPEG = loaded.jpeg
        await upload()
    }

    private func retryPhoto() {
        Task { await upload() }
    }

    private func upload() async {
        guard let jpeg = pickedJPEG else { photoState = .failed; return }
        photoState = .uploading(0)
        if await app.uploadAvatar(jpeg) != nil {
            photoState = .done
            app.show("Photo saved.")
        } else {
            photoState = .failed
        }
        pick = nil
    }

    // MARK: Mobile

    @ViewBuilder
    private var mobile: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Mobile").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            HStack(alignment: .firstTextBaseline) {
                Text(client?.phone.isEmpty == false ? client!.phone : "None yet")
                    .font(HDFont.body.monospacedDigit())
                    .foregroundStyle(client?.phone.isEmpty == false ? Palette.ink : Palette.inkSoft)
                Spacer()
                if phoneStep == nil {
                    TertiaryButton(title: client?.phone.isEmpty == false ? "Change" : "Add", tint: Palette.ink) {
                        newPhone = ""; code = ""; phoneProblem = nil; phoneDone = false
                        withAnimation(Motion.spring) { phoneStep = .enter }
                    }
                    .disabled(app.isOffline)
                    .padding(.trailing, -8)
                }
            }
            .padding(.vertical, Space.xs)
            .overlay(alignment: .bottom) { Hairline() }
            if phoneDone && phoneStep == nil {
                Text("Saved. That's the number you sign in with now.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            } else if phoneStep == nil {
                Text("It's how you sign in, so a change goes through a code.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            if let step = phoneStep { phoneFlow(step).transition(.opacity) }
        }
    }

    @ViewBuilder
    private func phoneFlow(_ step: PhoneStep) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            switch step {
            case .enter:
                HDTextField(label: "New mobile", placeholder: "04xx xxx xxx", text: $newPhone, keyboard: .phonePad,
                            contentType: .telephoneNumber, caption: "We'll text the new number a code.", error: phoneProblem)
                    .onChange(of: newPhone) { _, new in
                        let formatted = AUPhone.format(new)
                        if formatted != new { newPhone = formatted }
                        phoneProblem = nil
                    }
                InkButton(title: "Text me a code", isLoading: phoneWorking, isEnabled: !newPhone.isEmpty && !app.isOffline, compact: true) {
                    sendPhoneCode()
                }
            case .code:
                HDTextField(label: "Code", placeholder: "6 digits", text: $code, keyboard: .numberPad, contentType: .oneTimeCode,
                            caption: "We sent it to \(AUPhone.display(newPhone)).", error: phoneProblem)
                    .onChange(of: code) { _, new in
                        let d = String(new.filter(\.isNumber).prefix(6))
                        if d != new { code = d }
                        phoneProblem = nil
                    }
                InkButton(title: "Check it", isLoading: phoneWorking, isEnabled: code.count == 6 && !app.isOffline, compact: true) {
                    verifyPhone()
                }
            }
            TertiaryButton(title: "Keep my number") {
                withAnimation(Motion.spring) { phoneStep = nil }
            }
            .padding(.leading, -8)
        }
        .padding(.top, Space.s)
    }

    private func sendPhoneCode() {
        guard AUPhone.isValid(newPhone) else {
            Haptics.warning()
            phoneProblem = "That doesn't look like an Australian mobile."
            return
        }
        phoneWorking = true
        let number = AUPhone.display(newPhone)
        Task { @MainActor in
            let sent = await app.changePhone(to: number)
            phoneWorking = false
            if sent {
                newPhone = number
                withAnimation(Motion.spring) { phoneStep = .code }
            } else {
                phoneProblem = app.lastError ?? "We couldn't text that number. Check it and try again."
            }
        }
    }

    private func verifyPhone() {
        phoneWorking = true
        Task { @MainActor in
            let ok = await app.verifyPhoneChange(code, phone: AUPhone.display(newPhone))
            phoneWorking = false
            if ok {
                Haptics.success()
                phoneDone = true
                withAnimation(Motion.spring) { phoneStep = nil }
            } else {
                Haptics.warning()
                code = ""
                phoneProblem = app.lastError ?? "That code's not right. Have another look."
            }
        }
    }

    // MARK: Save

    private func save() {
        guard var c = app.client else { return }
        let cleanedEmail = EmailAddress.clean(email)
        if !cleanedEmail.isEmpty && !EmailAddress.isValid(cleanedEmail) {
            emailProblem = "That email doesn't look right. Have another look."
            return
        }
        c.firstName = first.trimmingCharacters(in: .whitespaces)
        c.lastName = last.trimmingCharacters(in: .whitespaces)
        c.email = cleanedEmail
        saving = true
        withAnimation(Motion.gentle) { problem = nil }
        Task { @MainActor in
            do {
                try await app.data.updateClient(c)
                app.client = c
                saving = false
                dismiss()
                app.show("Saved.")
            } catch {
                saving = false
                Haptics.warning()
                withAnimation(Motion.gentle) { problem = didntSave }
            }
        }
    }
}

// MARK: - Addresses

/// Where she comes to. The first one's the default. Edit, make default, or remove (with Undo).
struct AccountAddressesSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Address? = nil
    @State private var adding = false
    @State private var undo: (address: Address, index: Int)? = nil
    @State private var undoToken = 0
    @State private var problem: String? = nil

    private var addresses: [Address] { app.client?.addresses ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Addresses", subtitle: addresses.isEmpty ? nil : "First one's your default.", onClose: { dismiss() })
            if app.isOffline { OfflineBar() }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if addresses.isEmpty {
                        EmptyState(title: "No saved addresses.", message: "Add one and booking's two taps quicker.")
                            .padding(.horizontal, -Space.gutter)
                    } else {
                        Hairline(strong: true)
                        ForEach(Array(addresses.enumerated()), id: \.element.id) { i, address in
                            row(address, isDefault: i == 0)
                        }
                    }
                    if let problem { FieldMessage(text: problem).padding(.top, Space.m) }
                    OutlineButton(title: "Add an address", isEnabled: !app.isOffline) { adding = true }
                        .padding(.top, Space.xl)
                }
                .screenGutter()
                .padding(.bottom, Space.section + 60)
            }
        }
        .accountSheet()
        .presentationDetents([.large])
        .overlay(alignment: .bottom) { undoBar }
        .sheet(item: $editing) { address in
            AddressEditor(address: address) { saved in upsert(saved); editing = nil }
        }
        .sheet(isPresented: $adding) {
            AddressEditor(address: nil) { saved in upsert(saved); adding = false }
        }
    }

    private func row(_ address: Address, isDefault: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(address.label.isEmpty ? "Address" : address.label).font(HDFont.body).foregroundStyle(Palette.ink)
                if isDefault { Tag(text: "Default") }
            }
            Text(address.full).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if !address.instructions.isEmpty {
                Text(address.instructions).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Space.s) {
                TertiaryButton(title: "Edit", tint: Palette.ink) { editing = address }
                if !isDefault {
                    TertiaryButton(title: "Make default", tint: Palette.ink) { makeDefault(address) }
                        .disabled(app.isOffline)
                }
                TertiaryButton(title: "Remove") { remove(address) }
                    .disabled(app.isOffline)
            }
            .padding(.leading, -8)
        }
        .padding(.top, Space.m)
        .padding(.bottom, Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(address.label)\(isDefault ? ", default" : ""), \(address.full)")
    }

    @ViewBuilder
    private var undoBar: some View {
        if let undo {
            HStack(spacing: Space.m) {
                Text("Removed. \(undo.address.label.isEmpty ? "Address" : undo.address.label).")
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.paper)
                Spacer(minLength: Space.s)
                Button {
                    Haptics.light()
                    restore()
                } label: {
                    Text("Undo").font(HDFont.subMedium).foregroundStyle(Palette.paper)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.xs)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Saving

    /// Shows the change at once and saves it. If it doesn't save, it goes back and says so.
    private func commit(_ updated: Client, before: Client) async -> Bool {
        app.client = updated
        do {
            try await app.data.updateClient(updated)
            withAnimation(Motion.gentle) { problem = nil }
            return true
        } catch {
            app.client = before
            Haptics.warning()
            withAnimation(Motion.gentle) { problem = "Didn't save. Your addresses are as they were. Try again." }
            return false
        }
    }

    private func upsert(_ address: Address) {
        guard let before = app.client else { return }
        var c = before
        if let i = c.addresses.firstIndex(where: { $0.id == address.id }) { c.addresses[i] = address } else { c.addresses.append(address) }
        Task { @MainActor in _ = await commit(c, before: before) }
    }

    private func makeDefault(_ address: Address) {
        guard let before = app.client, let i = before.addresses.firstIndex(where: { $0.id == address.id }) else { return }
        var c = before
        let moved = c.addresses.remove(at: i)
        c.addresses.insert(moved, at: 0)
        Haptics.light()
        Task { @MainActor in
            withAnimation(Motion.spring) { app.client = c }
            if await commit(c, before: before) { app.show("\(moved.label.isEmpty ? "That one" : moved.label)'s your default now.") }
        }
    }

    private func remove(_ address: Address) {
        guard let before = app.client, let i = before.addresses.firstIndex(where: { $0.id == address.id }) else { return }
        var c = before
        c.addresses.remove(at: i)
        Haptics.light()
        undoToken += 1
        let token = undoToken
        Task { @MainActor in
            withAnimation(Motion.spring) { app.client = c }
            guard await commit(c, before: before) else { return }
            withAnimation(Motion.spring) { undo = (address, i) }
            try? await Task.sleep(for: .seconds(5))
            if token == undoToken { withAnimation(Motion.gentle) { undo = nil } }
        }
    }

    private func restore() {
        guard let undo, let before = app.client else { return }
        var c = before
        c.addresses.insert(undo.address, at: min(undo.index, c.addresses.count))
        withAnimation(Motion.gentle) { self.undo = nil }
        Task { @MainActor in
            withAnimation(Motion.spring) { app.client = c }
            _ = await commit(c, before: before)
        }
    }
}

// MARK: - Payment methods

/// Cards and Apple Pay. One's the default. Removing a card asks first.
struct AccountPaymentsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var removing: PaymentMethod? = nil
    @State private var confirmRemove = false
    @State private var problem: String? = nil

    private var methods: [PaymentMethod] { app.client?.paymentMethods ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Payment methods", subtitle: "We hold the amount when you book and charge it when she's done.", onClose: { dismiss() })
            if app.isOffline { OfflineBar() }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if methods.isEmpty {
                        EmptyState(title: "No cards yet.", message: "Apple Pay works without one.")
                            .padding(.horizontal, -Space.gutter)
                    } else {
                        Hairline(strong: true)
                        ForEach(methods) { method in row(method) }
                    }
                    if let problem { FieldMessage(text: problem).padding(.top, Space.m) }
                    if app.payments.checkoutCard == nil {
                        OutlineButton(title: "Add a card", isEnabled: !app.isOffline) { adding = true }
                            .padding(.top, Space.xl)
                    } else {
                        // With Stripe, a card goes in the first time you pay with it, then it's kept here.
                        Text("You add a card when you book. It's kept here for next time.")
                            .font(HDFont.caption)
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.top, Space.l)
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.section)
            }
        }
        .accountSheet()
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $adding) {
            AddCardSheet { added in
                guard let before = app.client else { return }
                var c = before
                var new = added
                if c.paymentMethods.isEmpty { new.isDefault = true }
                c.paymentMethods.append(new)
                adding = false
                Task { @MainActor in _ = await commit(c, before: before) }
            }
        }
        .confirmSheet(isPresented: $confirmRemove,
                      title: "Remove \(removing?.brand ?? "card") ending \(removing?.last4 ?? "")?",
                      message: "You can add it again when you next book.",
                      confirmTitle: "Remove",
                      cancelTitle: "Keep it") {
            if let m = removing { remove(m) }
        }
    }

    private func row(_ method: PaymentMethod) -> some View {
        HStack(alignment: .center, spacing: Space.m) {
            Image(systemName: method.kind == .applePay ? "apple.logo" : "creditcard")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Palette.ink)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(method.label).font(HDFont.body).foregroundStyle(Palette.ink)
                    if method.isDefault { Tag(text: "Default") }
                }
                if method.kind == .card, !method.expiry.isEmpty {
                    Text("Expires \(method.expiry)").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: Space.s)
            VStack(alignment: .trailing, spacing: 0) {
                if !method.isDefault {
                    TertiaryButton(title: "Make default", tint: Palette.ink) { makeDefault(method) }
                        .disabled(app.isOffline)
                }
                if method.kind == .card {
                    TertiaryButton(title: "Remove") {
                        removing = method
                        confirmRemove = true
                    }
                    .disabled(app.isOffline)
                }
            }
            .padding(.trailing, -8)
        }
        .padding(.vertical, Space.s)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(method.label)\(method.isDefault ? ", default" : "")")
    }

    private func commit(_ updated: Client, before: Client) async -> Bool {
        app.client = updated
        do {
            try await app.data.updateClient(updated)
            withAnimation(Motion.gentle) { problem = nil }
            return true
        } catch {
            app.client = before
            Haptics.warning()
            withAnimation(Motion.gentle) { problem = "Didn't save. Your cards are as they were. Try again." }
            return false
        }
    }

    private func makeDefault(_ method: PaymentMethod) {
        guard let before = app.client else { return }
        var c = before
        for i in c.paymentMethods.indices { c.paymentMethods[i].isDefault = c.paymentMethods[i].id == method.id }
        Haptics.light()
        Task { @MainActor in _ = await commit(c, before: before) }
    }

    private func remove(_ method: PaymentMethod) {
        guard let before = app.client else { return }
        var c = before
        c.paymentMethods.removeAll { $0.id == method.id }
        if method.isDefault, !c.paymentMethods.isEmpty { c.paymentMethods[0].isDefault = true }
        removing = nil
        Task { @MainActor in
            if await commit(c, before: before) { app.show("Removed.") }
        }
    }
}

// MARK: - Notifications

/// What we'll tell her about. Booking updates and messages always come through (product-spec §12);
/// the rest she can switch. If iOS has them off, says so first, with the way to Settings.
struct AccountNotificationsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("notify.reminders") private var reminders = true
    @AppStorage("notify.whosFree") private var whosFree = false
    /// What iOS says. The switches below only matter once this is on.
    @State private var system: UNAuthorizationStatus = .authorized

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Notifications", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if system == .denied || system == .notDetermined {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            FieldMessage(text: system == .denied
                                         ? "Notifications are off in Settings, so none of these come through."
                                         : "Notifications aren't on yet, so none of these come through.")
                            TertiaryButton(title: system == .denied ? "Open Settings" : "Turn on", tint: Palette.ink) {
                                Task { @MainActor in await turnOn() }
                            }
                            .padding(.leading, -8)
                        }
                        .padding(.bottom, Space.l)
                    }
                    Hairline(strong: true)
                    HairlineRow(title: "Booking updates",
                                subtitle: "Can't turn these off, sorry. They're the useful ones.",
                                value: "Always on", chevron: false)
                    HairlineRow(title: "Messages",
                                subtitle: "Always on too. She might be at your door.",
                                value: "Always on", chevron: false)
                    HDSwitch(title: "Day-before reminders", isOn: $reminders)
                        .padding(.vertical, Space.s)
                        .overlay(alignment: .bottom) { Hairline(strong: true) }
                    HDSwitch(title: "Who's free near you", subtitle: "Now and then. Never before 9 am.", isOn: $whosFree)
                        .padding(.vertical, Space.s)
                        .overlay(alignment: .bottom) { Hairline(strong: true) }
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
        }
        .accountSheet()
        .presentationDetents([.medium, .large])
        .task { await refreshStatus() }
        .onAppear {
            // Messages are locked on; the push banner reads this.
            UserDefaults.standard.set(true, forKey: "notify.messages")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshStatus() } }
        }
        .onChange(of: reminders) { _, _ in syncMaster() }
        .onChange(of: whosFree) { _, _ in syncMaster() }
    }

    @MainActor
    private func refreshStatus() async {
        system = await PushCenter.shared.status()
    }

    @MainActor
    private func turnOn() async {
        if system == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) { _ = await UIApplication.shared.open(url) }
            return
        }
        PushCenter.shared.markAsked(.client)
        await PushCenter.shared.requestPermission()
        system = await PushCenter.shared.status()
    }

    /// `client.notificationsOn` mirrors the optional ones: on if any of them is.
    private func syncMaster() {
        guard let before = app.client else { return }
        let on = reminders || whosFree
        guard before.notificationsOn != on else { return }
        var c = before
        c.notificationsOn = on
        app.client = c
        Task { @MainActor in
            do { try await app.data.updateClient(c) } catch {
                app.client = before
                app.show("Didn't save. Try again.")
            }
        }
    }
}

// MARK: - Help

/// A few answers, and a person if they're not enough.
struct AccountHelpSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var open: Set<String> = []

    static let supportEmail = "hello@hairdone.app"

    private let faqs: [(String, String)] = [
        ("How holds and charges work", "When you book, we hold the total on your card. Nothing's taken until she's done. Then you pay in the app, with a tip if you like, or we charge the card 12 hours later. The receipt lands in your inbox. If the booking doesn't happen, the hold drops off in a few days."),
        ("Cancelling and rescheduling", "Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. Once she's on her way it's half, and once she's at the door it's the full price and the booking fee. Moving a booking is free with more than 24 hours' notice."),
        ("What if she's late", "She'll message you from the thread if she's running behind. If she's more than 20 minutes late with no word, message us from here and a person will sort it, usually the same day."),
        ("Safety", "Every pro has had her ID checked by a person before she's listed, and reviews only come from finished, paid bookings. Phone numbers stay hidden until she's confirmed. If anything feels off, report the pro from her profile or the conversation and we'll look at it."),
        ("Reporting a pro", "Open her profile or the conversation and tap Report. Tell us what happened in a line or two. A person reads every one."),
        ("Becoming a pro", "Do hair, nails, makeup, lashes or brows? Tap Set up Pro mode on You. It's about ten minutes: what you do and your prices, where you'll go, your hours, three photos of your work, your ID and where your money lands. Clients can't see you until it's done and a person has checked your ID. It's the same account, so you can still book for yourself. Switch sides from You, or from Profile in Pro mode."),
        ("Deleting your account", "Tap Delete account at the bottom of You. Your profile, addresses and cards go, and if you're a pro, your pro profile, work photos and payout link go too. Past receipts stay in your email and money already on its way still lands. It can't be undone, and it has to wait until every booking you've got on, on either side, is finished.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Help", subtitle: "A person replies, usually the same day.", onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Hairline(strong: true)
                    ForEach(Array(faqs.enumerated()), id: \.offset) { _, faq in faqRow(faq.0, answer: faq.1) }
                    OutlineButton(title: "Message us") { messageUs() }
                        .padding(.top, Space.xl)
                    Text(Self.supportEmail)
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Space.s)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
        }
        .accountSheet()
        .presentationDetents([.large])
        .overlay(alignment: .bottom) { ToastView() }
    }

    /// Mail if there's an account set up; otherwise the address goes on the clipboard and says so.
    private func messageUs() {
        let url = URL(string: "mailto:\(Self.supportEmail)?subject=Help")
        if MFMailComposeViewController.canSendMail(), let url {
            openURL(url) { accepted in
                if !accepted { copyAddress() }
            }
        } else {
            copyAddress()
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = Self.supportEmail
        Haptics.success()
        app.show("Copied \(Self.supportEmail).")
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
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(HDFont.body).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.inkFaint)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint(isOpen ? "Hides the answer" : "Shows the answer")
            if isOpen {
                Text(answer)
                    .font(HDFont.quote)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.l)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) { Hairline(strong: true) }
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
                    Text("The short version").font(HDFont.name).foregroundStyle(Palette.ink)
                    Text("Hair Done connects you with a mobile pro and takes payment for the booking. The pro is her own business; the work is hers, the booking terms are ours. We charge you what's on the review screen and nothing else.")
                        .font(HDFont.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    Hairline(strong: true)
                    Text("Your data").font(HDFont.name).foregroundStyle(Palette.ink)
                    Text("We keep your name, mobile, email, addresses and bookings so the app works. Your address goes to a pro only once she's confirmed. Your card details go to Stripe, not to us. Location is used only while you're in the app, to show who's near.")
                        .font(HDFont.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    Hairline(strong: true)
                    Text("The full terms and privacy policy are on hairdone.app. Questions go to Help.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Space.l) {
                        Link("Terms", destination: URL(string: "https://hairdone.app/terms")!)
                        Link("Privacy policy", destination: URL(string: "https://hairdone.app/privacy")!)
                    }
                    .font(HDFont.subMedium)
                    .tint(Palette.ink)
                    .frame(minHeight: 44)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
        }
        .accountSheet()
        .presentationDetents([.medium, .large])
    }
}

#Preview("Addresses") {
    AccountAddressesSheet().environment(previewApp())
}

#Preview("Payment methods") {
    AccountPaymentsSheet().environment(previewApp())
}

#Preview("Details") {
    AccountDetailsSheet().environment(previewApp())
}
