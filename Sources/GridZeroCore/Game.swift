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
    // Storage bounds also keep downstream arithmetic safe (over 68 years per game).
    public static let maximumElapsed: TimeInterval = 2_147_483_647
    public static let maximumStrikes = 2_147_483_647
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
    public var elapsedText: String {
        let seconds = Int(elapsed.isFinite ? min(Self.maximumElapsed, max(0, elapsed)) : 0)
        return "\(seconds / 60):\(seconds % 60 < 10 ? "0" : "")\(seconds % 60)"
    }

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
            if strikes < Self.maximumStrikes { strikes += 1 }
            return .strike
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
        finished = Sudoku.isComplete(board.values)
    }
    public mutating func redo() {
        guard canRedo, let next = redoStack.popLast() else { return }
        undoStack.append(board); board = next
        finished = Sudoku.isComplete(board.values)
    }
    public mutating func continueInClassic() { mode = .classic }

    /// Validate persisted state before letting UI index into it.
    public var isValidSave: Bool {
        guard puzzle.givens.count == 81, puzzle.solution.count == 81,
              Sudoku.isComplete(puzzle.solution), Sudoku.isConsistent(puzzle.givens),
               (0...Self.maximumStrikes).contains(strikes), (0...10).contains(strikeLimit),
               elapsed.isFinite, (0...Self.maximumElapsed).contains(elapsed),
               undoStack.count <= 300, redoStack.count <= 300,
               undoStack.count + redoStack.count <= 300 else { return false }
        guard (0..<81).allSatisfy({ puzzle.givens[$0] == 0 || puzzle.givens[$0] == puzzle.solution[$0] }) else { return false }
        func valid(_ state: BoardState) -> Bool {
            guard state.values.count == 81, state.notes.count == 81,
                  state.values.allSatisfy({ (0...9).contains($0) }),
                  state.notes.allSatisfy({ $0 & ~Sudoku.all == 0 }) else { return false }
            return (0..<81).allSatisfy { index in
                let value = state.values[index]
                if puzzle.givens[index] != 0 && value != puzzle.givens[index] { return false }
                if value != 0 && state.notes[index] != 0 { return false }
                return mode != .challenge || value == 0 || value == puzzle.solution[index]
            }
        }
        func validHistory(_ state: BoardState) -> Bool {
            valid(state) && !Sudoku.isComplete(state.values)
        }
        guard valid(board), undoStack.allSatisfy(validHistory), redoStack.allSatisfy(validHistory),
              finished == Sudoku.isComplete(board.values),
              !finished || redoStack.isEmpty else { return false }
        // A bounded, exhausted search returns no solutions, never a false uniqueness result.
        return Sudoku.solutions(puzzle.givens) == [puzzle.solution]
    }
}
