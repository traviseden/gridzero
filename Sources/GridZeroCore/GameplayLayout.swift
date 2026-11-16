import Foundation
import CoreGraphics

/// Layout in the current window's safe-area coordinates, never device-model coordinates.
/// The geometry is shared with the app and checked independently of SwiftUI rendering.
public struct GameplayLayout: Sendable {
    public enum Arrangement: String, Sendable { case stacked, sideBySide }
    public let arrangement: Arrangement
    public let compact: Bool
    public let tight: Bool
    public let header: CGRect
    public let metadata: CGRect
    public let board: CGRect
    public let tools: CGRect
    public let keypad: CGRect
    public let status: CGRect
    public let keyHeight: CGFloat
    public let keyGap: CGFloat
    public let keyFontSize: CGFloat
    private let textScale: CGFloat

    public var toolHeight: CGFloat { tools.height }
    public var toolWidth: CGFloat { min(84 * textScale, (tools.width - toolSpacing * 2) / 3) }
    public var toolSpacing: CGFloat { textScale > 1 ? 8 : min(28, max(8, (tools.width - 204) / 2)) }
    public var keyWidth: CGFloat { min(86, max(44, keypad.width / 5 - 8)) }
    public var regions: [CGRect] { [header, metadata, board, tools, keypad, status] }

    public func keyFrame(for digit: Int) -> CGRect {
        guard (1...9).contains(digit) else { return .zero }
        let even = digit.isMultiple(of: 2)
        let pitch = keypad.width / 5
        let center = keypad.minX + (CGFloat(digit / 2) + (even ? 0 : 0.5)) * pitch
        return CGRect(x: center - keyWidth / 2, y: keypad.minY + (even ? keyHeight + keyGap : 0),
                      width: keyWidth, height: keyHeight)
    }

