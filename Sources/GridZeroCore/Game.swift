import Foundation

public struct BoardState: Codable, Equatable, Sendable {
    public var values: [Int]
    public var notes: [UInt16]
    public init(values: [Int], notes: [UInt16] = Array(repeating: 0, count: 81)) {
        self.values = values; self.notes = notes
    }
}

public enum MoveResult: Equatable, Sendable { case ignored, changed, strike, completed }

public struct Game: Codable, Sendable {
    public let puzzle: Puzzle
    public var mode: PlayMode
    public let strikeLimit: Int // 0 means unlimited
    public private(set) var strikes = 0
    public private(set) var board: BoardState
    public private(set) var undoStack: [BoardState] = []
    public private(set) var redoStack: [BoardState] = []
    public var elapsed: TimeInterval = 0
    public private(set) var finished = false

    public init(puzzle: Puzzle, mode: PlayMode = .challenge, strikeLimit: Int = 3) {
        self.puzzle = puzzle; self.mode = mode; self.strikeLimit = strikeLimit
        self.board = BoardState(values: puzzle.givens)
    }
    public var isOut: Bool { mode == .challenge && strikeLimit > 0 && strikes >= strikeLimit && !finished }
    public var filledCount: Int { board.values.filter { $0 != 0 }.count }
    public var canUndo: Bool { !undoStack.isEmpty && !finished && !isOut }
    public var canRedo: Bool { !redoStack.isEmpty && !finished && !isOut }

    private mutating func remember() {
        undoStack.append(board)
        if undoStack.count > 300 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    @discardableResult
    public mutating func enter(_ digit: Int, at index: Int, pencil: Bool, cleanup: Bool = false) -> MoveResult {
        guard (0..<81).contains(index), (1...9).contains(digit), puzzle.givens[index] == 0,
              !finished, !isOut else { return .ignored }
        if pencil {
            guard board.values[index] == 0 else { return .ignored }
            remember(); board.notes[index] ^= 1 << digit
            return .changed
        }
        guard board.values[index] != digit else { return .ignored }
        if mode == .challenge && puzzle.solution[index] != digit {
            strikes += 1; return .strike
        }
        remember()
        board.values[index] = digit
        board.notes[index] = 0
        if cleanup {
            for peer in Sudoku.peers[index] { board.notes[peer] &= ~(1 << digit) }
        }
        finished = Sudoku.isComplete(board.values)
        return finished ? .completed : .changed
    }

    public mutating func erase(at index: Int) {
        guard (0..<81).contains(index), puzzle.givens[index] == 0, !finished, !isOut,
              board.values[index] != 0 || board.notes[index] != 0 else { return }
        remember(); board.values[index] = 0; board.notes[index] = 0
    }
    public mutating func fillNotes() {
        guard !finished, !isOut else { return }
        let notes = (0..<81).map { Sudoku.candidates(board.values, at: $0) }
        guard notes != board.notes else { return }
        remember(); board.notes = notes
    }
    public mutating func undo() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        redoStack.append(board); board = previous
    }
    public mutating func redo() {
        guard canRedo, let next = redoStack.popLast() else { return }
        undoStack.append(board); board = next
    }
    public mutating func continueInClassic() { mode = .classic }

    /// Validate persisted state before letting UI index into it.
    public var isValidSave: Bool {
        guard puzzle.givens.count == 81, puzzle.solution.count == 81,
              Sudoku.isComplete(puzzle.solution), Sudoku.isConsistent(puzzle.givens),
              strikes >= 0, strikeLimit >= 0, elapsed.isFinite, elapsed >= 0,
              undoStack.count <= 300, redoStack.count <= 300 else { return false }
        guard (0..<81).allSatisfy({ puzzle.givens[$0] == 0 || puzzle.givens[$0] == puzzle.solution[$0] }) else { return false }
        func valid(_ state: BoardState) -> Bool {
            state.values.count == 81 && state.notes.count == 81 &&
            state.values.allSatisfy { (0...9).contains($0) } &&
            state.notes.allSatisfy { $0 & ~Sudoku.all == 0 } &&
            (0..<81).allSatisfy { puzzle.givens[$0] == 0 || state.values[$0] == puzzle.givens[$0] }
        }
        return valid(board) && undoStack.allSatisfy(valid) && redoStack.allSatisfy(valid) &&
            finished == Sudoku.isComplete(board.values)
    }
}
