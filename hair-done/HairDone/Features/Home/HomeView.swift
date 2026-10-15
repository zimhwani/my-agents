import SwiftUI
import MapKit
import CoreLocation

/// The Home tab. Greeting, search, a waiting pro request (if she's a pro), next booking, who's free,
/// categories, near you (list or map), book again, favourites. Every pro tap pushes `Route.pro`.
/// She never sees her own pro profile in any of these lists.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Kept on AppState so switching sides and back lands her where she was.
    private var path: Binding<NavigationPath> { app.path(for: ClientTab.home) }
    @State private var query = ""
    /// The query the current results are for, so a half-typed word doesn't flash "Nothing for…".
    @State private var searchedQuery = ""
    @State private var category: Category? = nil
    @State private var showMap = false
    /// 0 is today, 1 is tomorrow. Late at night the lists start on tomorrow.
    @State private var dayOffset = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    VStack(alignment: .leading, spacing: Space.m) {
                        header
                        if app.isOffline { OfflineBar() }
                    }

                    if isSearching {
                        searchResults
                    } else {
                        requestBanner

                        if let next = app.nextBooking {
                            HomeNextUpCard(booking: next, pro: app.pro(next.proID)) {
                                app.selectedTab = .bookings
                                app.pendingRoute = .booking(next.id)
                            }
                            .screenGutter()
                        }

                        if app.isLoadingPros && app.pros.isEmpty {
                            HomeSkeleton()
                        } else if app.prosLoadFailed && app.pros.isEmpty {
                            ErrorState(title: "Couldn't load who's near.", message: "Check your connection.") {
                                Task { await app.loadPros() }
                            }
                        } else {
                            whosFree
                            categories
                            nearYou
                            bookAgain
                            favourites
                        }
                    }
                }
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await app.loadPros() }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
            .animation(reduceMotion ? nil : Motion.spring, value: category)
            .animation(reduceMotion ? nil : Motion.spring, value: showMap)
            .animation(reduceMotion ? nil : Motion.spring, value: isSearching)
            .animation(reduceMotion ? nil : Motion.spring, value: dayOffset)
            .animation(Motion.gentle, value: app.isOffline)
            .onAppear { if isLate { dayOffset = 1 } }
            .onChange(of: category) { _, new in
                Task { await app.loadWhosFree(category: new) }
            }
            .task(id: query) { await runSearch() }
            .receivesPendingRoutes(path) { $0.isPro }
            .hdDestinations()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            MonogramMark(size: 22)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: 6) {
                    Image(systemName: locationOff ? "location.slash" : "mappin")
                        .font(.system(size: 10, weight: .regular))
                    Text(suburbLine)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .eyebrowStyle()
                .accessibilityElement(children: .combine)

                greetingText
                    .font(HDFont.display)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(greeting)
                    .accessibilityAddTraits(.isHeader)
            }

            HomeSearchField(text: $query, focused: $searchFocused)
        }
        .screenGutter()
    }

    private var hour: Int { Date().hourOfDay }
    private var isLate: Bool { hour >= 22 || hour < 5 }

    private var greeting: String {
        let name = app.firstName.trimmingCharacters(in: .whitespaces)
        switch hour {
        case 5..<12: return name.isEmpty ? "Morning." : "Morning, \(name)."
        case 12..<17: return name.isEmpty ? "Afternoon." : "Afternoon, \(name)."
        case 17..<22: return "Who's free tonight."
        default: return "Late one. Here's tomorrow."
        }
    }

    /// The greeting with her name in italic: the one word on Home the serif leans on.
    private var greetingText: Text {
        let name = app.firstName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, hour >= 5, hour < 17 else { return Text(greeting) }
        let part = hour < 12 ? "Morning, " : "Afternoon, "
        return Text(part) + Text(name).italic() + Text(".")
    }

    private var locationOff: Bool { app.location.hasAsked && !app.location.isAllowed }

    private var suburbLine: String {
        locationOff ? "Location's off. Showing \(app.location.suburbGuess)." : app.location.suburbGuess
    }

    // MARK: Data

    private var here: CLLocationCoordinate2D { app.location.coordinate }
    private var selfID: String? { app.proSelf?.id }

    private func distance(_ pro: Pro) -> Double { pro.distanceKm(from: here) }

    /// Never her own pro profile, never someone she's blocked.
    private func listable(_ pro: Pro) -> Bool {
        pro.id != selfID && !app.blockedIDs.contains(pro.id)
    }

    private var sortedPros: [Pro] {
        app.pros.filter(listable).sorted { distance($0) < distance($1) }
    }

    private func inCategory(_ pro: Pro) -> Bool {
        guard let category else { return true }
        return pro.specialties.contains(category)
    }

    private var filteredPros: [Pro] { sortedPros.filter(inCategory) }

    /// Who's free today, from her real slots on the server, soonest first.
    private var freeToday: [HomeFreePro] {
        app.whosFree.compactMap { entry -> HomeFreePro? in
            guard let pro = app.pro(entry.key), listable(pro), inCategory(pro) else { return nil }
            return HomeFreePro(pro: pro, from: entry.value)
        }
        .sorted { $0.from == $1.from ? distance($0.pro) < distance($1.pro) : $0.from < $1.from }
    }

    /// Late at night: who works tomorrow, from her hours. The time step has the real slots.
    private var workingTomorrow: [HomeFreePro] {
        let tomorrow = Date().startOfDay.adding(days: 1)
        return filteredPros.compactMap { pro -> HomeFreePro? in
            guard let first = pro.availability.ranges(on: tomorrow).first else { return nil }
            return HomeFreePro(pro: pro, from: tomorrow.adding(minutes: first.startMinutes))
        }
    }

    private var freeList: [HomeFreePro] { dayOffset == 0 ? freeToday : workingTomorrow }

    /// "Free from 5 pm" from her real first free time today; "Works tomorrow from 9 am" late at night.
    private func eyebrow(for pro: Pro) -> String? {
        if dayOffset == 0 {
            guard let from = app.whosFree[pro.id] else { return nil }
            return from <= Date() ? "Free now" : "Free from \(from.spokenClock)"
        }
        let tomorrow = Date().startOfDay.adding(days: 1)
        guard let first = pro.availability.ranges(on: tomorrow).first else { return nil }
        return "Works tomorrow from \(tomorrow.adding(minutes: first.startMinutes).spokenClock)"
    }

    /// "1.2 km away, free from 5 pm"
    private func freeLine(_ item: HomeFreePro) -> String {
        let away = "\(distance(item.pro).distanceLabel) away"
        if dayOffset == 0 {
            return item.from <= Date() ? "\(away), free now" : "\(away), free from \(item.from.spokenClock)"
        }
        return "\(away), works from \(item.from.spokenClock)"
    }

    private var bookAgainItems: [HomeBookAgainItem] {
        var seen = Set<String>()
        var out: [HomeBookAgainItem] = []
        for b in app.pastBookings where b.status.isFinished {
            guard !seen.contains(b.proID), let pro = app.pro(b.proID), listable(pro), let service = b.services.first else { continue }
            seen.insert(b.proID)
            out.append(HomeBookAgainItem(pro: pro, line: "\(service.name) · \(b.start.shortDay)"))
        }
        return out
    }

    private func open(_ pro: Pro) {
        searchFocused = false
        path.wrappedValue.append(Route.pro(pro))
    }

    // MARK: Search: on the server, across every bookable pro

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmedQuery.isEmpty }

    /// Waits for her to stop typing (about 300 ms), then asks the server. Offline, the loaded list is searched instead.
    private func runSearch() async {
        let q = trimmedQuery
        guard q.count >= 2 else {
            await app.search("")
            searchedQuery = q
            return
        }
        guard !app.isOffline else {
            searchedQuery = q
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await app.search(q)
        guard !Task.isCancelled else { return }
        searchedQuery = q
    }

    /// Offline only: what's already loaded.
    private var localMatches: [Pro] {
        let q = trimmedQuery
        return sortedPros.filter { pro in
            var hay = [pro.firstName, pro.displayName, pro.suburb, pro.headline]
            hay += pro.services.map(\.name)
            hay += pro.specialties.flatMap { [$0.label, $0.specialtyTitle] }
            return hay.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    private var results: [Pro] {
        app.isOffline ? localMatches : app.searchResults.filter(listable)
    }

    private var resultsAreCurrent: Bool { searchedQuery == trimmedQuery && !app.isSearching }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(app.isOffline ? "Offline. Searching who's loaded near \(app.location.suburbGuess)." : "Searching all of Melbourne")
                .font(HDFont.caption)
                .foregroundStyle(Palette.inkSoft)
                .screenGutter()

            if trimmedQuery.count < 2 {
                Text("Keep typing. A name, a service or a suburb.")
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
                    .screenGutter()
            } else if !resultsAreCurrent && !app.isOffline {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in RowSkeleton(photo: CGSize(width: 96, height: 120)) }
                }
                .screenGutter()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Searching")
            } else if results.isEmpty {
                EmptyState(
                    title: "Nothing for \"\(trimmedQuery)\".",
                    message: "Try a service or a suburb.",
                    actionTitle: "Clear",
                    action: { query = "" }
                )
            } else {
                VStack(spacing: Space.l) {
                    ForEach(results) { pro in
                        HomeProRow(pro: pro, eyebrow: dayOffset == 0 ? eyebrow(for: pro) : nil, distanceKm: distance(pro)) { open(pro) }
                    }
                }
                .screenGutter()
            }
        }
    }

    // MARK: A request waiting on her pro side

    /// She's a pro, in booking mode, and a client is waiting on an answer. One tap takes her there.
    @ViewBuilder
    private var requestBanner: some View {
        if app.mode == .client, app.proSelf != nil,
           let request = app.openRequests.first(where: { app.requestDeadline($0) > Date() }) {
            HomeRequestBanner(
                request: request,
                clientName: app.clientName(request.clientID),
                deadline: app.requestDeadline(request)
            ) {
                app.selectedProTab = .today
                app.pendingRoute = .proBooking(request.id)
                app.switchMode(.pro)
            }
            .screenGutter()
        }
    }

    // MARK: Who's free

    private var whosFree: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            homeSection(dayOffset == 0 ? "Who's free today" : "Working tomorrow")

            if freeList.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(emptyFreeLine)
                        .font(HDFont.body)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if dayOffset == 0 && category == nil {
                        TertiaryButton(title: "See tomorrow", tint: Palette.ink) { dayOffset = 1 }
                            .padding(.horizontal, -8)
                    } else if category != nil {
                        TertiaryButton(title: "Clear the filter", tint: Palette.ink) { category = nil }
                            .padding(.horizontal, -8)
                    }
                }
                .screenGutter()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(freeList) { item in
                            HomePortraitTile(item: item.pro.homeCover, width: 150, title: item.pro.firstName, line: freeLine(item)) { open(item.pro) }
                        }
                    }
                    .screenGutter()
                }
            }
        }
    }

    private var emptyFreeLine: String {
        if let category {
            return dayOffset == 0
                ? "No one in \(category.label.lowercased()) is free today."
                : "No one in \(category.label.lowercased()) works tomorrow."
        }
        return dayOffset == 0 ? "No one's free today. Tomorrow's looking better." : "No one's working tomorrow either. Everyone near you is in the list below."
    }

    // MARK: Categories

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Category.allCases) { c in
                    HomeCategoryTile(category: c, isSelected: category == c, isDimmed: category != nil && category != c) {
                        category = (category == c) ? nil : c
                    }
                }
            }
            .screenGutter()
        }
    }

    // MARK: Near you

    private var nearYouTitle: some View {
        Text(category.map { "\($0.label) near you" } ?? "Near you")
            .font(HDFont.section)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var nearYouControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            if category != nil {
                TertiaryButton(title: "Clear", tint: Palette.ink) { category = nil }
                    .padding(.horizontal, -8)
                    .accessibilityLabel("Clear the filter")
            }
            TextTabs(selection: $showMap, options: [false, true]) { $0 ? "Map" : "List" }
        }
    }

    private var nearYou: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    nearYouTitle
                    Spacer(minLength: Space.m)
                    nearYouControls
                }
                VStack(alignment: .leading, spacing: 0) {
                    nearYouTitle
                    nearYouControls
                }
            }
            .screenGutter()

            if filteredPros.isEmpty {
                EmptyState(
                    title: category.map { "No \($0.label.lowercased()) pros in \(app.location.suburbGuess) yet." } ?? "No pros in \(app.location.suburbGuess) yet.",
                    message: "We're new here and adding more every week.",
                    actionTitle: category != nil ? "Clear the filter" : nil,
                    action: clearFilter
                )
            } else if showMap {
                HomeMap(pros: filteredPros, centre: here, onSelect: open)
                    .screenGutter()
                    .transition(.opacity)
            } else {
                VStack(spacing: Space.l) {
                    ForEach(filteredPros) { pro in
                        HomeProRow(pro: pro, eyebrow: eyebrow(for: pro), distanceKm: distance(pro)) { open(pro) }
                    }
                }
                .screenGutter()
                .transition(.opacity)
            }
        }
    }

    /// Clears the category, when there is one.
    private var clearFilter: (() -> Void)? {
        guard category != nil else { return nil }
        return { category = nil }
    }

    /// A section title in serif.
    private func homeSection(_ title: String) -> some View {
        Text(title)
            .font(HDFont.section)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .screenGutter()
    }

    // MARK: Book again

    @ViewBuilder
    private var bookAgain: some View {
        let items = bookAgainItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.l) {
                homeSection("Book again")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(items) { item in
                            HomePortraitTile(item: item.pro.homeCover, width: 120, title: item.pro.firstName, line: item.line) { open(item.pro) }
                        }
                    }
                    .screenGutter()
                }
            }
        }
    }

    // MARK: Favourites

    @ViewBuilder
    private var favourites: some View {
        let favs = app.favouritePros.filter(listable)
        if !favs.isEmpty {
            VStack(alignment: .leading, spacing: Space.l) {
                homeSection("Favourites")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(favs) { pro in
                            HomePortraitTile(item: pro.homeCover, width: 120, title: pro.firstName, line: pro.specialtyLine) { open(pro) }
                        }
                    }
                    .screenGutter()
                }
            }
        }
    }
}

