import SwiftUI

/// Her profile: cover work, who she is, what she charges, her work, what other women said,
/// when she's free, and a sticky Book. Services can be picked right here.
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

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ProfileCover(items: Array(live.work.prefix(4)), seed: live.seed) { viewing = $0 }
                        identity(proxy: proxy)

                        VStack(alignment: .leading, spacing: Space.section) {
                            about
                            Hairline()
                            services
                            Hairline()
                            work
                            Hairline()
                            reviews
                            Hairline()
                            availability
                            HStack {
                                Spacer()
                                TertiaryButton(title: "Report or block", tint: Palette.inkFaint) { showReport = true }
                                Spacer()
                            }
                        }
                        .screenGutter()
                        .padding(.top, Space.section)
                        .padding(.bottom, Space.section)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .onAppear {
                    guard scrollToReviews else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        withAnimation(reduceMotion ? nil : Motion.springSlow) { proxy.scrollTo("reviews", anchor: .top) }
                    }
                }
            }

            floatingButtons
        }
        .paperBackground()
        .safeAreaInset(edge: .bottom) { stickyBar }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
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

    // MARK: Floating buttons

    private var floatingButtons: some View {
        HStack(spacing: Space.s) {
            IconButton(symbol: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            ShareLink(item: shareURL, message: Text(shareText)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Palette.card, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
            }
            .buttonStyle(PressLift(scale: 0.92))
            .accessibilityLabel("Share")

            IconButton(symbol: "heart", label: isFavourite ? "Saved" : "Save", filled: isFavourite, tint: isFavourite ? Palette.lacquer : Palette.ink) {
                withAnimation(reduceMotion ? nil : Motion.spring) { app.toggleFavourite(live) }
            }
            .symbolEffect(.bounce, value: isFavourite)
        }
        .screenGutter()
        .padding(.top, Space.s)
    }

    private var shareURL: URL { URL(string: "https://hairdone.app/pro/\(live.id)") ?? URL(string: "https://hairdone.app")! }
    private var shareText: String {
        "\(live.firstName), \(live.primaryCategory.specialtyTitle.lowercased()) in \(live.suburb), on Hair Done."
    }

    // MARK: Identity

    private func identity(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Avatar(name: live.firstName, seed: live.seed, size: 76)
                .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 4))
                .offset(y: -38)
                .padding(.bottom, -38)

            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(live.displayName)
                        .font(HDFont.title)
                        .foregroundStyle(Palette.ink)
                    if live.isVerified {
                        Button { Haptics.light(); showVerified = true } label: { VerifiedBadge() }
                            .buttonStyle(.plain)
                            .accessibilityHint("Explains the badge")
                    }
                }
                Text(live.specialtyLine)
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
            }

            Button {
                Haptics.light()
                withAnimation(reduceMotion ? nil : Motion.springSlow) { proxy.scrollTo("reviews", anchor: .top) }
            } label: {
                HStack(spacing: 8) {
                    RatingLine(rating: live.rating, count: live.reviewCount)
                    Text("·").foregroundStyle(Palette.inkFaint)
                    Text("\(distanceKm.distanceLabel) from you")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Jumps to reviews")

            Text(live.headline)
                .font(HDFont.serifItalic)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.xs)

            HStack(alignment: .top, spacing: Space.m) {
                Image(systemName: "car")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 20)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Comes to \(live.suburb) and \(Int(live.travelRadiusKm.rounded())) km around")
                        .font(HDFont.body)
                        .foregroundStyle(Palette.ink)
                    Text(live.travelFeeCents > 0 ? "Travel fee \(Money.format(live.travelFeeCents)), flat" : "No travel fee")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(.top, Space.xs)
            .accessibilityElement(children: .combine)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    if live.instantBook {
                        Button { Haptics.light(); showInstant = true } label: {
                            Tag(text: "Instant book", color: Palette.lacquer, background: Palette.lacquerSoft)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Explains instant book")
                    }
                    Tag(text: replyLabel)
                    if live.completedBookings > 0 {
                        Tag(text: "\(live.completedBookings) done")
                    }
                }
            }
            .padding(.top, Space.xs)

            if !live.instantBook {
                Text("\(live.firstName) confirms each booking herself. She usually replies within \(replyWithin).")
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .screenGutter()
    }

    private var replyLabel: String {
        let m = live.responseMinutes
        if m < 60 { return "Replies in about \(m) min" }
        let h = max(1, Int((Double(m) / 60).rounded()))
        return h == 1 ? "Replies in about an hour" : "Replies in about \(h) hours"
    }

    private var replyWithin: String {
        let m = live.responseMinutes
        if m < 60 { return "\(m) minutes" }
        let h = max(1, Int((Double(m) / 60).rounded()))
        return h == 1 ? "an hour" : "\(h) hours"
    }

    // MARK: About

    private var about: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "About", subtitle: "\(live.yearsExperience) years in")
            Text(live.bio)
                .font(HDFont.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(bioExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
            if !bioExpanded && live.bio.count > 140 {
                TertiaryButton(title: "More", tint: Palette.lacquer) {
                    withAnimation(reduceMotion ? nil : Motion.spring) { bioExpanded = true }
                }
                .padding(.horizontal, -8)
            }
        }
    }

    // MARK: Services

    private var services: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHeader(title: "Services", subtitle: "Pick as many as you like. She'll do them in one visit.")
                .padding(.bottom, Space.xs)
            ForEach(Array(live.services.enumerated()), id: \.element.id) { i, service in
                ProfileServiceRow(service: service, isSelected: selectedIDs.contains(service.id)) {
                    withAnimation(reduceMotion ? nil : Motion.spring) {
                        if selectedIDs.contains(service.id) { selectedIDs.remove(service.id) } else { selectedIDs.insert(service.id) }
                    }
                }
                if i < live.services.count - 1 { Hairline() }
            }
        }
    }

    // MARK: Work

    private var work: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SectionHeader(title: "Her work", subtitle: live.work.count == 1 ? "1 photo" : "\(live.work.count) photos")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                ForEach(live.work) { item in
                    Button {
                        Haptics.light()
                        viewing = item
                    } label: {
                        WorkTile(item: item, cornerRadius: 10)
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(PressLift(scale: 0.96))
                    .accessibilityLabel(item.caption)
                    .accessibilityHint("Opens the photo")
                }
            }
        }
    }

    // MARK: Reviews

    private var reviews: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SectionHeader(title: "Reviews")
                .id("reviews")

            if live.reviews.isEmpty {
                Text("No reviews yet. Someone has to go first.")
                    .font(HDFont.body)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    Text(live.rating.ratingLabel)
                        .font(HDFont.hero.monospacedDigit())
                        .foregroundStyle(Palette.ink)
                    VStack(alignment: .leading, spacing: 4) {
                        StarsRow(rating: Int(live.rating.rounded()), size: 14)
                        Text(live.reviewCount == 1 ? "1 review" : "\(live.reviewCount) reviews")
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .accessibilityElement(children: .combine)

                ForEach(live.reviews.prefix(3)) { review in
                    ProfileReviewCard(review: review, proName: live.firstName)
                }

                if live.reviews.count > 3 {
                    TertiaryButton(title: "All \(live.reviews.count) reviews", tint: Palette.lacquer) { showAllReviews = true }
                        .padding(.horizontal, -8)
                }
            }
        }
    }

    // MARK: Availability

    private var availability: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SectionHeader(title: "Next free")
            ProfileAvailabilityStrip(availability: live.availability)
        }
    }

    // MARK: Sticky bar

    private var stickyBar: some View {
        StickyBar(title: "Book", action: { showBooking = true }, leading: {
            VStack(alignment: .leading, spacing: 2) {
                if selectedServices.isEmpty {
                    Text("Pick a service")
                        .font(HDFont.subStrong)
                        .foregroundStyle(Palette.inkSoft)
                    Text("From \(Money.format(live.cheapestServiceCents))")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    Text("\(Money.format(totalCents)) · \(totalMinutes.minutesLabel)")
                        .font(HDFont.price)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(selectedServices.count == 1 ? "1 service" : "\(selectedServices.count) services")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        })
        .animation(reduceMotion ? nil : Motion.spring, value: selectedIDs.count)
    }
}

// MARK: - Cover

/// Her first four photos, staggered. Fewer than four and it fills with what's there.
private struct ProfileCover: View {
    var items: [WorkItem]
    var seed: Int
    var onTap: (WorkItem) -> Void

    private let height: CGFloat = 360
    private let gap: CGFloat = 3

    var body: some View {
        Group {
            if items.count >= 4 {
                HStack(spacing: gap) {
                    VStack(spacing: gap) {
                        tile(items[0]).frame(height: height * 0.58)
                        tile(items[2])
                    }
                    VStack(spacing: gap) {
                        tile(items[1])
                        tile(items[3]).frame(height: height * 0.58)
                    }
                }
            } else if items.count >= 2 {
                HStack(spacing: gap) {
                    tile(items[0])
                    tile(items[1])
                }
            } else if let first = items.first {
                tile(first)
            } else {
                Rectangle().fill(Placeholder.gradient(seed: seed))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .top) {
            LinearGradient(colors: [Color.black.opacity(0.22), Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Her work")
    }

    private func tile(_ item: WorkItem) -> some View {
        Button {
            Haptics.light()
            onTap(item)
        } label: {
            WorkTile(item: item, cornerRadius: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.caption)
        .accessibilityHint("Opens the photo")
    }
}

// MARK: - Service row

private struct ProfileServiceRow: View {
    var service: Service
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(alignment: .top, spacing: Space.m) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Palette.lacquer : Palette.line, lineWidth: 1.5)
                    Circle()
                        .fill(Palette.lacquer)
                        .scaleEffect(isSelected ? 1 : 0.01)
                        .opacity(isSelected ? 1 : 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.onLacquer)
                        .opacity(isSelected ? 1 : 0)
                }
                .frame(width: 24, height: 24)
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Space.s) {
                        Text(service.name)
                            .font(HDFont.bodyStrong)
                            .foregroundStyle(Palette.ink)
                        if service.isPopular {
                            Tag(text: "Popular", color: Palette.tintInk(.theLot), background: Palette.tint(.theLot))
                        }
                    }
                    if !service.detail.isEmpty {
                        Text(service.detail)
                            .font(HDFont.caption)
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(service.durationLabel)
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: Space.s)

                Text(service.priceLabel)
                    .font(HDFont.price)
                    .foregroundStyle(Palette.ink)
            }
            .padding(.vertical, Space.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Takes it off your booking" : "Adds it to your booking")
    }
}

// MARK: - Review card

private struct ProfileReviewCard: View {
    var review: Review
    var proName: String

    private var seed: Int {
        review.photoSeed ?? review.clientFirstName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                Avatar(name: review.clientFirstName, seed: seed, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(review.clientFirstName)
                        .font(HDFont.subStrong)
                        .foregroundStyle(Palette.ink)
                    HStack(spacing: 6) {
                        StarsRow(rating: review.rating)
                        Text(review.date.longDate)
                            .font(HDFont.caption)
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }

            Text(review.text)
                .font(HDFont.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !review.serviceName.isEmpty {
                Tag(text: review.serviceName)
            }

            if let reply = review.proReply {
                HStack(alignment: .top, spacing: Space.m) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Palette.lacquerSoft)
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(proName) replied").labelStyle()
                        Text(reply)
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, Space.s)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Work viewer

/// Full-screen pager over her photos. Swipe between, caption underneath, close top right.
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
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    VStack(spacing: Space.l) {
                        Spacer()
                        WorkTile(item: item, cornerRadius: Radius.card)
                            .aspectRatio(0.8, contentMode: .fit)
                            .padding(.horizontal, Space.gutter)
                        Text(item.caption)
                            .font(HDFont.serifItalic)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.xxl)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                Text("\(index + 1) of \(items.count)")
                    .font(HDFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                    .accessibilityLabel("Photo \(index + 1) of \(items.count)")
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            .screenGutter()
            .padding(.top, Space.s)
        }
    }
}

// MARK: - Availability strip

/// The next seven days. Days she works get a card and a lacquer dot.
private struct ProfileAvailabilityStrip: View {
    var availability: WeeklyAvailability

    private var days: [Date] { (0..<7).map { Date().startOfDay.adding(days: $0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                ForEach(days, id: \.self) { day in
                    let works = !availability.ranges(on: day).isEmpty
                    VStack(spacing: 4) {
                        Text(day.weekdayLetter)
                            .font(HDFont.label)
                            .foregroundStyle(works ? Palette.inkSoft : Palette.inkFaint)
                        Text(day.dayNumber)
                            .font(HDFont.subStrong.monospacedDigit())
                            .foregroundStyle(works ? Palette.ink : Palette.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(works ? Palette.card : Color.clear, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                            .strokeBorder(works ? Palette.line : Color.clear, lineWidth: 1)
                    )
                    .overlay(alignment: .bottom) {
                        if works {
                            Circle().fill(Palette.lacquer).frame(width: 4, height: 4).padding(.bottom, 6)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.friendlyDay), \(works ? "she works" : "off")")
                }
            }
            Text(nextFreeLine)
                .font(HDFont.sub)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nextFreeLine: String {
        let now = Date()
        for day in days {
            let ranges = availability.ranges(on: day)
            guard let first = ranges.first, let last = ranges.last else { continue }
            let start = day.startOfDay.adding(minutes: first.startMinutes)
            let end = day.startOfDay.adding(minutes: last.endMinutes)
            if Calendar.current.isDateInToday(day) {
                if end <= now { continue }
                return start > now ? "Today from \(first.clock(first.startMinutes))" : "Today until \(last.clock(last.endMinutes))"
            }
            return "\(day.friendlyDay) from \(first.clock(first.startMinutes))"
        }
        return "Nothing free this week. Message her."
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
                VStack(spacing: Space.m) {
                    ForEach(pro.reviews) { review in
                        ProfileReviewCard(review: review, proName: pro.firstName)
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
