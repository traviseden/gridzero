#if DEBUG
import Foundation
import GridZeroCore

/// Each UI test uses its own sandbox and preferences. Relaunching the same session
/// exercises real persistence, while a new session always starts from a known board.
@MainActor
enum UITestFixture {
    static func makeModel() -> GameModel? {
        let environment = ProcessInfo.processInfo.environment
        guard let session = environment["GRIDZERO_TEST_SESSION"], let id = UUID(uuidString: session),
              let defaults = UserDefaults(suiteName: "win.gridzero.uitests.\(id.uuidString)") else { return nil }
        let directory = URL.applicationSupportDirectory.appending(path: "UITests/\(id.uuidString)")
        let url = directory.appending(path: "game-v1.json")
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var preferences = Preferences()
                preferences.showTimer = environment["GRIDZERO_TEST_TIMER"] == "1"
                defaults.set(try JSONEncoder().encode(preferences), forKey: "preferences.v1")
                if environment["GRIDZERO_TEST_SAVE"] == "corrupt" {
                    try Data("corrupt fixture".utf8).write(to: url, options: .atomic)
                } else {
                    let givens = "530070000600195000098000060800060003400803001700020006060000280000419005000080079".compactMap(\.wholeNumberValue)
                    let puzzle = Puzzle(id: "ui-fixture", givens: givens, solution: Sudoku.solutions(givens)[0],
                                        difficulty: .medium, source: .collection)
                    let save = SaveEnvelope(game: Game(puzzle: puzzle), played: [puzzle.id])
                    try JSONEncoder().encode(save).write(to: url, options: .atomic)
                }
            }
        } catch {
            preconditionFailure("Couldn't create UI test fixture: \(error)")
        }
        return GameModel(defaults: defaults, storage: GameStore(url: url))
    }
}
#endif
