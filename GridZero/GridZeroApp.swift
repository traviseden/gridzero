import SwiftUI

@main
struct GridZeroApp: App {
    @State private var model = launchModel()
    var body: some Scene {
        WindowGroup {
            GameView(model: model)
                // DEBUG-only viewport harness exercises SwiftUI at resized window dimensions.
                // Production always uses the real window proposal without an override.
                #if DEBUG
                .frame(width: testViewport?.width, height: testViewport?.height)
                .background {
                    if testViewport != nil { ViewportProbe() }
                }
                .transformEnvironment(\.dynamicTypeSize) { size in
                    if ProcessInfo.processInfo.environment["GRIDZERO_TEST_ACCESSIBILITY_TEXT"] == "1" {
                        size = .accessibility5
                    }
                }
                #endif
                .preferredColorScheme(model.preferences.appearance.scheme(
                    at: model.clock, lightAt: model.preferences.lightAt, darkAt: model.preferences.darkAt))
        }
    }

    private static func launchModel() -> GameModel {
        #if DEBUG
        if let model = UITestFixture.makeModel() { return model }
        #endif
        return GameModel()
    }

    #if DEBUG
    private var testViewport: CGSize? {
        let environment = ProcessInfo.processInfo.environment
        guard let width = Double(environment["GRIDZERO_TEST_WIDTH"] ?? ""),
              let height = Double(environment["GRIDZERO_TEST_HEIGHT"] ?? ""),
              width >= 280, height >= 320 else { return nil }
        return CGSize(width: width, height: height)
    }
    #endif
}

#if DEBUG
// UIKit reports the exact test-container frame. SwiftUI accessibility groups can
// report only the union of their visible children, which is smaller than a window.
private struct ViewportProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "viewport-bounds"
        view.accessibilityLabel = "Layout test viewport"
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {}
}
#endif
