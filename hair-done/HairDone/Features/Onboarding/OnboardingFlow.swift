import SwiftUI
import AuthenticationServices

/// Welcome → phone → code → your name → location → home.
/// `app.stage` decides which half you're in: `.welcome` covers welcome, phone and code;
/// `.signedIn` covers name and location. Local `step` moves within each half.
struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Step: Int { case welcome, phone, code, name, location }

    @State private var step: Step = .welcome
    @State private var forward = true
    @State private var phone = ""

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                OnboardingWelcome(onPhone: { go(.phone) })
                    .transition(slide)
            case .phone:
                OnboardingPhone(phone: $phone, onBack: { go(.welcome, forward: false) }, onNext: { go(.code) })
                    .transition(slide)
            case .code:
                OnboardingCode(phone: phone, onBack: { go(.phone, forward: false) })
                    .transition(slide)
            case .name:
                OnboardingName(onNext: { go(.location) })
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

/// Serif headline and a soft sub-line. Air above, air below.
private struct OnboardingHeadline: View {
    var title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title)
                .font(HDFont.hero)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
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

/// Top row with an optional back button. Keeps the same height with or without it.
private struct OnboardingTopBar: View {
    var onBack: (() -> Void)? = nil
    var body: some View {
        HStack {
            if let onBack { IconButton(symbol: "chevron.left", label: "Back", action: onBack) }
            Spacer()
        }
        .frame(height: 44)
        .screenGutter()
        .padding(.top, Space.s)
    }
}

/// One line of red under a field, only when there's something to say.
private struct OnboardingError: View {
    var text: String?
    var body: some View {
        if let text {
            Text(text)
                .font(HDFont.caption)
                .foregroundStyle(Palette.lacquer)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

// MARK: - Welcome

private struct OnboardingWelcome: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onPhone: () -> Void

    @State private var appeared = false
    @State private var appleError: String? = nil
    @State private var isSigningIn = false

    /// Paper-coloured ink for everything sitting on the video.
    private let onVideo = Color(hex: 0xF4ECE4)
    private let onVideoSoft = Color(hex: 0xF4ECE4).opacity(0.78)

    var body: some View {
        ZStack(alignment: .bottom) {
            IntroBackdrop()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("hd").italic()
                    Text(".").foregroundStyle(Palette.lacquer)
                    Text(" nd").italic()
                    Text(".").foregroundStyle(Palette.lacquer)
                }
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(onVideo)
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
                .padding(.bottom, Space.l)

                Text("A vetted pro comes to you. Melbourne, for now.")
                    .font(HDFont.body)
                    .foregroundStyle(onVideoSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.xxl)

                VStack(spacing: Space.m) {
                    PrimaryButton(title: "Continue with phone", isLoading: false, isEnabled: !isSigningIn, action: onPhone)

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .accessibilityLabel("Continue with Apple")

                    OnboardingError(text: appleError)

                    Text("By continuing you agree to the [terms](https://hairdone.app/terms) and [privacy policy](https://hairdone.app/privacy).")
                        .font(HDFont.caption)
                        .foregroundStyle(onVideoSoft)
                        .tint(onVideo)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Space.xs)
                }
                .padding(.bottom, Space.l)
            }
            .screenGutter()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if reduceMotion { appeared = true } else { withAnimation(Motion.springSlow.delay(0.15)) { appeared = true } }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success:
            isSigningIn = true
            appleError = nil
            Task {
                await app.signInWithApple()
                isSigningIn = false
            }
        case .failure(let error):
            if let e = error as? ASAuthorizationError, e.code == .canceled { return }
            withAnimation(Motion.gentle) { appleError = "Apple didn't come back to us. Try again, or use your phone." }
        }
    }
}

// MARK: - Phone

private struct OnboardingPhone: View {
    @Binding var phone: String
    var onBack: () -> Void
    var onNext: () -> Void

