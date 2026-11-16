import XCTest

@MainActor
func fixtureApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["GRIDZERO_TEST_SESSION"] = UUID().uuidString
    return app
}

@MainActor
func selectMenu(_ title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let menu = app.buttons["Game menu"]
    XCTAssertTrue(menu.waitForExistence(timeout: 5), file: file, line: line)
    menu.tap()
    let item = app.buttons[title]
    tapCenter(item, file: file, line: line)
}

@MainActor
func tapCenter(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(element.waitForExistence(timeout: 3), file: file, line: line)
    // iOS 27 can return an invalid activation point for visible SwiftUI Menu/Form
    // rows. Use the element's actual frame, rather than an off-screen hit point.
    element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
}