/// A pro in Who's free, with when she's free from.
private struct HomeFreePro: Identifiable {
    var pro: Pro
    var from: Date
    var id: String { pro.id }
}

/// One tile in "Book again": the pro and the last thing she did for you.
private struct HomeBookAgainItem: Identifiable {
    var pro: Pro
    var line: String
    var id: String { pro.id }
}

// MARK: - Search field

private struct HomeSearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Palette.ink)
                .accessibilityHidden(true)
            TextField("French tip, blow-dry, a suburb", text: $text)
                .font(HDFont.body)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel("Search pros, services and suburbs")
            if !text.isEmpty {
                IconButton(symbol: "xmark", label: "Clear search") { text = "" }
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.ink).frame(height: 1)
        }
        .animation(Motion.gentle, value: text.isEmpty)
    }
}

// MARK: - Request banner

/// Any open request, with Open. An ink row, like the Pro mode signal. With an hour or more left it
/// says when to answer by ("Ruby wants a gel set, Sat 2:00 pm. Answer by 4:10 pm."); under an hour it
/// gets the warn dot and counts down ("48 min to answer.") while she looks at it.
private struct HomeRequestBanner: View {
    var request: Booking
    var clientName: String
    var deadline: Date
    var action: () -> Void

    private func isUrgent(now: Date) -> Bool { deadline.timeIntervalSince(now) < 60 * 60 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(alignment: .center, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if isUrgent(now: context.date) {
                            Circle().fill(Palette.warn).frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                        }
                        Text(isUrgent(now: context.date) ? "Pro mode · Answer soon" : "Pro mode")
                            .eyebrowStyle(color: Palette.onInkSoft)
                    }
                    Text(line(now: context.date))
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.onInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Space.s)
                Button {
                    Haptics.light()
                    action()
                } label: {
                    Text("Open")
                        .font(HDFont.subMedium)
                        .foregroundStyle(Palette.inkGround)
                        .padding(.horizontal, Space.l)
                        .frame(minWidth: 64, minHeight: 44)
                        .background(Palette.onInk, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
                .buttonStyle(PressLift())
                .accessibilityLabel("Open the request")
            }
            .inkBlock(padding: Space.l)
            .accessibilityElement(children: .combine)
        }
    }

    private var who: String { clientName == "Client" || clientName.isEmpty ? "A client" : clientName }

    /// "a gel set", "a BIAB overlay", "an eyelash lift", "a gel set and 1 more"
    private var what: String {
        guard let first = request.services.first else { return "a booking" }
        let name = first.name.prefix(2).allSatisfy(\.isUppercase) ? first.name : first.name.lowercasedFirst
        let article = name.first.map { "aeiouAEIOU".contains($0) } == true ? "an" : "a"
        let more = request.services.count > 1 ? " and \(request.services.count - 1) more" : ""
        return "\(article) \(name)\(more)"
    }

    private var when: String {
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(request.start) { day = "today" }
        else if cal.isDateInTomorrow(request.start) { day = "tomorrow" }
        else { day = request.start.weekday.short }
        return "\(day) \(request.start.clock)"
    }

    /// "48 min to answer" under an hour; "Answer by 4:10 pm" otherwise.
    private func left(now: Date) -> String {
        guard isUrgent(now: now) else { return "Answer by \(deadline.clock)" }
        let minutes = max(1, Int(deadline.timeIntervalSince(now) / 60))
        return "\(minutes) min to answer"
    }

    private func line(now: Date) -> String {
        "\(who) wants \(what), \(when). \(left(now: now))."
    }
}

