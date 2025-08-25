import AsyncReactor
import SwiftUI

@main
struct PDFHubApp: App {
    var body: some Scene {
        WindowGroup {
            ReactorView(PDFHubReactor()) {
                MainView()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
    }
}
