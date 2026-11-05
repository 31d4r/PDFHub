import SwiftUI

/// Asks before Back or Clear All throws away the files on the current screen.
struct DiscardConfirmationModifier: ViewModifier {
    @ObservedObject var reactor: BeaverReactor

    func body(content: Content) -> some View {
        let request = reactor.state.pendingDiscard

        content
            .confirmationDialog(
                DesignSystem.Confirmations.discardTitle(count: reactor.state.discardableCount),
                isPresented: Binding(
                    get: { reactor.state.pendingDiscard != nil },
                    set: { isPresented in
                        if !isPresented {
                            reactor.action(.didCancelDiscard)
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: request
            ) { request in
                Button(
                    request == .goBack
                        ? DesignSystem.Confirmations.goBack
                        : DesignSystem.Confirmations.clearAll,
                    role: .destructive
                ) {
                    reactor.send(.confirmDiscard(request))
                }
                Button(DesignSystem.Confirmations.cancel, role: .cancel) {
                    reactor.action(.didCancelDiscard)
                }
            } message: { _ in
                Text(DesignSystem.Confirmations.discardMessage(includesRotations: reactor.state.hasDiscardableRotations))
            }
    }
}

extension View {
    func discardConfirmation(reactor: BeaverReactor) -> some View {
        modifier(DiscardConfirmationModifier(reactor: reactor))
    }
}
