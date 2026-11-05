/// Which browsing controls the iOS toolbar shows. Kept out of the view, and built on macOS too,
/// so the tests cover it.
///
/// An empty workspace already offers Scan, Photos and Files as large buttons, so the toolbar
/// doesn't repeat them with an Add menu, and has nothing to select or act on. The more menu
/// appears there only when Undo or Redo would do something, such as right after Remove All.
struct MobileToolbarLayout: Equatable {
    var showsMoreMenu: Bool
    var showsSelect: Bool
    var showsAddMenu: Bool
    var showsActionsMenu: Bool

    var showsBottomBar: Bool { showsAddMenu || showsActionsMenu }

    init(showsMoreMenu: Bool, showsSelect: Bool, showsAddMenu: Bool, showsActionsMenu: Bool) {
        self.showsMoreMenu = showsMoreMenu
        self.showsSelect = showsSelect
        self.showsAddMenu = showsAddMenu
        self.showsActionsMenu = showsActionsMenu
    }

    init(_ state: BeaverReactor.State) {
        let hasItems = !state.isEmpty
        self.init(
            showsMoreMenu: hasItems || state.canUndo || state.canRedo,
            showsSelect: hasItems,
            showsAddMenu: hasItems,
            showsActionsMenu: hasItems
        )
    }
}
