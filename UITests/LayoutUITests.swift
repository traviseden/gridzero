import XCTest
import UIKit

@MainActor
final class LayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPortraitAndLandscapeLayouts() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp()
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
        validate(app, name: "portrait")
        exerciseNotes(app)

        XCUIDevice.shared.orientation = .landscapeLeft
        let surface = app.descendants(matching: .any).matching(identifier: "game-surface").firstMatch
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { surface.frame.width > surface.frame.height }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 8), .completed)
        validate(app, name: "landscape")
        exerciseNotes(app)

        // A window/rotation change must preserve the puzzle and its notes.
        XCUIDevice.shared.orientation = .portrait
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { surface.frame.height > surface.frame.width }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 8), .completed)
        validate(app, name: "portrait-restored", screenshot: false)
    }

    func testResizableTabletViewports() throws {
        XCUIDevice.shared.orientation = .portrait
        let probe = fixtureApp()
        probe.launch()
        let nativeBounds = probe.frame
        probe.terminate()
        guard UIDevice.current.userInterfaceIdiom == .pad,
              min(nativeBounds.width, nativeBounds.height) >= 1024 else {
            throw XCTSkip("Run viewport sweep on a 13-inch iPad")
        }
        let sizes: [(CGFloat, CGFloat, UIDeviceOrientation)] = [
            (320, 480, .portrait), (375, 700, .portrait), (480, 620, .portrait),
            (600, 500, .portrait), (640, 480, .portrait), (744, 900, .portrait),
            (768, 1024, .portrait), (834, 1112, .portrait), (980, 700, .portrait), (1100, 760, .landscapeLeft)
        ]
        for (width, height, orientation) in sizes {
            XCUIDevice.shared.orientation = orientation
            let app = fixtureApp()
            app.launchEnvironment["GRIDZERO_TEST_WIDTH"] = "\(width)"
            app.launchEnvironment["GRIDZERO_TEST_HEIGHT"] = "\(height)"
            app.launch()
            XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
            let surface = app.descendants(matching: .any).matching(identifier: "viewport-bounds").firstMatch.frame
            XCTAssertEqual(surface.width, width, accuracy: 1)
            XCTAssertEqual(surface.height, height, accuracy: 1)
            validate(app, name: "window-\(Int(width))x\(Int(height))")
            exerciseNotes(app)
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testAccessibilityTextKeepsControlsReachable() throws {
        let app = fixtureApp()
        app.launchEnvironment["GRIDZERO_TEST_ACCESSIBILITY_TEXT"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
        // SwiftUI can inherit the root's game-surface identifier onto the scroll view.
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.exists, app.debugDescription)
        // Existing labels grow with Dynamic Type; nothing is reduced to fit a fixed footer.
        let notes = app.buttons["tool-notes"]
        for _ in 0..<6 where !notes.isHittable { scroll.swipeUp() }
        XCTAssertTrue(notes.isHittable)
        XCTAssertGreaterThan(notes.frame.height, 44)
        notes.tap()
        for _ in 0..<6 where !app.buttons["number-2"].isHittable { scroll.swipeUp() }
        XCTAssertTrue(app.buttons["number-2"].isHittable)
        app.buttons["number-2"].tap()
        for _ in 0..<6 where !app.buttons["cell-2"].isHittable { scroll.swipeDown() }
        XCTAssertTrue(app.buttons["cell-2"].label.contains("notes: 2"))
    }

    private func exerciseNotes(_ app: XCUIApplication) {
        let cell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' AND label CONTAINS 'empty'")).firstMatch
        XCTAssertTrue(cell.exists)
        let identifier = cell.identifier
        cell.tap()
        app.buttons["tool-notes"].tap()
        app.buttons["number-2"].tap()
        XCTAssertTrue(app.buttons[identifier].label.contains("notes: 2"))
        app.buttons["tool-undo"].tap()
        XCTAssertFalse(app.buttons[identifier].label.contains("notes:"))
        app.buttons["tool-notes"].tap()
    }

    private func validate(_ app: XCUIApplication, name: String, screenshot: Bool = true,
                          file: StaticString = #filePath, line: UInt = #line) {
        let probe = app.descendants(matching: .any).matching(identifier: "viewport-bounds").firstMatch
        let surface = probe.exists ? probe.frame : app.descendants(matching: .any).matching(identifier: "game-surface").firstMatch.frame
        XCTAssertTrue(app.frame.insetBy(dx: -1, dy: -1).contains(surface), "Viewport stays inside the native window", file: file, line: line)
        XCTAssertGreaterThan(surface.width, 0, file: file, line: line)
        XCTAssertEqual(app.scrollViews.count, 0, file: file, line: line)
        let bounds = surface.insetBy(dx: -1, dy: -1)
        let board = app.buttons["cell-0"].frame.union(app.buttons["cell-80"].frame)
        XCTAssertTrue(bounds.contains(board), "Board fits the safe-area viewport", file: file, line: line)
        XCTAssertEqual(board.width, board.height, accuracy: 1, file: file, line: line)
        XCTAssertLessThanOrEqual(board.width, 721, file: file, line: line)
        if surface.width <= 500 && surface.height >= surface.width + 254 {
            XCTAssertEqual(board.width, surface.width, accuracy: 1, file: file, line: line)
            XCTAssertEqual(board.minX, surface.minX, accuracy: 1, file: file, line: line)
        }
        var keys: [CGRect] = []
        for digit in 1...9 {
            let key = app.buttons["number-\(digit)"]
            XCTAssertTrue(key.exists, "Key \(digit) has its own accessibility identity", file: file, line: line)
            XCTAssertTrue(key.isHittable, "Key \(digit) remains reachable", file: file, line: line)
            let frame = key.frame
            // Accessibility converts transformed frames to floating-point window coordinates.
            // A mathematically 44-point edge can report 43.99999999999994.
            XCTAssertGreaterThanOrEqual(frame.width, 43.999, "Key \(digit) width", file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height, 43.999, "Key \(digit) height", file: file, line: line)
            XCTAssertTrue(bounds.contains(frame), "Entire key \(digit) fits", file: file, line: line)
            XCTAssertFalse(board.intersects(frame), file: file, line: line)
            keys.append(frame)
        }
        for even in [2, 4, 6, 8] {
            XCTAssertGreaterThan(keys[even - 1].midX, keys[even - 2].midX, file: file, line: line)
            XCTAssertLessThan(keys[even - 1].midX, keys[even].midX, file: file, line: line)
            XCTAssertGreaterThanOrEqual(keys[even - 1].minY, keys[even - 2].maxY, file: file, line: line)
        }
        for tool in ["tool-undo", "tool-erase", "tool-notes"] {
            let frame = app.buttons[tool].frame
            XCTAssertTrue(bounds.contains(frame), file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height, 43.999, "\(tool) touch target height", file: file, line: line)
            XCTAssertFalse(board.intersects(frame), file: file, line: line)
            for key in keys { XCTAssertFalse(key.intersects(frame), file: file, line: line) }
        }
        XCTAssertTrue(bounds.contains(app.buttons["Game menu"].frame), file: file, line: line)
        if screenshot {
            // Capture the display, not a cropped application-frame rectangle;
            // application snapshots can be rotated/cropped incorrectly by simulator runtimes.
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
