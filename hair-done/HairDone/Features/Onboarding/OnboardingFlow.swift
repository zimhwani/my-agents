import SwiftUI
import AuthenticationServices

/// Welcome (Apple, or email) → email → code → your name → location → home. Phone is still there,
/// a step to the side of email ("Use your phone instead"), for the test numbers.
/// `app.stage` decides which half you're in: `.welcome` covers welcome, email, phone and code;
/// `.signedIn` covers name and location. Local `step` moves within each half.
struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Step: Int { case welcome, email, phone, code, name, location }

    @State private var step: Step = .welcome
    @State private var forward = true
    @State private var email = ""
    @State private var phone = ""
    /// Where the code went: email unless she took the phone way.
    @State private var viaPhone = false

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                OnboardingWelcome(onEmail: { go(.email) })
                    .transition(slide)
            case .email:
                OnboardingEmail(
                    email: $email,
                    onBack: { go(.welcome, forward: false) },
                    onNext: { viaPhone = false; go(.code) },
                    onPhone: { go(.phone) }
                )
                .transition(slide)
            case .phone:
                OnboardingPhone(phone: $phone, onBack: { go(.email, forward: false) }, onNext: { viaPhone = true; go(.code) })
                    .transition(slide)
            case .code:
                OnboardingCode(
                    destination: viaPhone ? .phone(phone) : .email(email),
                    onBack: { go(viaPhone ? .phone : .email, forward: false) }
                )
                .transition(slide)
            case .name:
                OnboardingName(onNext: nameDone)
                    .transition(slide)
            case .location:
                OnboardingLocation()
                    .transition(slide)
            }
        }
        .paperBackground()
        .animation(reduceMotion ? nil : Motion.springSlow, value: step)
        .onAppear { sync(app.stage) }
        .onChange(of: app.stage) { _, new in sync(new) }
    }

    private var slide: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    /// After her name: the location ask, unless she came in through "Get booked here", in which
    /// case she goes straight to You, where pro setup opens (`AccountView` takes the intent).
    private func nameDone() {
        if app.wantsProOnboarding {
            app.selectedTab = .you
            app.finishOnboarding()
        } else {
            go(.location)
        }
    }

    private func go(_ to: Step, forward: Bool = true) {
        self.forward = forward
        step = to
    }

    /// Keeps the local step honest with the session stage.
    private func sync(_ stage: SessionStage) {
        switch stage {
        case .welcome:
            if step.rawValue >= Step.name.rawValue { go(.welcome, forward: false) }
        case .signedIn:
            if step.rawValue < Step.name.rawValue { go(.name) }
        case .ready:
            break
        }
    }
}

// MARK: - Shared pieces

/// Serif title and a soft sub-line. Air above, air below.
private struct OnboardingHeadline: View {
    var title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title)
                .font(HDFont.title)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let sub {
                Text(sub)
                    .font(HDFont.body)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Top row with an optional bare back glyph. Keeps the same height with or without it.
private struct OnboardingTopBar: View {
    var onBack: (() -> Void)? = nil
    var body: some View {
        HStack {
            if let onBack { IconButton(symbol: "chevron.left", label: "Back", action: onBack) }
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, Space.gutter - 12)
        .padding(.top, Space.s)
    }
}

/// A problem under a field: warn dot, ink words. Never lacquer, never red.
private struct OnboardingError: View {
    var text: String?
    var body: some View {
        if let text {
            FieldMessage(text: text)
                .transition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

/// The underline field the sign-in steps share, like `HDTextField`, but with focus the step can
/// set (so the keyboard is up when the step arrives). A leading view sits on the same rule (+61).
private struct OnboardingField<Leading: View>: View {
    var placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var hasError: Bool
    var monospaced = false
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            leading()
            TextField(placeholder, text: $text)
                .font(monospaced ? HDFont.body.monospacedDigit() : HDFont.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.ink)
                .focused(focused)
        }
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(hasError ? Palette.warn : (focused.wrappedValue ? Palette.ink : Palette.line))
                .frame(height: focused.wrappedValue || hasError ? 2 : 1)
                .animation(Motion.gentle, value: focused.wrappedValue)
        }
    }
}

extension OnboardingField where Leading == EmptyView {
    init(placeholder: String, text: Binding<String>, focused: FocusState<Bool>.Binding, hasError: Bool, monospaced: Bool = false) {
        self.init(placeholder: placeholder, text: text, focused: focused, hasError: hasError, monospaced: monospaced) { EmptyView() }
    }
}

/// The paper footer every step's action sits in.
private struct OnboardingFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: Space.xs) { content() }
            .screenGutter()
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
            .background(Palette.paper)
    }
}

