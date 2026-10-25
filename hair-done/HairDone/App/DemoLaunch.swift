#if DEBUG
import SwiftUI

/// The screen tour (CI, `HairDoneUITests/ScreenTour.swift`) opens the app straight onto a tab on
/// the sample data: `-hdDemo client|pro -hdTab <ClientTab or ProTab raw value>`. The App Store
/// pictures (`AppStoreShots.swift`) add `-hdShow pro|booked|receipt` to open one screen over it.
/// Debug builds on the sample data only; a build pointed at the live backend ignores it.
enum DemoLaunch {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var isOn: Bool { value("-hdDemo") != nil }
}

extension AppState {
    /// Signs in on the sample data and lands on the asked-for side and tab, past onboarding.
    func startDemo() async {
        guard !isLive, let side = DemoLaunch.value("-hdDemo") else { return }
        client = try? await data.verifyCode(phone: "0400 000 002", code: "123456")
        proSelf = await data.currentPro()
        mode = (side == "pro" && proSelf != nil) ? .pro : .client
        if let raw = DemoLaunch.value("-hdTab") {
            if mode == .client, let tab = ClientTab(rawValue: raw) { selectedTab = tab }
            if mode == .pro, let tab = ProTab(rawValue: raw) { selectedProTab = tab }
        }
        isRestoring = false
        stage = .ready
        await refreshAll()
        if DemoLaunch.value("-hdShow") == "pro", let kiara = pro("pro_kiara") { pendingRoute = .pro(kiara) }
    }
}

/// `-hdShow booked|receipt`: the client shell opens You're booked, or a paid booking's receipt,
/// once the sample bookings are in.
struct DemoShow: ViewModifier {
    @Environment(AppState.self) private var app
    @State private var booked: Booking? = nil
    @State private var receipt: Booking? = nil

    func body(content: Content) -> some View {
        content
            .task {
                let show = DemoLaunch.value("-hdShow")
                guard show == "booked" || show == "receipt" else { return }
                while !app.hasLoadedBookings { try? await Task.sleep(for: .milliseconds(200)) }
                try? await Task.sleep(for: .milliseconds(400))
                if show == "booked" { booked = app.bookings.first { $0.id == "bk_1" } }
                if show == "receipt" { receipt = app.bookings.first { $0.id == "bk_5" } }
            }
            .fullScreenCover(item: $booked) { b in
                if let pro = app.pro(b.proID) {
                    BookedStep(booking: b, pro: pro, onMessage: {}, onDone: { booked = nil })
                        .background(Palette.inkGround.ignoresSafeArea())
                }
            }
            .sheet(item: $receipt) { ReceiptSheet(booking: $0) }
    }
}
#endif
