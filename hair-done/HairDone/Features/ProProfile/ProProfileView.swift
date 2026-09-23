import SwiftUI

/// Her profile: her best work edge to edge with her name on it, then the facts, her words,
/// a plain price list, her work, what other women said, when she's next free,
/// and an ink Book bar that has the bottom of the screen to itself (the tab bar steps aside).
/// Services can be picked right here and go straight into the booking flow.
struct ProProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pro: Pro
    var scrollToReviews: Bool = false

    @State private var selectedIDs: Set<String> = []
    @State private var bioExpanded = false
    @State private var viewing: WorkItem? = nil
    @State private var showAllReviews = false
    @State private var showReport = false
    @State private var showBooking = false
    @State private var showVerified = false
    @State private var showInstant = false

    /// The freshest copy of her, so a review you just left shows up.
    private var live: Pro { app.pro(pro.id) ?? pro }
    private var selectedServices: [Service] { live.services.filter { selectedIDs.contains($0.id) } }
    private var totalCents: Int { selectedServices.reduce(0) { $0 + $1.priceCents } }
    private var totalMinutes: Int { selectedServices.reduce(0) { $0 + $1.minutes } }
    private var isFavourite: Bool { app.isFavourite(live) }
    private var distanceKm: Double { live.distanceKm(from: app.location.coordinate) }
    private var nextFree: Date? { ProfileNextFree.start(in: live.availability) }

    /// Her pinned photo if she has one, else her first.
    private var heroItem: WorkItem? { live.work.first(where: { $0.isPinned }) ?? live.work.first }

    /// Where the reviews marker lands when we scroll to it: clear of the status bar and the floating controls.
    private var reviewsAnchor: UnitPoint { UnitPoint(x: 0.5, y: 0.13) }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero

                        VStack(alignment: .leading, spacing: 0) {
                            facts(proxy: proxy)
                                .padding(.top, 20)
                            bio
                                .padding(.top, 14)
                            services
                                .padding(.top, 24)
                            if !live.work.isEmpty {
                                work
                                    .padding(.top, Space.section)
                            }
                            reviews
                                .padding(.top, Space.section)
                            availability
                            HStack {
                                Spacer()
                                TertiaryButton(title: "Report or block", tint: Palette.inkFaint) { showReport = true }
                                Spacer()
                            }
                            .padding(.top, Space.xl)
                        }
                        .screenGutter()
                        .padding(.bottom, Space.xl)
                    }
                }
                .coordinateSpace(.named(ProfileSpace.scroll))
                .ignoresSafeArea(edges: .top)
                .onAppear {
                    guard scrollToReviews else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        withAnimation(reduceMotion ? nil : Motion.springSlow) {
                            proxy.scrollTo(ProfileSpace.reviews, anchor: reviewsAnchor)
                        }
                    }
                }
            }

            floatingControls
        }
        .paperBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) { bookBar }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { app.hidesTabBar = true }
        .onDisappear { app.hidesTabBar = false }
        .fullScreenCover(item: $viewing) { item in
            ProfileWorkViewer(items: live.work, current: item)
        }
        .fullScreenCover(isPresented: $showBooking) {
            BookingFlowView(pro: live, preselected: selectedServices, onBooked: { _ in selectedIDs = [] })
        }
        .sheet(isPresented: $showAllReviews) { ProfileAllReviewsSheet(pro: live) }
        .sheet(isPresented: $showReport) { ProfileReportSheet(pro: live) }
        .sheet(isPresented: $showVerified) {
            ProfileExplainerSheet(title: "ID checked", text: "Hair Done has seen her ID and ABN. Reviews only come from completed bookings.")
        }
        .sheet(isPresented: $showInstant) {
            ProfileExplainerSheet(title: "Instant book", text: "Book a free slot and it's confirmed straight away. No waiting on a reply.")
        }
    }

    // MARK: Hero

    /// Her best photo, full bleed and 4:5, running up under the status bar. It stretches when you pull down.
    /// Her name and headline sit on it in paper serif over a soft ink scrim.
    private var hero: some View {
        Color.clear
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Button {
                    if let item = heroItem {
                        Haptics.light()
                        viewing = item
                    }
                } label: {
                    ProfileHeroPhoto(item: heroItem, seed: live.seed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(heroItem?.caption ?? "Her work")
                .accessibilityHint(heroItem == nil ? "" : "Opens her photos")
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: ProfileTone.inkFixed.opacity(0.38), location: 0),
                        .init(color: ProfileTone.inkFixed.opacity(0), location: 0.28),
                        .init(color: ProfileTone.inkFixed.opacity(0), location: 0.5),
                        .init(color: ProfileTone.inkFixed.opacity(0.35), location: 0.74),
                        .init(color: ProfileTone.inkFixed.opacity(0.66), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) { heroTitle }
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(live.displayName)
                .font(ProfileType.heroName)
                .tracking(-0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !live.headline.isEmpty {
                Text(live.headline)
                    .font(HDFont.serifItalic)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.95)
            }
        }
        .foregroundStyle(ProfileTone.onPhoto)
        .shadow(color: ProfileTone.inkFixed.opacity(0.25), radius: 10, x: 0, y: 1)
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, 28)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Floating controls

    /// Back on the left, save and share on the right: paper icons in small ink circles so they read on any photo.
    private var floatingControls: some View {
        HStack(spacing: 2) {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                ProfileRoundIcon(symbol: "chevron.left", weight: .medium)
            }
            .buttonStyle(PressLift(scale: 0.92))
            .accessibilityLabel("Back")

            Spacer()

            Button {
                Haptics.light()
                withAnimation(reduceMotion ? nil : Motion.spring) { app.toggleFavourite(live) }
            } label: {
                ProfileRoundIcon(
                    symbol: isFavourite ? "heart.fill" : "heart",
                    tint: isFavourite ? Palette.lacquer : ProfileTone.onPhoto
                )
                .symbolEffect(.bounce, value: isFavourite)
            }
            .buttonStyle(PressLift(scale: 0.92))
            .accessibilityLabel(isFavourite ? "Saved" : "Save")
            .accessibilityHint(isFavourite ? "Takes her off your saved list" : "Keeps her in your saved list")

            ShareLink(item: shareURL, message: Text(shareText)) {
                ProfileRoundIcon(symbol: "square.and.arrow.up")
            }
            .buttonStyle(PressLift(scale: 0.92))
            .accessibilityLabel("Share")
        }
        .padding(.horizontal, 13)
        .padding(.top, 2)
    }

    private var shareURL: URL { URL(string: "https://hairdone.app/pro/\(live.id)") ?? URL(string: "https://hairdone.app")! }
    private var shareText: String {
        "\(live.firstName), \(live.primaryCategory.specialtyTitle.lowercased()) in \(live.suburb), on Hair Done."
    }

    // MARK: Facts

    private var whatAndWhere: String {
        let place = live.primaryCategory == .theLot
            ? "Does the lot around \(live.suburb)"
            : "\(live.primaryCategory.specialtyTitle) in \(live.suburb)"
        return "\(place) · \(distanceKm.distanceLabel) from you"
    }

    /// "Nail tech in Brunswick · 2.9 km from you" over "☆ 4.9 · 212 reviews · ID checked".
    private func facts(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(whatAndWhere)
                .font(HDFont.sub)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    ratingButton(proxy: proxy)
                    if live.isVerified {
                        Text(" · ")
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                            .accessibilityHidden(true)
                        verifiedButton
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    ratingButton(proxy: proxy)
                    if live.isVerified { verifiedButton }
                }
            }
        }
    }

    private func ratingButton(proxy: ScrollViewProxy) -> some View {
        Button {
            Haptics.light()
            withAnimation(reduceMotion ? nil : Motion.springSlow) {
                proxy.scrollTo(ProfileSpace.reviews, anchor: reviewsAnchor)
            }
        } label: {
            HStack(spacing: 0) {
                if live.reviewCount > 0 {
                    Image(systemName: "star")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Palette.ink)
                        .padding(.trailing, 3)
                    Text(live.rating.ratingLabel)
                        .font(HDFont.sub.monospacedDigit())
                        .foregroundStyle(Palette.ink)
                    Text(live.reviewCount == 1 ? " · 1 review" : " · \(live.reviewCount) reviews")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    Text("New here, no reviews yet")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .lineLimit(1)
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(live.reviewCount > 0
            ? "Rated \(live.rating.ratingLabel) out of 5 from \(live.reviewCount) reviews"
            : "No reviews yet")
        .accessibilityHint(live.reviewCount > 0 ? "Jumps to reviews" : "")
    }

    private var verifiedButton: some View {
        Button {
            Haptics.light()
            showVerified = true
        } label: {
            Text("ID checked")
                .font(HDFont.sub)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .fixedSize()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ID checked")
        .accessibilityHint("Explains what we checked")
    }

    // MARK: Bio

    /// Her own words in serif. Long ones show whole sentences first, with More at the end.
    @ViewBuilder
    private var bio: some View {
        if !live.bio.isEmpty {
            if !bioExpanded, let preview = ProfileBio.preview(live.bio) {
                Button {
                    Haptics.light()
                    withAnimation(reduceMotion ? nil : Motion.spring) { bioExpanded = true }
                } label: {
                    (Text(preview).font(ProfileType.bio)
                        + Text("  More").font(HDFont.sub).foregroundColor(Palette.inkSoft))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preview)
                .accessibilityHint("Shows the rest")
            } else {
                Text(live.bio)
                    .font(ProfileType.bio)
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Services

    private var travelLine: String {
        live.travelFeeCents > 0 ? "Travel fee \(Money.format(live.travelFeeCents)), flat" : "No travel fee"
    }

    private var replyWithin: String {
        let m = live.responseMinutes
        if m < 60 { return "\(m) min" }
        let h = max(1, Int((Double(m) / 60).rounded()))
        return h == 1 ? "an hour" : "\(h) hours"
    }

    /// A plain price list: name on the left, duration and price on the right, hairlines between.
    private var services: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text("Services").profileEyebrow()
                Spacer(minLength: 0)
                Text(travelLine)
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.bottom, 10)

            if live.services.isEmpty {
                ProfileRule()
                Text("She hasn't listed her services yet. Message her to ask.")
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, Space.l)
            } else {
                ForEach(live.services) { service in
                    ProfileRule()
                    ProfileServiceRow(service: service, isSelected: selectedIDs.contains(service.id)) {
                        withAnimation(reduceMotion ? nil : Motion.spring) {
                            if selectedIDs.contains(service.id) { selectedIDs.remove(service.id) } else { selectedIDs.insert(service.id) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Comes to you within \(Int(live.travelRadiusKm.rounded())) km of \(live.suburb).")
                if live.instantBook {
                    Button {
                        Haptics.light()
                        showInstant = true
                    } label: {
                        (Text("Instant book").underline() + Text(", and she replies in about \(replyWithin)."))
                            .multilineTextAlignment(.leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Explains instant book")
                } else {
                    Text("\(live.firstName) confirms each booking herself, usually within \(replyWithin).")
                }
            }
            .font(HDFont.caption)
            .foregroundStyle(Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.m)
        }
    }

    // MARK: Work

    private var work: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Her work").profileEyebrow()
                Spacer(minLength: 0)
                Text(live.work.count == 1 ? "1 photo" : "\(live.work.count) photos")
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(live.work) { item in
                    Button {
                        Haptics.light()
                        viewing = item
                    } label: {
                        WorkTile(item: item, cornerRadius: 2)
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(PressLift(scale: 0.97))
                    .accessibilityLabel(item.caption)
                    .accessibilityHint("Opens the photo")
                }
            }
        }
    }

    // MARK: Reviews

    private var reviews: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Zero-height marker the rating line and `scrollToReviews` scroll to.
            Color.clear.frame(height: 1).id(ProfileSpace.reviews)

            HStack(alignment: .firstTextBaseline) {
                Text("Reviews").profileEyebrow()
                Spacer(minLength: 0)
                if live.reviewCount > 0 {
                    Text("\(live.rating.ratingLabel) · \(live.reviewCount == 1 ? "1 review" : "\(live.reviewCount) reviews")")
                        .font(HDFont.caption.monospacedDigit())
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(.bottom, 10)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if live.reviews.isEmpty {
                ProfileRule()
                Text("No reviews yet. Someone has to go first.")
                    .font(ProfileType.quote)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, 18)
            } else {
                ForEach(live.reviews.prefix(3)) { review in
                    ProfileRule()
                    ProfileReviewQuote(review: review, proName: live.firstName)
                        .padding(.vertical, 18)
                }
                if live.reviews.count > 3 {
                    ProfileRule()
                    Button {
                        Haptics.light()
                        showAllReviews = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("All \(live.reviews.count) reviews")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .font(HDFont.sub.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Availability

    /// One quiet line: when she's next free.
    private var availability: some View {
        VStack(spacing: 0) {
            ProfileRule()
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text("Next free").profileEyebrow()
                Spacer(minLength: 0)
                Text(ProfileNextFree.sectionLine(nextFree))
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Space.l)
            .accessibilityElement(children: .combine)
            ProfileRule()
        }
    }

    // MARK: Book bar

    private var barPrice: String {
        if !selectedServices.isEmpty {
            return "\(Money.format(totalCents)) · \(ProfileDuration.label(totalMinutes))"
        }
        return live.services.isEmpty ? "" : "from \(Money.format(live.cheapestServiceCents))"
    }

    private var barAccessibilityLabel: String {
        var parts: [String] = [live.firstName]
        if selectedServices.isEmpty {
            if !live.services.isEmpty { parts.append("from \(Money.format(live.cheapestServiceCents))") }
        } else {
            let count = selectedServices.count == 1 ? "1 service" : "\(selectedServices.count) services"
            parts.append("\(count), \(Money.format(totalCents)), \(totalMinutes.minutesLabel)")
        }
        if let line = ProfileNextFree.barLine(nextFree) { parts.append(line) }
        return parts.joined(separator: ", ")
    }

    /// Ink, paper text, her name and price on the left, a squared paper Book on the right.
    private var bookBar: some View {
        HStack(spacing: Space.l) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(live.firstName)
                        .font(ProfileType.barName)
                        .lineLimit(1)
                    if !barPrice.isEmpty {
                        Text(barPrice)
                            .font(HDFont.sub.monospacedDigit())
                            .opacity(0.7)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .contentTransition(.numericText())
                    }
                }
                if let line = ProfileNextFree.barLine(nextFree) {
                    Text(line)
                        .font(HDFont.caption)
                        .opacity(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(ProfileTone.paperOnInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(barAccessibilityLabel)

            Button {
                Haptics.medium()
                showBooking = true
            } label: {
                Text("Book")
                    .font(HDFont.bodyStrong)
                    .foregroundStyle(ProfileTone.inkFixed)
                    .padding(.horizontal, Space.l)
                    .frame(minWidth: 116, minHeight: 44)
                    .background(ProfileTone.paperOnInk, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .buttonStyle(PressLift())
            .accessibilityLabel(selectedServices.isEmpty ? "Book \(live.firstName)" : "Book \(live.firstName), \(Money.format(totalCents))")
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, 10)
        .background(ProfileTone.inkGround.ignoresSafeArea(edges: .bottom))
        .animation(reduceMotion ? nil : Motion.spring, value: selectedIDs)
    }
}

// MARK: - Tokens

private enum ProfileSpace {
    static let scroll = "profileScroll"
    static let reviews = "reviews"
}

/// The few fixed colours this screen needs beyond the palette: ink that stays ink in dark mode,
/// paper for type on ink and photos, and the stronger hairline from the price list mockup.
private enum ProfileTone {
    static let inkFixed = Color(hex: 0x241A16)
    static let inkGround = Palette.dyn(light: 0x241A16, dark: 0x2E231E)
    static let paperOnInk = Color(hex: 0xF4ECE4)
    static let onPhoto = Color(hex: 0xFBF7F2)
    static let viewerGround = Color(hex: 0x171210)
    static let lineStrong = Palette.dyn(light: 0xDDD2C5, dark: 0x3A302B)
}

private enum ProfileType {
    /// ~48 regular serif for her name on the hero; grows with Dynamic Type, capped so it stays one line.
    static var heroName: Font {
        let size = min(UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 48), 64)
        return Font.system(size: size, weight: .regular, design: .serif)
    }
    /// 19 regular serif for her bio.
    static var bio: Font {
        Font.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 19), weight: .regular, design: .serif)
    }
    /// 19 regular serif for review pull quotes.
    static var quote: Font {
        Font.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 19), weight: .regular, design: .serif)
    }
    /// 21 regular serif for her first name in the Book bar.
    static var barName: Font {
        Font.system(size: UIFontMetrics(forTextStyle: .title3).scaledValue(for: 21), weight: .regular, design: .serif)
    }
}

private extension View {
    /// Small tracked uppercase marker, "SERVICES".
    func profileEyebrow() -> some View {
        self.font(HDFont.eyebrow)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Palette.inkSoft)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The price list's hairline, a touch stronger than `Hairline` so it reads on paper.
private struct ProfileRule: View {
    var body: some View {
        Rectangle().fill(ProfileTone.lineStrong).frame(height: 1)
    }
}

/// "1 h 15", "1 h", "45 min".
private enum ProfileDuration {
    static func label(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h " + String(format: "%02d", m)
    }
}

/// Whole sentences from the start of a long bio, so "More" lands after a full stop.
private enum ProfileBio {
    static func preview(_ text: String, limit: Int = 140) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > limit + 20 else { return nil }
        var result = ""
        var sentence = ""
        for ch in t {
            sentence.append(ch)
            if ch == "." || ch == "!" || ch == "?" {
                if result.count + sentence.count > limit { break }
                result += sentence
                sentence = ""
            }
        }
        let whole = result.trimmingCharacters(in: .whitespaces)
        if whole.count >= 40 { return whole }
        // No sentence ends early enough: cut at a word.
        let cut = t.prefix(limit)
        if let space = cut.lastIndex(of: " ") { return String(cut[..<space]) + "…" }
        return String(cut) + "…"
    }
}

/// When she's next free: an hour's notice today, else the first hour she works in the next week.
/// A guide only; the slot picker in the booking flow has the real answer.
private enum ProfileNextFree {
    static func start(in availability: WeeklyAvailability, now: Date = Date()) -> Date? {
        let today = now.startOfDay
        let step = max(15, availability.stepMinutes)
        for offset in 0..<7 {
            let day = today.adding(days: offset)
            let ranges = availability.ranges(on: day).sorted { $0.startMinutes < $1.startMinutes }
            for range in ranges {
                var from = range.startMinutes
                if offset == 0 {
                    let earliest = now.hourOfDay * 60 + now.minuteOfHour + 60
                    let rounded = ((earliest + step - 1) / step) * step
                    from = max(from, rounded)
                }
                if from + 30 <= range.endMinutes { return day.adding(minutes: from) }
            }
        }
        return nil
    }

    /// "Free today from 5:00 pm". Nil when she has nothing this week.
    static func barLine(_ date: Date?) -> String? {
        guard let date else { return nil }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Free today from \(date.clock)" }
        if cal.isDateInTomorrow(date) { return "Free tomorrow from \(date.clock)" }
        return "Next free \(date.weekday.long) from \(date.clock)"
    }

    /// "Today from 5:00 pm".
    static func sectionLine(_ date: Date?) -> String {
        guard let date else { return "Nothing free this week. Message her." }
        return "\(date.friendlyDay) from \(date.clock)"
    }
}

// MARK: - Hero photo

/// Fills the hero frame; when you pull down past the top it grows upward instead of leaving a gap.
private struct ProfileHeroPhoto: View {
    var item: WorkItem?
    var seed: Int

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(ProfileSpace.scroll)).minY
            let stretch = max(0, minY)
            Group {
                if let item {
                    WorkTile(item: item, cornerRadius: 0)
                } else {
                    Rectangle().fill(Placeholder.gradient(seed: seed))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height + stretch)
            .offset(y: -stretch)
        }
    }
}

// MARK: - Round icon

/// A paper icon in a small ink circle at 70%, for controls that sit on photos.
private struct ProfileRoundIcon: View {
    var symbol: String
    var tint: Color = ProfileTone.onPhoto
    var weight: Font.Weight = .regular

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: weight))
            .foregroundStyle(tint)
            .frame(width: 38, height: 38)
            .background(Circle().fill(ProfileTone.inkFixed.opacity(0.7)))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

// MARK: - Service row

private struct ProfileServiceRow: View {
    var service: Service
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(service.name)
                        .font(HDFont.body)
                        .fontWeight(isSelected ? Font.Weight.semibold : Font.Weight.regular)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.lacquer)
                            .transition(.opacity)
                    }
                }
                Spacer(minLength: Space.m)
                Text(ProfileDuration.label(service.minutes))
                    .font(HDFont.sub.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.trailing, 22)
                Text(service.priceLabel)
                    .font(HDFont.body.monospacedDigit())
                    .fontWeight(isSelected ? Font.Weight.semibold : Font.Weight.regular)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: 44, alignment: .trailing)
            }
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(service.name), \(service.minutes.minutesLabel), \(service.priceLabel)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "Takes it off your booking" : "Adds it to your booking")
    }
}

