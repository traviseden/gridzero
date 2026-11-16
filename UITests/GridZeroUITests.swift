import XCTest
import GridZeroCore

@MainActor
final class GridZeroUITests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    func testBoardNotesUndoAndAppearance() throws {
        let app = fixtureApp()
        app.launch()
        let firstEmpty = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' AND label CONTAINS 'empty'")).firstMatch
        XCTAssertTrue(firstEmpty.waitForExistence(timeout: 10))
        assertEntireGameFits(app)
        let identifier = firstEmpty.identifier
        firstEmpty.tap()
        app.buttons["tool-notes"].tap()
        app.buttons["number-2"].tap()
        XCTAssertTrue(app.buttons[identifier].label.contains("notes: 2"))
        app.buttons["tool-undo"].tap()
        XCTAssertFalse(app.buttons[identifier].label.contains("notes:"))
        // The even digits sit between the odd ones, on a lower row.
        let one = app.buttons["number-1"].frame
        let two = app.buttons["number-2"].frame
        let three = app.buttons["number-3"].frame
        XCTAssertGreaterThan(two.midY, one.midY)
        XCTAssertGreaterThan(two.midX, one.midX)
        XCTAssertLessThan(two.midX, three.midX)
        let first = app.buttons["cell-0"].frame
        let last = app.buttons["cell-8"].frame
        XCTAssertEqual(first.minX, 0, accuracy: 2)
        XCTAssertEqual(last.maxX, app.frame.width, accuracy: 2)
        selectMenu("Settings", in: app)
        XCTAssertTrue(app.buttons["Clay theme"].waitForExistence(timeout: 3))
        app.buttons["Clay theme"].tap()
        app.descendants(matching: .any).matching(identifier: "appearance-picker").firstMatch.tap()
        app.buttons["Dark"].tap()
        let strikeField = app.textFields["Challenge strike limit"]
        XCTAssertTrue(strikeField.waitForExistence(timeout: 3))
        strikeField.doubleTap()
        strikeField.typeText("2")
        XCTAssertEqual(strikeField.value as? String, "2")
        app.steppers.buttons["Increment"].tap()
        XCTAssertEqual(strikeField.value as? String, "3")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["number-1"].waitForExistence(timeout: 3))
        app.buttons["number-3"].tap()
        XCTAssertTrue(app.buttons[identifier].label.contains("notes: 3"))
        // A scene transition flushes the ordered writer before relaunch.
        XCUIDevice.shared.press(.home)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[identifier].label.contains("notes: 3"))
        app.buttons["tool-undo"].tap()
        XCTAssertFalse(app.buttons[identifier].label.contains("notes:"))
    }

    func testClassicGeneratedPuzzleAndExplicitCheck() throws {
        let app = fixtureApp()
        app.launch()
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 5))
        selectMenu("New Puzzle", in: app)
        XCTAssertTrue(app.buttons["Classic"].waitForExistence(timeout: 3))
        app.buttons["Classic"].tap()
        app.descendants(matching: .any).matching(identifier: "source-picker").firstMatch.tap()
        app.buttons["Generated on Device"].tap()
        app.buttons["About game mode"].tap()
        XCTAssertTrue(app.alerts["Classic"].waitForExistence(timeout: 3))
        app.alerts.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Classic"].isSelected)
        XCTAssertTrue(app.buttons["Start Puzzle"].isHittable)
        tapCenter(app.buttons["Start Puzzle"])
        XCTAssertTrue(app.buttons["Start Puzzle"].waitForNonExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Classic"].waitForExistence(timeout: 20))
        let empty = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' AND label CONTAINS 'empty'")).firstMatch
        XCTAssertTrue(empty.exists)
        let identifier = empty.identifier
        empty.tap()
        app.buttons["number-1"].tap()
        XCTAssertTrue(app.buttons[identifier].label.hasSuffix(", 1"))
        selectMenu("Check Board", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()
    }

    func testCompactChallengeEntryAndRejection() throws {
        let app = fixtureApp()
        app.launch()
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 5))
        selectMenu("New Puzzle", in: app)
        XCTAssertTrue(app.buttons["Challenge"].waitForExistence(timeout: 3))
        app.buttons["Challenge"].tap()
        app.descendants(matching: .any).matching(identifier: "difficulty-picker").firstMatch.tap()
        app.buttons["Easy"].tap()
        app.descendants(matching: .any).matching(identifier: "source-picker").firstMatch.tap()
        app.buttons["Puzzle Collection"].tap()
        tapCenter(app.buttons["Start Puzzle"])
        XCTAssertTrue(app.buttons["Start Puzzle"].waitForNonExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Challenge"].waitForExistence(timeout: 10))
        assertEntireGameFits(app)

        let board = (0..<81).map { index -> Int in
            let label = app.buttons["cell-\(index)"].label
            guard label.hasSuffix(", starting clue") else { return 0 }
            return Int(label.components(separatedBy: ", ").dropLast().last ?? "0") ?? 0
        }
        let index = try XCTUnwrap(board.firstIndex(of: 0))
        let solution = try XCTUnwrap(Sudoku.solutions(board, limit: 1).first)
        let wrong = solution[index] % 9 + 1
        let cell = app.buttons["cell-\(index)"]
        cell.tap()
        app.buttons["number-\(wrong)"].tap()
        XCTAssertTrue(cell.label.contains("empty"), "A rejected digit must never enter the board")
        let strikes = app.descendants(matching: .any).matching(identifier: "strikes").firstMatch
        XCTAssertTrue(strikes.label.hasPrefix("1"))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "wrong-entry-feedback").firstMatch.exists)

        app.buttons["number-\(solution[index])"].tap()
        XCTAssertTrue(cell.label.hasSuffix(", \(solution[index])"))
        app.buttons["tool-undo"].tap()
        XCTAssertTrue(cell.label.contains("empty"))
        XCTAssertTrue(strikes.label.hasPrefix("1"), "Undo must not remove a strike")
        assertEntireGameFits(app)

        // The last strike's alert must wait until the rejection flight completes.
        XCTAssertTrue(strikes.label.contains("of 3"))
        app.buttons["number-\(wrong)"].tap()
        app.buttons["number-\(wrong)"].tap()
        XCTAssertTrue(app.alerts["Strike limit reached"].waitForExistence(timeout: 3))
        app.alerts.buttons["Retry This Puzzle"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(strikes.label.hasPrefix("0"))
        XCTAssertTrue(cell.label.contains("empty"))
    }

    func testCorruptSaveRequiresExplicitRecovery() throws {
        let app = fixtureApp()
        app.launchEnvironment["GRIDZERO_TEST_SAVE"] = "corrupt"
        app.launch()
        let recovery = app.alerts["Couldn't restore your game"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["cell-0"].exists)
        recovery.buttons["Retry"].tap()
        XCTAssertTrue(recovery.waitForExistence(timeout: 5))
        recovery.buttons["New Puzzle"].tap()
        XCTAssertTrue(app.buttons["Start Puzzle"].waitForExistence(timeout: 5))
        tapCenter(app.buttons["Start Puzzle"])
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        XCTAssertFalse(recovery.exists)
        XCUIDevice.shared.press(.home)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
        XCTAssertFalse(recovery.exists)
    }

    func testRestartAlertPausesTimer() throws {
        let app = fixtureApp()
        app.launchEnvironment["GRIDZERO_TEST_TIMER"] = "1"
        app.launch()
        let timer = app.staticTexts["elapsed-time"]
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        selectMenu("Restart Puzzle", in: app)
        XCTAssertTrue(app.alerts["Restart this puzzle?"].waitForExistence(timeout: 3))
        let paused = timer.label
        // Wait via an XCTest expectation rather than blocking the app's run loop.
        let changes = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { timer.label != paused }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [changes], timeout: 3), .timedOut)
        app.alerts.buttons["Cancel"].tap()
        let resumes = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { timer.label != paused }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resumes], timeout: 4), .completed)
    }

    private func assertEntireGameFits(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.scrollViews.count, 0, "Playing should never require a scroll view", file: file, line: line)
        for digit in 1...9 {
            let button = app.buttons["number-\(digit)"]
            XCTAssertTrue(button.isHittable, "Key \(digit) must be reachable", file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX, file: file, line: line)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX, file: file, line: line)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.frame.maxY - 34,
                                     "The entire key must clear the home indicator", file: file, line: line)
        }
        let first = app.buttons["cell-0"].frame
        let last = app.buttons["cell-8"].frame
        XCTAssertEqual(first.minX, 0, accuracy: 2, file: file, line: line)
        XCTAssertEqual(last.maxX, app.frame.width, accuracy: 2, file: file, line: line)
        XCTAssertEqual(first.width * 9, app.frame.width, accuracy: 2, file: file, line: line)
    }
}
