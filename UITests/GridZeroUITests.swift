import XCTest
import GridZeroCore

@MainActor
final class GridZeroUITests: XCTestCase {
    func testBoardNotesUndoAndAppearance() throws {
        let app = XCUIApplication()
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
        app.buttons["Game menu"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Clay theme"].waitForExistence(timeout: 3))
        app.buttons["Clay theme"].tap()
        app.descendants(matching: .any).matching(identifier: "appearance-picker").firstMatch.tap()
        app.buttons["Dark"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["number-1"].waitForExistence(timeout: 3))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[identifier].label.contains("notes:"))
    }

    func testClassicGeneratedPuzzleAndExplicitCheck() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 5))
        app.buttons["Game menu"].tap()
        app.buttons["New Puzzle"].tap()
        XCTAssertTrue(app.buttons["Classic"].waitForExistence(timeout: 3))
        app.buttons["Classic"].tap()
        app.descendants(matching: .any).matching(identifier: "source-picker").firstMatch.tap()
        app.buttons["Generated on Device"].tap()
        app.buttons["Start Puzzle"].tap()
        XCTAssertTrue(app.buttons["Start Puzzle"].waitForNonExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Classic"].waitForExistence(timeout: 20))
        let empty = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' AND label CONTAINS 'empty'")).firstMatch
        XCTAssertTrue(empty.exists)
        let identifier = empty.identifier
        empty.tap()
        app.buttons["number-1"].tap()
        XCTAssertTrue(app.buttons[identifier].label.hasSuffix(", 1"))
        app.buttons["Game menu"].tap()
        app.buttons["Check Board"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()
    }

    func testCompactChallengeEntryAndRejection() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Game menu"].waitForExistence(timeout: 5))
        app.buttons["Game menu"].tap()
        app.buttons["New Puzzle"].tap()
        XCTAssertTrue(app.buttons["Challenge"].waitForExistence(timeout: 3))
        app.buttons["Challenge"].tap()
        app.descendants(matching: .any).matching(identifier: "difficulty-picker").firstMatch.tap()
        app.buttons["Easy"].tap()
        app.descendants(matching: .any).matching(identifier: "source-picker").firstMatch.tap()
        app.buttons["Puzzle Collection"].tap()
        app.buttons["Start Puzzle"].tap()
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
        if strikes.label.contains("of 3") {
            app.buttons["number-\(wrong)"].tap()
            app.buttons["number-\(wrong)"].tap()
            XCTAssertTrue(app.alerts["Time for a fresh start."].waitForExistence(timeout: 3))
            app.alerts.buttons["Retry This Puzzle"].tap()
            XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 3))
            XCTAssertTrue(strikes.label.hasPrefix("0"))
            XCTAssertTrue(cell.label.contains("empty"))
        }
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
