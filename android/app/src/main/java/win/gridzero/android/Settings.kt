package win.gridzero.android

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import org.json.JSONObject
import win.gridzero.android.core.*
import java.util.Calendar

enum class Theme { INK, MOSS, CLAY }
enum class Appearance { SYSTEM, LIGHT, DARK, SCHEDULED }

data class Settings(
    var theme: Theme = Theme.INK, var appearance: Appearance = Appearance.SYSTEM,
    var lightAt: Int = 420, var darkAt: Int = 1140,
    var source: PuzzleSource = PuzzleSource.COLLECTION, var difficulty: Difficulty = Difficulty.EASY,
    var mode: PlayMode = PlayMode.CHALLENGE, var strikeLimit: Int = 3, var customEmpty: Int = 45,
    var allowAutofill: Boolean = false, var cleanupNotes: Boolean = false,
    var highlightPeers: Boolean = true, var highlightMatching: Boolean = true,
    var showTimer: Boolean = false, var haptics: Boolean = true
) {
    fun isDark(configuration: Configuration, minutes: Int = Calendar.getInstance().let { it.get(Calendar.HOUR_OF_DAY) * 60 + it.get(Calendar.MINUTE) }): Boolean = when (appearance) {
        Appearance.SYSTEM -> configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        Appearance.LIGHT -> false
        Appearance.DARK -> true
        Appearance.SCHEDULED -> !(if (lightAt < darkAt) minutes >= lightAt && minutes < darkAt else minutes >= lightAt || minutes < darkAt)
    }
    fun save(context: Context) {
        val json = JSONObject().put("theme", theme.name).put("appearance", appearance.name)
            .put("lightAt", lightAt).put("darkAt", darkAt).put("source", source.name)
            .put("difficulty", difficulty.name).put("mode", mode.name).put("strikeLimit", strikeLimit)
            .put("customEmpty", customEmpty).put("allowAutofill", allowAutofill).put("cleanupNotes", cleanupNotes)
            .put("highlightPeers", highlightPeers).put("highlightMatching", highlightMatching)
            .put("showTimer", showTimer).put("haptics", haptics)
        context.getSharedPreferences("settings", Context.MODE_PRIVATE).edit().putString("v1", json.toString()).apply()
    }
    companion object {
        fun load(context: Context): Settings {
            val text = context.getSharedPreferences("settings", Context.MODE_PRIVATE).getString("v1", null) ?: return Settings()
            return try {
                val j = JSONObject(text)
                Settings(Theme.valueOf(j.getString("theme")), Appearance.valueOf(j.getString("appearance")),
                    j.getInt("lightAt").coerceIn(0, 1439), j.getInt("darkAt").coerceIn(0, 1439),
                    PuzzleSource.valueOf(j.getString("source")), Difficulty.valueOf(j.getString("difficulty")),
                    PlayMode.valueOf(j.getString("mode")), j.getInt("strikeLimit").let { if (it in listOf(0, 3, 5, 10)) it else 3 },
                    j.getInt("customEmpty").coerceIn(20, 60), j.getBoolean("allowAutofill"), j.getBoolean("cleanupNotes"),
                    j.getBoolean("highlightPeers"), j.getBoolean("highlightMatching"), j.getBoolean("showTimer"), j.getBoolean("haptics"))
            } catch (_: Exception) { Settings() }
        }
    }
}

class Palette(theme: Theme, val dark: Boolean) {
    private fun color(hex: Int) = 0xff000000.toInt() or hex
    val paper = color(if (dark) 0x151A1B else 0xFAF9F5)
    val surface = color(if (dark) 0x21282A else 0xF0EFEA)
    val ink = color(if (dark) 0xF0F0E9 else 0x252C30)
    val secondary = color(if (dark) 0xA2ADB0 else 0x687476)
    val line = color(if (dark) 0x495456 else 0xBFC5C2)
    val strongLine = color(if (dark) 0x99A3A0 else 0x6E7C78)
    val error = color(if (dark) 0xFFB4AC else 0xB33735)
    val accent = color(when (theme) {
        Theme.INK -> if (dark) 0x91B7E8 else 0x315E91
        Theme.MOSS -> if (dark) 0xA8C6A7 else 0x416B50
        Theme.CLAY -> if (dark) 0xE8B39D else 0xA45C43
    })
    fun tint(value: Int, alpha: Float) = Color.argb((alpha * 255).toInt(), Color.red(value), Color.green(value), Color.blue(value))
}
