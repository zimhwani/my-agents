import SwiftUI
import MapKit
import CoreLocation

/// The Home tab. It opens on one full-bleed photo of the pro who's coming today, or the nearest one free,
/// then who's free, categories, near you (list or map), book again and favourites.
/// Search sits behind the magnifier in the top bar. Every pro tap pushes `Route.pro`.
/// Layout follows docs/design/mockups/01-home and 02-home-scrolled.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var path: [Route] = []
    @State private var query = ""
    @State private var category: Category? = nil
    @State private var showMap = false
    /// 0 is today, 1 is tomorrow. Late at night the lists start on tomorrow.
    @State private var dayOffset = 0
    /// The magnifier was tapped: the bar shows the search field and the page shows results.
    @State private var showSearch = false
    @State private var showAllFree = false
    /// The top bar turns to paper once the hero has scrolled up under it.
    @State private var barSolid = false
    /// Where the top bar ends on screen, measured.
    @State private var barBottom: CGFloat = 100
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if inSearch {
                            searchResults
                                .padding(.top, barBottom + Space.l)
                        } else {
                            hero

                            if app.isLoadingPros && app.pros.isEmpty {
                                HomeSkeleton()
                                    .padding(.top, 32)
                            } else {
                                whosFree
                                    .padding(.top, 32)
                                categories
                                    .padding(.top, Space.section)
                                nearYou
                                    .padding(.top, 40)
                                bookAgain
                                favourites
                            }
                        }
                    }
                    .padding(.bottom, Space.section)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await app.loadPros() }
                // The hero runs under the status bar. The tab bar is a bottom inset, so the bottom is left alone.
                .ignoresSafeArea(edges: .top)

                topBar
            }
            .paperBackground()
            .onPreferenceChange(HomeBarBottomKey.self) { value in
                if value > 0, abs(value - barBottom) > 0.5 { barBottom = value }
            }
            .onPreferenceChange(HomeHeroBottomKey.self) { heroBottom in
                let solid = heroBottom < barBottom + 1
                if solid != barSolid {
                    withAnimation(reduceMotion ? nil : Motion.gentle) { barSolid = solid }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(reduceMotion ? nil : Motion.spring, value: category)
            .animation(reduceMotion ? nil : Motion.spring, value: showMap)
            .animation(reduceMotion ? nil : Motion.spring, value: inSearch)
            .animation(reduceMotion ? nil : Motion.spring, value: dayOffset)
            .onAppear { if isLate { dayOffset = 1 } }
            .sheet(isPresented: $showAllFree) { allFreeSheet }
            .hdDestinations()
        }
    }

    // MARK: Top bar

    /// "hair done." centred with the magnifier on the right. Clear over the hero, paper with a blur once
    /// the hero has gone under it. In search it holds the field and Cancel.
    private var topBar: some View {
        let solid = barSolid || inSearch
        return ZStack {
            if inSearch {
                HStack(spacing: Space.xs) {
                    HomeSearchField(text: $query, focused: $searchFocused)
                    TertiaryButton(title: "Cancel", tint: Palette.ink) { closeSearch() }
                }
                .padding(.horizontal, Space.gutter - 8)
                .padding(.leading, 8)
                .transition(.opacity)
            } else {
                Text("hair done.")
                    .font(HomeFont.wordmark)
                    .foregroundStyle(solid ? Palette.ink : HomeInk.paper)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Hair done")
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Spacer()
                    Button(action: openSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 19, weight: .light))
                            .foregroundStyle(solid ? Palette.ink : HomeInk.paper)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search")
                    .accessibilityHint("Search pros, services and suburbs")
                }
                .padding(.trailing, 9)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: inSearch ? 48 : 32)
        .padding(.bottom, 8)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: HomeBarBottomKey.self, value: geo.frame(in: .global).maxY)
            }
        }
        .background {
            ZStack(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial)
                Palette.paper.opacity(0.84)
                Rectangle().fill(Palette.ink.opacity(0.12)).frame(height: 0.5)
            }
            .opacity(solid ? 1 : 0)
            .ignoresSafeArea(edges: .top)
        }
    }

    private func openSearch() {
        Haptics.light()
        showSearch = true
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            searchFocused = true
        }
    }

    private func closeSearch() {
        searchFocused = false
        query = ""
        showSearch = false
    }

    // MARK: Hero

    private var hero: some View {
        let pick = heroPick
        let loading = app.isLoadingPros && app.pros.isEmpty
        let headline: String? = pick?.headline ?? (loading ? nil : "No one's near you yet.")
        var spoken = [eyebrowSpoken]
        if let headline { spoken.append(headline) }
        if let facts = pick?.facts { spoken.append(facts) }
        var onTap: (() -> Void)? = nil
        if let pro = pick?.pro {
            onTap = { open(pro) }
        }
        return HomeHero(
            item: pick?.pro.work.first,
            eyebrow: eyebrow,
            headline: headline,
            facts: pick?.facts,
            accessibilityText: spoken.joined(separator: ". "),
            onTap: onTap
        )
        // A new pro in the hero gets a fresh settle.
        .id(pick?.pro.id ?? "none")
    }

    private var hour: Int { Date().hourOfDay }
    private var isLate: Bool { hour >= 22 || hour < 5 }

    private var greetingWord: String {
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Late one"
        }
    }

    /// "Afternoon, Tash · Fitzroy North", set in tracked capitals on the photo.
    private var eyebrow: String {
        let name = app.firstName.trimmingCharacters(in: .whitespaces)
        let hello = name.isEmpty ? greetingWord : "\(greetingWord), \(name)"
        return "\(hello) · \(app.location.suburbGuess)"
    }

    private var eyebrowSpoken: String {
        locationOff ? "\(eyebrow). Location's off, showing \(app.location.suburbGuess)" : eyebrow
    }

    private var locationOff: Bool { app.location.hasAsked && !app.location.isAllowed }

    /// Her pro if she's booked today; otherwise the nearest pro who's free; otherwise the nearest pro.
    private var heroPick: HomeHeroPick? {
        if let next = app.nextBooking, next.isToday, let pro = app.pro(next.proID) {
            let minutes = next.start.hourOfDay * 60 + next.start.minuteOfHour
            let when = next.start.hourOfDay >= 17 ? "\(shortClock(minutes)) tonight" : "\(next.start.clock) today"
            let what = next.services.first?.name ?? "Your booking"
            return HomeHeroPick(pro: pro, headline: "\(pro.firstName), \(when).", facts: "\(what) · at yours in \(next.address.suburb)")
        }
        if let pro = freePros.first, let phrase = freePhrase(pro, on: listDay) {
            return HomeHeroPick(pro: pro, headline: "\(pro.firstName) is \(phrase).", facts: heroFacts(pro))
        }
        if let pro = sortedPros.first {
            return HomeHeroPick(pro: pro, headline: "\(pro.firstName), \(distance(pro).distanceLabel) away.", facts: heroFacts(pro))
        }
        return nil
    }

    /// "Nail tech · Brunswick · 2.9 km · BIAB $95"
    private func heroFacts(_ pro: Pro) -> String {
        var parts = [pro.primaryCategory.specialtyTitle, pro.suburb, distance(pro).distanceLabel]
        if let cheapest = pro.services.min(by: { $0.priceCents < $1.priceCents }) {
            parts.append("\(cheapest.name) \(cheapest.priceLabel)")
        }
        return parts.joined(separator: " · ")
    }

    /// "Nail tech · St Kilda · 13 km"
    private func nearFacts(_ pro: Pro) -> String {
        [pro.primaryCategory.specialtyTitle, pro.suburb, distance(pro).distanceLabel].joined(separator: " · ")
    }

    // MARK: Data

    private var here: CLLocationCoordinate2D { app.location.coordinate }

    private func distance(_ pro: Pro) -> Double { pro.distanceKm(from: here) }

    private var sortedPros: [Pro] {
        app.pros.sorted { distance($0) < distance($1) }
    }

    private var filteredPros: [Pro] {
        guard let category else { return sortedPros }
        return sortedPros.filter { $0.specialties.contains(category) }
    }

    private var listDay: Date { Date().startOfDay.adding(days: dayOffset) }

    /// "Free from 5 pm" today, "Free today" once she's already started, "Tomorrow from 9 am" for tomorrow.
    /// Nil when she isn't working that day or has finished for it.
    private func nextFreeLabel(_ pro: Pro, on day: Date) -> String? {
        let ranges = pro.availability.ranges(on: day)
        guard let first = ranges.first, let last = ranges.last else { return nil }
        let start = day.startOfDay.adding(minutes: first.startMinutes)
        let end = day.startOfDay.adding(minutes: last.endMinutes)
        let time = first.clock(first.startMinutes)
        if Calendar.current.isDateInToday(day) {
            if end <= Date() { return nil }
            return start > Date() ? "Free from \(time)" : "Free today"
        }
        return "Tomorrow from \(time)"
    }

    /// The same, as the mockup says it in a sentence: "free from 5", "free today", "free tomorrow from 9".
    private func freePhrase(_ pro: Pro, on day: Date) -> String? {
        let ranges = pro.availability.ranges(on: day)
        guard let first = ranges.first, let last = ranges.last else { return nil }
        let start = day.startOfDay.adding(minutes: first.startMinutes)
        let end = day.startOfDay.adding(minutes: last.endMinutes)
        let time = shortClock(first.startMinutes)
        if Calendar.current.isDateInToday(day) {
            if end <= Date() { return nil }
            return start > Date() ? "free from \(time)" : "free today"
        }
        return "free tomorrow from \(time)"
    }

    /// Minutes since midnight as the clock face says it: 1020 → "5", 1050 → "5:30".
    private func shortClock(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == 0 ? "\(h12)" : String(format: "%d:%02d", h12, m)
    }

    private var freePros: [Pro] {
        sortedPros.filter { nextFreeLabel($0, on: listDay) != nil }
    }

    /// Who's free, less the pro already on the hero (unless she's the only one).
    private var railPros: [Pro] {
        let heroID = heroPick?.pro.id
        let others = freePros.filter { $0.id != heroID }
        return others.isEmpty ? freePros : others
    }

    /// "8.4 km away, free from 3"
    private func whosFreeLine(_ pro: Pro) -> String {
        let phrase = freePhrase(pro, on: listDay) ?? "free today"
        return "\(distance(pro).distanceLabel) away, \(phrase)"
    }

    private var bookAgainItems: [HomeBookAgainItem] {
        var seen = Set<String>()
        var out: [HomeBookAgainItem] = []
        for b in app.pastBookings where b.status.isFinished {
            guard !seen.contains(b.proID), let pro = app.pro(b.proID), let service = b.services.first else { continue }
            seen.insert(b.proID)
            out.append(HomeBookAgainItem(pro: pro, line: "\(service.name) · \(b.start.shortDay)"))
        }
        return out
    }

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    private var inSearch: Bool { showSearch || isSearching }

    private var matches: [Pro] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return sortedPros.filter { pro in
            var hay = [pro.firstName, pro.displayName, pro.suburb, pro.headline]
            hay += pro.services.map(\.name)
            hay += pro.specialties.flatMap { [$0.label, $0.specialtyTitle] }
            return hay.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    private func open(_ pro: Pro) {
        searchFocused = false
        path.append(.pro(pro))
    }

    // MARK: Search

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isSearching {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("A name, a service or a suburb. Or start with one of these.")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, Space.s)
                    ForEach(Category.allCases) { c in
                        Button {
                            Haptics.selection()
                            category = c
                            closeSearch()
                        } label: {
                            Text(c.label)
                                .font(HomeFont.section)
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows \(c.label.lowercased()) pros near you")
                    }
                }
            } else if matches.isEmpty {
                EmptyState(
                    symbol: "magnifyingglass",
                    title: "Nothing for \"\(query.trimmingCharacters(in: .whitespaces))\".",
                    message: "Try a service or a suburb.",
                    actionTitle: "Clear",
                    action: { query = "" }
                )
            } else {
                ForEach(matches) { pro in
                    HomeProRow(pro: pro, eyebrow: nextFreeLabel(pro, on: listDay), facts: nearFacts(pro)) { open(pro) }
                    Hairline()
                }
            }
        }
        .screenGutter()
    }

    // MARK: Who's free

    private var whosFree: some View {
        let pros = railPros
        return VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayOffset == 0 ? "Who's free today" : "Who's free tomorrow")
                    .font(HomeFont.section)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Space.s)
                if !freePros.isEmpty {
                    Button {
                        Haptics.light()
                        showAllFree = true
                    } label: {
                        Text("See all")
                            .font(.system(.subheadline))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(dayOffset == 0 ? "See everyone free today" : "See everyone free tomorrow")
                }
            }
            .screenGutter()

            if pros.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(dayOffset == 0 ? "No one's free today. Tomorrow's looking better." : "No one's free tomorrow either. Everyone near you is in the list below.")
                        .font(HDFont.body)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if dayOffset == 0 {
                        TertiaryButton(title: "See tomorrow", tint: Palette.ink) { dayOffset = 1 }
                            .padding(.horizontal, -8)
                    }
                }
                .screenGutter()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.m) {
                        ForEach(pros) { pro in
                            HomePortraitTile(item: pro.work.first, width: 300, title: pro.firstName, line: whosFreeLine(pro), titleFont: HomeFont.railName) { open(pro) }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    // MARK: Categories

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Category.allCases) { c in
                    HomeCategoryTile(category: c, isSelected: category == c, isDimmed: category != nil && category != c) {
                        category = (category == c) ? nil : c
                    }
                }
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
    }

    // MARK: Near you

    private var nearYou: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .center) {
                Text(category.map { "\($0.label) near you" } ?? "Near you")
                    .font(HomeFont.section)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Space.s)
                Button {
                    Haptics.selection()
                    showMap.toggle()
                } label: {
                    Image(systemName: showMap ? "list.bullet" : "map")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -11)
                .accessibilityLabel(showMap ? "Show as a list" : "Show on a map")
            }
            .screenGutter()

            if let category {
                HStack(spacing: 0) {
                    Text("Showing \(category.label.lowercased()) only.")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                    TertiaryButton(title: "Show everything", tint: Palette.ink) { self.category = nil }
                }
                .screenGutter()
                .transition(.opacity)
            }

            if filteredPros.isEmpty {
                EmptyState(
                    symbol: "mappin.slash",
                    title: "No pros in \(app.location.suburbGuess) yet.",
                    message: "We're new here and adding more every week.",
                    actionTitle: category != nil ? "Everything" : (app.pros.isEmpty ? "Try again" : nil),
                    action: {
                        if category != nil { category = nil } else { Task { await app.loadPros() } }
                    }
                )
                .screenGutter()
            } else if showMap {
                HomeMap(pros: filteredPros, centre: here, onSelect: open)
                    .screenGutter()
                    .padding(.top, Space.xs)
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 44) {
                    ForEach(filteredPros) { pro in
                        HomeNearYouItem(pro: pro, eyebrow: nextFreeLabel(pro, on: listDay), facts: nearFacts(pro)) { open(pro) }
                    }
                }
                .padding(.top, Space.xs)
                .transition(.opacity)
            }
        }
    }

    // MARK: Book again

    @ViewBuilder
    private var bookAgain: some View {
        let items = bookAgainItems
        if !items.isEmpty {
            smallRail(title: "Book again") {
                ForEach(items) { item in
                    HomePortraitTile(item: item.pro.work.first, width: 160, title: item.pro.firstName, line: item.line, titleFont: HDFont.name) { open(item.pro) }
                }
            }
            .padding(.top, 48)
        }
    }

    // MARK: Favourites

    @ViewBuilder
    private var favourites: some View {
        let favs = app.favouritePros
        if !favs.isEmpty {
            smallRail(title: "Favourites") {
                ForEach(favs) { pro in
                    HomePortraitTile(item: pro.work.first, width: 160, title: pro.firstName, line: pro.specialtyLine, titleFont: HDFont.name) { open(pro) }
                }
            }
            .padding(.top, 48)
        }
    }

    private func smallRail<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(title)
                .font(HomeFont.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .screenGutter()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.m) {
                    content()
                }
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        }
    }

    // MARK: See all

    private var allFreeSheet: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: dayOffset == 0 ? "Free today" : "Free tomorrow",
                subtitle: "Closest first",
                onClose: { showAllFree = false }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(freePros) { pro in
                        HomeProRow(pro: pro, eyebrow: nextFreeLabel(pro, on: listDay), facts: nearFacts(pro)) { openFromSheet(pro) }
                        Hairline()
                    }
                }
                .screenGutter()
                .padding(.bottom, Space.xl)
            }
        }
        .paperBackground()
        .presentationDragIndicator(.visible)
    }

    private func openFromSheet(_ pro: Pro) {
        showAllFree = false
        Task {
            // Let the sheet get out of the way before the push.
            try? await Task.sleep(for: .milliseconds(350))
            path.append(.pro(pro))
        }
    }
}