// MARK: - Welcome

private struct OnboardingWelcome: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onEmail: () -> Void

    @State private var appeared = false
    @State private var appleError: String? = nil
    @State private var isSigningIn = false
    /// The raw nonce for the Apple request in flight; its hash goes to Apple, the raw one to our server.
    @State private var nonce = ""

    /// Paper-coloured type for everything sitting on the video.
    private let onVideo = Palette.onInk
    private let onVideoSoft = Palette.onInk.opacity(0.78)

    var body: some View {
        ZStack(alignment: .bottom) {
            IntroBackdrop()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                MonogramMark(size: 22, color: onVideo)
                    .padding(.bottom, Space.l)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: -2) {
                    Text("hair done.")
                    Text("nails done.")
                    HStack(spacing: 0) {
                        Text("everything ") + Text("done").italic()
                        Text(".").foregroundStyle(Palette.lacquer)
                    }
                }
                .font(.system(size: 40, weight: .medium, design: .serif))
                .foregroundStyle(onVideo)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hair done, nails done, everything done")
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Space.l)

                Text("A vetted pro comes to you. Melbourne, for now.")
                    .font(HDFont.body)
                    .foregroundStyle(onVideoSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.xxl)

                VStack(spacing: Space.m) {
                    SignInWithAppleButton(.continue) { request in
                        let raw = AppleNonce.make()
                        nonce = raw
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleNonce.sha256(raw)
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    .disabled(isSigningIn)
                    .accessibilityLabel("Continue with Apple")

                    InkButton(title: "Continue with email", isEnabled: !isSigningIn, tone: .onInk, action: onEmail)

                    if let appleError {
                        Text(appleError)
                            .font(HDFont.caption)
                            .foregroundStyle(onVideo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }

                    proLink

                    Text("By continuing you agree to the [terms](https://hairdonenailsdone.app/terms) and [privacy policy](https://hairdonenailsdone.app/privacy).")
                        .font(HDFont.caption)
                        .foregroundStyle(onVideoSoft)
                        .tint(onVideo)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, Space.l)
            }
            .screenGutter()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        // Dark only for the welcome's own content: the window keeps the system scheme, so the next
        // step doesn't arrive dark and snap to light (audit m27).
        .environment(\.colorScheme, .dark)
        .onAppear {
            if reduceMotion { appeared = true } else { withAnimation(Motion.springSlow.delay(0.15)) { appeared = true } }
        }
    }

    /// "Do hair, nails or makeup? Get booked here." Sets the intent: after sign-in she skips the
    /// location ask and goes straight to pro setup.
    @ViewBuilder
    private var proLink: some View {
        if app.wantsProOnboarding {
            HStack(spacing: Space.s) {
                Text("Sign in first, then we'll set up your pro side.")
                    .font(HDFont.sub)
                    .foregroundStyle(onVideo)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    Haptics.light()
                    withAnimation(Motion.gentle) { app.wantsProOnboarding = false }
                } label: {
                    Text("Undo").font(HDFont.subMedium).foregroundStyle(onVideoSoft)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .transition(.opacity)
        } else {
            Button {
                Haptics.light()
                withAnimation(Motion.gentle) { app.wantsProOnboarding = true }
            } label: {
                Text("Do hair, nails or makeup? Get booked here.")
                    .font(HDFont.subMedium)
                    .foregroundStyle(onVideo)
                    .underline()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("After you sign in, sets up your pro side")
            .transition(.opacity)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = AppleCredential(authorization: authorization, rawNonce: nonce) else {
                withAnimation(Motion.gentle) { appleError = "Apple didn't come back to us. Try again, or use your email." }
                return
            }
            isSigningIn = true
            appleError = nil
            Task {
                await app.signInWithApple(credential)
                isSigningIn = false
                if app.stage == .welcome {
                    withAnimation(Motion.gentle) { appleError = "Apple didn't come back to us. Try again, or use your email." }
                }
            }
        case .failure(let error):
            if let e = error as? ASAuthorizationError, e.code == .canceled { return }
            withAnimation(Motion.gentle) { appleError = "Apple didn't come back to us. Try again, or use your email." }
        }
    }
}

// MARK: - Email

private struct OnboardingEmail: View {
    @Environment(AppState.self) private var app
    @Binding var email: String
    var onBack: () -> Void
    var onNext: () -> Void
    var onPhone: () -> Void

    @FocusState private var focused: Bool
    @State private var error: String? = nil
    @State private var sending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTopBar(onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    OnboardingHeadline(title: "Your email", sub: "We'll email you a code. No newsletters, no spam.")
                        .padding(.top, Space.l)

                    VStack(alignment: .leading, spacing: Space.s) {
                        OnboardingField(placeholder: "you@example.com", text: $email, focused: $focused, hasError: error != nil)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onChange(of: email) { _, _ in
                                if error != nil { withAnimation(Motion.gentle) { error = nil } }
                            }
                            .accessibilityLabel("Your email")
                        OnboardingError(text: error)
                        if app.wantsProOnboarding {
                            Text("Then we'll set up your pro side.")
                                .font(HDFont.caption)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
                .screenGutter()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingFooter {
                InkButton(title: "Continue", isLoading: sending, isEnabled: !email.trimmingCharacters(in: .whitespaces).isEmpty, action: submit)
                // Hidden until texts to Australian numbers are switched on (app_flags.phone_sign_in).
                if app.phoneSignInOn {
                    TertiaryButton(title: "Use your phone instead", action: onPhone)
                }
            }
        }
        .onAppear { focused = true }
        .onSubmit(submit)
    }

    private func submit() {
        let cleaned = EmailAddress.clean(email)
        guard EmailAddress.isValid(cleaned) else {
            Haptics.warning()
            withAnimation(Motion.gentle) { error = "That email doesn't look right. Have another look." }
            return
        }
        guard !sending else { return }
        email = cleaned
        focused = false
        sending = true
        Task { @MainActor in
            let sent = await app.sendEmailCode(to: cleaned)
            sending = false
            if sent {
                onNext()
            } else {
                Haptics.warning()
                withAnimation(Motion.gentle) { error = app.lastError ?? "That didn't work. Try again." }
            }
        }
    }
}

/// Light checks only: something before an @, and a dot somewhere after it. The code proves the rest.
enum EmailAddress {
    static func clean(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValid(_ raw: String) -> Bool {
        let s = clean(raw)
        guard !s.contains(" "), let at = s.firstIndex(of: "@"), at != s.startIndex else { return false }
        let domain = s[s.index(after: at)...]
        guard let dot = domain.lastIndex(of: "."), dot != domain.startIndex else { return false }
        return domain.index(after: dot) != domain.endIndex
    }
}

// MARK: - Phone

private struct OnboardingPhone: View {
    @Environment(AppState.self) private var app
    @Binding var phone: String
    var onBack: () -> Void
    var onNext: () -> Void

    @FocusState private var focused: Bool
    @State private var error: String? = nil
    @State private var sending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTopBar(onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    OnboardingHeadline(title: "Your number", sub: "We'll text you a code. No calls, no spam.")
                        .padding(.top, Space.l)

                    VStack(alignment: .leading, spacing: Space.s) {
                        OnboardingField(placeholder: "04xx xxx xxx", text: $phone, focused: $focused, hasError: error != nil, monospaced: true) {
                            Text("+61")
                                .font(HDFont.body.monospacedDigit())
                                .foregroundStyle(Palette.inkSoft)
                                .accessibilityLabel("Country code plus 61, Australia")
                        }
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .onChange(of: phone) { _, new in
                            let formatted = AUPhone.format(new)
                            if formatted != new { phone = formatted }
                            if error != nil { withAnimation(Motion.gentle) { error = nil } }
                        }
                        .accessibilityLabel("Mobile number")
                        OnboardingError(text: error)
                    }
                }
                .screenGutter()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingFooter {
                InkButton(title: "Text me a code", isLoading: sending, isEnabled: !phone.isEmpty, action: submit)
            }
        }
        .onAppear { focused = true }
        .onSubmit(submit)
    }

    private func submit() {
        guard AUPhone.isValid(phone) else {
            Haptics.warning()
            withAnimation(Motion.gentle) { error = "That doesn't look like an Australian mobile." }
            return
        }
        guard !sending else { return }
        phone = AUPhone.display(phone)
        focused = false
        sending = true
        Task {
            let sent = await app.sendCode(to: phone)
            sending = false
            if sent {
                onNext()
            } else {
                Haptics.warning()
                withAnimation(Motion.gentle) { error = app.lastError ?? "That didn't work. Try again." }
            }
        }
    }
}

/// Australian mobile formatting for the one field that needs it. +61 is fixed.
enum AUPhone {
    /// Digits only, capped at a mobile's length.
    static func digits(_ raw: String) -> String {
        let d = raw.filter(\.isNumber)
        return String(d.prefix(d.hasPrefix("0") ? 10 : 9))
    }

    /// "0412 345 678" or "412 345 678", formatting as you type.
    static func format(_ raw: String) -> String {
        let d = digits(raw)
        let groups = d.hasPrefix("0") ? [4, 3, 3] : [3, 3, 3]
        var out = ""
        var i = d.startIndex
        for g in groups {
            guard i < d.endIndex else { break }
            let end = d.index(i, offsetBy: g, limitedBy: d.endIndex) ?? d.endIndex
            if !out.isEmpty { out += " " }
            out += d[i..<end]
            i = end
        }
        return out
    }

    /// Always with the leading zero, for showing back to her.
    static func display(_ raw: String) -> String {
        let d = digits(raw)
        return format(d.hasPrefix("0") ? d : "0" + d)
    }

    static func isValid(_ raw: String) -> Bool {
        let d = digits(raw)
        return (d.hasPrefix("04") && d.count == 10) || (d.hasPrefix("4") && d.count == 9)
    }
}

// MARK: - Code

private struct OnboardingCode: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the code went.
    enum Destination {
        case email(String)
        case phone(String)
    }

    var destination: Destination
    var onBack: () -> Void

    @State private var code = ""
    @State private var isVerifying = false
    @State private var error: String? = nil
    @State private var resendIn = 30
    @State private var resendCycle = 0
    /// When the code in hand was sent. GoTrue says "expired or invalid" for both, so an old code is
    /// told apart by its age (Supabase's email codes last an hour by default).
    @State private var sentAt = Date()
    @FocusState private var focused: Bool

    private let length = 6
    private let emailCodeLifetime: TimeInterval = 3600

    private var isEmail: Bool {
        if case .email = destination { return true }
        return false
    }

    private var address: String {
        switch destination {
        case .email(let e): return e
        case .phone(let p): return p
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTopBar(onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    OnboardingHeadline(title: isEmail ? "Check your email" : "Check your texts",
                                       sub: "We sent a 6-digit code to \(address).")
                        .padding(.top, Space.l)

                    VStack(alignment: .leading, spacing: Space.m) {
                        boxes
                        OnboardingError(text: error)
                    }

                    HStack(spacing: Space.l) {
                        if resendIn > 0 {
                            Text("Send again in \(resendIn)s")
                                .font(HDFont.subMedium)
                                .foregroundStyle(Palette.inkSoft)
                                .monospacedDigit()
                                .frame(minHeight: 44)
                                .padding(.horizontal, 8)
                        } else {
                            TertiaryButton(title: "Send it again", tint: Palette.ink) {
                                withAnimation(Motion.gentle) { error = nil }
                                resend()
                            }
                        }
                        TertiaryButton(title: isEmail ? "Use a different email" : "Wrong number", action: onBack)
                    }
                    .padding(.horizontal, -8)

                    if isVerifying {
                        HStack(spacing: Space.m) {
                            LoadingDots()
                            Text("Checking")
                                .font(HDFont.sub)
                                .foregroundStyle(Palette.inkSoft)
                        }
                        .transition(.opacity)
                    }
                }
                .screenGutter()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { focused = true }
        .task(id: resendCycle) {
            while resendIn > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { resendIn -= 1 }
            }
        }
        .animation(reduceMotion ? nil : Motion.spring, value: isVerifying)
    }

    /// Six underline cells drawn from one hidden field, so the system keyboard and one-time-code
    /// autofill both work as usual.
    private var boxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .accessibilityLabel("6-digit code")
                .onChange(of: code) { _, new in
                    let d = String(new.filter(\.isNumber).prefix(length))
                    if d != new { code = d }
                    if error != nil { withAnimation(Motion.gentle) { error = nil } }
                    if d.count == length { verify() }
                }

            HStack(spacing: Space.m) {
                ForEach(0..<length, id: \.self) { i in
                    let chars = Array(code)
                    let ch = i < chars.count ? String(chars[i]) : ""
                    let isActive = focused && i == min(chars.count, length - 1)
                    Text(ch)
                        .font(HDFont.priceTotal)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(error != nil ? Palette.warn : (isActive || !ch.isEmpty ? Palette.ink : Palette.line))
                                .frame(height: isActive || error != nil ? 2 : 1)
                        }
                        .animation(reduceMotion ? nil : Motion.spring, value: ch)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .accessibilityHidden(true)
        }
    }

    /// A fresh code, and the 30 seconds before another. Says so if it didn't go.
    private func resend() {
        resendIn = 30
        resendCycle += 1
        code = ""
        sentAt = Date()
        Task { @MainActor in
            let sent: Bool
            switch destination {
            case .email(let e): sent = await app.sendEmailCode(to: e)
            case .phone(let p): sent = await app.sendCode(to: p)
            }
            if !sent {
                withAnimation(Motion.gentle) { error = app.lastError ?? "That didn't work. Try again." }
            }
        }
    }

    private func verify() {
        guard !isVerifying else { return }
        isVerifying = true
        focused = false
        Task { @MainActor in
            switch destination {
            case .email(let e): await app.verifyEmailCode(code, email: e)
            case .phone(let p): await app.verifyCode(code, phone: p)
            }
            isVerifying = false
            guard app.stage == .welcome else { return }
            Haptics.error()
            let stale = isEmail && app.signInFailure == .wrongCode && Date().timeIntervalSince(sentAt) > emailCodeLifetime
            if stale {
                // "That code's expired. We've sent a new one." So send one.
                resend()
                withAnimation(Motion.gentle) { error = DataError.codeExpired.errorDescription }
            } else {
                withAnimation(Motion.gentle) { error = app.lastError ?? "That code's not right. Have another look." }
            }
            code = ""
            focused = true
        }
    }
}