    public init(size: CGSize, isTablet: Bool, textScale: CGFloat = 1, expandedStatus: Bool = false) {
        self.textScale = textScale
        let width = max(1, size.width)
        let height = max(1, size.height)
        let landscape = width >= 600 && width > height * 1.08
        if landscape {
            arrangement = .sideBySide
            compact = height < 550
            tight = height < 420
            let margin: CGFloat = compact ? 12 : 24
            let top: CGFloat = compact ? 4 : 16
            let headerHeight: CGFloat = max(compact ? 44 : 48, 32 * textScale)
            let headerGap: CGFloat = compact ? (textScale > 1 ? 0 : 8) : 20
            let metadataHeight: CGFloat = (compact ? (tight && textScale > 1 ? 24 : 28) : 36) * textScale
            let columnGap: CGFloat = compact ? 20 : 32
            let panelWidth = min(isTablet && !compact ? 360 : 280, max(260, width * 0.34))
            let usableRowHeight = height - top - headerHeight - headerGap - margin
            let side = min(720, usableRowHeight,
                           width - margin * 2 - columnGap - panelWidth)
            let groupWidth = side + columnGap + panelWidth
            let left = (width - groupWidth) / 2
            let rowTop = top + headerHeight + headerGap
            header = CGRect(x: left, y: top, width: groupWidth, height: headerHeight)
            board = CGRect(x: left, y: rowTop, width: side, height: side)

            keyHeight = tight ? 44 : compact ? 52 : 66
            keyGap = compact ? 8 : 10
            keyFontSize = compact ? 27 : 32
            let toolHeight: CGFloat = (compact ? 44 : 52) + 16 * (textScale - 1)
            let contentHeight = metadataHeight + toolHeight + keyHeight * 2 + keyGap
            let statusHeight = min((expandedStatus ? 54 : 18) * textScale,
                                   max(18 * textScale, usableRowHeight - contentHeight))
            let gap = max(0, min(compact ? 12 : 20, (usableRowHeight - contentHeight - statusHeight) / 3))
            let panelHeight = contentHeight + gap * 3 + statusHeight
            let panelTop = max(rowTop, min(height - margin - panelHeight, board.midY - panelHeight / 2))
            let panelX = board.maxX + columnGap
            metadata = CGRect(x: panelX, y: panelTop, width: panelWidth, height: metadataHeight)
            tools = CGRect(x: panelX, y: metadata.maxY + gap, width: panelWidth, height: toolHeight)
            keypad = CGRect(x: panelX, y: tools.maxY + gap, width: panelWidth, height: keyHeight * 2 + keyGap)
            status = CGRect(x: panelX, y: keypad.maxY + gap, width: panelWidth, height: statusHeight)
        } else {
            arrangement = .stacked
            let spaciousTablet = isTablet && width > 500
            let nominalSide = spaciousTablet ? min(720, width - 48) : width
            let remaining = height - nominalSide
            compact = remaining < (spaciousTablet ? 410 : 350)
            tight = remaining < 300

            let top: CGFloat = tight ? 0 : spaciousTablet ? 16 : compact ? 4 : 8
            let bottom: CGFloat = tight ? 4 : spaciousTablet ? 16 : compact ? 4 : 8
            let headerHeight: CGFloat = max(spaciousTablet && !compact ? 48 : 44, 32 * textScale)
            let headerGap: CGFloat = tight ? 4 : compact ? 8 : spaciousTablet ? 20 : 16
            let metadataHeight: CGFloat = (tight ? 24 : 34) * textScale
            let boardGap: CGFloat = tight ? 4 : compact ? 8 : spaciousTablet ? 16 : 12
            let toolsGap: CGFloat = tight ? 8 : compact ? 12 : spaciousTablet ? 20 : 16
            let keysGap: CGFloat = tight ? 6 : compact ? 8 : spaciousTablet ? 16 : 12
            let statusGap: CGFloat = tight ? 4 : compact ? 6 : 8
            let toolHeight: CGFloat = (compact ? 44 : spaciousTablet ? 52 : 48) + 16 * (textScale - 1)
            keyHeight = tight ? 44 : compact ? 52 : spaciousTablet ? 64 : 56
            keyGap = tight ? 6 : 8
            keyFontSize = tight ? 26 : spaciousTablet ? 32 : 29
            let fixedChrome = top + headerHeight + headerGap + metadataHeight + boardGap + toolsGap + toolHeight +
                keysGap + keyHeight * 2 + keyGap + statusGap + bottom
            let statusHeight = min((expandedStatus ? 54 : 18) * textScale, max(1, height - fixedChrome - 1))
            let chrome = fixedChrome + statusHeight
            let side = max(1, min(nominalSide, height - chrome))
            let extra = max(0, height - side - chrome)
            // Center a tablet's notebook as a whole; keep phone keys near the thumb.
            let groupTop = spaciousTablet ? extra / 2 : 0
            let boardX = (width - side) / 2
            let columnWidth = spaciousTablet ? nominalSide : width
            let columnX = (width - columnWidth) / 2
            header = CGRect(x: columnX + 22, y: groupTop + top, width: columnWidth - 44, height: headerHeight)
            metadata = CGRect(x: columnX + 22, y: header.maxY + headerGap, width: columnWidth - 44, height: metadataHeight)
            board = CGRect(x: boardX, y: metadata.maxY + boardGap, width: side, height: side)
            let inputWidth = min(480, width - 36, spaciousTablet ? nominalSide : width)
            let inputX = (width - inputWidth) / 2
            let inputTop = board.maxY + toolsGap + (spaciousTablet ? 0 : extra)
            tools = CGRect(x: inputX, y: inputTop, width: inputWidth, height: toolHeight)
            keypad = CGRect(x: inputX, y: tools.maxY + keysGap, width: inputWidth, height: keyHeight * 2 + keyGap)
            status = CGRect(x: inputX, y: keypad.maxY + statusGap, width: inputWidth, height: statusHeight)
        }
    }
}
