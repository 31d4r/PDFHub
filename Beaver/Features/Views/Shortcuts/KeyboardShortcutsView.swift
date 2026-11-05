import SwiftUI

/// Help ▸ Keyboard Shortcuts. A quiet reference window: it lists what the menus and the grid
/// respond to and never opens by itself.
struct KeyboardShortcutsView: View {
    var body: some View {
        Form {
            ForEach(DesignSystem.Shortcuts.sections) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        LabeledContent(entry.title) {
                            Text(entry.keys)
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: Constants.width, idealWidth: Constants.width, minHeight: Constants.minHeight)
    }
}

private enum Constants {
    static let width: CGFloat = 420
    static let minHeight: CGFloat = 360
}
