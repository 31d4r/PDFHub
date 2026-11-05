import AsyncReactor
import SwiftUI

@main
struct BeaverApp: App {
    var body: some Scene {
        WindowGroup {
            ReactorView(BeaverReactor()) {
                MainView()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
    }
}
