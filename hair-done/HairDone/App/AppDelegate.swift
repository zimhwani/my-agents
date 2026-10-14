import UIKit
import UserNotifications

/// The few things SwiftUI's App doesn't hand over: the push token, and being the notification
/// centre's delegate early enough to hear about the tap that launched the app.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = PushCenter.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushCenter.shared.tokenArrived(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Nothing to tell her: the app works the same without pushes. The simulator lands here often.
        #if DEBUG
        print("Push registration failed: \(error.localizedDescription)")
        #endif
    }
}