// MARK: - Map

private struct HomeMap: View {
    var pros: [Pro]
    var centre: CLLocationCoordinate2D
    var onSelect: (Pro) -> Void

    @State private var position: MapCameraPosition

    init(pros: [Pro], centre: CLLocationCoordinate2D, onSelect: @escaping (Pro) -> Void) {
        self.pros = pros
        self.centre = centre
        self.onSelect = onSelect
        _position = State(initialValue: HomeMap.home(centre))
    }

    private static func home(_ centre: CLLocationCoordinate2D) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: centre, latitudinalMeters: 9000, longitudinalMeters: 9000))
    }

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(pros) { pro in
                Annotation(pro.displayName, coordinate: pro.coordinate, anchor: .bottom) {
                    Button {
                        Haptics.light()
                        onSelect(pro)
                    } label: {
                        pin(pro)
                    }
                    .buttonStyle(PressLift(scale: 0.92))
                    .accessibilityLabel("\(pro.displayName), from \(Money.format(pro.cheapestServiceCents))")
                    .accessibilityHint("Opens her profile")
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .frame(height: 440)
        .clipShape(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Button {
                Haptics.light()
                withAnimation(Motion.spring) { position = HomeMap.home(centre) }
            } label: {
                Image(systemName: "location")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressLift(scale: 0.92))
            .accessibilityLabel("Recentre")
            .padding(Space.s)
        }
    }

    /// Her cover at 36 by 45 with a paper edge, and her price on a small paper label.
    private func pin(_ pro: Pro) -> some View {
        VStack(spacing: 3) {
            HomePhoto(item: pro.homeCover)
                .frame(width: 36, height: 45)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.photo, style: .continuous)
                        .strokeBorder(Palette.paper, lineWidth: 1.5)
                )
            Text("from \(Money.format(pro.cheapestServiceCents))")
                .font(HDFont.caption.monospacedDigit())
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }
}

// MARK: - Skeleton

/// Home loading for the first time, in the real shapes: 4:5 Who's free tiles, the category photos,
/// then Near you rows.
private struct HomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            VStack(alignment: .leading, spacing: Space.l) {
                SkeletonBlock(width: 180, height: 24)
                HStack(alignment: .top, spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in TileSkeleton(width: 150) }
                }
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Space.s) {
                        SkeletonBlock(width: 104, height: 130)
                        SkeletonBlock(width: 52, height: 12)
                    }
                }
            }
            VStack(alignment: .leading, spacing: Space.s) {
                SkeletonBlock(width: 120, height: 24)
                ForEach(0..<3, id: \.self) { _ in RowSkeleton(photo: CGSize(width: 96, height: 120)) }
            }
        }
        .padding(.leading, Space.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

// MARK: - Previews

#Preview("Home") {
    HomeView().environment(previewApp())
}

#Preview("Loading") {
    let app = previewApp()
    app.pros = []
    app.isLoadingPros = true
    return HomeView().environment(app)
}
