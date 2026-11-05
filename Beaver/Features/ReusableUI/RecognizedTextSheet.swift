import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Shows the text Vision read from a page, with Copy and Share.
struct RecognizedTextSheet: View {
    enum Content: Identifiable, Equatable {
        case loading(pageTitle: String)
        case ready(String)
        case empty

        var id: String {
            switch self {
            case .loading(let title): return "loading-\(title)"
            case .ready(let text): return "ready-\(text.hashValue)"
            case .empty: return "empty"
            }
        }
    }

    @Binding var content: Content?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch content {
                case .loading:
                    ProgressView(DesignSystem.Scan.recognizingText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let text):
                    ScrollView {
                        Text(text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                            .accessibilityLabel(DesignSystem.Scan.recognizedText)
                            .accessibilityValue(text)
                    }
                case .empty, .none:
                    ContentUnavailableView(
                        DesignSystem.Scan.recognizedText,
                        systemImage: "text.viewfinder",
                        description: Text(DesignSystem.Scan.noTextFound)
                    )
                }
            }
            .navigationTitle(DesignSystem.Scan.recognizedText)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(DesignSystem.Scan.done) { content = nil }
                }
                if case .ready(let text) = content {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: text) {
                            Label(DesignSystem.Scan.shareText, systemImage: "square.and.arrow.up")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(DesignSystem.Scan.copyText) {
                            copy(text)
                        }
                    }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
#endif
    }

    private func copy(_ text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
}
