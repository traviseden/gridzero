package win.gridzero.android.core

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class GameTest {
    private val board = "530070000600195000098000060800060003400803001700020006060000280000419005000080079".map { it.digitToInt() }.toIntArray()
    private fun puzzle() = Puzzle("fixture", board.copyOf(), Sudoku.solutions(board, 1).first(), Difficulty.EASY, PuzzleSource.COLLECTION)
    @Test fun solverDistinguishesUniqueInvalidAndAmbiguous() {
        assertEquals(1, Sudoku.solutions(board).size)
        val invalid = board.copyOf(); invalid[2] = 5
        assertTrue(Sudoku.solutions(invalid).isEmpty())
        assertEquals(2, Sudoku.solutions(IntArray(81)).size)
    }
    @Test fun challengeRejectsErrorsAndUndoNeverRemovesStrikes() {
        val game = Game(puzzle()); val correct = game.puzzle.solution[2]; val wrong = correct % 9 + 1
        assertEquals(MoveResult.STRIKE, game.enter(wrong, 2, false))
        assertEquals(0, game.board.values[2]); assertEquals(1, game.strikes)
        game.enter(correct, 2, false); game.undo()
        assertEquals(0, game.board.values[2]); assertEquals(1, game.strikes)
        game.enter(wrong, 2, false); game.enter(wrong, 2, false)
        assertTrue(game.isOut); assertEquals(MoveResult.IGNORED, game.enter(correct, 2, false))
        game.continueClassic(); assertFalse(game.isOut)
    }
    @Test fun notesCleanupUndoRedoRestoreWholeMove() {
        val game = Game(puzzle()); val digit = game.puzzle.solution[2]
        game.enter(digit, 3, true); game.enter(digit, 2, false, true)
        assertEquals(0, game.board.notes[3])
        game.undo(); assertEquals(1 shl digit, game.board.notes[3]); assertEquals(0, game.board.values[2])
        game.redo(); assertEquals(0, game.board.notes[3]); assertEquals(digit, game.board.values[2])
    }
    @Test fun classicAllowsWrongValuesButOnlyValidBoardCompletes() {
        val game = Game(puzzle(), PlayMode.CLASSIC)
        assertEquals(MoveResult.CHANGED, game.enter(game.puzzle.solution[2] % 9 + 1, 2, false))
        for (i in 0..80) if (game.puzzle.givens[i] == 0 && i != 2) game.enter(game.puzzle.solution[i], i, false)
        assertFalse(game.finished); assertEquals(0, game.strikes)
        assertEquals(MoveResult.COMPLETED, game.enter(game.puzzle.solution[2], 2, false))
    }
    @Test fun autofillIsUndoableAndDoesNotUseSolution() {
        val game = Game(puzzle(), PlayMode.CLASSIC)
        game.fillNotes(); assertEquals(Sudoku.candidates(board, 2), game.board.notes[2])
        game.undo(); assertTrue(game.board.notes.all { it == 0 })
    }
    @Test fun validatesAllSharedCollectionPuzzles() {
        val text = File("../../Sources/GridZeroCore/Resources/puzzles.txt").readText()
        val records = text.lineSequence().filter { it.isNotBlank() }.toList()
        assertEquals(8000, records.size)
        for (level in listOf("easy", "medium", "hard", "expert")) {
            assertEquals(2000, records.count { it.startsWith("$level ") })
        }
        for (record in records) {
            val data = record.split(' ')[2].map { it.digitToInt() }.toIntArray()
            assertEquals(1, Sudoku.solutions(data).size)
        }
    }
    @Test fun generatedLevelsAndCustomCountsAreUnique() {
        val factory = PuzzleFactory("")
        val custom = factory.generate(Difficulty.CUSTOM, 45)
        assertEquals(45, custom.givens.count { it == 0 }); assertEquals(1, Sudoku.solutions(custom.givens).size)
        for (difficulty in listOf(Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD, Difficulty.EXPERT)) {
            val p = factory.generate(difficulty)
            assertEquals(difficulty, Sudoku.grade(p.givens)); assertEquals(1, Sudoku.solutions(p.givens).size)
        }
    }
    @Test fun validatesWindowGeometryAndAndroidTouchTargets() {
        for (width in 300..1400 step 37) for (height in 340..1400 step 31) {
            val layout = GameplayLayout(width.toFloat(), height.toFloat(), true)
            val regions = layout.regions
            for (region in regions) {
                assertTrue("$width x $height: $region", region.width > 0 && region.height > 0 && region.x >= 0 && region.y >= 0 && region.right <= width + .01f && region.bottom <= height + .01f)
            }
            for (a in regions.indices) for (b in a + 1 until regions.size) assertFalse(regions[a].intersects(regions[b]))
            for (digit in 1..9) {
                val key = layout.key(digit)
                assertTrue(key.width >= 48 && key.height >= 48)
                assertTrue(key.x >= 0 && key.y >= 0 && key.right <= width + .01f && key.bottom <= height + .01f)
            }
        }
        val onePlus = GameplayLayout(384f, 748f, false)
        assertEquals(384f, onePlus.board.width, .01f)
        for (digit in listOf(2, 4, 6, 8)) {
            assertTrue(onePlus.key(digit).centerX > onePlus.key(digit - 1).centerX)
            assertTrue(onePlus.key(digit).centerX < onePlus.key(digit + 1).centerX)
        }
    }
}
