import SwiftUI

struct ExportAlertModifier: ViewModifier {
    @ObservedObject var reactor: PDFHubReactor
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false

    func body(content: Content) -> some View {
        content
            .onReceive(reactor.$state) { state in
                guard let alert = state.exportAlert else { return }
                showingAlert = true
                alertMessage = alert.message
                alertSuccess = alert.isSuccess
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    reactor.send(.dismissAlert)
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertSuccess ? DesignSystem.Alerts.success : DesignSystem.Alerts.error),
                    message: Text(alertMessage),
                    dismissButton: .default(Text(DesignSystem.Alerts.ok))
                )
            }
    }
}

extension View {
    func exportAlert(reactor: PDFHubReactor) -> some View {
        modifier(ExportAlertModifier(reactor: reactor))
    }
}
