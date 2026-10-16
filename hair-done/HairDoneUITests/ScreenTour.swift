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

    /// Profile > Travel area and fee: taps the km boxes, drags the slider, flips Instant book and types
    /// a travel fee, naming each picture with what changed. Run three ways to find what stops taps on
    /// that screen: as it is, without the map, and without the swipe-back helper. Findings are assertion
    /// messages (in the run log) and picture names.
    func testTravelArea() { travelExperiment("travel", extra: []) }

    /// With the app's debug probe on: after each tap, what the km box's action count, the travel
    /// control's radius and the edit screen's draft say, and whether the screen was rebuilt.
    /// Reported as assertion messages so they land in the run log.
    func testTravelProbe() { travelProbe("base", extra: []) }
    func testTravelProbeNoScrim() { travelProbe("noscrim", extra: ["-hdNoScrim", "YES"]) }
    func testTravelProbeNoRoom() { travelProbe("noroom", extra: ["-hdNoRoom", "YES"]) }
    func testTravelProbeNoBoth() { travelProbe("noboth", extra: ["-hdNoScrim", "YES", "-hdNoRoom", "YES"]) }

    private func travelProbe(_ name: String, extra: [String]) {
        let app = openProfileEdit(viaTravelRow: true, extra: ["-hdProbe", "YES"] + extra)
        let travel = app.staticTexts["probe-travel"], screen = app.staticTexts["probe-edit"]
        guard travel.waitForExistence(timeout: 10) else { XCTFail("PROBE: no travel probe"); return }
        sleep(2)
        func report(_ step: String) {
            let copies = "edit screens=\(app.staticTexts.matching(identifier: "probe-edit").count) "
                + "travel=\(app.staticTexts.matching(identifier: "probe-travel").count) "
                + "Today tabs=\(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Today'")).count)"
            XCTFail("PROBE \(name) \(step): \(travel.label) | \(screen.exists ? screen.label : "edit probe off screen") | \(copies)")
        }
        report("open")
        app.buttons["15 km"].tap(); sleep(1); report("after 15 km")
        app.buttons["25 km"].tap(); sleep(1); report("after 25 km")
        let instant = app.switches.firstMatch
        if instant.exists { instant.tap(); sleep(1); report("after Instant book") }
        shoot("probe-\(name)")
    }

    private func travelExperiment(_ name: String, extra: [String]) {
        let app = openProfileEdit(viaTravelRow: true, extra: extra)
        let slider = app.sliders["How far"]
        guard slider.waitForExistence(timeout: 10) else { shoot("\(name)-0-no-slider"); XCTFail("\(name): no slider"); return }
        sleep(2)
        shoot("\(name)-1-open-\(tag(slider.value))")
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

        let instant = app.switches.firstMatch
        if instant.exists {
            let was = tag(instant.value)
            instant.tap()
            sleep(1)
            shoot("\(name)-4-instant-\(was)-to-\(tag(instant.value))")
            XCTAssertNotEqual(tag(instant.value), was, "\(name): Instant book didn't flip")
        } else {
            XCTFail("\(name): no Instant book switch found")
        }
    }

    /// A switch on a tab's own screen (not pushed), to compare: Profile's Taking bookings.
    func testRootSwitch() {
        let app = XCUIApplication()
        app.launchArguments = ["-hdDemo", "pro", "-hdTab", "profile", "-push.asked.client", "YES", "-push.asked.pro", "YES",
                               "-hdProbe", "YES"]
        app.launch()
        _ = app.buttons["Profile"].waitForExistence(timeout: 20)
        sleep(3)
        for _ in 0..<4 where !app.switches.firstMatch.isHittable { app.swipeUp(velocity: .slow) }
        let probe = app.staticTexts["probe-root"]
        XCTFail("PROBE root before: \(probe.exists ? probe.label : "none")")
        let sw = app.switches.firstMatch
        guard sw.exists else { XCTFail("ROOT: no switch"); return }
        let was = tag(sw.value)
        sw.tap()
        sleep(2)
        // Turning it off may ask first; either the switch flipped or a sheet came up.
        let flipped = tag(sw.value) != was
        let asked = app.buttons.count > 0 && app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] '?'")).count > 0
        shoot("root-switch-\(was)-to-\(tag(sw.value))-asked-\(asked)")
        XCTFail("PROBE root after: \(probe.exists ? probe.label : "none")")
        XCTAssertTrue(flipped || asked, "ROOT: Taking bookings didn't respond")
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
