import Testing
import Foundation
@testable import GridZeroCore

private let example = "530070000600195000098000060800060003400803001700020006060000280000419005000080079".compactMap { $0.wholeNumberValue }

private func puzzle() -> Puzzle {
    Puzzle(id: "fixture", givens: example, solution: Sudoku.solutions(example, limit: 1)[0], difficulty: .easy, source: .collection)
}

@Test func solverRejectsInvalidAndAmbiguousBoards() {
    #expect(Sudoku.solutions(example).count == 1)
    var invalid = example; invalid[2] = 5
    #expect(Sudoku.solutions(invalid).isEmpty)
    #expect(Sudoku.solutions(Array(repeating: 0, count: 81)).count == 2)
    #expect(!Sudoku.isConsistent([1, 2]))
    #expect(Sudoku.isComplete(puzzle().solution))
}

@Test func challengeRejectsWrongDigitAndKeepsStrikesAcrossUndo() {
    let p = puzzle()
    var game = Game(puzzle: p)
    let index = 2
    #expect(game.enter(p.solution[index] % 9 + 1, at: index, pencil: false) == .strike)
    #expect(game.board.values[index] == 0)
    #expect(game.strikes == 1)
    #expect(game.enter(p.solution[index], at: index, pencil: false) == .changed)
    game.undo()
    #expect(game.board.values[index] == 0)
    #expect(game.strikes == 1)
    _ = game.enter(p.solution[index] % 9 + 1, at: index, pencil: false)
    _ = game.enter(p.solution[index] % 9 + 1, at: index, pencil: false)
    #expect(game.isOut)
    #expect(game.enter(p.solution[index], at: index, pencil: false) == .ignored)
    game.continueInClassic()
    #expect(!game.isOut)
}

@Test func notesCleanupAndUndoRestoreAllAffectedCells() {
    let p = puzzle()
    var game = Game(puzzle: p)
    let index = 2
    let peer = 3
    let digit = p.solution[index]
    _ = game.enter(digit, at: peer, pencil: true)
    _ = game.enter(digit, at: index, pencil: false, cleanup: true)
    #expect(game.board.notes[peer] == 0)
    game.undo()
    #expect(game.board.notes[peer] == 1 << digit)
    #expect(game.board.values[index] == 0)
    game.redo()
    #expect(game.board.values[index] == digit)
    #expect(game.board.notes[peer] == 0)
}

@Test func classicAllowsHypothesesButOnlyValidCompletionWins() {
    let p = puzzle()
    var game = Game(puzzle: p, mode: .classic)
    let wrong = p.solution[2] % 9 + 1
    #expect(game.enter(wrong, at: 2, pencil: false) == .changed)
    #expect(game.strikes == 0)
    #expect(game.board.values[2] == wrong)
    for index in 0..<81 where p.givens[index] == 0 && index != 2 {
        _ = game.enter(p.solution[index], at: index, pencil: false)
    }
    #expect(!game.finished)
    #expect(game.enter(p.solution[2], at: 2, pencil: false) == .completed)
    #expect(game.finished)
}

@Test func autofillUsesCurrentBoardAndIsUndoable() {
    var game = Game(puzzle: puzzle(), mode: .classic)
    game.fillNotes()
    #expect(game.board.notes[2] == Sudoku.candidates(example, at: 2))
    #expect(game.board.notes[0] == 0)
    game.undo()
    #expect(game.board.notes.allSatisfy { $0 == 0 })
}

@Test func savesRoundTripAndRejectMalformedState() throws {
    var game = Game(puzzle: puzzle())
    _ = game.enter(1, at: 2, pencil: true)
    let data = try JSONEncoder().encode(game)
    let restored = try JSONDecoder().decode(Game.self, from: data)
    #expect(restored.isValidSave)
    #expect(restored.board == game.board)
    let broken = Puzzle(id: "broken", givens: [0], solution: [1], difficulty: .easy, source: .generated)
    #expect(!Game(puzzle: broken).isValidSave)
}

@Test func bundledCollectionHasRatedUniquePuzzles() throws {
    for difficulty in Difficulty.allCases where difficulty != .custom {
        let p = try PuzzleFactory.collection(difficulty)
        #expect(p.givens.count == 81)
        #expect(Sudoku.solutions(p.givens).count == 1)
        #expect(Sudoku.isComplete(p.solution))
        #expect(p.rating != nil)
    }
}

