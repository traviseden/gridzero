import Foundation
import GridZeroCore

struct SaveEnvelope: Codable, Sendable {
    var version = 1
    var game: Game
    var played: [String]
}

protocol GameStorage: Sendable {
    func load() async throws -> SaveEnvelope?
    func write(_ save: SaveEnvelope, preservingOriginal: Bool) async throws
}

enum SaveReadError: Error {
    case invalid
}

/// Encoding, disk access, and bounded solution validation never run on the UI actor.
actor GameStore: GameStorage {
    static let defaultURL = URL.applicationSupportDirectory
        .appending(path: "GridZero", directoryHint: .isDirectory).appending(path: "game-v1.json")
    private let url: URL
    private var preservedOriginal = false

    init(url: URL = defaultURL) { self.url = url }

    func load() throws -> SaveEnvelope? {
        try Task.checkCancellation()
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch CocoaError.fileReadNoSuchFile { return nil }
        let save: SaveEnvelope
        do { save = try JSONDecoder().decode(SaveEnvelope.self, from: data) }
        catch { throw SaveReadError.invalid }
        let valid = save.version == 1 && save.game.isValidSave
        try Task.checkCancellation()
        guard valid else { throw SaveReadError.invalid }
        return save
    }

    func write(_ save: SaveEnvelope, preservingOriginal: Bool) throws {
        let data = try JSONEncoder().encode(save)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if preservingOriginal && !preservedOriginal {
            let backup = directory.appending(path: "game-recovery-\(UUID().uuidString).json")
            // Copy without a preflight existence check: permission failures must not
            // masquerade as a missing save. If preservation fails, do not overwrite.
            do { try FileManager.default.copyItem(at: url, to: backup) }
            catch CocoaError.fileNoSuchFile { /* The original was removed externally. */ }
            preservedOriginal = true
        }
        try data.write(to: url, options: .atomic)
    }
}
