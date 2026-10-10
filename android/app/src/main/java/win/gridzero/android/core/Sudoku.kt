package win.gridzero.android.core

import java.util.UUID
import java.util.concurrent.CancellationException
import kotlin.random.Random

enum class Difficulty(val title: String) { EASY("Easy"), MEDIUM("Medium"), HARD("Hard"), EXPERT("Expert"), CUSTOM("Custom") }
enum class PlayMode(val title: String) { CHALLENGE("Challenge"), CLASSIC("Classic") }
enum class PuzzleSource(val title: String) { COLLECTION("Puzzle Collection"), GENERATED("Generated on Device") }

data class Puzzle(val id: String, val givens: IntArray, val solution: IntArray,
                  val difficulty: Difficulty, val source: PuzzleSource, val rating: Double? = null)

object Sudoku {
    const val ALL = 0b1111111110
    val units: List<List<Int>> = (0..8).map { r -> (0..8).map { r * 9 + it } } +
        (0..8).map { c -> (0..8).map { it * 9 + c } } +
        (0..8).map { b -> (0..8).map { (b / 3 * 3 + it / 3) * 9 + b % 3 * 3 + it % 3 } }
    val peers: Array<IntArray> = Array(81) { index ->
        units.filter { index in it }.flatten().toSet().minus(index).sorted().toIntArray()
    }
    fun digits(mask: Int) = (1..9).filter { mask and (1 shl it) != 0 }
    fun candidates(board: IntArray, index: Int): Int {
        if (board.size != 81 || index !in 0..80 || board[index] != 0) return 0
        var mask = ALL
        for (peer in peers[index]) if (board[peer] in 1..9) mask = mask and (1 shl board[peer]).inv()
        return mask
    }
    fun consistent(board: IntArray): Boolean = board.size == 81 && board.all { it in 0..9 } &&
        units.all { unit -> val values = unit.map { board[it] }.filter { it != 0 }; values.distinct().size == values.size }
    fun complete(board: IntArray) = consistent(board) && board.none { it == 0 }
    fun solutions(input: IntArray, limit: Int = 2, randomized: Boolean = false): List<IntArray> {
        if (limit <= 0 || !consistent(input)) return emptyList()
        val board = input.copyOf()
        val rows = IntArray(9); val columns = IntArray(9); val boxes = IntArray(9)
        for (i in 0..80) if (board[i] != 0) {
            val bit = 1 shl board[i]
            rows[i / 9] = rows[i / 9] or bit; columns[i % 9] = columns[i % 9] or bit
            val box = i / 27 * 3 + i % 9 / 3; boxes[box] = boxes[box] or bit
        }
        val found = mutableListOf<IntArray>()
        var nodes = 0; var exhausted = false
        fun search() {
            if (found.size >= limit || exhausted || Thread.currentThread().isInterrupted) return
            if (++nodes > 100_000) { exhausted = true; return }
            var best = -1; var bestMask = 0; var count = 10
            for (i in 0..80) if (board[i] == 0) {
                val mask = ALL and (rows[i / 9] or columns[i % 9] or boxes[i / 27 * 3 + i % 9 / 3]).inv()
                val possible = Integer.bitCount(mask)
                if (possible == 0) return
                if (possible < count) { best = i; bestMask = mask; count = possible; if (count == 1) break }
            }
            if (best == -1) { found.add(board.copyOf()); return }
            val options = digits(bestMask).let { if (randomized) it.shuffled() else it }
            val r = best / 9; val c = best % 9; val b = best / 27 * 3 + best % 9 / 3
            for (digit in options) {
                val bit = 1 shl digit; board[best] = digit
                rows[r] = rows[r] or bit; columns[c] = columns[c] or bit; boxes[b] = boxes[b] or bit
                search()
                rows[r] = rows[r] and bit.inv(); columns[c] = columns[c] and bit.inv(); boxes[b] = boxes[b] and bit.inv()
                if (found.size >= limit || exhausted || Thread.currentThread().isInterrupted) break
            }
            board[best] = 0
        }
        search()
        return if (exhausted || Thread.currentThread().isInterrupted) emptyList() else found
    }

