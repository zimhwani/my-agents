#if DEBUG
import SwiftUI

/// The screen tour (CI, `HairDoneUITests/ScreenTour.swift`) opens the app straight onto a tab on
/// the sample data: `-hdDemo client|pro -hdTab <ClientTab or ProTab raw value>`.
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
    }
}
#endif

/// Debug builds only: lets the screen tour switch one piece off (launch with `-hdNoMap YES`) to find
/// which one is at fault. Always false in a release build.
enum DebugSwitch {
    static func on(_ key: String) -> Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: key)
        #else
        return false
        #endif
    }
}