    @FocusState private var focused: Bool
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTopBar(onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    OnboardingHeadline(title: "Your number", sub: "We'll text you a code. No calls, no spam.")
                        .padding(.top, Space.l)

                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack(spacing: Space.m) {
                            Text("+61")
                                .font(HDFont.bodyStrong)
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 52)
                                .background(Palette.line.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                                .accessibilityLabel("Country code plus 61, Australia")

                            TextField("04xx xxx xxx", text: $phone)
                                .font(HDFont.body.monospacedDigit())
                                .keyboardType(.numberPad)
                                .textContentType(.telephoneNumber)
                                .focused($focused)
                                .padding(.horizontal, 14)
                                .frame(height: 52)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(error == nil ? Palette.line : Palette.lacquer, lineWidth: 1))
                                .onChange(of: phone) { _, new in
                                    let formatted = AUPhone.format(new)
                                    if formatted != new { phone = formatted }
                                    if error != nil { withAnimation(Motion.gentle) { error = nil } }
                                }
                                .accessibilityLabel("Mobile number")
                        }
                        OnboardingError(text: error)
                    }
                }
                .screenGutter()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Text me a code", isEnabled: !phone.isEmpty, action: submit)
                .screenGutter()
                .padding(.vertical, Space.m)
                .background(Palette.paper)
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
        phone = AUPhone.display(phone)
        focused = false
        onNext()
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
    var phone: String
    var onBack: () -> Void

    @State private var code = ""
    @State private var isVerifying = false
    @State private var error: String? = nil
    @State private var resendIn = 30
    @State private var resendCycle = 0
    @FocusState private var focused: Bool

    private let length = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingTopBar(onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    OnboardingHeadline(title: "Check your texts", sub: "We sent a 6-digit code to \(phone).")
                        .padding(.top, Space.l)

                    VStack(alignment: .leading, spacing: Space.m) {
                        boxes
                        OnboardingError(text: error)
                    }

                    HStack(spacing: Space.l) {
                        if resendIn > 0 {
                            Text("Send again in \(resendIn)s")
                                .font(HDFont.subStrong)
                                .foregroundStyle(Palette.inkFaint)
                                .monospacedDigit()
                                .frame(minHeight: 44)
                                .padding(.horizontal, 8)
                        } else {
                            TertiaryButton(title: "Send it again", tint: Palette.lacquer) {
                                resendIn = 30
                                resendCycle += 1
                                code = ""
                                withAnimation(Motion.gentle) { error = nil }
                            }
                        }
                        TertiaryButton(title: "Wrong number", action: onBack)
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

    /// Six boxes drawn from one hidden field, so the system keyboard and one-time-code
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

            HStack(spacing: Space.s) {
                ForEach(0..<length, id: \.self) { i in
                    let chars = Array(code)
                    let ch = i < chars.count ? String(chars[i]) : ""
                    let isActive = focused && i == min(chars.count, length - 1)
                    Text(ch)
                        .font(Font.system(.title, design: .serif).weight(.medium).monospacedDigit())
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                                .strokeBorder(error != nil ? Palette.lacquer : (isActive ? Palette.ink : Palette.line), lineWidth: isActive ? 1.5 : 1)
                        )
                        .animation(reduceMotion ? nil : Motion.spring, value: ch)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .accessibilityHidden(true)
        }
    }

    private func verify() {
        guard !isVerifying else { return }
        isVerifying = true
        focused = false
        Task {
            await app.signIn(phone: phone)
            isVerifying = false
            if app.stage == .welcome {
                Haptics.error()
                withAnimation(Motion.gentle) { error = app.lastError ?? "That code's not right. Have another look." }
                code = ""
                focused = true
            }
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
                    OnboardingHeadline(title: "And you are", sub: "First name's fine. It's what she'll see when you book.")
                        .padding(.top, Space.l)

                    VStack(alignment: .leading, spacing: Space.s) {
                        TextField("Your first name", text: $name)
                            .font(HDFont.body)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .submitLabel(.done)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(error == nil ? Palette.line : Palette.lacquer, lineWidth: 1))
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
            PrimaryButton(title: "That's me", action: submit)
                .screenGutter()
                .padding(.vertical, Space.m)
                .background(Palette.paper)
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
            withAnimation(Motion.gentle) { error = "She'll need something to call you." }
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
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Space.l)

                    OnboardingHeadline(
                        title: "Pros near you",
                        sub: "We use your location to show who's close and what her travel fee comes to. Only while you're in the app."
                    )
                }
                .screenGutter()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.xs) {
                PrimaryButton(title: "Use my location", isLoading: waiting, action: allow)
                TertiaryButton(title: "Not now") { app.finishOnboarding() }
            }
            .screenGutter()
            .padding(.vertical, Space.m)
            .background(Palette.paper)
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

    /// Concentric hairlines, the drop in the middle, three pros dotted around it.
    private var rings: some View {
        let nearby = Array(MockData.pros.prefix(3))
        return ZStack {
            ForEach([1.0, 0.68, 0.36], id: \.self) { scale in
                Circle()
                    .strokeBorder(Palette.line, lineWidth: 1)
                    .frame(width: 220 * scale, height: 220 * scale)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
            }
            Circle().fill(Palette.lacquerSoft).frame(width: 56, height: 56)
            DropMark(size: 28)

            ForEach(Array(nearby.enumerated()), id: \.element.id) { i, pro in
                let angle = Double(i) * 120 - 30
                let radius: CGFloat = i == 1 ? 96 : 70
                Avatar(name: pro.firstName, seed: pro.seed, size: 40)
                    .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 3))
                    .offset(x: cos(angle * .pi / 180) * radius, y: sin(angle * .pi / 180) * radius)
                    .scaleEffect(appeared ? 1 : 0.5)
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
