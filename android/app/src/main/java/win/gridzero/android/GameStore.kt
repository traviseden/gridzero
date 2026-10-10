package win.gridzero.android

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import win.gridzero.android.core.*
import java.io.File
import java.util.concurrent.Executors

/** Ordered background writes, atomic replacement, explicit versioned JSON (no reflection). */
class GameStore(context: Context, private val onError: (String) -> Unit) {
    private val file = AtomicFile(File(context.filesDir, "game-v1.json"))
    private val writer = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    data class Restored(val game: Game, val played: List<String>)
    fun load(): Restored? {
        if (!file.baseFile.exists()) return null
        return try {
            val j = JSONObject(file.openRead().use { it.readBytes().toString(Charsets.UTF_8) })
            require(j.getInt("version") == 1)
            val p = j.getJSONObject("puzzle")
            val puzzle = Puzzle(p.getString("id"), ints(p.getJSONArray("givens")), ints(p.getJSONArray("solution")),
                Difficulty.valueOf(p.getString("difficulty")), PuzzleSource.valueOf(p.getString("source")),
                if (p.isNull("rating")) null else p.getDouble("rating"))
            fun states(name: String) = j.getJSONArray(name).let { a ->
                require(a.length() <= 300)
                (0 until a.length()).map { state(a.getJSONObject(it)) }.toMutableList()
            }
            val game = Game(puzzle, PlayMode.valueOf(j.getString("mode")), j.getInt("limit"), j.getInt("strikes"),
                state(j.getJSONObject("board")), states("undo"), states("redo"), j.getLong("elapsed"), j.getBoolean("finished"))
            require(game.validSave())
            val played = j.getJSONArray("played").let { a -> (0 until a.length()).map { a.getString(it) }.takeLast(500) }
            Restored(game, played)
        } catch (_: Exception) { onError("Your previous save couldn't be restored. Start a new puzzle."); null }
    }
    fun save(game: Game, played: List<String>) {
        val puzzle = game.puzzle
        val board = game.board.snapshot(); val undo = game.undoStack.map { it.snapshot() }; val redo = game.redoStack.map { it.snapshot() }
        val mode = game.mode; val limit = game.strikeLimit; val strikes = game.strikes
        val elapsed = game.elapsedMillis; val finished = game.finished; val seen = played.toList()
        writer.execute {
            var stream: java.io.FileOutputStream? = null
            try {
                val p = JSONObject().put("id", puzzle.id).put("givens", array(puzzle.givens)).put("solution", array(puzzle.solution))
                    .put("difficulty", puzzle.difficulty.name).put("source", puzzle.source.name).put("rating", puzzle.rating ?: JSONObject.NULL)
                val j = JSONObject().put("version", 1).put("puzzle", p).put("mode", mode.name).put("limit", limit)
                    .put("strikes", strikes).put("board", json(board)).put("undo", JSONArray(undo.map(::json)))
                    .put("redo", JSONArray(redo.map(::json))).put("elapsed", elapsed).put("finished", finished).put("played", JSONArray(seen))
                stream = file.startWrite(); stream.write(j.toString().toByteArray(Charsets.UTF_8)); file.finishWrite(stream)
            } catch (e: Exception) {
                file.failWrite(stream)
                main.post { onError("Couldn't save your progress: ${e.message}") }
            }
        }
    }
    fun close() { writer.shutdown() }
    private fun ints(a: JSONArray): IntArray { require(a.length() == 81); return IntArray(81) { a.getInt(it) } }
    private fun array(a: IntArray) = JSONArray(a.toList())
    private fun state(j: JSONObject) = BoardState(ints(j.getJSONArray("values")), ints(j.getJSONArray("notes")))
    private fun json(s: BoardState) = JSONObject().put("values", array(s.values)).put("notes", array(s.notes))
}