// MARK: - Review quote

/// A review set as a serif pull quote with one line of attribution under it.
private struct ProfileReviewQuote: View {
    var review: Review
    var proName: String

    private var attribution: String {
        var parts: [String] = [review.clientFirstName]
        if !review.serviceName.isEmpty { parts.append(review.serviceName) }
        parts.append(review.date.longDate)
        if review.rating < 5 { parts.append("\(review.rating) of 5") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\u{201C}\(review.text)\u{201D}")
                .font(ProfileType.quote)
                .foregroundStyle(Palette.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(attribution)
                .font(HDFont.caption)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if let reply = review.proReply, !reply.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(proName) replied")
                        .font(HDFont.caption.weight(.medium))
                        .foregroundStyle(Palette.inkSoft)
                    Text(reply)
                        .font(HDFont.italicSub)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, Space.m)
                .overlay(alignment: .leading) {
                    Rectangle().fill(ProfileTone.lineStrong).frame(width: 1)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Work viewer

/// Full-screen ink pager over her photos. Swipe between, caption in paper serif underneath, close top right.
private struct ProfileWorkViewer: View {
    var items: [WorkItem]
    var current: WorkItem

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(items: [WorkItem], current: WorkItem) {
        self.items = items
        self.current = current
        _index = State(initialValue: items.firstIndex(where: { $0.id == current.id }) ?? 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ProfileTone.viewerGround.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    VStack(spacing: Space.l) {
                        Spacer(minLength: 0)
                        WorkTile(item: item, cornerRadius: 2)
                            .aspectRatio(0.8, contentMode: .fit)
                        Text(item.caption)
                            .font(HDFont.italicSub)
                            .foregroundStyle(ProfileTone.paperOnInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.xxl)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                Text("\(index + 1) of \(items.count)")
                    .font(HDFont.caption.monospacedDigit())
                    .foregroundStyle(ProfileTone.paperOnInk.opacity(0.6))
                    .accessibilityLabel("Photo \(index + 1) of \(items.count)")
                Spacer()
                Button {
                    Haptics.light()
                    dismiss()
                } label: {
                    ProfileRoundIcon(symbol: "xmark", weight: .medium)
                }
                .buttonStyle(PressLift(scale: 0.92))
                .accessibilityLabel("Close")
            }
            .padding(.leading, Space.gutter)
            .padding(.trailing, 13)
            .padding(.top, 2)
        }
        .statusBarHidden()
    }
}

// MARK: - Sheets

/// One short paragraph and a Got it. For the verified badge and instant book.
private struct ProfileExplainerSheet: View {
    var title: String
    var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SheetHeader(title: title, onClose: { dismiss() })
            Text(text)
                .font(HDFont.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .screenGutter()
            PrimaryButton(title: "Got it") { dismiss() }
                .screenGutter()
            Spacer()
        }
        .paperBackground()
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

private struct ProfileAllReviewsSheet: View {
    var pro: Pro
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Reviews",
                subtitle: "\(pro.rating.ratingLabel) · \(pro.reviewCount == 1 ? "1 review" : "\(pro.reviewCount) reviews")",
                onClose: { dismiss() }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(pro.reviews) { review in
                        ProfileRule()
                        ProfileReviewQuote(review: review, proName: pro.firstName)
                            .padding(.vertical, 18)
                    }
                }
                .screenGutter()
                .padding(.vertical, Space.m)
            }
        }
        .paperBackground()
        .presentationDragIndicator(.visible)
    }
}

/// Report or block. Report asks why, block asks once.
private struct ProfileReportSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var pro: Pro

