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
    /// Then, to tell "this control" from "every edit on the screen": the Instant book switch and the
    /// travel fee, each checked by whether the Save bar appears. Findings are assertion messages
    /// (they show in the run log) and picture names.
    func testTravelArea() {
        let app = openProfileEdit(viaTravelRow: true)
        let slider = app.sliders["How far"]
        guard slider.waitForExistence(timeout: 10) else { shoot("travel-0-no-slider"); XCTFail("TRAVEL: no slider"); return }
        sleep(2)
        shoot("travel-1-open-\(tag(slider.value))")

        for km in ["15 km", "25 km"] {
            let box = app.buttons[km]
            XCTAssertTrue(box.isHittable, "TRAVEL: \(km) not hittable, frame \(box.frame)")
            box.tap()
            sleep(1)
            shoot("travel-2-tapped-\(km.replacingOccurrences(of: " ", with: ""))-now-\(tag(slider.value))")
            XCTAssertTrue(tag(slider.value).hasPrefix(km.replacingOccurrences(of: " km", with: "")),
                          "TRAVEL: tapped \(km), slider says \(tag(slider.value)); save bar: \(app.buttons["Save"].exists)")
        }
        slider.adjust(toNormalizedSliderPosition: 0.2)
        sleep(1)
        shoot("travel-3-dragged-now-\(tag(slider.value))")
        XCTAssertNotEqual(tag(slider.value), "8kilometres", "TRAVEL: slider didn't move after a drag")

        // Another kind of edit on the same screen.
        let instant = app.switches.firstMatch.exists ? app.switches.firstMatch
            : app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Instant book'")).firstMatch
        if instant.exists {
            let before = tag(instant.value)
            instant.tap()
            sleep(1)
            shoot("travel-4-instant-\(before)-to-\(tag(instant.value))-save-\(app.buttons["Save"].exists)")
            XCTAssertTrue(app.buttons["Save"].exists, "TRAVEL: Instant book \(before) -> \(tag(instant.value)), no Save bar")
        } else {
            XCTFail("TRAVEL: no Instant book switch found")
        }
        let fee = app.textFields.matching(NSPredicate(format: "value == '15' OR placeholderValue == '15'")).firstMatch
        if fee.exists {
            fee.tap()
            fee.typeText("9")
            sleep(1)
            shoot("travel-5-fee-\(tag(fee.value))-save-\(app.buttons["Save"].exists)")
            XCTAssertTrue(app.buttons["Save"].exists, "TRAVEL: typed in the fee (now \(tag(fee.value))), no Save bar")
        } else {
            XCTFail("TRAVEL: no fee field found")
        }
    }

    /// The same, opening Profile edit the normal way ("Edit your profile"), not jumped to Travel.
    func testTravelAreaFromTop() {
        let app = openProfileEdit(viaTravelRow: false)
        let slider = app.sliders["How far"]
        for _ in 0..<6 where !slider.isHittable { app.swipeUp(velocity: .slow) }
        guard slider.waitForExistence(timeout: 10) else { shoot("traveltop-0-no-slider"); XCTFail("TOP: no slider"); return }
        let box = app.buttons["15 km"]
        if !box.isHittable { app.swipeUp(velocity: .slow) }
        box.tap()
        sleep(1)
        shoot("traveltop-1-tapped-15km-now-\(tag(slider.value))-save-\(app.buttons["Save"].exists)")
        XCTAssertTrue(tag(slider.value).hasPrefix("15"), "TOP: tapped 15 km, slider says \(tag(slider.value))")
    }

    private func openProfileEdit(viaTravelRow: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hdDemo", "pro", "-hdTab", "profile", "-push.asked.client", "YES", "-push.asked.pro", "YES"]
        app.launch()
        _ = app.buttons["Profile"].waitForExistence(timeout: 20)
        sleep(3)
        let label = viaTravelRow ? "Travel area" : "Edit your profile"
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        if row.waitForExistence(timeout: 10) { row.tap() } else { XCTFail("no \(label) button") }
        return app
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
