import SwiftUI
import _d_swift_globe_widget

@main
struct GlobeApp: App {
    var body: some Scene {
        WindowGroup {
            Globe3DWidget()
                .frame(minWidth: 800, minHeight: 600)
                .background(Color.black)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
