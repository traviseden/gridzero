package win.gridzero.android.core

import kotlin.math.min

data class Box(val x: Float, val y: Float, val width: Float, val height: Float) {
    val right get() = x + width
    val bottom get() = y + height
    val centerX get() = x + width / 2
    val centerY get() = y + height / 2
    fun intersects(other: Box) = x < other.right && right > other.x && y < other.bottom && bottom > other.y
}

/** Density-independent safe-area geometry. Android controls retain 48dp touch targets. */
class GameplayLayout(val width: Float, val height: Float, tablet: Boolean) {
    val sideBySide = width >= 620 && width > height * 1.08f
    val header: Box
    val metadata: Box
    val board: Box
    val tools: Box
    val keypad: Box
    val status: Box
    val keyHeight: Float
    val keyGap: Float
    val keyFont: Float
    val toolWidth: Float get() = min(84f, (tools.width - toolGap * 2) / 3)
    val toolGap: Float get() = min(28f, ((tools.width - 216) / 2).coerceAtLeast(8f))
    val keyWidth: Float get() = min(86f, (keypad.width / 5 - 8).coerceAtLeast(48f))
    init {
        if (sideBySide) {
            val compact = height < 550
            val margin = if (compact) 12f else 24f
            val top = if (compact) 4f else 16f
            val headerHeight = 48f
            val gap = if (compact) 12f else 20f
            val panelWidth = min(if (tablet && !compact) 360f else 290f, (width * .34f).coerceAtLeast(280f))
            val columnGap = if (compact) 20f else 32f
            val rowTop = top + headerHeight + gap
            val side = minOf(720f, height - rowTop - margin, width - margin * 2 - columnGap - panelWidth)
            val groupWidth = side + columnGap + panelWidth
            val left = (width - groupWidth) / 2
            header = Box(left, top, groupWidth, headerHeight)
            board = Box(left, rowTop, side, side)
            keyHeight = if (compact) 48f else 66f
            keyGap = 8f; keyFont = if (compact) 27f else 32f
            val panelHeight = 34 + gap + 48 + gap + keyHeight * 2 + keyGap + gap + 18
            val panelTop = min(height - margin - panelHeight, (board.centerY - panelHeight / 2).coerceAtLeast(rowTop))
            val x = board.right + columnGap
            metadata = Box(x, panelTop, panelWidth, 34f)
            tools = Box(x, metadata.bottom + gap, panelWidth, 48f)
            keypad = Box(x, tools.bottom + gap, panelWidth, keyHeight * 2 + keyGap)
            status = Box(x, keypad.bottom + gap, panelWidth, 18f)
        } else {
            val spacious = tablet && width > 500
            val nominal = if (spacious) min(720f, width - 48) else width
            val remaining = height - nominal
            val compact = remaining < if (spacious) 420 else 360
            val tight = remaining < 310
            val top = if (tight) 0f else if (spacious) 16f else if (compact) 4f else 8f
            val bottom = if (spacious && !tight) 16f else if (compact) 4f else 8f
            val headerGap = if (tight) 4f else if (compact) 8f else 16f
            val metaHeight = if (tight) 28f else 34f
            val boardGap = if (tight) 4f else if (compact) 8f else 12f
            val toolsGap = if (tight) 8f else if (compact) 12f else 16f
            val inputGap = if (tight) 6f else if (compact) 8f else 12f
            val statusGap = if (compact) 6f else 8f
            val toolHeight = if (spacious && !compact) 52f else 48f
            keyHeight = if (tight) 48f else if (compact) 52f else if (spacious) 64f else 56f
            keyGap = 8f; keyFont = if (spacious) 32f else if (tight) 26f else 29f
            val chrome = top + 48 + headerGap + metaHeight + boardGap + toolsGap + toolHeight + inputGap + keyHeight * 2 + keyGap + statusGap + 18 + bottom
            val side = min(nominal, height - chrome)
            val extra = (height - side - chrome).coerceAtLeast(0f)
            val groupTop = if (spacious) extra / 2 else 0f
            val column = if (spacious) nominal else width
            val columnX = (width - column) / 2
            header = Box(columnX + 20, groupTop + top, column - 40, 48f)
            metadata = Box(columnX + 20, header.bottom + headerGap, column - 40, metaHeight)
            board = Box((width - side) / 2, metadata.bottom + boardGap, side, side)
            val inputWidth = min(480f, width - 24)
            val inputX = (width - inputWidth) / 2
            tools = Box(inputX, board.bottom + toolsGap + if (spacious) 0f else extra, inputWidth, toolHeight)
            keypad = Box(inputX, tools.bottom + inputGap, inputWidth, keyHeight * 2 + keyGap)
            status = Box(inputX, keypad.bottom + statusGap, inputWidth, 18f)
        }
    }
    fun key(digit: Int): Box {
        val even = digit % 2 == 0
        val center = keypad.x + (digit / 2 + if (even) 0f else .5f) * keypad.width / 5
        return Box(center - keyWidth / 2, keypad.y + if (even) keyHeight + keyGap else 0f, keyWidth, keyHeight)
    }
    val regions get() = listOf(header, metadata, board, tools, keypad, status)
}
