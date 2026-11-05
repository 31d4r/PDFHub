import SwiftUI

/// Presents a failed export as an alert and clears it on dismissal. Successes show as the
/// non-blocking `ExportBanner` instead.
struct ExportAlertModifier: ViewModifier {
    @ObservedObject var reactor: BeaverReactor

    func body(content: Content) -> some View {
        let alert = reactor.state.exportAlert.flatMap { $0.isSuccess ? nil : $0 }

        content
            .alert(
                DesignSystem.Alerts.error,
                isPresented: Binding(
                    get: { alert != nil },
                    set: { isPresented in
                        if !isPresented {
                            reactor.action(.didDismissAlert)
                        }
                    }
                ),
                presenting: alert
            ) { _ in
                Button(DesignSystem.Alerts.ok, role: .cancel) {}
            } message: { alert in
                Text(alert.message)
            }
    }
}

extension View {
    func exportAlert(reactor: BeaverReactor) -> some View {
        modifier(ExportAlertModifier(reactor: reactor))
    }
}
