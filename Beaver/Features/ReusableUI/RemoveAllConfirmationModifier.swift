import SwiftUI

/// Asks before Remove All. Removing selected files never asks: it can be undone.
struct RemoveAllConfirmationModifier: ViewModifier {
    @ObservedObject var reactor: BeaverReactor

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                DesignSystem.Confirmations.removeAllTitle(count: reactor.state.items.count),
                isPresented: Binding(
                    get: { reactor.state.isConfirmingRemoveAll },
                    set: { isPresented in
                        if !isPresented { reactor.action(.didCancelRemoveAll) }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(DesignSystem.Confirmations.removeAll, role: .destructive) {
                    reactor.send(.confirmRemoveAll)
                }
                Button(DesignSystem.Confirmations.cancel, role: .cancel) {
                    reactor.action(.didCancelRemoveAll)
                }
            } message: {
                Text(DesignSystem.Confirmations.removeAllMessage(
                    includesRotations: reactor.state.hasDiscardableRotations
                ))
            }
    }
}

extension View {
    func removeAllConfirmation(reactor: BeaverReactor) -> some View {
        modifier(RemoveAllConfirmationModifier(reactor: reactor))
    }
}
