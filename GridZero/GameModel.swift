import Foundation
import Observation
import GridZeroCore
import UIKit

struct Preferences: Codable {
    var theme: Theme = .ink
    var appearance: Appearance = .system
    var lightAt = 7 * 60
    var darkAt = 19 * 60
    var source: PuzzleSource = .collection
    var difficulty: Difficulty = .easy
    var mode: PlayMode = .challenge
    var strikeLimit = 3
    var customEmpty = 45
    var allowAutofill = false
    var cleanupNotes = false
    var highlightPeers = true
    var highlightMatching = true
    var showTimer = false
    var haptics = true
}

struct SaveEnvelope: Codable {
    var version = 1
    var game: Game
    var played: [String]
}

struct GameNotice: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

@MainActor @Observable
final class GameModel {
    var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) {
                UserDefaults.standard.set(data, forKey: "preferences.v1")
            }
        }
    }
    var game: Game?
    var selected: Int?
    var pencil = false
    var errorCell: Int?
    var checkedCells: Set<Int> = []
    var notice: GameNotice?
    var generating = false
    var generationError: String?
    var showCompletion = false
    var showStrikeOut = false
    var clock = Date()
    var saveError: String?
    private var played: [String] = []
    private var worker: Task<Puzzle, Error>?
    private var requestID: UUID?
    private var lastTick: Date?
    private var errorFeedbackID = UUID()
    private let saveURL: URL

    init() {
        let stored = UserDefaults.standard.data(forKey: "preferences.v1")
        var prefs = stored.flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        prefs.customEmpty = min(60, max(20, prefs.customEmpty))
        prefs.strikeLimit = [0, 3, 5, 10].contains(prefs.strikeLimit) ? prefs.strikeLimit : 3
        prefs.lightAt = min(1439, max(0, prefs.lightAt))
        prefs.darkAt = min(1439, max(0, prefs.darkAt))
        preferences = prefs
        saveURL = URL.applicationSupportDirectory.appending(path: "GridZero", directoryHint: .isDirectory)
            .appending(path: "game-v1.json")
        if let data = try? Data(contentsOf: saveURL) {
            if let save = try? JSONDecoder().decode(SaveEnvelope.self, from: data),
               save.version == 1, save.game.isValidSave {
                game = save.game; played = Array(save.played.suffix(500))
                selected = save.game.board.values.firstIndex(of: 0)
                showStrikeOut = save.game.isOut
            } else {
                saveError = "Your previous save couldn't be restored. You can start a new puzzle."
            }
        }
    }

    func start(difficulty: Difficulty, mode: PlayMode, source: PuzzleSource, empty: Int) async -> Bool {
        cancelGeneration()
        let id = UUID()
        requestID = id
        generating = true; generationError = nil
        let excluded = Set(played)
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            if source == .collection && difficulty != .custom {
                return try PuzzleFactory.collection(difficulty, excluding: excluded)
            }
            return try PuzzleFactory.generate(difficulty, emptySquares: empty)
        }
        worker = task
        do {
            let puzzle = try await task.value
            guard requestID == id else { return false }
            game = Game(puzzle: puzzle, mode: mode, strikeLimit: preferences.strikeLimit)
            selected = puzzle.givens.firstIndex(of: 0)
            pencil = false; checkedCells = []; errorCell = nil
            errorFeedbackID = UUID()
            showCompletion = false; showStrikeOut = false
            played.append(puzzle.id); played = Array(played.suffix(500))
            preferences.difficulty = difficulty; preferences.mode = mode
            preferences.source = source; preferences.customEmpty = empty
            lastTick = nil
            generating = false; worker = nil; requestID = nil
            save()
            return true
        } catch {
            guard requestID == id else { return false }
            generating = false; worker = nil; requestID = nil
            if !(error is CancellationError) { generationError = error.localizedDescription }
            return false
        }
    }

    func cancelGeneration() {
        worker?.cancel(); worker = nil; requestID = nil; generating = false
    }

    @discardableResult
    func enter(_ digit: Int, deferFeedback: Bool = false) -> MoveResult {
        guard let selected else { return .ignored }
        checkedCells = []
        let result = game?.enter(digit, at: selected, pencil: pencil, cleanup: preferences.cleanupNotes) ?? .ignored
        if !deferFeedback { presentEntryFeedback(result, at: selected) }
        // Persist the rule result immediately, independently of the visual flight.
        save()
        return result
    }

    func presentEntryFeedback(_ result: MoveResult, at index: Int, showOutcome: Bool = true) {
        switch result {
        case .strike:
            errorCell = index
            let token = UUID()
            errorFeedbackID = token
            feedback(error: true)
            UIAccessibility.post(notification: .announcement,
                                 argument: "Incorrect. Strike \(game?.strikes ?? 0)\(game?.strikeLimit == 0 ? "" : " of \(game?.strikeLimit ?? 3)").")
            if showOutcome && game?.isOut == true { showStrikeOut = true }
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                if errorFeedbackID == token { errorCell = nil }
            }
        case .completed:
            if showOutcome { showCompletion = true }
            if preferences.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        case .changed: feedback()
        default: break
        }
    }

    func finishEntryPresentation() {
        if game?.isOut == true { showStrikeOut = true }
        if game?.finished == true { showCompletion = true }
    }

    func erase() { if let selected { game?.erase(at: selected); checkedCells = []; save() } }
    func undo() { game?.undo(); checkedCells = []; save() }
    func redo() { game?.redo(); checkedCells = []; save() }
    func fillNotes() { game?.fillNotes(); save() }
    func continueClassic() { game?.continueInClassic(); showStrikeOut = false; save() }
    func retry() {
        guard let old = game else { return }
        game = Game(puzzle: old.puzzle, mode: old.mode, strikeLimit: old.strikeLimit)
        selected = old.puzzle.givens.firstIndex(of: 0)
        pencil = false; showStrikeOut = false; showCompletion = false; checkedCells = []
        errorCell = nil; errorFeedbackID = UUID()
        save()
    }
    func checkBoard() {
        guard let game else { return }
        checkedCells = Set((0..<81).filter { game.board.values[$0] != 0 && game.board.values[$0] != game.puzzle.solution[$0] })
        notice = GameNotice(title: checkedCells.isEmpty ? "Looking good" : "A second look",
                            message: checkedCells.isEmpty ? "All your entered numbers are correct so far." :
                                "\(checkedCells.count) \(checkedCells.count == 1 ? "cell needs" : "cells need") another look. They're marked on the board.")
    }

    func tick(active: Bool) {
        let now = Date(); clock = now
        if active, game?.finished == false, game?.isOut == false {
            if let lastTick { game?.elapsed += max(0, min(5, now.timeIntervalSince(lastTick))) }
            self.lastTick = now
        } else { lastTick = nil }
    }
    func pause() { lastTick = nil; save() }
    func save() {
        guard let game else { return }
        do {
            try FileManager.default.createDirectory(at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SaveEnvelope(game: game, played: played))
            try data.write(to: saveURL, options: .atomic)
            saveError = nil
        } catch { saveError = "Couldn't save your progress: \(error.localizedDescription)" }
    }
    func feedback(error: Bool = false) {
        guard preferences.haptics else { return }
        if error { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        else { UISelectionFeedbackGenerator().selectionChanged() }
    }
}
