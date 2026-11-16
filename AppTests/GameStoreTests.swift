import XCTest
import GridZeroCore
@testable import GridZero

final class GameStoreTests: XCTestCase {
    func testCorruptionIsPreservedBeforeReplacementAndBackupIsNotOverwritten() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "game-v1.json")
        let original = Data("broken save".utf8)
        try original.write(to: url)
        let store = GameStore(url: url)
        do { _ = try await store.load(); XCTFail("Corrupt save loaded") }
        catch { XCTAssertTrue(error is SaveReadError) }
        XCTAssertEqual(try Data(contentsOf: url), original)
        let puzzle = try PuzzleFactory.collection(.easy)
        var save = SaveEnvelope(game: Game(puzzle: puzzle), played: [puzzle.id])
        try await store.write(save, preservingOriginal: true)
        save.game.enter(1, at: puzzle.givens.firstIndex(of: 0)!, pencil: true)
        try await store.write(save, preservingOriginal: true)
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("game-recovery-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), original)
        let restored = try await store.load()
        XCTAssertEqual(restored?.game.board, save.game.board)
    }

    func testOnlyMissingFilesAreTreatedAsFreshInstall() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = GameStore(url: directory.appending(path: "game.json"))
        let absent = try await store.load()
        XCTAssertNil(absent)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let invalidLocation = GameStore(url: directory)
        do { _ = try await invalidLocation.load(); XCTFail("A read error was treated as missing") }
        catch { XCTAssertFalse(error is SaveReadError) }
    }

    func testUnwritableDestinationReportsFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("not a directory".utf8).write(to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GameStore(url: directory.appending(path: "game.json"))
        let puzzle = try PuzzleFactory.collection(.easy)
        do {
            try await store.write(SaveEnvelope(game: Game(puzzle: puzzle), played: []), preservingOriginal: false)
            XCTFail("Writing under a regular file succeeded")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: directory), Data("not a directory".utf8))
    }
}
