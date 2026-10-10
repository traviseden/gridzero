import Foundation

public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard, expert, custom
    public var title: String { rawValue.capitalized }
}

public enum PlayMode: String, Codable, CaseIterable, Sendable {
    case challenge, classic
    public var title: String { rawValue.capitalized }
}

public enum PuzzleSource: String, Codable, CaseIterable, Sendable {
    case collection, generated
    public var title: String { self == .collection ? "Puzzle Collection" : "Generated on Device" }
}

public struct Puzzle: Codable, Equatable, Sendable {
    public let id: String
    public let givens: [Int]
    public let solution: [Int]
    public let difficulty: Difficulty
    public let source: PuzzleSource
    public let rating: Double?

    public init(id: String, givens: [Int], solution: [Int], difficulty: Difficulty,
                source: PuzzleSource, rating: Double? = nil) {
        self.id = id
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
        self.source = source
        self.rating = rating
    }
}

public enum Sudoku {
    public static let all: UInt16 = 0b1111111110
    public static let units: [[Int]] = {
        let rows = (0..<9).map { row in (0..<9).map { row * 9 + $0 } }
        let columns = (0..<9).map { col in (0..<9).map { $0 * 9 + col } }
        let boxes = (0..<9).map { box in
            (0..<9).map { offset in (box / 3 * 3 + offset / 3) * 9 + box % 3 * 3 + offset % 3 }
        }
        return rows + columns + boxes
    }()
    public static let peers: [[Int]] = (0..<81).map { index in
        Array(Set(units.filter { $0.contains(index) }.flatMap { $0 }).subtracting([index])).sorted()
    }

    public static func digits(_ mask: UInt16) -> [Int] {
        (1...9).filter { mask & (1 << $0) != 0 }
    }

    public static func candidates(_ board: [Int], at index: Int) -> UInt16 {
        guard board.count == 81, (0..<81).contains(index), board[index] == 0 else { return 0 }
        return peers[index].reduce(all) { mask, peer in
            let value = board[peer]
            return (1...9).contains(value) ? mask & ~(1 << value) : mask
        }
    }

    public static func isConsistent(_ board: [Int]) -> Bool {
        guard board.count == 81, board.allSatisfy({ (0...9).contains($0) }) else { return false }
        return units.allSatisfy { unit in
            let values = unit.map { board[$0] }.filter { $0 != 0 }
            return Set(values).count == values.count
        }
    }

    public static func isComplete(_ board: [Int]) -> Bool {
        isConsistent(board) && !board.contains(0)
    }

    public static func solutions(_ input: [Int], limit: Int = 2) -> [[Int]] {
        solve(input, limit: limit, randomized: false)
    }

    private static func solve(_ input: [Int], limit: Int, randomized: Bool) -> [[Int]] {
        guard limit > 0, isConsistent(input) else { return [] }
        var board = input
        var found: [[Int]] = []
        var rows = Array(repeating: UInt16(0), count: 9)
        var columns = rows
        var boxes = rows
        for index in 0..<81 where board[index] != 0 {
            let bit = UInt16(1 << board[index])
            rows[index / 9] |= bit; columns[index % 9] |= bit
            boxes[index / 27 * 3 + index % 9 / 3] |= bit
        }
        var nodes = 0
        var exhausted = false
        func search() {
            guard found.count < limit, !Task<Never, Never>.isCancelled else { return }
            nodes += 1
            if nodes > 100_000 { exhausted = true; return }
            var best = -1
            var bestMask: UInt16 = 0
            var count = 10
            for index in 0..<81 where board[index] == 0 {
                let mask = all & ~(rows[index / 9] | columns[index % 9] | boxes[index / 27 * 3 + index % 9 / 3])
                let possibleCount = mask.nonzeroBitCount
                if possibleCount == 0 { return }
                if possibleCount < count {
                    best = index
                    bestMask = mask; count = possibleCount
                    if count == 1 { break }
                }
            }
            if best == -1 { found.append(board); return }
            let options = randomized ? digits(bestMask).shuffled() : digits(bestMask)
            let row = best / 9, column = best % 9, box = best / 27 * 3 + best % 9 / 3
            for digit in options {
                let bit = UInt16(1 << digit)
                board[best] = digit
                rows[row] |= bit; columns[column] |= bit; boxes[box] |= bit
                search()
                rows[row] &= ~bit; columns[column] &= ~bit; boxes[box] &= ~bit
                if found.count >= limit || exhausted || Task<Never, Never>.isCancelled { break }
            }
            board[best] = 0
        }
        search()
        // Never report uniqueness when search couldn't finish.
        return exhausted || Task<Never, Never>.isCancelled ? [] : found
    }

    public static func randomSolution() -> [Int]? {
        solve(Array(repeating: 0, count: 81), limit: 1, randomized: true).first
    }

