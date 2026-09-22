import SwiftUI

/// Every push destination in the app. Each tab's NavigationStack calls `.hdDestinations()` once,
/// then any view can `NavigationLink(value: Route.pro(pro))`.
enum Route: Hashable {
    case pro(Pro)
    case booking(String)       // client-side booking detail, by id
    case proBooking(String)    // pro-side booking detail, by id
    case thread(String)        // message thread, by id
    case proProfileEdit
}

struct RouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            switch route {
            case .pro(let pro): ProProfileView(pro: pro)
            case .booking(let id): BookingDetailView(bookingID: id)
            case .proBooking(let id): ProBookingDetailView(bookingID: id)
            case .thread(let id): ThreadView(threadID: id)
            case .proProfileEdit: ProProfileEditView()
            }
        }
    }
}

extension View {
    func hdDestinations() -> some View { modifier(RouteDestinations()) }
}
