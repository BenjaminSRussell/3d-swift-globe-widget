import SwiftUI
import TitanCore

@main
struct TitanDemoApp: App {
    // Configuration from the environment (TITAN_DATA, TITAN_BOOKMARKS, ...), bundled sample data otherwise
    private let container = DependencyContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            TitanWidget(container: container)
                .frame(minWidth: 800, minHeight: 600)
                .navigationTitle("Titan Visualization Engine")
        }
    }
}
