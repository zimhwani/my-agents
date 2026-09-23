import SwiftUI
import MapKit
import CoreLocation

/// The Home tab. Greeting, search, next booking, who's free, categories, near you (list or map),
/// book again, favourites. Every pro tap pushes `Route.pro`.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var path: [Route] = []
    @State private var query = ""
    @State private var category: Category? = nil
    @State private var showMap = false
    /// 0 is today, 1 is tomorrow. Late at night the lists start on tomorrow.
    @State private var dayOffset = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header
                        .reveal()

                    if isSearching {
                        searchResults
                    } else {
                        if let next = app.nextBooking {
                            HomeNextUpCard(booking: next, pro: app.pro(next.proID)) {
                                app.selectedTab = .bookings
                            }
                            .screenGutter()
                            .reveal(delay: 0.06)
                        }

                        if app.isLoadingPros && app.pros.isEmpty {
                            HomeSkeleton().screenGutter()
                        } else {
                            whosFree.reveal(delay: 0.12)
                            categories.reveal(delay: 0.18)
                            nearYou.reveal(delay: 0.24)
                            bookAgain
                            favourites
                        }
                    }
                }
                .padding(.top, Space.l)
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
            .onAppear { if isLate { dayOffset = 1 } }
            .hdDestinations()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: 6) {
                    Image(systemName: locationOff ? "location.slash" : "location")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                    Text(suburbLine)
                        .labelStyle()
                        .lineLimit(2)
                }
                .accessibilityElement(children: .combine)

                greetingText
                    .font(HDFont.display)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            HomeSearchField(text: $query, focused: $searchFocused)
        }
        .screenGutter()
    }

    private var hour: Int { Date().hourOfDay }
    private var isLate: Bool { hour >= 22 || hour < 5 }

    private var firstName: String { app.firstName.trimmingCharacters(in: .whitespaces) }

    private var greeting: String {
        let name = firstName
        switch hour {
        case 5..<12: return name.isEmpty ? "Morning." : "Morning, \(name)."
        case 12..<17: return name.isEmpty ? "Afternoon." : "Afternoon, \(name)."
        case 17..<22: return "Who's free tonight."
        default: return "Late one. Here's tomorrow."
        }
    }

    /// The greeting with her name leaning in italic: the one italic word on this screen.
    private var greetingText: Text {
        let name = firstName
        guard !name.isEmpty else { return Text(greeting) }
        switch hour {
        case 5..<12: return Text("Morning, ") + Text(name).italic() + Text(".")
        case 12..<17: return Text("Afternoon, ") + Text(name).italic() + Text(".")
        default: return Text(greeting)
        }
    }

    private var locationOff: Bool { app.location.hasAsked && !app.location.isAllowed }

    private var suburbLine: String {
        locationOff ? "Location's off. Showing \(app.location.suburbGuess)." : app.location.suburbGuess
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

    private var freePros: [Pro] {
        sortedPros.filter { nextFreeLabel($0, on: listDay) != nil }
    }

    /// "1.2 km away, free from 5 pm"
    private func whosFreeLine(_ pro: Pro) -> String {
        let label = nextFreeLabel(pro, on: listDay) ?? "Free today"
        let lowered = label.prefix(1).lowercased() + String(label.dropFirst())
        return "\(distance(pro).distanceLabel) away, \(lowered)"
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
        VStack(alignment: .leading, spacing: Space.xxl) {
            if matches.isEmpty {
                EmptyState(
                    symbol: "magnifyingglass",
                    title: "Nothing for \"\(query.trimmingCharacters(in: .whitespaces))\".",
                    message: "Try a service or a suburb.",
                    actionTitle: "Clear",
                    action: { query = "" }
                )
                .screenGutter()
            } else {
                ForEach(matches) { pro in
                    ProCard(pro: pro, distanceKm: distance(pro), nextFree: nextFreeLabel(pro, on: listDay)) { open(pro) }
                }
            }
        }
    }

    // MARK: Who's free

    private var whosFree: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SectionHeader(title: dayOffset == 0 ? "Who's free today" : "Who's free tomorrow")
                .screenGutter()

            if freePros.isEmpty {
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
                        ForEach(freePros) { pro in
                            ProMiniTile(pro: pro, line: whosFreeLine(pro)) { open(pro) }
                        }
                    }
                    .screenGutter()
                }
            }
        }
    }

    // MARK: Categories

    /// The six categories as serif words in a row, the chosen one underlined. A magazine's section index.
    private var categories: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.xl) {
                    ForEach(Category.allCases) { c in
                        HomeCategoryWord(category: c, isSelected: category == c) {
                            category = (category == c) ? nil : c
                        }
                    }
                }
                .screenGutter()
            }
            if category == .theLot {
                Text("Hair, makeup, nails. For events.")
                    .font(HDFont.italicSub)
                    .foregroundStyle(Palette.inkSoft)
                    .screenGutter()
                    .transition(.opacity)
            }
        }
    }

    // MARK: Near you

    private var nearYou: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.map { "\($0.label) near you" } ?? "Near you")
                        .font(HDFont.heading)
                        .foregroundStyle(Palette.ink)
                    Text("Closest first")
                        .font(HDFont.italicSub)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                HomeListMapToggle(showMap: $showMap)
            }
            .screenGutter()

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
                    .transition(.opacity)
            } else {
                VStack(spacing: Space.xxl) {
                    ForEach(filteredPros) { pro in
                        ProCard(pro: pro, distanceKm: distance(pro), nextFree: nextFreeLabel(pro, on: listDay)) { open(pro) }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: Book again

    @ViewBuilder
    private var bookAgain: some View {
        let items = bookAgainItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.l) {
                SectionHeader(title: "Book again").screenGutter()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.m) {
                        ForEach(items) { item in
                            ProMiniTile(pro: item.pro, line: item.line) { open(item.pro) }
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
        let favs = app.favouritePros
        if !favs.isEmpty {
            VStack(alignment: .leading, spacing: Space.l) {
                SectionHeader(title: "Favourites").screenGutter()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.m) {
                        ForEach(favs) { pro in
                            ProMiniTile(pro: pro, line: pro.specialtyLine) { open(pro) }
                        }
                    }
                    .screenGutter()
                }
            }
        }
    }
}

/// One tile in "Book again": the pro and the last thing she did for you.
private struct HomeBookAgainItem: Identifiable {
    var pro: Pro
    var line: String
    var id: String { pro.id }
}

// MARK: - Search field

/// A line to type on, not a box: magnifier, placeholder, hairline underneath.
private struct HomeSearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
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
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                    .transition(.opacity)
                }
            }
            .frame(height: 48)
            Rectangle()
                .fill(focused.wrappedValue ? Palette.ink : Palette.line)
                .frame(height: 1)
        }
        .animation(Motion.gentle, value: text.isEmpty)
        .animation(Motion.gentle, value: focused.wrappedValue)
    }
}

