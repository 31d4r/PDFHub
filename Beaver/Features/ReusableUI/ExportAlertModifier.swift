import SwiftUI

/// Presents `state.exportAlert` and clears it when the user dismisses the alert.
struct ExportAlertModifier: ViewModifier {
    @ObservedObject var reactor: BeaverReactor

    func body(content: Content) -> some View {
        let alert = reactor.state.exportAlert

        content
            .alert(
                alert?.isSuccess == true ? DesignSystem.Alerts.success : DesignSystem.Alerts.error,
                isPresented: Binding(
                    get: { reactor.state.exportAlert != nil },
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
