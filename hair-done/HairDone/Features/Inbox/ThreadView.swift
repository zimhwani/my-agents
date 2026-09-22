import SwiftUI

/// One conversation. Yours on the right in ink, hers on the left on card, the app's in the middle.
struct ThreadView: View {
    @Environment(AppState.self) private var app
    var threadID: String

    @State private var draft = ""
    @State private var sending = false
    @FocusState private var composing: Bool

    private var thread: MessageThread? { app.threads.first { $0.id == threadID } }
    private var isPro: Bool { app.mode == .pro }

    var body: some View {
        Group {
            if let thread {
                conversation(thread)
            } else {
                EmptyState(symbol: "bubble.left", title: "We couldn't find that one.").paperBackground()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Lookups

    private func booking(for thread: MessageThread) -> Booking? {
        app.bookings.first { $0.id == thread.bookingID } ?? app.proBookings.first { $0.id == thread.bookingID }
    }

    private func otherName(_ thread: MessageThread) -> String {
        isPro ? app.clientName(thread.clientID) : (app.pro(thread.proID)?.firstName ?? "Her")
    }

    private func otherSeed(_ thread: MessageThread) -> Int {
        isPro ? thread.clientID.hdSeed : (app.pro(thread.proID)?.seed ?? 0)
    }

    /// Six quick replies. The client set is from the copy deck; the pro set is written in the same voice.
    private func quickReplies(_ thread: MessageThread) -> [String] {
        if isPro {
            return [
                "On my way, there in 10",
                "Running 5 minutes late, sorry",
                "Which unit is it?",
                "Parked, coming up now",
                "Thank you, it was lovely",
                "Same again in three weeks?"
            ]
        }
        let unit = booking(for: thread)?.address.line1.unitNumber
        return [
            "Running 5 minutes late, sorry",
            unit.map { "Come on up, buzzer's \($0)" } ?? "Come on up",
            "Parking's on the street out front",
            "Any chance a bit earlier?",
            "Thank you, love it",
            "Same again next time?"
        ]
    }

    // MARK: Conversation

    private func conversation(_ thread: MessageThread) -> some View {
        let name = otherName(thread)
        let linked = booking(for: thread)
        return VStack(spacing: 0) {
            if let linked { bookingStrip(linked, thread: thread) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Space.s) {
                        if linked?.status == .requested && !isPro {
                            Text("Phone numbers are shared once she's confirmed.")
                                .font(HDFont.caption)
                                .foregroundStyle(Palette.inkSoft)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, Space.s)
                        }
                        ForEach(thread.messages) { message in
                            bubble(message, otherName: name)
                                .id(message.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .screenGutter()
                    .padding(.top, Space.l)
                    .padding(.bottom, Space.s)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: thread.messages.count) { _, _ in
                    withAnimation(Motion.spring) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: composing) { _, focused in
                    if focused {
                        Task {
                            try? await Task.sleep(for: .milliseconds(320))
                            withAnimation(Motion.gentle) { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                }
            }
            .paperBackground()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer(thread)
        }
        .navigationTitle(name)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: Space.s) {
                    Avatar(name: name, seed: otherSeed(thread), size: 28)
                    Text(name).font(HDFont.bodyStrong).foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .onAppear { app.markRead(thread) }
        .onChange(of: thread.messages.count) { _, _ in app.markRead(thread) }
    }

    /// The booking this thread belongs to. Tap to open it.
    private func bookingStrip(_ booking: Booking, thread: MessageThread) -> some View {
        NavigationLink(value: isPro ? Route.proBooking(booking.id) : Route.booking(booking.id)) {
            HStack(spacing: Space.m) {
                Circle().fill(booking.status.color).frame(width: 8, height: 8).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(booking.servicesLine) · \(booking.start.friendlyDayTime)")
                        .font(HDFont.subStrong)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("\(booking.address.suburb) · \(booking.status.label)")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
            }
            .screenGutter()
            .padding(.vertical, Space.m)
            .background(Palette.card)
            .overlay(alignment: .bottom) { Hairline() }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the booking")
    }

    // MARK: Bubbles

    @ViewBuilder
    private func bubble(_ message: Message, otherName: String) -> some View {
        if message.isSystem {
            Text(message.text)
                .font(HDFont.caption)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s)
                .accessibilityLabel("Hair Done: \(message.text)")
        } else {
            let mine = message.senderID == app.userID
            HStack(alignment: .bottom, spacing: Space.s) {
                if mine { Spacer(minLength: 48) }
                VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                    Text(message.text)
                        .font(HDFont.body)
                        .foregroundStyle(mine ? Palette.paper : Palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(mine ? Palette.ink : Palette.card, in: BubbleShape(mine: mine))
                        .overlay(BubbleShape(mine: mine).strokeBorder(mine ? Color.clear : Palette.line, lineWidth: 1))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message.sentAt.friendlyDay == "Today" ? message.sentAt.clock : "\(message.sentAt.friendlyDay), \(message.sentAt.clock)")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkFaint)
                        .padding(.horizontal, 4)
                }
                if !mine { Spacer(minLength: 48) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(mine ? "You" : otherName), \(message.sentAt.friendlyDayTime): \(message.text)")
        }
    }

    // MARK: Composer

    private func composer(_ thread: MessageThread) -> some View {
        VStack(spacing: Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(quickReplies(thread), id: \.self) { line in
                        Chip(title: line) { send(line, in: thread) }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, 2)
            }
            .accessibilityLabel("Quick replies")

            HStack(alignment: .bottom, spacing: Space.s) {
                TextField("Message \(otherName(thread))", text: $draft, axis: .vertical)
                    .font(HDFont.body)
                    .lineLimit(1...5)
                    .focused($composing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    IconButton(symbol: "paperplane", label: "Send", filled: true, tint: Palette.lacquer) {
                        send(draft, in: thread)
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(Motion.spring, value: draft.isEmpty)
            .screenGutter()
        }
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(Palette.paper.opacity(0.94))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Hairline() }
    }

    private func send(_ text: String, in thread: MessageThread) {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !sending else { return }
        sending = true
        draft = ""
        Task {
            await app.send(line, in: thread)
            sending = false
        }
    }
}

/// A bubble with one tucked corner, so you can tell who's talking without reading.
struct BubbleShape: InsettableShape {
    var mine: Bool
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let big: CGFloat = 18, small: CGFloat = 5
        return UnevenRoundedRectangle(
            topLeadingRadius: big,
            bottomLeadingRadius: mine ? big : small,
            bottomTrailingRadius: mine ? small : big,
            topTrailingRadius: big,
            style: .continuous
        ).path(in: r)
    }

    func inset(by amount: CGFloat) -> BubbleShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

#Preview("Client thread") {
    NavigationStack { ThreadView(threadID: "th_1") }.environment(previewApp())
}

#Preview("Pro thread") {
    NavigationStack { ThreadView(threadID: "th_4") }.environment(previewApp(mode: .pro))
}