    fun grade(input: IntArray): Difficulty {
        val board = input.copyOf()
        val masks = IntArray(81) { candidates(board, it) }
        var level = 0
        fun place(index: Int, digit: Int) {
            board[index] = digit; masks[index] = 0
            for (peer in peers[index]) masks[peer] = masks[peer] and (1 shl digit).inv()
        }
        while (board.any { it == 0 }) {
            val single = (0..80).firstOrNull { board[it] == 0 && Integer.bitCount(masks[it]) == 1 }
            if (single != null) { place(single, Integer.numberOfTrailingZeros(masks[single])); continue }
            var hidden: Pair<Int, Int>? = null
            outer@ for (unit in units) for (digit in 1..9) {
                val cells = unit.filter { masks[it] and (1 shl digit) != 0 }
                if (cells.size == 1) { hidden = cells[0] to digit; break@outer }
            }
            if (hidden != null) { level = maxOf(level, 1); place(hidden.first, hidden.second); continue }
            var changed = false
            for (a in units) for (digit in 1..9) {
                val cells = a.filter { masks[it] and (1 shl digit) != 0 }
                if (cells.size < 2) continue
                for (b in units) if (a != b && cells.all { it in b }) {
                    for (index in b) if (index !in a && masks[index] and (1 shl digit) != 0) {
                        masks[index] = masks[index] and (1 shl digit).inv(); changed = true
                    }
                }
            }
            for (unit in units) {
                val pairs = unit.filter { Integer.bitCount(masks[it]) == 2 }
                for (index in pairs) {
                    val pair = masks[index]; val twins = pairs.filter { masks[it] == pair }
                    if (twins.size != 2) continue
                    for (other in unit) if (other !in twins && masks[other] and pair != 0) {
                        masks[other] = masks[other] and pair.inv(); changed = true
                    }
                }
            }
            if (changed) level = 2 else return Difficulty.EXPERT
        }
        return listOf(Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD)[level]
    }
}

class PuzzleFactory(private val collectionText: String) {
    fun collection(difficulty: Difficulty, excluding: Set<String> = emptySet()): Puzzle {
        val records = collectionText.lineSequence().map { it.trim().split(' ') }
            .filter { it.size == 4 && it[0] == difficulty.name.lowercase() }.toList()
        val unseen = records.filter { it[1] !in excluding }
        val fields = (unseen.ifEmpty { records }).randomOrNull() ?: error("Couldn't load the puzzle collection.")
        val board = fields[2].map { it.digitToInt() }.toIntArray()
        val solution = Sudoku.solutions(board, 1).firstOrNull() ?: error("Invalid collection puzzle.")
        return Puzzle(fields[1], board, solution, difficulty, PuzzleSource.COLLECTION, fields[3].toDouble())
    }
    fun generate(difficulty: Difficulty, emptySquares: Int = 45): Puzzle {
        val deadline = System.nanoTime() + 15_000_000_000L
        fun check() {
            if (Thread.currentThread().isInterrupted) throw CancellationException()
            if (System.nanoTime() >= deadline) throw IllegalStateException(GENERATION_ERROR)
        }
        repeat(100) {
            check()
            val solution = Sudoku.solutions(IntArray(81), 1, randomized = true).firstOrNull() ?: return@repeat
            val board = solution.copyOf()
            val target = when (difficulty) {
                Difficulty.EASY -> 42; Difficulty.MEDIUM -> 49; Difficulty.HARD -> 54
                Difficulty.EXPERT -> 57; Difficulty.CUSTOM -> emptySquares.coerceIn(20, 60)
            }
            var removed = 0
            for (index in (0..80).shuffled()) {
                check(); val previous = board[index]; board[index] = 0
                if (Sudoku.solutions(board).size == 1) removed++ else board[index] = previous
                if (removed == target) break
            }
            if (removed == target && (difficulty == Difficulty.CUSTOM || Sudoku.grade(board) == difficulty)) {
                return Puzzle(UUID.randomUUID().toString(), board, solution, difficulty, PuzzleSource.GENERATED)
            }
        }
        error(GENERATION_ERROR)
    }
    companion object {
        const val GENERATION_ERROR = "Couldn't make a unique puzzle with those settings this time. Try again, choose fewer empty squares, or use the collection."
    }
}
