package win.gridzero.android

import android.app.*
import android.content.*
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.*
import android.view.*
import android.widget.*
import win.gridzero.android.core.*
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.CancellationException
import kotlin.math.roundToInt

class MainActivity : Activity() {
    lateinit var settings: Settings
        private set
    lateinit var palette: Palette
        private set
    lateinit var surface: GameSurface
        private set
    var game: Game? = null
        private set
    var selected = -1
    var pencil = false
    var errorCell: Int? = null
        private set
    val checkedCells = mutableSetOf<Int>()
    var saveError: String? = null
        private set
    private lateinit var store: GameStore
    private lateinit var factory: PuzzleFactory
    private val played = mutableListOf<String>()
    private val handler = Handler(Looper.getMainLooper())
    private val generator = Executors.newSingleThreadExecutor()
    private var pending: Future<*>? = null
    private var generationToken = 0
    private var errorToken = 0
    private var dialog: AlertDialog? = null
    private var menuOpen = false
    private var active = false
    private var lastTick: Long? = null
    private var appearanceKey = ""
    private var outcomeShown = false
    override fun onCreate(savedInstanceState: Bundle?) {
        settings = Settings.load(this)
        palette = Palette(settings.theme, settings.isDark(resources.configuration))
        setTheme(if (palette.dark) R.style.AppThemeDark else R.style.AppTheme)
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 30) window.setDecorFitsSystemWindows(false)
        else window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        if (Build.VERSION.SDK_INT >= 28) {
            val attributes = window.attributes
            attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = attributes
        }
        store = GameStore(this) { message -> saveError = message; if (::surface.isInitialized) refresh() }
        store.load()?.let { game = it.game; played.addAll(it.played); selected = it.game.board.values.indexOfFirst { value -> value == 0 } }
        factory = PuzzleFactory(assets.open("puzzles.txt").bufferedReader().use { it.readText() })
        surface = GameSurface(this)
        surface.setOnApplyWindowInsetsListener { view, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val safe = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                view.setPadding(safe.left, safe.top, safe.right, safe.bottom)
            } else {
                view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
        setContentView(surface)
        surface.requestApplyInsets()
        refresh()
        if (game == null) startPuzzle(settings.difficulty, settings.mode, settings.source, settings.customEmpty) { error ->
            if (error != null) showMessage("Couldn't start a puzzle", error)
        }
    }
    override fun onConfigurationChanged(newConfig: Configuration) { super.onConfigurationChanged(newConfig); refresh(); surface.requestLayout() }
    override fun onResume() {
        super.onResume(); active = true; lastTick = null
        handler.removeCallbacks(tick); handler.post(tick)
        handler.post { showOutcome() }
    }
    override fun onPause() {
        active = false; lastTick = null
        handler.removeCallbacks(tick)
        if (::surface.isInitialized) surface.cancelFlight()
        save(); super.onPause()
    }
    override fun onDestroy() {
        generationToken++; pending?.cancel(true); generator.shutdownNow()
        handler.removeCallbacksAndMessages(null)
        if (::store.isInitialized) store.close()
        super.onDestroy()
    }
    private val tick = object : Runnable {
        override fun run() {
            val now = SystemClock.elapsedRealtime()
            val current = game
            if (active && dialog == null && !menuOpen && current != null && !current.finished && !current.isOut) {
                lastTick?.let { current.elapsedMillis += (now - it).coerceIn(0, 5000) }
                lastTick = now
            } else lastTick = null
            refresh()
            handler.postDelayed(this, 1000)
        }
    }
    fun dp(value: Float) = value * resources.displayMetrics.density
    fun refresh() {
        val dark = settings.isDark(resources.configuration)
        val key = "${settings.theme}-$dark"
        if (appearanceKey != key) {
            appearanceKey = key; palette = Palette(settings.theme, dark)
            setTheme(if (dark) R.style.AppThemeDark else R.style.AppTheme)
            if (Build.VERSION.SDK_INT >= 30) {
                val light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                window.insetsController?.setSystemBarsAppearance(if (dark) 0 else light, light)
                window.isNavigationBarContrastEnforced = false
            } else {
                val flags = window.decorView.systemUiVisibility and (View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR).inv()
                window.decorView.systemUiVisibility = flags or if (dark) 0 else View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                window.navigationBarColor = palette.paper
            }
        }
        if (::surface.isInitialized) surface.refresh()
    }
    fun save() { game?.let { if (::store.isInitialized) store.save(it, played) } }
    fun changed() { checkedCells.clear(); save(); refresh() }
    fun motionEnabled() = android.animation.ValueAnimator.areAnimatorsEnabled()
    fun haptic(error: Boolean) {
        if (!settings.haptics || !::surface.isInitialized) return
        surface.performHapticFeedback(if (error && Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT else
            if (error) HapticFeedbackConstants.LONG_PRESS else HapticFeedbackConstants.CLOCK_TICK)
    }
    fun entryFeedback(result: MoveResult, index: Int) {
        when (result) {
            MoveResult.STRIKE -> {
                errorCell = index; val token = ++errorToken; haptic(true)
                val current = game
                surface.announceForAccessibility("Incorrect. Strike ${current?.strikes}${if (current?.strikeLimit == 0) "" else " of ${current?.strikeLimit}"}.")
                handler.postDelayed({ if (errorToken == token) { errorCell = null; refresh() } }, 1100)
            }
            MoveResult.CHANGED, MoveResult.COMPLETED -> haptic(false)
            else -> Unit
        }
        refresh()
    }
    fun showOutcome() {
        if (!active || isFinishing || dialog != null || outcomeShown) return
        val current = game ?: return
        if (current.isOut) {
            outcomeShown = true
            track(AlertDialog.Builder(dialogContext()).setTitle("Time for a fresh start.")
                .setMessage("You've reached this game's ${current.strikeLimit}-strike limit. Your board is saved.")
                .setPositiveButton("Retry This Puzzle") { _, _ -> retry() }
                .setNegativeButton("Continue in Classic") { _, _ -> continueClassic() }
                .setNeutralButton("New Puzzle") { _, _ -> showNewPuzzle() }.create())
        } else if (current.finished) showCompletion()
    }
    fun showCompletion() {
        val current = game ?: return
        outcomeShown = true
        track(AlertDialog.Builder(dialogContext()).setTitle("Beautifully solved.")
            .setMessage("${current.puzzle.difficulty.title} · ${current.mode.title}${if (settings.showTimer) " · ${GameSurface.formatTime(current.elapsedMillis)}" else ""}")
            .setPositiveButton("Another puzzle") { _, _ -> showNewPuzzle() }
            .setNegativeButton("Enjoy the moment", null).create())
    }
    fun continueClassic() { surface.cancelFlight(); game?.continueClassic(); outcomeShown = false; changed() }
    fun retry() {
        surface.cancelFlight()
        game?.let { game = Game(it.puzzle, it.mode, it.strikeLimit) }
        selected = game?.board?.values?.indexOfFirst { it == 0 } ?: -1
        pencil = false; errorCell = null; errorToken++; checkedCells.clear(); outcomeShown = false; lastTick = null
        save(); refresh()
    }
    fun startPuzzle(difficulty: Difficulty, mode: PlayMode, source: PuzzleSource, empty: Int, callback: (String?) -> Unit) {
        val token = ++generationToken
        pending?.cancel(true)
        val excluded = played.toSet()
        pending = generator.submit {
            try {
                val puzzle = if (source == PuzzleSource.COLLECTION && difficulty != Difficulty.CUSTOM) factory.collection(difficulty, excluded)
                    else factory.generate(difficulty, empty)
                handler.post {
                    if (generationToken == token && !isDestroyed) {
                        surface.cancelFlight()
                        game = Game(puzzle, mode, settings.strikeLimit); selected = puzzle.givens.indexOfFirst { it == 0 }
                        pencil = false; errorCell = null; errorToken++; checkedCells.clear(); outcomeShown = false; lastTick = null
                        played.add(puzzle.id); while (played.size > 500) played.removeAt(0)
                        settings.difficulty = difficulty; settings.mode = mode; settings.source = if (difficulty == Difficulty.CUSTOM) PuzzleSource.GENERATED else source; settings.customEmpty = empty
                        settings.save(this); save(); refresh(); callback(null)
                    }
                }
            } catch (_: CancellationException) { } catch (error: Exception) {
                handler.post { if (generationToken == token && !isDestroyed) callback(error.message ?: "Couldn't prepare this puzzle.") }
            }
        }
    }
    private fun dialogContext() = ContextThemeWrapper(this, if (palette.dark) R.style.AppThemeDark else R.style.AppTheme)
    private fun track(next: AlertDialog) {
        dialog?.takeIf { it !== next && it.isShowing }?.dismiss()
        dialog = next; lastTick = null
        next.setOnDismissListener { if (dialog === next) { dialog = null; lastTick = null } }
        next.show()
        next.window?.setBackgroundDrawable(GradientDrawable().apply { setColor(palette.paper); cornerRadius = dp(22f) })
    }
    fun showMessage(title: String, message: String) { track(AlertDialog.Builder(dialogContext()).setTitle(title).setMessage(message).setPositiveButton("OK", null).create()) }
    fun showMenu(anchor: View) {
        surface.cancelFlight(); menuOpen = true; lastTick = null
        val popup = PopupMenu(dialogContext(), anchor)
        val actions = mutableMapOf<Int, () -> Unit>()
        fun add(label: String, enabled: Boolean = true, action: () -> Unit) {
            val id = actions.size + 1; actions[id] = action; popup.menu.add(0, id, id, label).isEnabled = enabled
        }
        add("New Puzzle") { showNewPuzzle() }
        add("Settings") { showSettings() }
        if (game?.mode == PlayMode.CLASSIC) add("Check Board") { checkBoard() }
        if (settings.allowAutofill) add("Fill Notes", game?.let { !it.finished && !it.isOut } == true) { game?.fillNotes(); changed() }
        add("Redo", game?.canRedo == true) { game?.redo(); changed() }
        add("Restart Puzzle", game != null) {
            track(AlertDialog.Builder(dialogContext()).setTitle("Restart this puzzle?")
                .setMessage("Your entries, notes, strikes, and time will be reset.")
                .setPositiveButton("Restart") { _, _ -> retry() }.setNegativeButton("Cancel", null).create())
        }
        popup.setOnMenuItemClickListener { actions[it.itemId]?.invoke(); true }
        popup.setOnDismissListener { menuOpen = false; lastTick = null }
        popup.show()
    }
    private fun checkBoard() {
        val current = game ?: return
        checkedCells.clear()
        checkedCells.addAll((0..80).filter { current.board.values[it] != 0 && current.board.values[it] != current.puzzle.solution[it] })
        refresh()
        showMessage(if (checkedCells.isEmpty()) "Looking good" else "A second look", if (checkedCells.isEmpty())
            "All your entered numbers are correct so far." else "${checkedCells.size} ${if (checkedCells.size == 1) "cell needs" else "cells need"} another look. They're marked on the board.")
    }
    private fun form(): LinearLayout = LinearLayout(dialogContext()).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(22f).toInt(), dp(8f).toInt(), dp(22f).toInt(), dp(12f).toInt()) }
    private fun label(parent: LinearLayout, text: String, small: Boolean = false): TextView = TextView(parent.context).apply {
        this.text = text; textSize = if (small) 13f else 16f; setTextColor(if (small) palette.secondary else palette.ink)
        setPadding(0, dp(12f).toInt(), 0, dp(6f).toInt()); parent.addView(this)
    }
    private fun picker(parent: LinearLayout, title: String, options: List<String>, selected: Int, change: (Int) -> Unit): Spinner {
        label(parent, title)
        return Spinner(parent.context).apply {
            adapter = ArrayAdapter(parent.context, android.R.layout.simple_spinner_dropdown_item, options)
            setSelection(selected)
            parent.addView(this, LinearLayout.LayoutParams(-1, dp(48f).toInt()))
            onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p: AdapterView<*>?, view: View?, position: Int, id: Long) { change(position) }
                override fun onNothingSelected(p: AdapterView<*>?) {}
            }
        }
    }
    fun showNewPuzzle() {
        val content = form()
        var level = settings.difficulty; var mode = settings.mode; var source = settings.source; var empty = settings.customEmpty
        val custom = LinearLayout(content.context).apply { orientation = LinearLayout.VERTICAL }
        val customLabel = label(custom, "$empty empty squares · ${81 - empty} starting clues")
        val slider = SeekBar(content.context).apply {
            max = 40; progress = empty - 20; contentDescription = "Empty squares"
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, value: Int, fromUser: Boolean) {
                    empty = value + 20; customLabel.text = "$empty empty squares · ${81 - empty} starting clues"
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }
        custom.addView(slider)
        picker(content, "Difficulty", Difficulty.entries.map { it.title }, level.ordinal) {
            level = Difficulty.entries[it]; custom.visibility = if (level == Difficulty.CUSTOM) View.VISIBLE else View.GONE
        }
        content.addView(custom); custom.visibility = if (level == Difficulty.CUSTOM) View.VISIBLE else View.GONE
        label(content, "Custom controls empty squares, not logical difficulty. Every puzzle has one unique solution.", true)
        val explanation = TextView(content.context).apply { textSize = 13f; setTextColor(palette.secondary) }
        picker(content, "Mode", PlayMode.entries.map { it.title }, mode.ordinal) {
            mode = PlayMode.entries[it]
            explanation.text = if (mode == PlayMode.CHALLENGE) "Immediate feedback. Wrong entries are rejected and add a strike. Notes are never checked."
                else "Solve freely. Use Check Board when you want feedback. No strikes."
        }
        content.addView(explanation)
        picker(content, "Puzzle source", PuzzleSource.entries.map { it.title }, source.ordinal) { source = PuzzleSource.entries[it] }
        label(content, "Collection: 8,000 rated puzzles. Generation is completely offline. Custom always uses generation.", true)
        val errorLabel = label(content, "", true).apply { setTextColor(palette.error) }
        val scroll = ScrollView(content.context).apply { addView(content) }
        val next = AlertDialog.Builder(content.context).setTitle("New puzzle").setView(scroll)
            .setPositiveButton("Start Puzzle", null).setNegativeButton("Cancel") { _, _ -> generationToken++; pending?.cancel(true) }.create()
        track(next)
        next.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
            val button = next.getButton(AlertDialog.BUTTON_POSITIVE)
            button.isEnabled = false; button.text = "Preparing…"; errorLabel.text = ""
            startPuzzle(level, mode, if (level == Difficulty.CUSTOM) PuzzleSource.GENERATED else source, empty) { error ->
                if (error == null) next.dismiss() else { errorLabel.text = error; button.text = "Start Puzzle"; button.isEnabled = true }
            }
        }
        next.setOnCancelListener { generationToken++; pending?.cancel(true) }
    }
    private fun toggle(parent: LinearLayout, title: String, value: Boolean, change: (Boolean) -> Unit) {
        val box = CheckBox(parent.context).apply {
            text = title; isChecked = value; setTextColor(palette.ink)
            buttonTintList = android.content.res.ColorStateList.valueOf(palette.accent)
            setPadding(0, dp(4f).toInt(), 0, dp(4f).toInt())
            setOnCheckedChangeListener { _, checked -> change(checked); settings.save(this@MainActivity); refresh() }
        }
        parent.addView(box, LinearLayout.LayoutParams(-1, -2))
    }
    fun showSettings() {
        val content = form()
        fun persist() { settings.save(this); refresh() }
        fun rebuild() {
            val previous = dialog
            handler.post { if (previous != null && dialog === previous && previous.isShowing) { previous.dismiss(); showSettings() } }
        }
        picker(content, "Theme", Theme.entries.map { it.name.lowercase().replaceFirstChar(Char::uppercase) }, settings.theme.ordinal) {
            val changed = settings.theme != Theme.entries[it]
            settings.theme = Theme.entries[it]; persist(); if (changed) rebuild()
        }
        val schedule = form()
        picker(content, "Appearance", Appearance.entries.map { it.name.lowercase().replaceFirstChar(Char::uppercase) }, settings.appearance.ordinal) {
            val changed = settings.appearance != Appearance.entries[it]
            settings.appearance = Appearance.entries[it]; schedule.visibility = if (settings.appearance == Appearance.SCHEDULED) View.VISIBLE else View.GONE; persist()
            if (changed) rebuild()
        }
        for (light in listOf(true, false)) {
            val button = Button(content.context)
            fun update() { val minutes = if (light) settings.lightAt else settings.darkAt; button.text = "${if (light) "Light" else "Dark"} at %02d:%02d".format(minutes / 60, minutes % 60) }
            update()
            button.setOnClickListener {
                val minutes = if (light) settings.lightAt else settings.darkAt
                TimePickerDialog(dialogContext(), { _, hour, minute ->
                    if (light) settings.lightAt = hour * 60 + minute else settings.darkAt = hour * 60 + minute
                    update(); persist()
                }, minutes / 60, minutes % 60, android.text.format.DateFormat.is24HourFormat(this)).show()
            }
            schedule.addView(button)
        }
        content.addView(schedule); schedule.visibility = if (settings.appearance == Appearance.SCHEDULED) View.VISIBLE else View.GONE
        label(content, "Scheduled uses your local clock. No location access needed.", true)
        picker(content, "Default puzzle source", PuzzleSource.entries.map { it.title }, settings.source.ordinal) { settings.source = PuzzleSource.entries[it]; persist() }
        val limits = listOf(3, 5, 10, 0)
        picker(content, "Challenge strike limit", listOf("3 strikes", "5 strikes", "10 strikes", "Unlimited"), limits.indexOf(settings.strikeLimit)) { settings.strikeLimit = limits[it]; persist() }
        label(content, "Strike limits apply to new games.", true)
        toggle(content, "Enable Fill Notes", settings.allowAutofill) { settings.allowAutofill = it }
        toggle(content, "Automatically clean up notes", settings.cleanupNotes) { settings.cleanupNotes = it }
        label(content, "Notes are manual by default. Autofill and cleanup use only your current board, never the hidden answer.", true)
        toggle(content, "Highlight related cells", settings.highlightPeers) { settings.highlightPeers = it }
        toggle(content, "Highlight matching numbers", settings.highlightMatching) { settings.highlightMatching = it }
        toggle(content, "Show timer", settings.showTimer) { settings.showTimer = it }
        toggle(content, "Gentle haptics", settings.haptics) { settings.haptics = it }
        label(content, "GridZero 1.0 · Free and open source. No ads. No tracking. No accounts.\n8,000 collection puzzles courtesy of Grant McLean / Sudoku Exchange. Generated with QQWing; rated with Sukaku Explainer. Public domain. Credits: https://gridzero.win/credits/", true)
        content.addView(Button(content.context).apply {
            text = "Open-source licenses"
            setOnClickListener {
                val notices = listOf("ThirdPartyNotices.txt", "License-MIT.txt", "Apache-2.0.txt", "Puzzle-LICENSE.txt")
                    .joinToString("\n\n") { name -> assets.open(name).bufferedReader().use { it.readText() } }
                showMessage("Open-source licenses", notices)
            }
        })
        track(AlertDialog.Builder(content.context).setTitle("Settings")
            .setView(ScrollView(content.context).apply { addView(content) }).setPositiveButton("Done", null).create())
    }
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (dialog != null) return super.onKeyDown(keyCode, event)
        if (keyCode in KeyEvent.KEYCODE_1..KeyEvent.KEYCODE_9) { surface.enter(keyCode - KeyEvent.KEYCODE_1 + 1); return true }
        if (event.isCtrlPressed && keyCode == KeyEvent.KEYCODE_Z) { surface.cancelFlight(); if (event.isShiftPressed) game?.redo() else game?.undo(); changed(); return true }
        if (keyCode == KeyEvent.KEYCODE_DEL) { surface.cancelFlight(); game?.erase(selected); changed(); return true }
        val delta = when (keyCode) { KeyEvent.KEYCODE_DPAD_LEFT -> -1; KeyEvent.KEYCODE_DPAD_RIGHT -> 1; KeyEvent.KEYCODE_DPAD_UP -> -9; KeyEvent.KEYCODE_DPAD_DOWN -> 9; else -> 0 }
        if (delta != 0) { selected = ((if (selected < 0) 0 else selected) + delta).coerceIn(0, 80); refresh(); return true }
        return super.onKeyDown(keyCode, event)
    }
}
