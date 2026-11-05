import SwiftUI

/// The whole window is the drop target when there's nothing in it: one clear action,
/// a line about what Beaver does, and the few shortcuts worth knowing.
struct EmptyStateView: View {
    let isTargeted: Bool
    let onChooseFiles: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(.beaverIcon)
                .resizable()
                .scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .scaleEffect(isTargeted && !reduceMotion ? Constants.targetedScale : 1)
                .accessibilityHidden(true)

            VStack(spacing: DesignSystem.Spacing.small) {
                Text(isTargeted ? DesignSystem.EmptyState.dropToAdd : DesignSystem.EmptyState.title)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(DesignSystem.EmptyState.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Constants.messageWidth)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onChooseFiles) {
                Label(DesignSystem.EmptyState.chooseFiles, systemImage: DesignSystem.Icons.addFiles)
                    .padding(.horizontal, DesignSystem.Spacing.small)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint(DesignSystem.Accessibility.dropTargetHint)

            HStack(spacing: DesignSystem.Spacing.large) {
                ShortcutHint(key: "⌘O", title: DesignSystem.EmptyState.hintChoose)
                ShortcutHint(key: DesignSystem.EmptyState.hintDragKey, title: DesignSystem.EmptyState.hintReorder)
                ShortcutHint(key: DesignSystem.EmptyState.hintSpaceKey, title: DesignSystem.EmptyState.hintQuickLook)
            }
            .padding(.top, DesignSystem.Spacing.small)
        }
        .padding(Constants.innerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(Constants.targetedFill) : .clear)
                .strokeBorder(
                    borderColor,
                    style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: isTargeted ? [] : Constants.dash)
                )
        }
        .padding(DesignSystem.Spacing.large)
        .animation(reduceMotion ? nil : .snappy(duration: Constants.animationDuration), value: isTargeted)
    }

    private var borderColor: Color {
        if isTargeted { return .accentColor }
        return Color.secondary.opacity(contrast == .increased ? 0.9 : 0.35)
    }
}

/// A key cap and what it does, e.g. [⌘O] Choose files.
private struct ShortcutHint: View {
    let key: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.callout.monospaced().weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(title)
                .font(.callout)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

private enum Constants {
    static let iconSize: CGFloat = 112
    static let targetedScale: CGFloat = 1.08
    static let messageWidth: CGFloat = 420
    static let innerPadding: CGFloat = 40
    static let cornerRadius: CGFloat = 20
    static let targetedFill: Double = 0.08
    static let dash: [CGFloat] = [8, 6]
    static let animationDuration: Double = 0.2
}
