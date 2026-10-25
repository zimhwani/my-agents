import SwiftUI

/// One conversation. Yours on the right on the ink ground, theirs on the left on paper with a hairline, the
/// app's in the middle in small type. Squared bubbles, an underline composer, and quick replies
/// that fill the field instead of sending. A message that doesn't go stays, at 60%, with
/// "Didn't send. Tap to try again."
struct ThreadView: View {
    @Environment(AppState.self) private var app
    var threadID: String

    @State private var draft = ""
    @State private var pending: [PendingMessage] = []
    @State private var movingOn = false
    @FocusState private var composing: Bool

    /// A message on its way, or one that didn't make it.
    struct PendingMessage: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var failed = false
    }

    private var thread: MessageThread? { app.threads.first { $0.id == threadID } }
    private var isPro: Bool { app.mode == .pro }

    var body: some View {
        Group {
            if let thread {
                conversation(thread)
            } else {
                EmptyState(title: "We couldn't find that one.", message: "It might be on your other side. Check Inbox there.")
                    .frame(maxHeight: .infinity, alignment: .top)
                    .paperBackground()
                    .hdNavHeader()
            }
        }
    }

    // MARK: Lookups

    private func booking(for thread: MessageThread) -> Booking? {
        app.bookings.first { $0.id == thread.bookingID } ?? app.proBookings.first { $0.id == thread.bookingID }
    }

    private func otherName(_ thread: MessageThread) -> String {
        isPro ? app.clientName(thread.clientID) : (app.pro(thread.proID)?.firstName ?? "Your pro")
    }

    /// On the pro side a client's name can still be on its way; show nothing rather than "Client".
    private func knownName(_ thread: MessageThread) -> String? {
        if isPro && !app.isClientNameKnown(thread.clientID) { return nil }
        return otherName(thread)
    }

    /// The pro's cover for the client side; nil on the pro side (clients have initials).
    private func otherPhoto(_ thread: MessageThread) -> WorkItem? {
        guard !isPro, let pro = app.pro(thread.proID) else { return nil }
        return pro.work.first(where: { $0.isPinned }) ?? pro.work.first
    }

    /// Six quick replies. The client set is from the copy deck; the pro set is written in the same
    /// voice. "On my way" only shows once she really is (the strip has the real button before that).
    private func quickReplies(_ thread: MessageThread) -> [String] {
        let linked = booking(for: thread)
        if isPro {
            var lines = [
                "Running 5 minutes late, sorry",
                "Which unit is it?",
                "Parked, coming up now",
                "Thank you, it was lovely",
                "Same again in three weeks?"
            ]
            if linked?.status == .onHerWay { lines.insert("On my way, there in 10", at: 0) }
            return lines
        }
        let unit = linked?.address.line1.unitNumber
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
            if app.isOffline { OfflineBar() }
            if let linked { bookingStrip(linked) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Space.s) {
                        if linked?.status == .requested && !isPro {
                            Text("Phone numbers are shared once they've confirmed.")
                                .font(HDFont.caption)
                                .foregroundStyle(Palette.inkSoft)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Space.s)
                        }
                        ForEach(thread.messages) { message in
                            bubble(message, otherName: name)
                                .id(message.id)
                        }
                        ForEach(pending) { p in
                            pendingBubble(p, in: thread)
                                .id(p.id.uuidString)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .screenGutter()
                    .padding(.top, Space.l)
                    .padding(.bottom, Space.s)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: thread.messages.count + pending.count) { _, _ in
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
        }
        .paperBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer(thread)
        }
        // The avatar sits beside the name, centred with it; a shimmer stands in for a name still on its way.
        .hdNavHeader(knownName(thread), showsHairline: linked == nil, titleMark: AnyView(
            HStack(spacing: Space.s) {
                Avatar(name: name, seed: isPro ? thread.clientID.hdSeed : (app.pro(thread.proID)?.seed ?? 0), size: 28,
                       photo: otherPhoto(thread))
                if knownName(thread) == nil { SkeletonBlock(width: 72, height: 14) }
            }
        ))
        .animation(Motion.gentle, value: app.isOffline)
        .onAppear {
            app.markRead(thread)
            app.hideTabBar("thread")
            app.openThreadID = thread.id
        }
        .onDisappear {
            app.showTabBar("thread")
            if app.openThreadID == thread.id { app.openThreadID = nil }
        }
        .onChange(of: thread.messages.count) { _, _ in app.markRead(thread) }
        // No live connection yet: on the real backend an open thread looks for new messages every 8 seconds.
        .task(id: thread.id) {
            guard app.isLive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                if Task.isCancelled { break }
                await app.refreshThread(thread.id)
            }
        }
    }

    /// The booking this thread belongs to, pinned under the header. Tap to open it. On the pro side,
    /// on the day of a confirmed job, the real `On my way` sits here (not a quick reply).
    private func bookingStrip(_ booking: Booking) -> some View {
        let pro = app.pro(booking.proID)
        let statusWord = isPro ? booking.status.proLabel : booking.status.label
        return VStack(spacing: Space.s) {
            NavigationLink(value: isPro ? Route.proBooking(booking.id) : Route.booking(booking.id)) {
                HStack(spacing: Space.m) {
                    if !isPro {
                        BookingPhoto(item: booking.coverItem(pro: pro))
                            .frame(width: 36, height: 45)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(booking.servicesLine) · \(booking.start.friendlyDayTime)")
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            if !booking.status.isCancelled {
                                Circle().fill(booking.status == .requested ? Palette.warn : Palette.success)
                                    .frame(width: 6, height: 6)
                                    .accessibilityHidden(true)
                            }
                            Text("\(booking.address.suburb) · \(statusWord)")
                                .font(HDFont.caption)
                                .foregroundStyle(Palette.inkSoft)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.inkFaint)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the booking")

            if isPro && booking.status == .confirmed && booking.isToday {
                InkButton(title: "On my way", isLoading: movingOn, isEnabled: !app.isOffline, compact: true) {
                    movingOn = true
                    Task {
                        _ = await app.update(booking, to: .onHerWay)
                        movingOn = false
                    }
                }
            }
        }
        .screenGutter()
        .padding(.vertical, Space.m)
        .background(Palette.paper)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
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
            bubbleBody(text: message.text, mine: mine, caption: timeLabel(message.sentAt))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(mine ? "You" : otherName), \(message.sentAt.friendlyDayTime): \(message.text)")
        }
    }

    private func pendingBubble(_ p: PendingMessage, in thread: MessageThread) -> some View {
        Button {
            guard p.failed else { return }
            retry(p, in: thread)
        } label: {
            bubbleBody(text: p.text, mine: true, caption: p.failed ? "Didn't send. Tap to try again." : "Sending…")
                .opacity(0.6)
        }
        .buttonStyle(.plain)
        .disabled(!p.failed)
        .accessibilityLabel(p.failed ? "Didn't send: \(p.text)" : "Sending: \(p.text)")
        .accessibilityHint(p.failed ? "Tries again" : "")
    }

    private func bubbleBody(text: String, mine: Bool, caption: String) -> some View {
        HStack(alignment: .bottom, spacing: Space.s) {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(HDFont.body)
                    .foregroundStyle(mine ? Palette.onInk : Palette.ink)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    // The ink ground, not `Palette.ink` (cream in dark), with its edge for dark paper.
                    .background(mine ? Palette.inkGround : Palette.paper, in: BubbleShape(mine: mine))
                    .overlay(BubbleShape(mine: mine).strokeBorder(mine ? Palette.inkEdge : Palette.line, lineWidth: mine ? 0.5 : 1))
                    .fixedSize(horizontal: false, vertical: true)
                Text(caption)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, 2)
            }
            if !mine { Spacer(minLength: 48) }
        }
    }

    private func timeLabel(_ date: Date) -> String {
        date.friendlyDay == "Today" ? date.clock : "\(date.friendlyDay), \(date.clock)"
    }

    // MARK: Composer

    private var hasText: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func composer(_ thread: MessageThread) -> some View {
        VStack(spacing: Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(quickReplies(thread), id: \.self) { line in
                        OptionBox(title: line, isSelected: false) {
                            draft = line
                            composing = true
                        }
                        .fixedSize()
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, 2)
            }
            .accessibilityLabel("Quick replies. They fill the message, ready to send.")

            HStack(alignment: .bottom, spacing: Space.m) {
                TextField(knownName(thread).map { "Message \($0)" } ?? "Message", text: $draft, axis: .vertical)
                    .font(HDFont.body)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.ink)
                    .lineLimit(1...5)
                    .focused($composing)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(composing ? Palette.ink : Palette.line).frame(height: composing ? 2 : 1)
                    }
                sendButton(thread)
            }
            .screenGutter()
        }
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(Palette.paper)
        .overlay(alignment: .top) { Hairline(strong: true) }
    }

    private func sendButton(_ thread: MessageThread) -> some View {
        let ready = hasText && !app.isOffline
        return Button {
            guard ready else { return }
            Haptics.light()
            send(draft, in: thread)
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 17, weight: ready ? .regular : .light))
                .foregroundStyle(ready ? Palette.onInk : Palette.inkFaint)
                .frame(width: 32, height: 32)
                .background(ready ? Palette.inkGround : Color.clear, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(ready ? Palette.inkEdge : Color.clear, lineWidth: 0.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.92))
        .disabled(!ready)
        .animation(Motion.spring, value: ready)
        .accessibilityLabel("Send")
    }

    private func send(_ text: String, in thread: MessageThread) {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        let p = PendingMessage(text: line)
        withAnimation(Motion.gentle) { pending.append(p) }
        draft = ""
        deliver(p, in: thread)
    }

    private func retry(_ p: PendingMessage, in thread: MessageThread) {
        guard !app.isOffline, let i = pending.firstIndex(where: { $0.id == p.id }) else { return }
        Haptics.light()
        pending[i].failed = false
        deliver(pending[i], in: thread)
    }

    private func deliver(_ p: PendingMessage, in thread: MessageThread) {
        Task { @MainActor in
            let sent = await app.send(p.text, in: thread)
            withAnimation(Motion.gentle) {
                if sent {
                    pending.removeAll { $0.id == p.id }
                } else if let i = pending.firstIndex(where: { $0.id == p.id }) {
                    pending[i].failed = true
                }
            }
        }
    }
}

/// A squared bubble with one tucked corner, so you can tell who's talking without reading.
struct BubbleShape: InsettableShape {
    var mine: Bool
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let big: CGFloat = 6, small: CGFloat = 2
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