    enum Mode { case pick, report }
    @State private var mode: Mode = .pick
    @State private var reason: String? = nil
    @State private var note = ""
    @State private var confirmBlock = false

    private let reasons = [
        "Photos aren't her work",
        "Asked me to pay outside the app",
        "Didn't show up",
        "Made me uncomfortable",
        "Something else"
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: mode == .pick ? "Report or block" : "Report \(pro.firstName)",
                subtitle: mode == .report ? "Tell us what happened" : nil,
                onClose: { dismiss() }
            )

            ScrollView {
                switch mode {
                case .pick:
                    VStack(spacing: 0) {
                        NavRow(symbol: "flag", title: "Report \(pro.firstName)") {
                            withAnimation(reduceMotion ? nil : Motion.spring) { mode = .report }
                        }
                        Hairline()
                        NavRow(symbol: "hand.raised", title: "Block \(pro.firstName)", tint: Palette.lacquer) {
                            confirmBlock = true
                        }
                    }
                    .card(padding: Space.m)
                    .screenGutter()
                    .padding(.top, Space.s)
                    .transition(.opacity)

                case .report:
                    VStack(alignment: .leading, spacing: Space.l) {
                        VStack(spacing: 0) {
                            ForEach(Array(reasons.enumerated()), id: \.element) { i, r in
                                Button {
                                    Haptics.selection()
                                    reason = r
                                } label: {
                                    HStack {
                                        Text(r).font(HDFont.body).foregroundStyle(Palette.ink)
                                        Spacer()
                                        Image(systemName: reason == r ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundStyle(reason == r ? Palette.lacquer : Palette.inkFaint)
                                    }
                                    .frame(minHeight: 48)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(reason == r ? .isSelected : [])
                                if i < reasons.count - 1 { Hairline() }
                            }
                        }
                        .card(padding: Space.m)

                        HDTextField(label: "", placeholder: "Only we see this.", text: $note, axis: .vertical)

                        PrimaryButton(title: "Send report", isEnabled: reason != nil) {
                            app.show("Sent. A person reads every one, and we'll get back to you within two days.")
                            dismiss()
                        }
                    }
                    .screenGutter()
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.section)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .paperBackground()
        .presentationDetents(mode == .pick ? [.height(300)] : [.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Block \(pro.firstName)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                app.show("Blocked.")
                dismiss()
            }
            Button("Leave it", role: .cancel) { }
        } message: {
            Text("She won't show up for you and can't message you. She won't be told.")
        }
    }
}

// MARK: - Previews

#Preview("Profile") {
    NavigationStack {
        ProProfileView(pro: MockData.pros[0])
    }
    .environment(previewApp())
}

#Preview("Straight to reviews") {
    NavigationStack {
        ProProfileView(pro: MockData.pros[1], scrollToReviews: true)
    }
    .environment(previewApp())
}
