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

                    if isSearching {
                        searchResults
                    } else {
                        if let next = app.nextBooking {
                            HomeNextUpCard(booking: next, pro: app.pro(next.proID)) {
                                app.selectedTab = .bookings
                            }
                            .screenGutter()
                        }

                        if app.isLoadingPros && app.pros.isEmpty {
                            HomeSkeleton().screenGutter()
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
            .onAppear { if isLate { dayOffset = 1 } }
            .hdDestinations()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: 6) {
                    Image(systemName: locationOff ? "location.slash" : "location")
                        .font(.system(size: 10, weight: .semibold))
                    Text(suburbLine)
                }
                .labelStyle()
                .accessibilityElement(children: .combine)

                greetingText
                    .font(HDFont.display)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(greeting)
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
        VStack(alignment: .leading, spacing: Space.l) {
            if matches.isEmpty {
                EmptyState(
                    symbol: "magnifyingglass",
                    title: "Nothing for \"\(query.trimmingCharacters(in: .whitespaces))\".",
                    message: "Try a service or a suburb.",
                    actionTitle: "Clear",
                    action: { query = "" }
                )
            } else {
                ForEach(matches) { pro in
                    ProCard(pro: pro, distanceKm: distance(pro), nextFree: nextFreeLabel(pro, on: listDay)) { open(pro) }
                }
            }
        }
        .screenGutter()
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
                        TertiaryButton(title: "See tomorrow", tint: Palette.lacquer) { dayOffset = 1 }
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

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(Category.allCases) { c in
                    HomeCategoryTile(category: c, isSelected: category == c) {
                        category = (category == c) ? nil : c
                    }
                }
            }
            .screenGutter()
        }
    }

    // MARK: Near you

    private var nearYou: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.map { "\($0.label) near you" } ?? "Near you")
                        .font(HDFont.heading)
                        .foregroundStyle(Palette.ink)
                    Text("Closest first")
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                HomeListMapToggle(showMap: $showMap)
            }
            .screenGutter()

            if let category {
                HStack(spacing: Space.s) {
                    Chip(title: "Everything") { self.category = nil }
                    Chip(title: category.label, symbol: category.symbol, isSelected: true) { self.category = nil }
                }
                .screenGutter()
                .transition(.opacity.combined(with: .move(edge: .top)))
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
                    .transition(.opacity)
            } else {
                VStack(spacing: Space.l) {
                    ForEach(filteredPros) { pro in
                        ProCard(pro: pro, distanceKm: distance(pro), nextFree: nextFreeLabel(pro, on: listDay)) { open(pro) }
                    }
                }
                .screenGutter()
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

private struct HomeSearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
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
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .animation(Motion.gentle, value: text.isEmpty)
    }
}

// MARK: - Next up

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
            HStack(spacing: Space.m) {
                Avatar(name: pro?.firstName ?? "", seed: pro?.seed ?? 0, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next up").labelStyle()
                    Text(title)
                        .font(HDFont.name)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(booking.start.friendlyDayTime)
                        .font(HDFont.sub)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: Space.s)
                StatusBadge(status: booking.status)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .card(padding: Space.m)
        }
        .buttonStyle(PressLift(scale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your bookings")
    }
}

// MARK: - Category tile

private struct HomeCategoryTile: View {
    var category: Category
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: category.symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(category.tintInk)
                Spacer(minLength: Space.s)
                Text(category.label)
                    .font(HDFont.name)
                    .foregroundStyle(category.tintInk)
                if category == .theLot {
                    Text("Hair, makeup, nails. For events.")
                        .font(HDFont.caption)
                        .foregroundStyle(category.tintInk.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(Space.m)
            .frame(width: 132, height: 112, alignment: .topLeading)
            .background(category.tint, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(isSelected ? category.tintInk : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PressLift(scale: 0.96))
        .accessibilityLabel(category.label)
        .accessibilityHint(isSelected ? "Clears the filter" : "Shows \(category.label.lowercased()) pros")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - List / map toggle

private struct HomeListMapToggle: View {
    @Binding var showMap: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment("List", symbol: "list.bullet", isMap: false)
            segment("Map", symbol: "map", isMap: true)
        }
        .padding(3)
        .background(Palette.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func segment(_ title: String, symbol: String, isMap: Bool) -> some View {
        let selected = showMap == isMap
        return Button {
            guard !selected else { return }
            Haptics.selection()
            showMap = isMap
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(title).font(HDFont.label)
            }
            .foregroundStyle(selected ? Palette.paper : Palette.inkSoft)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(selected ? Palette.ink : Color.clear, in: Capsule())
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
            Chip(title: "Recentre", symbol: "location") {
                withAnimation(Motion.spring) { position = HomeMap.home(centre) }
            }
            .padding(Space.m)
        }
    }

    private func pin(_ pro: Pro) -> some View {
        VStack(spacing: 3) {
            Avatar(name: pro.firstName, seed: pro.seed, size: 40)
                .overlay(Circle().strokeBorder(Palette.lacquer, lineWidth: 2))
            Text("from \(Money.format(pro.cheapestServiceCents))")
                .font(HDFont.label)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        }
    }
}

// MARK: - Skeleton

/// Soft rounded blocks in the line colour, breathing while pros load for the first time.
private struct HomeSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            VStack(alignment: .leading, spacing: Space.l) {
                block(width: 160, height: 22)
                HStack(spacing: Space.m) {
                    ForEach(0..<3, id: \.self) { _ in block(width: 150, height: 150, radius: Radius.tile) }
                }
            }
            HStack(spacing: Space.s) {
                ForEach(0..<3, id: \.self) { _ in block(width: 132, height: 112, radius: Radius.tile) }
            }
            VStack(alignment: .leading, spacing: Space.l) {
                block(width: 120, height: 22)
                block(height: 230)
                block(height: 230)
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

    private func block(width: CGFloat? = nil, height: CGFloat, radius: CGFloat = Radius.card) -> some View {
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
