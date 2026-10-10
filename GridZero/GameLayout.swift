import SwiftUI

extension View {
    func gameRegion(_ frame: CGRect) -> some View {
        self.frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}

struct EntryFlight: Identifiable {
    let id = UUID()
    let digit: Int
    let index: Int
    let source: CGPoint
    let target: CGPoint
    let accepted: Bool
    var position: CGPoint
    var fontSize: CGFloat
    var opacity: Double = 1
    var scale: CGFloat = 1
    var rejected = false
}

struct CellShake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 6) * 4, y: 0))
    }
}
