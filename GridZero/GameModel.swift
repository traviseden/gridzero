import Foundation
import Observation
import GridZeroCore
import UIKit

struct GameNotice: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

@MainActor @Observable
final class GameModel {
    typealias PuzzleLoader = @Sendable (Difficulty, PuzzleSource, Int, Set<String>) throws -> Puzzle
    typealias EntryFeedback = @MainActor (MoveResult, Int, Int, Bool) -> Void

    var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: "preferences.v1")
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
    var loading = false
    var generationError: String?
    var showCompletion = false
    var showStrikeOut = false
    var clock = Date()
    var saveError: String?
    private(set) var recoveryError: String?
    var showRecoveryAlert = false
    private var initialized = false
    private var preserveOriginal = false
    private var played: [String] = []
    private var worker: Task<Puzzle, Error>?
    private var requestID: UUID?
    private var lastTick: TimeInterval?
    private var lastCheckpoint: TimeInterval
    private var errorFeedbackID = UUID()
    private var pendingWrite: Task<Void, Never>?
    private var writeID = UUID()
    private let defaults: UserDefaults
    private let storage: any GameStorage
    private let uptime: () -> TimeInterval
    private let loadPuzzle: PuzzleLoader
    private let entryFeedback: EntryFeedback

    init(defaults: UserDefaults = .standard, storage: any GameStorage = GameStore(),
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         loadPuzzle: @escaping PuzzleLoader = GameModel.makePuzzle,
         entryFeedback: @escaping EntryFeedback = GameModel.hardwareFeedback) {
        self.defaults = defaults
        self.storage = storage
        self.uptime = uptime
        self.loadPuzzle = loadPuzzle
        self.entryFeedback = entryFeedback
        lastCheckpoint = uptime()
        preferences = defaults.data(forKey: "preferences.v1")
            .flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
    }

    nonisolated static func makePuzzle(_ difficulty: Difficulty, _ source: PuzzleSource,
                                      _ empty: Int, _ excluded: Set<String>) throws -> Puzzle {
        if source == .collection && difficulty != .custom {
            return try PuzzleFactory.collection(difficulty, excluding: excluded)
        }
        return try PuzzleFactory.generate(difficulty, emptySquares: empty)
    }

    func bootstrap() async {
        guard !initialized else { return }
        initialized = true
        await restore()
        if Task.isCancelled, game == nil, recoveryError == nil { initialized = false }
    }

    func restore() async {
        guard !loading, game == nil else { return }
        loading = true
        defer { loading = false }
        do {
            let restored = try await storage.load()
            try Task.checkCancellation()
            if let save = restored {
                game = save.game
                played = Array(save.played.suffix(500))
                selected = save.game.board.values.firstIndex(of: 0)
                showStrikeOut = save.game.isOut
            }
            recoveryError = nil
            showRecoveryAlert = false
            preserveOriginal = false
        } catch {
            if error is CancellationError || Task.isCancelled {
                initialized = false
                return
            }
            preserveOriginal = true
            recoveryError = error is SaveReadError
                ? "Your previous save couldn't be restored. Retry or start a new puzzle. The original save will be preserved."
                : "Your previous save couldn't be read: \(error.localizedDescription)"
            showRecoveryAlert = true
            return
        }
        loading = false
        if game == nil {
            _ = await start(difficulty: preferences.difficulty, mode: preferences.mode,
                            source: preferences.source, empty: preferences.customEmpty)
        }
    }

    func start(difficulty: Difficulty, mode: PlayMode, source: PuzzleSource, empty: Int) async -> Bool {
        cancelGeneration()
        let id = UUID()
        requestID = id
        generating = true; generationError = nil
        let excluded = Set(played)
        let loader = loadPuzzle
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let puzzle = try loader(difficulty, source, empty, excluded)
            try Task.checkCancellation()
            return puzzle
        }
        worker = task
        do {
            let puzzle = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            try Task.checkCancellation()
            guard requestID == id else { return false }
            game = Game(puzzle: puzzle, mode: mode, strikeLimit: preferences.strikeLimit)
            selected = puzzle.givens.firstIndex(of: 0)
            pencil = false; checkedCells = []; errorCell = nil
            errorFeedbackID = UUID()
            showCompletion = false; showStrikeOut = false; notice = nil
            played.append(puzzle.id); played = Array(played.suffix(500))
            preferences.difficulty = difficulty; preferences.mode = mode
            preferences.source = difficulty == .custom ? .generated : source; preferences.customEmpty = empty
            lastTick = nil
            lastCheckpoint = uptime()
            generating = false; worker = nil; requestID = nil
            recoveryError = nil; showRecoveryAlert = false
            save()
            return true
        } catch {
            guard requestID == id else { return false }
            generating = false; worker = nil; requestID = nil
            if !(error is CancellationError), !Task.isCancelled { generationError = error.localizedDescription }
            return false
        }
    }

    func cancelGeneration() {
        worker?.cancel(); worker = nil; requestID = nil; generating = false
    }

    @discardableResult
    func enter(_ digit: Int, deferOutcome: Bool = false) -> MoveResult {
        guard let selected else { return .ignored }
        accountTime()
        checkedCells = []
        let result = game?.enter(digit, at: selected, pencil: pencil, cleanup: preferences.cleanupNotes) ?? .ignored
        // Rule feedback is synchronous; replacing/cancelling a visual flight cannot
        // lose a strike announcement or report a later entry's strike count.
        if result != .ignored {
            entryFeedback(result, game?.strikes ?? 0, game?.strikeLimit ?? 3, preferences.haptics)
        }
        if result == .strike {
            errorCell = selected
            let token = UUID()
            errorFeedbackID = token
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                if errorFeedbackID == token { errorCell = nil }
            }
        }
        if game?.finished == true || game?.isOut == true { lastTick = nil }
        if !deferOutcome { finishEntryPresentation() }
        if result != .ignored { save() }
        return result
    }

    static func hardwareFeedback(_ result: MoveResult, _ strikes: Int, _ limit: Int, _ haptics: Bool) {
        switch result {
        case .strike:
            if haptics { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            UIAccessibility.post(notification: .announcement,
                                 argument: "Incorrect. Strike \(strikes)\(limit == 0 ? "" : " of \(limit)").")
        case .completed:
            if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        case .changed:
            if haptics { UISelectionFeedbackGenerator().selectionChanged() }
        case .ignored: break
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
        lastTick = nil; lastCheckpoint = uptime()
        game = Game(puzzle: old.puzzle, mode: old.mode, strikeLimit: old.strikeLimit)
        selected = old.puzzle.givens.firstIndex(of: 0)
        pencil = false; showStrikeOut = false; showCompletion = false; checkedCells = []
        errorCell = nil; errorFeedbackID = UUID()
        save()
    }
    func checkBoard() {
        guard let game else { return }
        pause()
        checkedCells = Set((0..<81).filter { game.board.values[$0] != 0 && game.board.values[$0] != game.puzzle.solution[$0] })
        notice = GameNotice(title: checkedCells.isEmpty ? "Looking good" : "A second look",
                            message: checkedCells.isEmpty ? "All your entered numbers are correct so far." :
                                "\(checkedCells.count) \(checkedCells.count == 1 ? "cell needs" : "cells need") another look. They're marked on the board.")
    }

    func setActive(_ active: Bool) {
        if active, game?.finished == false, game?.isOut == false {
            if lastTick == nil { lastTick = uptime() }
        } else { pause() }
    }

    private func accountTime() {
        guard let lastTick else { return }
        let now = uptime()
        let elapsed = min(Game.maximumElapsed, (game?.elapsed ?? 0) + max(0, now - lastTick))
        game?.elapsed = elapsed
        self.lastTick = now
    }

    func tick() {
        clock = Date()
        accountTime()
        if lastTick != nil, uptime() - lastCheckpoint >= 15 { save() }
    }

    func pause() {
        accountTime()
        lastTick = nil
        guard let write = save() else { return }
        // Give the ordered background writer time to finish when the scene suspends.
        let lease = SaveBackgroundLease()
        Task { await write.value; lease.end() }
    }

    @discardableResult
    func save() -> Task<Void, Never>? {
        accountTime()
        guard let game else { return nil }
        lastCheckpoint = uptime()
        let snapshot = SaveEnvelope(game: game, played: played)
        let previous = pendingWrite
        let id = UUID()
        writeID = id
        let preserve = preserveOriginal
        let storage = storage
        let task = Task {
            // Actor isolation alone doesn't guarantee the order of separately
            // scheduled tasks. Chain submissions so an old move cannot win.
            await previous?.value
            do {
                try await storage.write(snapshot, preservingOriginal: preserve)
                guard writeID == id else { return }
                saveError = nil
                preserveOriginal = false
            } catch {
                guard writeID == id else { return }
                saveError = "Couldn't save your progress: \(error.localizedDescription)"
            }
        }
        pendingWrite = task
        return task
    }

    func flushSaves() async { await pendingWrite?.value }

    func feedback() {
        if preferences.haptics { UISelectionFeedbackGenerator().selectionChanged() }
    }
}

@MainActor
private final class SaveBackgroundLease {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    init() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Save game") { [weak self] in
            self?.end()
        }
    }
    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