// MARK: - Next up

/// The next booking as a row between two hairlines: eyebrow, what, when, status.
private struct HomeNextUpCard: View {
    var booking: Booking
    var pro: Pro?
    var action: () -> Void

    private var title: String {
        let first = booking.services.first?.name ?? "Booking"
        let rest = booking.services.count - 1
        let what = rest > 0 ? "\(first) and \(rest) more" : first
        if let pro { return "\(what) with \(pro.firstName)" }
        return what
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 0) {
                Hairline()
                HStack(alignment: .center, spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next up").labelStyle()
                        Text(title)
                            .font(HDFont.name)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(booking.start.friendlyDayTime)
                            .font(HDFont.sub)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: Space.s)
                    StatusBadge(status: booking.status)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.inkFaint)
                }
                .padding(.vertical, Space.l)
                Hairline()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressLift(scale: 0.99))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your bookings")
    }
}

// MARK: - Category word

/// One category in the index: a serif word, underlined in ink when it's the filter.
private struct HomeCategoryWord: View {
    var category: Category
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Text(category.label)
                    .font(HDFont.name)
                    .foregroundStyle(isSelected ? Palette.ink : Palette.inkSoft)
                Rectangle()
                    .fill(isSelected ? Palette.ink : Color.clear)
                    .frame(height: 1.5)
            }
            .padding(.vertical, Space.s)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.label)
        .accessibilityHint(isSelected ? "Clears the filter" : "Shows \(category.label.lowercased()) pros")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - List / map toggle

/// "List  Map" as two words; the current one in ink with a rule under it.
private struct HomeListMapToggle: View {
    @Binding var showMap: Bool

    var body: some View {
        HStack(spacing: Space.l) {
            segment("List", isMap: false)
            segment("Map", isMap: true)
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(_ title: String, isMap: Bool) -> some View {
        let selected = showMap == isMap
        return Button {
            guard !selected else { return }
            Haptics.selection()
            showMap = isMap
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(HDFont.sub.weight(.medium))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                Rectangle()
                    .fill(selected ? Palette.ink : Color.clear)
                    .frame(height: 1)
            }
            .frame(minWidth: 36, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Chip(title: "Recentre", symbol: "location", tint: Palette.card) {
                withAnimation(Motion.spring) { position = HomeMap.home(centre) }
            }
            .padding(Space.m)
        }
    }

    private func pin(_ pro: Pro) -> some View {
        VStack(spacing: 3) {
            Avatar(name: pro.firstName, seed: pro.seed, size: 40)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5))
            Text("from \(Money.format(pro.cheapestServiceCents))")
                .font(HDFont.label)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        }
    }
}

// MARK: - Skeleton

/// Soft blocks in the line colour, breathing while pros load for the first time.
private struct HomeSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            VStack(alignment: .leading, spacing: Space.l) {
                block(width: 180, height: 26)
                HStack(spacing: Space.m) {
                    ForEach(0..<3, id: \.self) { _ in block(width: 150, height: 188, radius: Radius.tile) }
                }
            }
            HStack(spacing: Space.xl) {
                ForEach(0..<4, id: \.self) { _ in block(width: 56, height: 22, radius: 2) }
            }
            VStack(alignment: .leading, spacing: Space.l) {
                block(width: 120, height: 26)
                block(height: 210, radius: 0)
                block(height: 210, radius: 0)
            }
        }
        .opacity(pulse ? 0.5 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    private func block(width: CGFloat? = nil, height: CGFloat, radius: CGFloat = Radius.tile) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Palette.line)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
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
