import SwiftUI
import MapKit
import CoreLocation

/// Her base suburb, found on the map, with the circle she'll travel inside. Used in pro setup and
/// Profile edit. Typing the suburb looks it up (CLGeocoder) and moves the centre there, so the
/// circle is around where she actually starts, not wherever she was standing.
///
/// It never changes the bound pro just by appearing: a saved suburb already has its pin, so it's
/// only looked up once she edits it (or when there's no pin yet). Otherwise Profile edit would be
/// "changed" the moment it opened.
struct ProTravelArea: View {
    @Binding var base: String
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var radiusKm: Double
    var placeholder: String = "Suburb or postcode"

    @State private var notFound = false
    @State private var looking = false
    @State private var position: MapCameraPosition = .automatic
    /// The suburb the pin belongs to. Set on the first look; a lookup only runs once `base` differs.
    @State private var pinnedBase: String? = nil

    private var hasPin: Bool { latitude != 0 || longitude != 0 }
    private var typed: String { base.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var centre: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HDTextField(label: "Your base", placeholder: placeholder, text: $base, contentType: .addressCity,
                        caption: looking ? "Finding it on the map." : nil,
                        error: notFound ? "We couldn't find that one. Try the suburb and postcode." : nil)

            Map(position: $position, interactionModes: []) {
                MapCircle(center: centre, radius: radiusKm * 1000)
                    .foregroundStyle(Palette.ink.opacity(0.08))
                    .stroke(Palette.ink, lineWidth: 1)
                Annotation("", coordinate: centre) {
                    Circle().fill(Palette.ink).frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 1.5))
                }
            }
            .frame(height: 200)
            .photoShape()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Map: \(Int(radiusKm)) kilometres around \(base.isEmpty ? "your base" : base)")

            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text("How far").font(HDFont.body).foregroundStyle(Palette.ink)
                    Spacer()
                    Text("\(Int(radiusKm)) km").font(HDFont.price).foregroundStyle(Palette.ink)
                }
                Slider(value: $radiusKm, in: 2...25, step: 1)
                    .tint(Palette.ink)
                    .accessibilityLabel("How far")
                    .accessibilityValue("\(Int(radiusKm)) kilometres")
                ProFlowLayout {
                    ForEach([5, 10, 15, 25], id: \.self) { km in
                        OptionBox(title: "\(km) km", isSelected: Int(radiusKm) == km) {
                            withAnimation(Motion.spring) { radiusKm = Double(km) }
                        }
                    }
                }
                Text("Clients inside the circle can book you.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
        }
        .onAppear { frame(animated: false) }
        .onChange(of: radiusKm) { _, _ in frame(animated: true) }
        .onChange(of: latitude) { _, _ in frame(animated: true) }
        .onChange(of: longitude) { _, _ in frame(animated: true) }
        .task(id: base) { await lookUp() }
    }

    private func frame(animated: Bool) {
        let metres = max(radiusKm, 2) * 1000 * 2.6
        let region = MKCoordinateRegion(center: centre, latitudinalMeters: metres, longitudinalMeters: metres)
        if animated {
            withAnimation(Motion.gentle) { position = .region(region) }
        } else {
            position = .region(region)
        }
    }

    /// Waits for her to stop typing, then finds the suburb in Victoria. Not on the first look when
    /// the suburb already has a pin, and not when she's typed her way back to the pinned suburb.
    private func lookUp() async {
        let words = typed
        if pinnedBase == nil { pinnedBase = hasPin ? words : "" }
        guard words != pinnedBase else {
            notFound = false
            return
        }
        guard words.count >= 3 else {
            notFound = false
            return
        }
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        looking = true
        defer { looking = false }
        let found = try? await CLGeocoder().geocodeAddressString("\(words), Victoria, Australia")
        guard !Task.isCancelled else { return }
        if let location = found?.first?.location {
            notFound = false
            pinnedBase = words
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        } else {
            notFound = true
        }
    }
}
