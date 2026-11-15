package win.gridzero.android

import android.animation.ValueAnimator
import android.content.res.ColorStateList
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.*
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import win.gridzero.android.core.*
import kotlin.math.*

class GameSurface(val owner: MainActivity) : ViewGroup(owner) {
    val board = SudokuBoardView(owner)
    val menu = text("•••", 20f).apply { id = R.id.game_menu; contentDescription = "Game menu"; isClickable = true; isFocusable = true; setOnClickListener { owner.showMenu(this) } }
    private val title = text("GridZero", 25f).apply { typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL); gravity = Gravity.CENTER_VERTICAL }
    private val metadata = text("", 14f).apply { gravity = Gravity.CENTER_VERTICAL; setLineSpacing(owner.dp(2f), 1f) }
    private val strikes = text("", 18f)
    private val timer = text("", 13f)
    private val status = text("", 12f)
    private val loading = text("Preparing your puzzle…", 16f)
    val numberButtons = (1..9).associateWith { digit ->
        text(digit.toString(), 29f).apply {
            id = NUMBER_IDS[digit - 1]; typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            isClickable = true; isFocusable = true
            setOnClickListener { enter(digit) }
        }
    }
    private val tools = listOf(
        ToolButton("Undo", "undo", R.id.undo) { cancelFlight(); owner.game?.undo(); owner.changed() },
        ToolButton("Erase", "erase", R.id.erase) { cancelFlight(); owner.game?.erase(owner.selected); owner.changed() },
        ToolButton("Notes", "notes", R.id.notes) { cancelFlight(); owner.pencil = !owner.pencil; owner.haptic(false); owner.refresh() }
    )
    var layoutSpec: GameplayLayout? = null
        private set
    private var paletteVersion = ""
    private var animator: ValueAnimator? = null
    private var flight: Flight? = null
    private val flightPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var lastWidth = 0; private var lastHeight = 0
    data class Flight(val digit: Int, val index: Int, val source: PointF, val target: PointF,
                      val result: MoveResult, val font: Float, var x: Float, var y: Float,
                      var size: Float, var alpha: Float = 1f, var rejected: Boolean = false)
    init {
        id = R.id.game_surface
        clipChildren = true
        addView(title); addView(menu); addView(metadata); addView(strikes); addView(timer)
        addView(board); tools.forEach(::addView); numberButtons.values.forEach(::addView)
        addView(status); addView(loading)
        layoutDirection = LAYOUT_DIRECTION_LTR
        setWillNotDraw(false)
    }
    private fun text(value: String, size: Float) = TextView(context).apply {
        text = value; setTextSize(TypedValue.COMPLEX_UNIT_DIP, size); gravity = Gravity.CENTER
        includeFontPadding = false; setPadding(0, 0, 0, 0)
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }
    private fun background(fill: Int, radius: Float, stroke: Int? = null) = RippleDrawable(
        ColorStateList.valueOf(owner.palette.tint(owner.palette.accent, .12f)),
        GradientDrawable().apply { setColor(fill); cornerRadius = owner.dp(radius); if (stroke != null) setStroke(owner.dp(1f).roundToInt(), stroke) }, null)
    fun refresh() {
        val p = owner.palette
        setBackgroundColor(p.paper)
        title.setTextColor(p.ink); menu.setTextColor(p.ink); metadata.setTextColor(p.ink); timer.setTextColor(p.secondary)
        menu.background = background(p.surface, 24f)
        loading.setTextColor(p.secondary)
        val game = owner.game
        loading.visibility = if (game == null) VISIBLE else GONE
        board.visibility = if (game != null) VISIBLE else GONE
        if (game != null) {
            val difficulty = if (game.puzzle.difficulty == Difficulty.CUSTOM) "Custom · ${game.puzzle.givens.count { it == 0 }} empty" else game.puzzle.difficulty.title
            metadata.text = "$difficulty\n${game.mode.title}"
            timer.text = if (owner.settings.showTimer) formatTime(game.elapsedMillis) else ""
            if (game.mode == PlayMode.CHALLENGE) {
                val label = if (game.strikeLimit in 1..5) List(game.strikeLimit) { "×" }.joinToString(" ")
                    else "× ${game.strikes}${if (game.strikeLimit == 0) "" else " / ${game.strikeLimit}"}"
                val colored = SpannableString(label)
                if (game.strikeLimit in 1..5) for (i in 0 until game.strikeLimit) {
                    colored.setSpan(ForegroundColorSpan(if (i < game.strikes) p.error else p.line), i * 2, i * 2 + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                } else colored.setSpan(ForegroundColorSpan(if (game.strikes > 0) p.error else p.secondary), 0, label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                strikes.text = colored
                strikes.contentDescription = if (game.strikeLimit == 0) "${game.strikes} strikes" else "${game.strikes} of ${game.strikeLimit} strikes"
            } else { strikes.text = ""; strikes.contentDescription = "Classic mode, no strikes" }
            for ((digit, view) in numberButtons) {
                view.setTextColor(p.accent)
                view.background = background(if (owner.pencil) p.tint(p.accent, .1f) else p.surface, 17f,
                    if (owner.pencil) p.tint(p.accent, .35f) else null)
                view.isEnabled = canEnter()
                view.alpha = if (!view.isEnabled) .35f else if (game.board.values.count { it == digit } >= 9) .45f else 1f
                view.contentDescription = if (owner.pencil) "Toggle note $digit" else "Enter $digit"
            }
            tools[0].update(game.canUndo, false)
            tools[1].update(canEnter(), false)
            tools[2].update(!game.finished && !game.isOut, owner.pencil)
            status.text = when {
                owner.saveError != null -> owner.saveError
                owner.errorCell != null -> "Incorrect number"
                game.finished -> "Puzzle complete"
                game.isOut -> "Continue in Classic"
                else -> ""
            }
            status.setTextColor(if (owner.errorCell != null || owner.saveError != null) p.error else p.accent)
            status.isClickable = game.finished || game.isOut
            status.setOnClickListener { if (game.finished) owner.showCompletion() else if (game.isOut) owner.continueClassic() }
        }
        board.invalidate()
        val version = "${p.dark}-${owner.settings.theme}"
        if (paletteVersion != version) { paletteVersion = version; invalidate() }
    }
    fun canEnter(): Boolean {
        val game = owner.game ?: return false
        return owner.selected in 0..80 && game.puzzle.givens[owner.selected] == 0 && !game.finished && !game.isOut
    }
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = MeasureSpec.getSize(widthMeasureSpec); val h = MeasureSpec.getSize(heightMeasureSpec)
        setMeasuredDimension(w, h)
        val density = resources.displayMetrics.density
        layoutSpec = GameplayLayout((w - paddingLeft - paddingRight) / density, (h - paddingTop - paddingBottom) / density,
            resources.configuration.smallestScreenWidthDp >= 600)
        for (i in 0 until childCount) getChildAt(i).measure(MeasureSpec.makeMeasureSpec(w, MeasureSpec.AT_MOST), MeasureSpec.makeMeasureSpec(h, MeasureSpec.AT_MOST))
    }
    private fun place(view: View, rect: Box) {
        val x = paddingLeft + owner.dp(rect.x).roundToInt(); val y = paddingTop + owner.dp(rect.y).roundToInt()
        val w = owner.dp(rect.width).roundToInt(); val h = owner.dp(rect.height).roundToInt()
        view.measure(MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY))
        view.layout(x, y, x + w, y + h)
    }
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        if (width != lastWidth || height != lastHeight) { cancelFlight(); lastWidth = width; lastHeight = height }
        val s = layoutSpec ?: return
        place(title, Box(s.header.x, s.header.y, s.header.width - 60, s.header.height))
        place(menu, Box(s.header.right - 48, s.header.y, 48f, 48f))
        place(metadata, Box(s.metadata.x, s.metadata.y, (s.metadata.width - 130).coerceAtLeast(80f), s.metadata.height))
        place(timer, Box(s.metadata.right - 130, s.metadata.y, 50f, s.metadata.height))
        place(strikes, Box(s.metadata.right - 76, s.metadata.y, 76f, s.metadata.height))
        place(board, s.board)
        val groupWidth = s.toolWidth * 3 + s.toolGap * 2
        val start = s.tools.x + (s.tools.width - groupWidth) / 2
        for (i in tools.indices) place(tools[i], Box(start + i * (s.toolWidth + s.toolGap), s.tools.y, s.toolWidth, s.tools.height))
        for ((digit, view) in numberButtons) {
            view.setTextSize(TypedValue.COMPLEX_UNIT_DIP, s.keyFont)
            place(view, s.key(digit))
        }
        place(status, s.status)
        place(loading, Box(20f, (height - paddingTop - paddingBottom) / resources.displayMetrics.density / 2 - 24,
            (width - paddingLeft - paddingRight) / resources.displayMetrics.density - 40, 48f))
    }
    fun enter(digit: Int) {
        if (!canEnter()) return
        cancelFlight()
        val game = owner.game ?: return
        val index = owner.selected
        owner.checkedCells.clear()
        val result = game.enter(digit, index, owner.pencil, owner.settings.cleanupNotes)
        if (result == MoveResult.IGNORED) return
        owner.save(); refresh()
        if (owner.pencil || !owner.motionEnabled()) { owner.entryFeedback(result, index); owner.showOutcome(); return }
        val key = numberButtons.getValue(digit)
        val source = PointF(key.x + key.width / 2, key.y + key.height / 2)
        val side = board.width / 9f
        val target = PointF(board.x + (index % 9 + .5f) * side, board.y + (index / 9 + .5f) * side)
        val f = Flight(digit, index, source, target, result, key.textSize, source.x, source.y, key.textSize)
        flight = f
        if (result != MoveResult.STRIKE) board.hiddenIndex = index
        animate(220, DecelerateInterpolator(), { t ->
            f.x = source.x + (target.x - source.x) * t
            val endY = target.y + if (result == MoveResult.STRIKE) side * .2f else 0f
            f.y = source.y + (endY - source.y) * t
            f.size = f.font + (side * .57f - f.font) * t
        }) {
            if (flight !== f) return@animate
            if (result == MoveResult.STRIKE) {
                f.rejected = true; owner.entryFeedback(result, index)
                val impactX = f.x; val impactY = f.y
                postDelayed({
                    if (flight === f) animate(240, AccelerateInterpolator(), { t ->
                        f.x = impactX + (source.x - impactX) * t; f.y = impactY + (source.y - impactY) * t
                        f.alpha = 1 - t; board.shake = t; board.invalidate()
                    }) { finishFlight(); owner.showOutcome() }
                }, 70)
            } else { finishFlight(); owner.entryFeedback(result, index); owner.showOutcome() }
        }
    }
    private fun animate(duration: Long, interpolator: android.animation.TimeInterpolator, update: (Float) -> Unit, end: () -> Unit) {
        val animation = ValueAnimator.ofFloat(0f, 1f)
        animator = animation; animation.duration = duration; animation.interpolator = interpolator
        animation.addUpdateListener { update(it.animatedValue as Float); invalidate() }
        animation.addListener(object : android.animation.AnimatorListenerAdapter() {
            var cancelled = false
            override fun onAnimationCancel(animation: android.animation.Animator) { cancelled = true }
            override fun onAnimationEnd(animation: android.animation.Animator) { if (!cancelled) end() }
        })
        animation.start()
    }
    private fun finishFlight() { flight = null; board.hiddenIndex = -1; board.shake = 0f; board.invalidate(); invalidate() }
    fun cancelFlight() {
        val pending = flight
        animator?.cancel(); animator = null; finishFlight()
        if (pending != null) owner.entryFeedback(pending.result, pending.index)
    }
    override fun dispatchDraw(canvas: Canvas) {
        super.dispatchDraw(canvas)
        flight?.let { f ->
            flightPaint.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            flightPaint.textSize = f.size; flightPaint.color = if (f.rejected) owner.palette.error else owner.palette.accent
            flightPaint.alpha = (f.alpha * 255).toInt(); flightPaint.textAlign = Paint.Align.CENTER
            canvas.drawText(f.digit.toString(), f.x, f.y - (flightPaint.fontMetrics.ascent + flightPaint.fontMetrics.descent) / 2, flightPaint)
        }
    }
    inner class ToolButton(label: String, private val symbol: String, identifier: Int, action: () -> Unit) : LinearLayout(context) {
        private val icon = IconView(symbol)
        private val caption = text(label, 12f)
        init {
            id = identifier; orientation = VERTICAL; gravity = Gravity.CENTER
            addView(icon, LayoutParams(owner.dp(22f).toInt(), owner.dp(22f).toInt()))
            addView(caption, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
            isClickable = true; isFocusable = true; contentDescription = label
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
            icon.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
            caption.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
            setOnClickListener { action() }
        }
        fun update(enabled: Boolean, active: Boolean) {
            isEnabled = enabled; alpha = if (enabled) 1f else .35f
            caption.setTextColor(if (active) owner.palette.accent else owner.palette.secondary)
            icon.color = if (active) owner.palette.accent else owner.palette.secondary; icon.invalidate()
            background = background(if (active) owner.palette.tint(owner.palette.accent, .1f) else Color.TRANSPARENT, 12f)
            if (symbol == "notes") contentDescription = "Notes, ${if (active) "on" else "off"}"
        }
    }
    inner class IconView(private val symbol: String) : View(context) {
        var color = owner.palette.secondary
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        override fun onDraw(canvas: Canvas) {
            paint.color = color; paint.style = Paint.Style.STROKE; paint.strokeWidth = 1.7f
            paint.strokeCap = Paint.Cap.ROUND; paint.strokeJoin = Paint.Join.ROUND
            val s = width / 24f; canvas.save(); canvas.scale(s, s)
            val path = Path()
            when (symbol) {
                "undo" -> { path.moveTo(8f, 5f); path.lineTo(3f, 10f); path.lineTo(8f, 15f); path.moveTo(3f, 10f); path.lineTo(15f, 10f); path.cubicTo(23f, 10f, 23f, 21f, 15f, 21f); path.lineTo(12f, 21f) }
                "erase" -> { path.moveTo(3f, 14f); path.lineTo(14f, 3f); path.lineTo(22f, 11f); path.lineTo(11f, 22f); path.lineTo(3f, 14f); path.moveTo(8f, 9f); path.lineTo(16f, 17f) }
                else -> { path.moveTo(4f, 20f); path.lineTo(7f, 13f); path.lineTo(18f, 2f); path.lineTo(22f, 6f); path.lineTo(11f, 17f); path.lineTo(4f, 20f); path.moveTo(16f, 4f); path.lineTo(20f, 8f) }
            }
            canvas.drawPath(path, paint); canvas.restore()
        }
    }
    companion object {
        val NUMBER_IDS = intArrayOf(R.id.number_1, R.id.number_2, R.id.number_3, R.id.number_4, R.id.number_5, R.id.number_6, R.id.number_7, R.id.number_8, R.id.number_9)
        fun formatTime(millis: Long): String { val seconds = millis / 1000; return "%d:%02d".format(seconds / 60, seconds % 60) }
    }
}
