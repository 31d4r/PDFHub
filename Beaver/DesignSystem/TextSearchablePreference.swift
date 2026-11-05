import Foundation

/// Whether Convert and Scan write an invisible searchable text layer. Shared by the Mac and
/// iOS UIs through `UserDefaults` / `@AppStorage`.
enum TextSearchablePreference {
    static let key = "makeTextSearchable"
    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