    /// Highest technique required by this deliberately small logical grader.
    /// Easy: naked singles. Medium: hidden singles. Hard: locked candidates / pairs.
    /// Expert: requires deductions beyond these techniques (or search).
    public static func grade(_ input: [Int]) -> Difficulty {
        var board = input
        var masks = (0..<81).map { candidates(board, at: $0) }
        var level = 0
        func place(_ index: Int, _ digit: Int) {
            board[index] = digit
            masks[index] = 0
            for peer in peers[index] { masks[peer] &= ~(1 << digit) }
        }
        while board.contains(0) {
            if let index = (0..<81).first(where: { board[$0] == 0 && masks[$0].nonzeroBitCount == 1 }) {
                place(index, digits(masks[index])[0]); continue
            }
            var hidden: (Int, Int)?
            for unit in units {
                for digit in 1...9 {
                    let cells = unit.filter { masks[$0] & (1 << digit) != 0 }
                    if cells.count == 1 { hidden = (cells[0], digit); break }
                }
                if hidden != nil { break }
            }
            if let (index, digit) = hidden {
                level = max(level, 1); place(index, digit); continue
            }
            var changed = false
            // Locked candidates, including pointing and claiming.
            for a in units {
                for digit in 1...9 {
                    let cells = a.filter { masks[$0] & (1 << digit) != 0 }
                    guard cells.count >= 2 else { continue }
                    for b in units where a != b && cells.allSatisfy({ b.contains($0) }) {
                        for index in b where !a.contains(index) && masks[index] & (1 << digit) != 0 {
                            masks[index] &= ~(1 << digit); changed = true
                        }
                    }
                }
            }
            // Naked pairs.
            for unit in units {
                let pairs = unit.filter { masks[$0].nonzeroBitCount == 2 }
                for index in pairs {
                    let pair = masks[index]
                    let twins = pairs.filter { masks[$0] == pair }
                    guard twins.count == 2 else { continue }
                    for other in unit where !twins.contains(other) && masks[other] & pair != 0 {
                        masks[other] &= ~pair; changed = true
                    }
                }
            }
            if changed { level = 2 } else { return .expert }
        }
        return [.easy, .medium, .hard][level]
    }
}

public enum PuzzleError: Error, LocalizedError, Sendable {
    case unavailable, generationLimit
    public var errorDescription: String? {
        switch self {
        case .unavailable: "The puzzle collection could not be loaded."
        case .generationLimit: "Couldn't make a unique puzzle with those settings this time. Try again, choose fewer empty squares, or use the collection."
        }
    }
}

public enum PuzzleFactory {
    public static func collection(_ difficulty: Difficulty, excluding: Set<String> = []) throws -> Puzzle {
        guard let url = Bundle.module.url(forResource: "puzzles", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { throw PuzzleError.unavailable }
        let records = text.split(separator: "\n").compactMap { line -> Puzzle? in
            let fields = line.split(separator: " ")
            guard fields.count == 4, fields[0] == difficulty.rawValue else { return nil }
            let board = fields[2].compactMap { $0.wholeNumberValue }
            // Solve only the selected record below; the bundle is validated by the import tool.
            guard board.count == 81 else { return nil }
            return Puzzle(id: String(fields[1]), givens: board, solution: [], difficulty: difficulty,
                          source: .collection, rating: Double(fields[3]))
        }
        let unseen = records.filter { !excluding.contains($0.id) }
        guard let record = (unseen.isEmpty ? records : unseen).randomElement(),
              let solution = Sudoku.solutions(record.givens, limit: 1).first else { throw PuzzleError.unavailable }
        return Puzzle(id: record.id, givens: record.givens, solution: solution,
                      difficulty: difficulty, source: .collection, rating: record.rating)
    }

    public static func generate(_ difficulty: Difficulty, emptySquares: Int = 45) throws -> Puzzle {
        let deadline = Date().addingTimeInterval(15)
        for _ in 0..<100 {
            try Task.checkCancellation()
            guard Date() < deadline, let solution = Sudoku.randomSolution() else { break }
            var board = solution
            let target = difficulty == .custom ? min(60, max(20, emptySquares)) :
                [.easy: 42, .medium: 49, .hard: 54, .expert: 57][difficulty, default: 45]
            var removed = 0
            for index in (0..<81).shuffled() {
                try Task.checkCancellation()
                guard Date() < deadline else { throw PuzzleError.generationLimit }
                let previous = board[index]
                board[index] = 0
                if Sudoku.solutions(board).count == 1 { removed += 1 } else { board[index] = previous }
                if removed == target { break }
            }
            guard removed == target else { continue }
            if difficulty != .custom && Sudoku.grade(board) != difficulty { continue }
            return Puzzle(id: UUID().uuidString, givens: board, solution: solution,
                          difficulty: difficulty, source: .generated)
        }
        throw PuzzleError.generationLimit
    }
}
