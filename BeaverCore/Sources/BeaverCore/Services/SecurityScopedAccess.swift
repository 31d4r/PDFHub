import Foundation

/// Keeps security-scoped access open for files chosen in the system file
/// importer for as long as the app still lists them.
///
/// URLs that are not security-scoped (for example dropped files) are ignored.
@MainActor
public final class SecurityScopedAccess {
    private var accessedURLs: Set<URL> = []

    public init() {}

    public func begin(_ urls: [URL]) {
        for url in urls where !accessedURLs.contains(url) {
            if url.startAccessingSecurityScopedResource() {
                accessedURLs.insert(url)
            }
        }
    }

    /// Ends access for every URL that is not in `urls`.
    public func retainOnly(_ urls: Set<URL>) {
        for url in accessedURLs.subtracting(urls) {
            url.stopAccessingSecurityScopedResource()
            accessedURLs.remove(url)
        }
    }
}
