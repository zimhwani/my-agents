import Foundation
import UIKit
import UserNotifications

/// What a notification is about, from the keys the `notify` function puts next to `aps`:
/// `kind` ("booking" or "message"), `booking_id`, `thread_id` on messages, and `side` ("client" or
/// "pro"), which side of the booking the person it was sent to is on.
struct PushTarget: Equatable {
    enum Kind: String { case booking, message }

    var kind: Kind
    var bookingID: String?
    var threadID: String?
    /// Nil from an older server; the app then works it out from the booking or thread.
    var side: AppMode?

    init(kind: Kind, bookingID: String?, threadID: String?, side: AppMode? = nil) {
        self.kind = kind
        self.bookingID = bookingID
        self.threadID = threadID
        self.side = side
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo["kind"] as? String, let kind = Kind(rawValue: raw) else { return nil }
        let booking = PushTarget.text(userInfo["booking_id"])
        let thread = PushTarget.text(userInfo["thread_id"])
        if kind == .booking && booking == nil { return nil }
        if kind == .message && thread == nil && booking == nil { return nil }
        let side = PushTarget.text(userInfo["side"]).flatMap { AppMode(rawValue: $0) }
        self.init(kind: kind, bookingID: booking, threadID: thread, side: side)
    }

    private static func text(_ value: Any?) -> String? {
        guard let s = value as? String, !s.isEmpty else { return nil }
        return s
    }
}

/// Which side of the app is asking for notifications. Each side asks once, at its own moment.
enum PushAskSide: String { case client, pro }

/// The app's end of push notifications: permission, the device token, and what happens when one
/// arrives or is tapped. iOS calls in through `AppDelegate` (the token) and as the notification
/// centre's delegate (banners and taps); everything that touches the app happens on the main queue.
final class PushCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushCenter()

    private weak var app: AppState?
    /// A tap that came in before the app was ready for it, e.g. one that launched the app.
    private var waiting: PushTarget?

    private override init() { super.init() }

    /// Previews have no app to register, and no one to ask.
    static var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

    /// APNs sandbox for builds run from Xcode, production for TestFlight and the App Store.
    static var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private static let tokenKey = "push.token"

    /// The last token iOS gave us, as hex. Kept so sign-out can take it off the account.
    static var savedToken: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    /// Her You → Notifications → Messages toggle (`AccountNotificationsSheet`).
    static var wantsMessages: Bool { UserDefaults.standard.object(forKey: "notify.messages") as? Bool ?? true }

    func attach(_ app: AppState) {
        self.app = app
        if let target = waiting {
            waiting = nil
            app.open(target)
        }
    }

    // MARK: Permission

    private static func askedKey(_ side: PushAskSide) -> String { "push.asked.\(side.rawValue)" }

    /// True when our pre-prompt is worth showing for this side: iOS hasn't asked yet, and nor have we.
    func shouldAsk(_ side: PushAskSide) async -> Bool {
        guard !PushCenter.isPreview else { return false }
        if UserDefaults.standard.bool(forKey: PushCenter.askedKey(side)) { return false }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .notDetermined
    }

    func markAsked(_ side: PushAskSide) {
        UserDefaults.standard.set(true, forKey: PushCenter.askedKey(side))
    }

    /// Where things stand in Settings, for the You → Notifications sheet.
    func status() async -> UNAuthorizationStatus {
        guard !PushCenter.isPreview else { return .authorized }
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// The system prompt. Registers with APNs straight away if she says yes.
    @discardableResult
    func requestPermission() async -> Bool {
        guard !PushCenter.isPreview else { return false }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
        return granted
    }

    /// Registers with APNs if she's allowed notifications. Safe to call often: iOS hands back the
    /// same token, and the server's register_device is an upsert.
    func registerIfAllowed() {
        guard !PushCenter.isPreview else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            default:
                break
            }
        }
    }

    // MARK: Token

    func tokenArrived(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        DispatchQueue.main.async {
            PushCenter.savedToken = hex
            self.app?.deviceTokenArrived(hex)
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    /// In the foreground: refresh what it's about, and show it as a banner, except a message for the
    /// thread that's open (she's reading it) or any message when she's turned messages off.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let target = PushTarget(userInfo: notification.request.content.userInfo)
        DispatchQueue.main.async {
            guard let target else {
                completionHandler([.banner, .list, .sound])
                return
            }
            self.app?.pushArrived(target)
            if target.kind == .message {
                let isOpen = target.threadID != nil && target.threadID == self.app?.openThreadID
                if isOpen || !PushCenter.wantsMessages {
                    completionHandler([])
                    return
                }
            }
            completionHandler([.banner, .list, .sound])
        }
    }

    /// A tap: open the booking or the thread it's about.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let target = response.actionIdentifier == UNNotificationDefaultActionIdentifier
            ? PushTarget(userInfo: response.notification.request.content.userInfo)
            : nil
        DispatchQueue.main.async {
            if let target {
                if let app = self.app { app.open(target) } else { self.waiting = target }
            }
            completionHandler()
        }
    }
}
