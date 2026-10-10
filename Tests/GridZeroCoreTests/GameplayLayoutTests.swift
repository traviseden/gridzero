import Testing
import Foundation
import CoreGraphics
@testable import GridZeroCore

private struct DeviceProfile: Decodable {
    let name: String
    let family: String
    let width: Double
    let height: Double
}

private func checkLayout(_ size: CGSize, tablet: Bool, context: String = "") {
    let layout = GameplayLayout(size: size, isTablet: tablet)
    let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -0.01, dy: -0.01)
    for region in layout.regions {
        #expect(region.width > 0 && region.height > 0, "Positive region: \(context) \(size)")
        #expect(bounds.contains(region), "Region must stay inside the window: \(context) \(size) \(region)")
    }
    for a in layout.regions.indices {
        for b in layout.regions.indices where b > a {
            #expect(!layout.regions[a].intersects(layout.regions[b]), "No overlapping UI: \(context) \(size)")
        }
    }
    #expect(layout.board.width == layout.board.height)
    #expect(layout.board.width <= 720)
    let keys = (1...9).map { layout.keyFrame(for: $0) }
    for key in keys {
        #expect(key.width >= 44 && key.height >= 44, "Keep usable touch targets: \(context) \(size)")
        #expect(bounds.contains(key))
        #expect(layout.keypad.insetBy(dx: -0.01, dy: -0.01).contains(key))
    }
    for a in keys.indices {
        for b in keys.indices where b > a { #expect(!keys[a].intersects(keys[b])) }
    }
    for even in [2, 4, 6, 8] {
        let key = layout.keyFrame(for: even)
        #expect(key.midX > layout.keyFrame(for: even - 1).midX)
        #expect(key.midX < layout.keyFrame(for: even + 1).midX)
        #expect(key.minY >= layout.keyFrame(for: even - 1).maxY)
    }
}

@Test func everyInventoriedModelFitsInBothOrientations() throws {
    let url = try #require(Bundle.module.url(forResource: "devices", withExtension: "json"))
    let devices = try JSONDecoder().decode([DeviceProfile].self, from: Data(contentsOf: url))
    #expect(devices.count >= 24)
    for device in devices {
        let tablet = device.family == "iPad"
        // Insets deliberately exceed usual status/titlebar/home-indicator budgets.
        // Actual app layout gets safe-area dimensions directly from GeometryReader.
        for inset in [44.0, 96.0, 120.0] {
            let portrait = CGSize(width: device.width, height: device.height - inset)
            checkLayout(portrait, tablet: tablet, context: device.name)
            if !tablet {
                #expect(GameplayLayout(size: portrait, isTablet: false).board.width == CGFloat(device.width),
                        "Phone portrait remains edge-to-edge: \(device.name)")
            }
            let landscape = CGSize(width: device.height - (tablet ? 0 : 128),
                                   height: device.width - (tablet ? inset : 34))
            checkLayout(landscape, tablet: tablet, context: "\(device.name) landscape")
        }
    }
}

@Test func resizedWindowsAndBreakpointsDoNotClipControls() {
    for width in stride(from: 280, through: 1440, by: 19) {
        for height in stride(from: 320, through: 1360, by: 23) {
            checkLayout(CGSize(width: width, height: height), tablet: true)
        }
    }
    // Exercise exact boundary transitions, not just a sparse sampling.
    for width in [499.0, 500, 501, 599, 600, 601, 719, 720, 721] {
        for height in [320.0, 419, 420, 421, 549, 550, 551, 699, 700, 701, 900, 1100] {
            checkLayout(CGSize(width: width, height: height), tablet: true)
        }
    }
}

@Test func displayZoomRetainsPhoneWidthAndAllKeys() {
    for (width, height) in [(320.0, 596.0), (360, 684), (375, 700), (390, 740), (402, 762)] {
        let size = CGSize(width: width, height: height)
        checkLayout(size, tablet: false, context: "Display Zoom")
        #expect(GameplayLayout(size: size, isTablet: false).board.width == CGFloat(width))
    }
}

@Test func tabletBoardAndKeypadHaveSensibleMaximumSizes() {
    let portrait = GameplayLayout(size: CGSize(width: 1032, height: 1320), isTablet: true)
    #expect(portrait.board.width == 720)
    #expect(portrait.keypad.width == 480)
    #expect(portrait.board.midX == 516)
    let landscape = GameplayLayout(size: CGSize(width: 1376, height: 976), isTablet: true)
    #expect(landscape.arrangement == .sideBySide)
    #expect(landscape.keypad.minX > landscape.board.maxX)
    #expect(landscape.board.width <= 720)
}
