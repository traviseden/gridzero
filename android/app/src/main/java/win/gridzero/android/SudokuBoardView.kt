package win.gridzero.android

import android.graphics.*
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityNodeProvider
import win.gridzero.android.core.Sudoku
import kotlin.math.*

class SudokuBoardView(private val owner: MainActivity) : View(owner) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val medium = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    private val regular = Typeface.create("sans-serif", Typeface.NORMAL)
    private var down = -1
    private var downX = 0f; private var downY = 0f
    private var accessibilityFocus = -1
    private var hover = -1
    var hiddenIndex = -1
    var shake = 0f
    init {
        id = R.id.sudoku_board
        contentDescription = "Sudoku board"
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        isFocusable = true
    }
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val game = owner.game ?: return
        val p = owner.palette
        val side = width / 9f
        val selected = owner.selected
        paint.style = Paint.Style.FILL
        paint.color = p.paper
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        for (i in 0..80) {
            val x = i % 9 * side; val y = i / 9 * side
            paint.color = when {
                owner.errorCell == i || i in owner.checkedCells -> p.tint(p.error, .14f)
                selected == i -> p.tint(p.accent, .17f)
                selected in 0..80 && owner.settings.highlightMatching && game.board.values[selected] != 0 &&
                    game.board.values[i] == game.board.values[selected] -> p.tint(p.accent, .13f)
                selected in 0..80 && owner.settings.highlightPeers && i in Sudoku.peers[selected] -> p.tint(p.accent, .045f)
                else -> Color.TRANSPARENT
            }
            canvas.drawRect(x, y, x + side, y + side, paint)
            canvas.save()
            if (owner.errorCell == i) canvas.translate(sin(shake * PI * 6).toFloat() * owner.dp(4f), 0f)
            val value = game.board.values[i]
            if (value != 0 && hiddenIndex != i) {
                paint.color = if (i in owner.checkedCells) p.error else if (game.puzzle.givens[i] != 0) p.ink else p.accent
                paint.typeface = if (game.puzzle.givens[i] != 0) medium else regular
                paint.textAlign = Paint.Align.CENTER; paint.textSize = side * .57f
                canvas.drawText(value.toString(), x + side / 2, baseline(y + side / 2), paint)
            } else if (value == 0) {
                paint.color = p.secondary; paint.typeface = regular; paint.textAlign = Paint.Align.CENTER
                paint.textSize = side * .22f
                for (digit in 1..9) if (game.board.notes[i] and (1 shl digit) != 0) {
                    val n = digit - 1
                    val cx = x + side * .08f + (n % 3 + .5f) * side * .84f / 3
                    val cy = y + side * .08f + (n / 3 + .5f) * side * .84f / 3
                    canvas.drawText(digit.toString(), cx, baseline(cy), paint)
                }
            }
            canvas.restore()
        }
        for (line in 0..9) {
            val heavy = line % 3 == 0
            paint.color = if (heavy) p.strongLine else p.line
            paint.strokeWidth = owner.dp(if (heavy) 1.5f else .5f)
            val position = (line * side).coerceIn(paint.strokeWidth / 2, width - paint.strokeWidth / 2)
            canvas.drawLine(position, 0f, position, height.toFloat(), paint)
            canvas.drawLine(0f, position, width.toFloat(), position, paint)
        }
        if (selected in 0..80) {
            canvas.save()
            if (owner.errorCell == selected) canvas.translate(sin(shake * PI * 6).toFloat() * owner.dp(4f), 0f)
            paint.style = Paint.Style.STROKE; paint.strokeWidth = owner.dp(2f)
            paint.color = if (owner.errorCell == selected) p.error else p.accent
            val x = selected % 9 * side; val y = selected / 9 * side
            canvas.drawRect(x + paint.strokeWidth / 2, y + paint.strokeWidth / 2,
                x + side - paint.strokeWidth / 2, y + side - paint.strokeWidth / 2, paint)
            canvas.restore()
        }
    }
    private fun baseline(center: Float) = center - (paint.fontMetrics.ascent + paint.fontMetrics.descent) / 2
    private fun cell(x: Float, y: Float): Int = if (x < 0 || y < 0 || x >= width || y >= height) -1 else
        ((y / (height / 9f)).toInt() * 9 + (x / (width / 9f)).toInt()).coerceIn(0, 80)
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> { down = cell(event.x, event.y); downX = event.x; downY = event.y; return down >= 0 }
            MotionEvent.ACTION_MOVE -> if (hypot(event.x - downX, event.y - downY) > ViewConfiguration.get(context).scaledTouchSlop) down = -1
            MotionEvent.ACTION_UP -> {
                if (down >= 0 && down == cell(event.x, event.y)) { select(down); performClick() }
                down = -1; return true
            }
            MotionEvent.ACTION_CANCEL -> { down = -1; return true }
        }
        return true
    }
    override fun performClick(): Boolean { super.performClick(); return true }
    private fun select(index: Int) { owner.selected = index; owner.haptic(false); owner.refresh() }
    fun cellLabel(index: Int): String {
        val game = owner.game ?: return "Empty board"
        val place = "Row ${index / 9 + 1}, column ${index % 9 + 1}"
        val value = game.board.values[index]
        return if (value != 0) "$place, $value${if (game.puzzle.givens[index] != 0) ", starting clue" else ""}${if (index in owner.checkedCells) ", incorrect" else ""}"
        else "$place, empty${Sudoku.digits(game.board.notes[index]).takeIf { it.isNotEmpty() }?.joinToString(prefix = ", notes: ") ?: ""}"
    }
    private fun sendVirtualEvent(index: Int, type: Int) {
        val event = AccessibilityEvent.obtain(type)
        event.packageName = context.packageName; event.className = "android.widget.Button"
        event.setSource(this, index); event.contentDescription = cellLabel(index)
        parent?.requestSendAccessibilityEvent(this, event)
    }
    private val provider = object : AccessibilityNodeProvider() {
        override fun createAccessibilityNodeInfo(virtualViewId: Int): AccessibilityNodeInfo? {
            if (virtualViewId == View.NO_ID) {
                val info = AccessibilityNodeInfo.obtain(this@SudokuBoardView)
                onInitializeAccessibilityNodeInfo(info)
                for (i in 0..80) info.addChild(this@SudokuBoardView, i)
                return info
            }
            if (virtualViewId !in 0..80) return null
            val info = AccessibilityNodeInfo.obtain()
            info.setSource(this@SudokuBoardView, virtualViewId); info.setParent(this@SudokuBoardView)
            info.packageName = context.packageName; info.className = "android.widget.Button"
            info.contentDescription = cellLabel(virtualViewId)
            info.isClickable = true; info.isFocusable = true; info.isEnabled = true
            info.isVisibleToUser = isShown; info.isSelected = owner.selected == virtualViewId
            info.isAccessibilityFocused = accessibilityFocus == virtualViewId
            val side = width / 9f
            val bounds = Rect((virtualViewId % 9 * side).roundToInt(), (virtualViewId / 9 * side).roundToInt(),
                ((virtualViewId % 9 + 1) * side).roundToInt(), ((virtualViewId / 9 + 1) * side).roundToInt())
            info.setBoundsInParent(bounds)
            val location = IntArray(2); getLocationOnScreen(location); bounds.offset(location[0], location[1]); info.setBoundsInScreen(bounds)
            info.addAction(AccessibilityNodeInfo.ACTION_CLICK)
            info.addAction(if (info.isAccessibilityFocused) AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS else AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS)
            return info
        }
        override fun performAction(virtualViewId: Int, action: Int, arguments: Bundle?): Boolean {
            if (virtualViewId !in 0..80) return false
            when (action) {
                AccessibilityNodeInfo.ACTION_CLICK -> { select(virtualViewId); sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_CLICKED) }
                AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS -> { accessibilityFocus = virtualViewId; sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED); invalidate() }
                AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS -> { accessibilityFocus = -1; sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED); invalidate() }
                else -> return false
            }
            return true
        }
        override fun findFocus(focus: Int): AccessibilityNodeInfo? = if (accessibilityFocus >= 0) createAccessibilityNodeInfo(accessibilityFocus) else null
    }
    override fun getAccessibilityNodeProvider() = provider
    override fun onHoverEvent(event: MotionEvent): Boolean {
        val manager = context.getSystemService(AccessibilityManager::class.java)
        if (!manager.isTouchExplorationEnabled) return super.onHoverEvent(event)
        val index = if (event.actionMasked == MotionEvent.ACTION_HOVER_EXIT) -1 else cell(event.x, event.y)
        if (index != hover) {
            if (hover >= 0) sendVirtualEvent(hover, AccessibilityEvent.TYPE_VIEW_HOVER_EXIT)
            if (index >= 0) sendVirtualEvent(index, AccessibilityEvent.TYPE_VIEW_HOVER_ENTER)
            hover = index
        }
        return true
    }
}
