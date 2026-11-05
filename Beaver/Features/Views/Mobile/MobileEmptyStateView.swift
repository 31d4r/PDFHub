#if os(iOS)
import SwiftUI

/// The first screen: what Beaver does and one clear way to start. On iPad the whole area
/// also takes files dragged in from another app.
struct MobileEmptyStateView: View {
    let isTargeted: Bool
    let onAddPhotos: () -> Void
    let onAddFiles: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = Constants.iconSize

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                Image(.beaverIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .scaleEffect(isTargeted && !reduceMotion ? Constants.targetedScale : 1)
                    .accessibilityHidden(true)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text(isTargeted ? DesignSystem.EmptyState.dropToAdd : DesignSystem.Mobile.emptyTitle)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(DesignSystem.Mobile.emptyMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: Constants.messageWidth)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Button(action: onAddPhotos) {
                        Label(DesignSystem.Mobile.choosePhotos, systemImage: DesignSystem.Icons.photos)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(DesignSystem.Mobile.photosHelp)

                    Button(action: onAddFiles) {
                        Label(DesignSystem.Mobile.browseFiles, systemImage: DesignSystem.Icons.folder)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(DesignSystem.Mobile.filesHelp)
                }
                .controlSize(.large)
                .frame(maxWidth: Constants.buttonWidth)
            }
            .padding(DesignSystem.Spacing.large)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center) { length, _ in length }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            if isTargeted {
                RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(Constants.targetedFill))
                    .padding(DesignSystem.Spacing.medium)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: Constants.animationDuration), value: isTargeted)
    }
}

private enum Constants {
    static let iconSize: CGFloat = 96
    static let targetedScale: CGFloat = 1.08
    static let messageWidth: CGFloat = 440
    static let buttonWidth: CGFloat = 320
    static let cornerRadius: CGFloat = 24
    static let targetedFill: Double = 0.08
    static let animationDuration: Double = 0.2
}
#endif
