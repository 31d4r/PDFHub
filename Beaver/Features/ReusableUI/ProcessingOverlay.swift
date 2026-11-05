import SwiftUI

/// Dims and disables the screen while an export runs, and shows what is happening.
struct ProcessingOverlay: ViewModifier {
    let activity: BeaverReactor.Activity?

    func body(content: Content) -> some View {
        content
            .disabled(activity != nil)
            .overlay {
                if let activity {
                    ZStack {
                        Color.black.opacity(0.08)
                            .ignoresSafeArea()

                        VStack(spacing: DesignSystem.Spacing.medium) {
                            ProgressView()
                                .controlSize(.large)
                            Text(activity.title)
                                .scaledFont(size: DesignSystem.Typography.subtitleFontSize, weight: .medium, design: .rounded)
                        }
                        .padding(DesignSystem.Spacing.large)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
    }
}

extension View {
    func processingOverlay(_ activity: BeaverReactor.Activity?) -> some View {
        modifier(ProcessingOverlay(activity: activity))
    }
}
