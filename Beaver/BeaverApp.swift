import AsyncReactor
import SwiftUI

@main
struct BeaverApp: App {
    var body: some Scene {
        WindowGroup {
            ReactorView(BeaverReactor()) {
                MainView()
                    .frame(
                        minWidth: Constants.minWindowSize.width,
                        maxWidth: .infinity,
                        minHeight: Constants.minWindowSize.height,
                        maxHeight: .infinity
                    )
            }
        }
        .defaultSize(Constants.defaultWindowSize)
        .windowResizability(.contentMinSize)
        .commands {
            BeaverCommands()
        }
    }
}

private enum Constants {
    static let defaultWindowSize = CGSize(width: 1100, height: 760)
    static let minWindowSize = CGSize(width: 900, height: 600)
}
