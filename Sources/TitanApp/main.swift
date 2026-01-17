import SwiftUI
import TitanCore

@main
struct TitanDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TitanWidget()
                .frame(minWidth: 800, minHeight: 600)
                .navigationTitle("Titan Visualization Engine")
        }
    }
}
