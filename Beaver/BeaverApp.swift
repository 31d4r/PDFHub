import AsyncReactor
import SwiftUI

@main
struct BeaverApp: App {
    var body: some Scene {
        WindowGroup {
            ReactorView(BeaverReactor()) {
                MainView()
                    .frame(
                        minWidth: DesignSystem.Layout.windowMinimumSize.width,
                        maxWidth: .infinity,
                        minHeight: DesignSystem.Layout.windowMinimumSize.height,
                        maxHeight: .infinity
                    )
            }
        }
        .defaultSize(DesignSystem.Layout.windowDefaultSize)
        .windowResizability(.contentMinSize)
        .commands {
            BeaverCommands()
        }
    }
}