@Test func generatorProducesUniqueExactCustomCount() throws {
    let p = try PuzzleFactory.generate(.custom, emptySquares: 45)
    #expect(p.givens.filter { $0 == 0 }.count == 45)
    #expect(Sudoku.solutions(p.givens) == [p.solution])
    #expect(p.source == .generated)
}

@Test func generatedDifficultyMatchesLogicalGrade() throws {
    for difficulty in [Difficulty.easy, .medium, .hard, .expert] {
        let p = try PuzzleFactory.generate(difficulty)
        #expect(Sudoku.grade(p.givens) == difficulty)
        #expect(Sudoku.solutions(p.givens).count == 1)
    }
}

@Test func generationRespectsCancellation() async {
    let started = AsyncStream<Void>.makeStream()
    let resume = DispatchSemaphore(value: 0)
    let task = Task.detached {
        defer { started.continuation.finish() }
        return try PuzzleFactory.generate(.expert, emptySquares: 45) {
            started.continuation.yield(())
            resume.wait()
        }
    }
    for await _ in started.stream { break }
    task.cancel()
    resume.signal()
    started.continuation.finish()
    do { _ = try await task.value; Issue.record("Cancelled generation returned a puzzle") }
    catch { #expect(error is CancellationError) }
}

private func mutatedSave(_ mutation: (inout [String: Any]) -> Void) throws -> Game {
    let data = try JSONEncoder().encode(Game(puzzle: puzzle()))
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    mutation(&object)
    return try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: object))
}

@Test func savesRejectUnsafeNumbersAndPreserveLegacyLimits() throws {
    for elapsed in [-1.0, 1e30] {
        #expect(try !mutatedSave { $0["elapsed"] = elapsed }.isValidSave)
    }
    #expect(try !mutatedSave { $0["strikes"] = Int.max; $0["strikeLimit"] = 0 }.isValidSave)
    #expect(try !mutatedSave { $0["strikeLimit"] = Int.max }.isValidSave)
    for limit in [0, 3, 10] {
        #expect(try mutatedSave { $0["strikeLimit"] = limit }.isValidSave)
    }
    var unlimited = try mutatedSave { $0["strikeLimit"] = 0; $0["strikes"] = Game.maximumStrikes }
    #expect(unlimited.isValidSave)
    #expect(unlimited.enter(puzzle().solution[2] % 9 + 1, at: 2, pencil: false) == .strike)
    #expect(unlimited.strikes == Game.maximumStrikes)
    var game = Game(puzzle: puzzle())
    for elapsed in [Double.infinity, Double.nan, -1, 1e30] {
        game.elapsed = elapsed
        #expect(!game.elapsedText.isEmpty)
    }
    game.elapsed = 65
    #expect(game.elapsedText == "1:05")
}

@Test func savesRejectCompletedHistoryAndAmbiguousPuzzles() throws {
    let completed = ["values": puzzle().solution, "notes": Array(repeating: 0, count: 81)]
    for key in ["undoStack", "redoStack"] {
        #expect(try !mutatedSave { $0[key] = [completed] }.isValidSave)
    }
    let ambiguous = Puzzle(id: "ambiguous", givens: Array(repeating: 0, count: 81),
                           solution: puzzle().solution, difficulty: .custom, source: .generated)
    #expect(!Game(puzzle: ambiguous).isValidSave)
    let state = ["values": example, "notes": Array(repeating: 0, count: 81)]
    #expect(try !mutatedSave {
        $0["undoStack"] = Array(repeating: state, count: 200)
        $0["redoStack"] = Array(repeating: state, count: 200)
    }.isValidSave)
}

@Test func fullHistoryRoundTripsAndCompletionLocksActions() throws {
    var game = Game(puzzle: puzzle())
    for _ in 0..<350 { game.enter(1, at: 2, pencil: true) }
    #expect(game.undoStack.count == 300)
    for _ in 0..<150 { game.undo() }
    #expect(game.isValidSave)
    let restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
    #expect(restored.isValidSave)
    for _ in 0..<150 { game.redo() }
    #expect(game.isValidSave)
    for index in 0..<81 where example[index] == 0 { game.enter(puzzle().solution[index], at: index, pencil: false) }
    let completed = game.board
    game.undo(); game.redo(); game.erase(at: 2); game.fillNotes()
    #expect(game.finished)
    #expect(game.board == completed)
    #expect(game.isValidSave)
}
