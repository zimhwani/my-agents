import SwiftUI
import CoreLocation

/// Add or edit an address. Geocodes on save so the pro's travel check and ETA have a point to work from.
struct AddressEditor: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var address: Address? = nil
    var onSave: (Address) -> Void

    private enum LabelChoice: String, CaseIterable {
        case home = "Home", work = "Work", other = "Somewhere else"
        var symbol: String {
            switch self {
            case .home: return "house"
            case .work: return "briefcase"
            case .other: return "mappin"
            }
        }
    }

    @State private var labelChoice: LabelChoice = .home
    @State private var customLabel = ""
    @State private var line1 = ""
    @State private var suburb = ""
    @State private var postcode = ""
    @State private var instructions = ""
    @State private var isSaving = false
    @State private var problem: String? = nil

    init(address: Address? = nil, onSave: @escaping (Address) -> Void) {
        self.address = address
        self.onSave = onSave
        if let address {
            let choice = LabelChoice.allCases.first { $0.rawValue == address.label } ?? .other
            _labelChoice = State(initialValue: choice)
            _customLabel = State(initialValue: choice == .other ? address.label : "")
            _line1 = State(initialValue: address.line1)
            _suburb = State(initialValue: address.suburb)
            _postcode = State(initialValue: address.postcode)
            _instructions = State(initialValue: address.instructions)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: address == nil ? "Add an address" : "Edit address", subtitle: "She'll only see it once you're confirmed.", onClose: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text("Call it").labelStyle()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                ForEach(LabelChoice.allCases, id: \.self) { choice in
                                    Chip(title: choice.rawValue, symbol: choice.symbol, isSelected: labelChoice == choice) {
                                        withAnimation(Motion.spring) { labelChoice = choice }
                                    }
                                }
                            }
                        }
                        if labelChoice == .other {
                            HDTextField(label: "", placeholder: "Call it something. Home, Mum's, the hotel.", text: $customLabel)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.l) {
                        HDTextField(label: "Street", placeholder: "Unit, number and street", text: $line1, contentType: .streetAddressLine1)
                        HStack(alignment: .top, spacing: Space.m) {
                            HDTextField(label: "Suburb", placeholder: "Suburb", text: $suburb, contentType: .addressCity)
                            HDTextField(label: "Postcode", placeholder: "3000", text: $postcode, keyboard: .numberPad, contentType: .postalCode)
                                .frame(width: 112)
                        }
                        HDTextField(label: "Getting in", placeholder: "Parking, buzzer, dogs. Anything she should know getting in.", text: $instructions, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if let problem {
                        InlineNote(text: problem, tone: .warn)
                            .transition(.opacity)
                    }
                }
                .screenGutter()
                .padding(.top, Space.m)
                .padding(.bottom, Space.xl)
                .animation(Motion.spring, value: labelChoice)
                .animation(Motion.spring, value: problem)
            }
            .scrollDismissesKeyboard(.interactively)

            StickyBar(title: "Save", isLoading: isSaving, action: save) {
                Text("Victoria only for now.")
                    .font(HDFont.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .paperBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: postcode) { _, new in
            let digits = String(new.filter(\.isNumber).prefix(4))
            if digits != new { postcode = digits }
        }
    }

    private var resolvedLabel: String {
        switch labelChoice {
        case .home, .work: return labelChoice.rawValue
        case .other:
            let trimmed = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Somewhere else" : trimmed
        }
    }

    private func validate() -> String? {
        if line1.trimmingCharacters(in: .whitespaces).isEmpty { return "Needs a street." }
        if suburb.trimmingCharacters(in: .whitespaces).isEmpty { return "Needs a suburb." }
        if postcode.count != 4 { return "Postcode's four digits." }
        return nil
    }

    private func save() {
        if let why = validate() {
            withAnimation(Motion.spring) { problem = why }
            return
        }
        withAnimation(Motion.gentle) { problem = nil }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            let street = line1.trimmingCharacters(in: .whitespacesAndNewlines)
            let town = suburb.trimmingCharacters(in: .whitespacesAndNewlines)
            let coordinate = await geocode("\(street), \(town) VIC \(postcode), Australia")
            let saved = Address(
                id: address?.id ?? "addr_\(UUID().uuidString.prefix(6))",
                label: resolvedLabel,
                line1: street,
                suburb: town,
                postcode: postcode,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSave(saved)
            dismiss()
        }
    }

    /// Apple's geocoder, or where you are now if it can't place it.
    private func geocode(_ query: String) async -> CLLocationCoordinate2D {
        if let mark = try? await CLGeocoder().geocodeAddressString(query).first, let location = mark.location {
            return location.coordinate
        }
        return app.location.coordinate
    }
}

#Preview("Add an address") {
    Color.clear
        .sheet(isPresented: .constant(true)) { AddressEditor { _ in } }
        .environment(previewApp())
}

#Preview("Edit an address") {
    Color.clear
        .sheet(isPresented: .constant(true)) { AddressEditor(address: MockData.client.addresses[0]) { _ in } }
        .environment(previewApp())
}
