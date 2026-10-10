package win.gridzero.android.core

data class BoardState(val values: IntArray, val notes: IntArray = IntArray(81)) {
    fun snapshot() = BoardState(values.copyOf(), notes.copyOf())
}
enum class MoveResult { IGNORED, CHANGED, STRIKE, COMPLETED }

class Game(val puzzle: Puzzle, var mode: PlayMode = PlayMode.CHALLENGE, val strikeLimit: Int = 3,
           var strikes: Int = 0, var board: BoardState = BoardState(puzzle.givens.copyOf()),
           val undoStack: MutableList<BoardState> = mutableListOf(),
           val redoStack: MutableList<BoardState> = mutableListOf(), var elapsedMillis: Long = 0,
           var finished: Boolean = false) {
    val isOut get() = mode == PlayMode.CHALLENGE && strikeLimit > 0 && strikes >= strikeLimit && !finished
    val canUndo get() = undoStack.isNotEmpty() && !finished && !isOut
    val canRedo get() = redoStack.isNotEmpty() && !finished && !isOut
    private fun remember() {
        undoStack.add(board.snapshot())
        if (undoStack.size > 300) undoStack.removeAt(0)
        redoStack.clear()
    }
    fun enter(digit: Int, index: Int, pencil: Boolean, cleanup: Boolean = false): MoveResult {
        if (index !in 0..80 || digit !in 1..9 || puzzle.givens[index] != 0 || finished || isOut) return MoveResult.IGNORED
        if (pencil) {
            if (board.values[index] != 0) return MoveResult.IGNORED
            remember(); board.notes[index] = board.notes[index] xor (1 shl digit)
            return MoveResult.CHANGED
        }
        if (board.values[index] == digit) return MoveResult.IGNORED
        if (mode == PlayMode.CHALLENGE && puzzle.solution[index] != digit) { strikes++; return MoveResult.STRIKE }
        remember(); board.values[index] = digit; board.notes[index] = 0
        if (cleanup) for (peer in Sudoku.peers[index]) board.notes[peer] = board.notes[peer] and (1 shl digit).inv()
        finished = Sudoku.complete(board.values)
        return if (finished) MoveResult.COMPLETED else MoveResult.CHANGED
    }
    fun erase(index: Int) {
        if (index !in 0..80 || puzzle.givens[index] != 0 || finished || isOut) return
        if (board.values[index] == 0 && board.notes[index] == 0) return
        remember(); board.values[index] = 0; board.notes[index] = 0
    }
    fun fillNotes() {
        if (finished || isOut) return
        val notes = IntArray(81) { Sudoku.candidates(board.values, it) }
        if (notes.contentEquals(board.notes)) return
        remember(); board = BoardState(board.values.copyOf(), notes)
    }
    fun undo() { if (canUndo) { redoStack.add(board.snapshot()); board = undoStack.removeAt(undoStack.lastIndex) } }
    fun redo() { if (canRedo) { undoStack.add(board.snapshot()); board = redoStack.removeAt(redoStack.lastIndex) } }
    fun continueClassic() { mode = PlayMode.CLASSIC }
    fun validSave(): Boolean {
        if (puzzle.givens.size != 81 || puzzle.solution.size != 81 || !Sudoku.complete(puzzle.solution) ||
            !Sudoku.consistent(puzzle.givens) || strikeLimit < 0 || strikes < 0 || elapsedMillis < 0 ||
            undoStack.size > 300 || redoStack.size > 300) return false
        if ((0..80).any { puzzle.givens[it] != 0 && puzzle.givens[it] != puzzle.solution[it] }) return false
        fun valid(state: BoardState) = state.values.size == 81 && state.notes.size == 81 &&
            state.values.all { it in 0..9 } && state.notes.all { it and Sudoku.ALL.inv() == 0 } &&
            (0..80).all { puzzle.givens[it] == 0 || state.values[it] == puzzle.givens[it] }
        return valid(board) && undoStack.all(::valid) && redoStack.all(::valid) && finished == Sudoku.complete(board.values)
    }
}
