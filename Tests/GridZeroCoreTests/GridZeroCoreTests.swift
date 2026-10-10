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
    let task = Task.detached {
        try await Task.sleep(for: .milliseconds(20))
        return try PuzzleFactory.generate(.expert)
    }
    task.cancel()
    do { _ = try await task.value; Issue.record("Cancelled generation returned a puzzle") }
    catch { #expect(error is CancellationError) }
}