/// Who the hero is about and what it says.
struct HomeHeroPick {
    var pro: Pro
    /// "Kiara is free from 5." or "Kiara, 6:15 tonight."
    var headline: String
    /// "Nail tech · Brunswick · 2.9 km · BIAB $95"
    var facts: String
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
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Palette.inkSoft)
            TextField("French tip, blow-dry, a suburb", text: $text)
                .font(HDFont.body)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel("Search pros, services and suburbs")
            if !text.isEmpty {
                Button {
                    Haptics.light()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .animation(Motion.gentle, value: text.isEmpty)
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
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Chip(title: "Recentre", symbol: "location") {
                withAnimation(Motion.spring) { position = HomeMap.home(centre) }
            }
            .padding(Space.m)
        }
    }

    private func pin(_ pro: Pro) -> some View {
        VStack(spacing: 3) {
            Avatar(name: pro.firstName, seed: pro.seed, size: 40)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5))
            Text(Money.format(pro.cheapestServiceCents))
                .font(HDFont.label)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        }
    }
}

// MARK: - Skeleton

/// Big grey photo blocks, breathing while pros load for the first time. The hero above it is already grey.
private struct HomeSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            block
                .frame(width: 190, height: 26)
                .screenGutter()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.m) {
                    ForEach(0..<2, id: \.self) { _ in block.frame(width: 300, height: 375) }
                }
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollDisabled(true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in block.frame(width: 128, height: 170) }
                }
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollDisabled(true)
            .padding(.top, Space.xl)
        }
        .opacity(pulse ? 0.5 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    private var block: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Palette.line)
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
