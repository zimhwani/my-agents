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

    /// Profile > Travel area and fee: taps the km boxes, drags the slider and flips Instant book,
    /// naming each picture with what changed. Guards against edits not redrawing the screen (a pro
    /// compared by id alone made SwiftUI skip the redraw).
    func testTravelArea() { travelExperiment("travel", extra: []) }

    private func travelExperiment(_ name: String, extra: [String]) {
        let app = openProfileEdit(viaTravelRow: true, extra: extra)
        let slider = app.sliders["How far"]
        guard slider.waitForExistence(timeout: 10) else { shoot("\(name)-0-no-slider"); XCTFail("\(name): no slider"); return }
        sleep(2)
        shoot("\(name)-1-open-\(tag(slider.value))")

        // Instant book first, while no Save bar covers the bottom of the screen.
        let instant = app.switches.firstMatch
        if instant.waitForExistence(timeout: 5) {
            scrollIntoView(instant, in: app)
            let was = tag(instant.value)
            instant.tap()
            sleep(1)
            shoot("\(name)-4-instant-\(was)-to-\(tag(instant.value))")
            XCTAssertNotEqual(tag(instant.value), was, "\(name): Instant book didn't flip")
            instant.tap() // back as it was
            sleep(1)
        } else {
            XCTFail("\(name): no Instant book switch found")
        }
        scrollIntoView(slider, in: app)

        for km in ["15 km", "25 km", "5 km"] {
            let box = app.buttons[km]
            XCTAssertTrue(box.isHittable, "\(name): \(km) not hittable, frame \(box.frame)")
            box.tap()
            sleep(1)
            let now = tag(slider.value)
            shoot("\(name)-2-tapped-\(km.replacingOccurrences(of: " ", with: ""))-now-\(now)")
            XCTAssertTrue(now.hasPrefix(km.replacingOccurrences(of: " km", with: "")),
                          "\(name): tapped \(km), slider says \(now); save bar: \(app.buttons["Save"].exists)")
        }
        let before = tag(slider.value)
        slider.adjust(toNormalizedSliderPosition: 0.4)
        sleep(1)
        shoot("\(name)-3-dragged-now-\(tag(slider.value))")
        XCTAssertNotEqual(tag(slider.value), before, "\(name): slider didn't move after a drag")

    }

    /// A switch on a tab's own screen (not pushed), to compare: Profile's Taking bookings.
    func testRootSwitch() {
        let app = XCUIApplication()
        app.launchArguments = ["-hdDemo", "pro", "-hdTab", "profile", "-push.asked.client", "YES", "-push.asked.pro", "YES"]
        app.launch()
        _ = app.buttons["Profile"].waitForExistence(timeout: 20)
        sleep(3)
        let sw = app.switches.firstMatch
        guard sw.waitForExistence(timeout: 5) else { XCTFail("ROOT: no switch"); return }
        scrollIntoView(sw, in: app)
        let was = tag(sw.value)
        sw.tap()
        sleep(2)
        // Turning it off may ask first; either the switch flipped or a sheet came up.
        let flipped = tag(sw.value) != was
        let asked = app.buttons.count > 0 && app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] '?'")).count > 0
        shoot("root-switch-\(was)-to-\(tag(sw.value))-asked-\(asked)")
        XCTAssertTrue(flipped || asked, "ROOT: Taking bookings didn't respond")
    }

    /// Inbox > a chat > type a message > back: the tab bar comes back, so she can leave Inbox.
    func testTabBarAfterChat() {
        let app = XCUIApplication()
        app.launchArguments = ["-hdDemo", "client", "-hdTab", "inbox", "-push.asked.client", "YES", "-push.asked.pro", "YES"]
        app.launch()
        _ = app.buttons["Home"].waitForExistence(timeout: 20)
        sleep(3)
        let thread = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Kiara' OR label CONTAINS[c] 'Mei' OR label CONTAINS[c] 'Priya'")).firstMatch
        func openAndType() -> Bool {
            guard thread.waitForExistence(timeout: 10) else { return false }
            thread.tap()
            sleep(2)
            let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
            if field.waitForExistence(timeout: 5) {
                field.tap()
                field.typeText("See you then")
                sleep(1)
            }
            return true
        }
        let homeBack = { app.buttons["Home"].waitForExistence(timeout: 5) && app.buttons["Home"].isHittable }

        // 1. Leave by the Back button, keyboard up.
        guard openAndType() else { XCTFail("CHAT: no thread to open"); return }
        XCTAssertFalse(app.buttons["Home"].isHittable, "CHAT: tab bar should step aside in a chat")
        app.buttons["Back"].firstMatch.tap()
        sleep(3)
        let byButton = homeBack()
        shoot("chat-back-button-tabbar-\(byButton ? "shown" : "missing")")
        XCTAssertTrue(byButton, "CHAT: tab bar didn't come back after Back from a chat")

        // 2. Leave by an edge swipe, keyboard up. Recorded either way: a swipe that doesn't leave is its own problem.
        guard openAndType() else { return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.3)))
        sleep(3)
        let left = !app.buttons["Back"].exists
        let bySwipe = left && homeBack()
        shoot("chat-swipe-\(left ? "left" : "stayed")-tabbar-\(bySwipe ? "shown" : "missing")")
        if left { XCTAssertTrue(bySwipe, "CHAT: tab bar didn't come back after swiping out of a chat") }
    }

    /// With the system bar hidden, a swipe from the left edge still goes back.
    func testSwipeBack() {
        let app = openProfileEdit(viaTravelRow: false, extra: [])
        _ = app.sliders["How far"].waitForExistence(timeout: 10)
        sleep(2)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        sleep(2)
        let back = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Edit your profile'")).firstMatch.exists
        shoot("swipeback-\(back ? "went-back" : "stayed")")
        XCTAssertTrue(back, "SWIPE: an edge swipe didn't go back from Profile edit")
    }

    private func openProfileEdit(viaTravelRow: Bool, extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hdDemo", "pro", "-hdTab", "profile", "-push.asked.client", "YES", "-push.asked.pro", "YES"] + extra
        app.launch()
        _ = app.buttons["Profile"].waitForExistence(timeout: 20)
        sleep(3)
        let label = viaTravelRow ? "Travel area" : "Edit your profile"
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        if row.waitForExistence(timeout: 10) { row.tap() } else { XCTFail("no \(label) button") }
        return app
    }

    /// Scrolls until the element sits in the middle band of the screen, clear of the status bar at the
    /// top and the tab bar (or a Save bar) at the bottom, so a tap lands on it and nothing else.
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<8 {
            let f = element.frame
            if f.minY > window.minY + 120 && f.maxY < window.maxY - 200 { return }
            if f.maxY >= window.maxY - 200 {
                app.swipeUp(velocity: .slow)
            } else {
                app.swipeDown(velocity: .slow)
            }
            sleep(1)
        }
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
