import SwiftUI
import AsyncReactor

@main
struct PDFHubApp: App {
    
    var body: some Scene {
        WindowGroup {
            ReactorView(PDFHubReactor()) {
                MainView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.mainBg)
            }
        }
    }
}