// MARK: - Name

private struct OnboardingName: View {
    @Environment(AppState.self) private var app
    var onNext: () -> Void

    @State private var name = ""
    @State private var error: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTopBar()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    OnboardingHeadline(title: "And you are", sub: "First name's fine. It's what your pro sees when you book.")
                        .padding(.top, Space.l)

                    VStack(alignment: .leading, spacing: Space.s) {
                        OnboardingField(placeholder: "Your first name", text: $name, focused: $focused, hasError: error != nil)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .accessibilityLabel("Your first name")
                            .onChange(of: name) { _, _ in
                                if error != nil { withAnimation(Motion.gentle) { error = nil } }
                            }
                        OnboardingError(text: error)
                    }
                }
                .screenGutter()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingFooter {
                InkButton(title: "That's me", action: submit)
            }
        }
        .onAppear {
            if name.isEmpty { name = app.client?.firstName ?? "" }
            focused = true
        }
        .onSubmit(submit)
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Haptics.warning()
            withAnimation(Motion.gentle) { error = "Your pro will need something to call you." }
            return
        }
        app.client?.firstName = trimmed
        focused = false
        onNext()
    }
}

// MARK: - Location

private struct OnboardingLocation: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var waiting = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTopBar()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    rings
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Space.l)

                    OnboardingHeadline(
                        title: "Pros near you",
                        sub: "We use your location to show who's close and what their travel fee comes to. Only while you're in the app."
                    )
                }
                .screenGutter()
            }
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingFooter {
                InkButton(title: "Use my location", isLoading: waiting, action: allow)
                TertiaryButton(title: "Not now") { app.finishOnboarding() }
            }
        }
        .onAppear {
            if reduceMotion { appeared = true } else { withAnimation(Motion.springSlow.delay(0.15)) { appeared = true } }
        }
        .onChange(of: app.location.hasAsked) { _, asked in
            if asked && waiting { app.finishOnboarding() }
        }
    }

    private func allow() {
        if app.location.hasAsked {
            app.location.request()
            app.finishOnboarding()
        } else {
            waiting = true
            app.location.request()
        }
    }

    /// Concentric hairlines, the mark in the middle, three bundled photos on the rings. Marketing art,
    /// not any pro's work, so nothing is named and it's drawn straight from the bundle.
    private static let ringArt: [(category: Category, seed: Int)] = [(.nails, 3), (.hair, 1), (.lashes, 2)]

    private var rings: some View {
        ZStack {
            ForEach([1.0, 0.68, 0.36], id: \.self) { scale in
                Circle()
                    .strokeBorder(Palette.lineStrong, lineWidth: 0.5)
                    .frame(width: 230 * scale, height: 230 * scale)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
            }
            MonogramMark(size: 20)

            ForEach(0..<Self.ringArt.count, id: \.self) { i in
                let art = Self.ringArt[i]
                let angle = Double(i) * 120 - 30
                let radius: CGFloat = i == 1 ? 115 : 78
                MarketingPhoto(category: art.category, seed: art.seed)
                    .frame(width: 36, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous).strokeBorder(Palette.paper, lineWidth: 1.5))
                    .offset(x: cos(angle * .pi / 180) * radius, y: sin(angle * .pi / 180) * radius)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : Motion.springSlow.delay(0.2 + Double(i) * 0.08), value: appeared)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Welcome") {
    OnboardingFlow().environment(previewApp(stage: .welcome))
}

#Preview("Signed in") {
    OnboardingFlow().environment(previewApp(stage: .signedIn))
}
