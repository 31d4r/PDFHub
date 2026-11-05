import AsyncReactor
import SwiftUI

@main
struct BeaverApp: App {
    var body: some Scene {
        #if os(macOS)
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

        Window(DesignSystem.Shortcuts.windowTitle, id: DesignSystem.Shortcuts.windowID) {
            KeyboardShortcutsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        #else
        WindowGroup {
            ReactorView(BeaverReactor()) {
                MobileMainView()
            }
        }
        .commands {
            // A hardware keyboard on iPad gets the same shortcuts, listed when ⌘ is held.
            BeaverCommands()
        }
        #endif
    }
}
