import XCTest

/// Walks every tab on both sides on the sample data and screenshots the top and the bottom of each,
/// so layout problems (the tab bar covering the last row, clipped text) show up without a phone.
/// Run by .github/workflows/hairdone-screens.yml, once in light and once in dark; the screenshots
/// come out of the result bundle as an artifact.
final class ScreenTour: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testClientTabs() {
        for (tab, title) in [("home", "Home"), ("bookings", "Bookings"), ("inbox", "Inbox"), ("you", "You")] {
            tour(side: "client", tab: tab, waitFor: title)
        }
    }

    func testProTabs() {
        for (tab, title) in [("today", "Today"), ("calendar", "Calendar"), ("inbox", "Inbox"),
                             ("earnings", "Earnings"), ("profile", "Profile")] {
            tour(side: "pro", tab: tab, waitFor: title)
        }
    }

    /// Profile > Travel area and fee: taps 15 km and 25 km, drags the slider, and names each picture
    /// with what the slider says afterwards, so a control that doesn't respond shows up in the names.
    func testTravelArea() {
        let app = XCUIApplication()
        app.launchArguments = ["-hdDemo", "pro", "-hdTab", "profile", "-push.asked.client", "YES", "-push.asked.pro", "YES"]
        app.launch()
        _ = app.buttons["Profile"].waitForExistence(timeout: 20)
        sleep(3)
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Travel area'")).firstMatch
        guard row.waitForExistence(timeout: 10) else { shoot("travel-0-no-row"); return }
        row.tap()
        let slider = app.sliders["How far"]
        guard slider.waitForExistence(timeout: 10) else { shoot("travel-0-no-slider"); return }
        sleep(2)
        shoot("travel-1-open-\(tag(slider.value))")

        for km in ["15 km", "25 km"] {
            let box = app.buttons[km]
            if !box.isHittable { app.swipeUp(velocity: .slow) }
            box.tap()
            sleep(1)
            shoot("travel-2-tapped-\(km.replacingOccurrences(of: " ", with: ""))-now-\(tag(slider.value))")
        }
        slider.adjust(toNormalizedSliderPosition: 0.2)
        sleep(1)
        shoot("travel-3-dragged-now-\(tag(slider.value))")
        XCTAssertNotEqual(tag(slider.value), "25kilometres", "the slider didn't move")
    }

    private func tag(_ value: Any?) -> String {
        "\(value ?? "none")".replacingOccurrences(of: " ", with: "")
    }

    // MARK: -

    private func tour(side: String, tab: String, waitFor title: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hdDemo", side, "-hdTab", tab,
            // Our own "turn on notifications?" pre-prompts would sit over the screen.
            "-push.asked.client", "YES", "-push.asked.pro", "YES",
        ]
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "OK", "Don't Allow"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }
        app.launch()
        _ = app.buttons[title].waitForExistence(timeout: 20)
        // Sample data loads with short pauses; let it settle before the first picture.
        // No tap to clear alerts: a tap lands on the screen and opens things. Location and photos are
        // granted by the workflow, and the push pre-prompts are marked as asked above.
        sleep(4)
        shoot("\(side)-\(tab)-1-top")
        for _ in 0..<10 { app.swipeUp(velocity: .fast) }
        sleep(2)
        shoot("\(side)-\(tab)-2-bottom")
        app.terminate()
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
