import XCTest

/// The six App Store pictures, from the real app on the sample data (docs/design/mockups/build_appstore.py
/// frames them). Run only by .github/workflows/hairdone-appstore.yml, on the 6.9-inch iPhone with a clean
/// status bar; the screen tour skips it. Each picture is named appstore-N-what.
final class AppStoreShots: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func test1Home() {
        let app = open(side: "client", tab: "home")
        _ = app.buttons["Home"].waitForExistence(timeout: 20)
        settle()
        shoot("appstore-1-home")
    }

    func test2Profile() {
        let app = open(side: "client", tab: "home", show: "pro")
        _ = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Ivy'")).firstMatch.waitForExistence(timeout: 20)
        settle()
        shoot("appstore-2-profile")
    }

    func test3Booked() {
        let app = open(side: "client", tab: "home", show: "booked")
        _ = app.staticTexts["You're booked."].waitForExistence(timeout: 20)
        settle(4)  // the check draws itself
        shoot("appstore-3-booked")
    }

    func test4Bookings() {
        let app = open(side: "client", tab: "bookings")
        _ = app.buttons["Bookings"].waitForExistence(timeout: 20)
        settle()
        shoot("appstore-4-bookings")
    }

    func test5Receipt() {
        let app = open(side: "client", tab: "bookings", show: "receipt")
        _ = app.staticTexts["Total paid"].waitForExistence(timeout: 20)
        settle()
        shoot("appstore-5-receipt")
    }

    func test6ProToday() {
        let app = open(side: "pro", tab: "today")
        _ = app.buttons["Today"].waitForExistence(timeout: 20)
        settle()
        shoot("appstore-6-pro-today")
    }

    // MARK: -

    private func open(side: String, tab: String, show: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hdDemo", side, "-hdTab", tab,
                               // Our own "turn on notifications?" pre-prompts would sit over the screen.
                               "-push.asked.client", "YES", "-push.asked.pro", "YES"]
            + (show.map { ["-hdShow", $0] } ?? [])
        app.launch()
        return app
    }

    /// Photos load and animations finish.
    private func settle(_ seconds: UInt32 = 3) { sleep(seconds) }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
