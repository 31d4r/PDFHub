import BeaverCore
import Foundation
import SwiftUI
import Testing
@testable import Beaver

/// Merge, Split, Convert, Combine and the image exports: when each one applies, what its tooltip says, and the
/// Actions menu that runs them.
@MainActor
struct DocumentActionTests {
    private let secondPNG = URL(fileURLWithPath: "/tmp/second.png")
    private let destination = URL(fileURLWithPath: "/tmp/beaver-tests/out.pdf")

    private func makeReactor(
        panels: MockSaveLocationProvider = MockSaveLocationProvider(),
        export: MockExportService = MockExportService()
    ) -> BeaverReactor {
        let images = MockImageService()
        images.thumbnailsByURL[TestFixtures.samplePNG] = TestImages.solid(width: 10, height: 10)
        images.thumbnailsByURL[secondPNG] = TestImages.solid(width: 12, height: 12)
        return BeaverReactor(saveLocationProvider: panels, imageService: images, exportService: export)
    }

    /// PDF, image, PDF, image.
    private func makeMixedReactor(
        panels: MockSaveLocationProvider = MockSaveLocationProvider(),
        export: MockExportService = MockExportService()
    ) async -> BeaverReactor {
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.samplePNG, TestFixtures.sample2PDF, secondPNG]))
        return reactor
    }

    private func availabilities(_ state: BeaverReactor.State) -> [DocumentAction: DocumentAction.Availability] {
        Dictionary(uniqueKeysWithValues: DocumentAction.allCases.map { ($0, state.availability(of: $0)) })
    }

    // MARK: - Availability

    @Test func emptyWorkspaceExplainsEveryAction() {
        let state = makeReactor().state
        #expect(availabilities(state) == [
            .merge: .unavailable(.needsTwoPDFs(selection: false)),
            .split: .unavailable(.needsPDF(selection: false)),
            .convert: .unavailable(.needsImages(selection: false)),
            .combine: .unavailable(.needsBothKinds(selection: false)),
            .exportPNG: .unavailable(.needsPDFForImages(selection: false)),
            .exportJPEG: .unavailable(.needsPDFForImages(selection: false)),
        ])
    }

    @Test func mixedWorkspaceWithoutSelection() async {
        let state = await makeMixedReactor().state
        #expect(availabilities(state) == [
            .merge: .unavailable(.mergeTakesOnlyPDFs),
            .split: .available(count: 2, selection: false),
            .convert: .unavailable(.convertTakesOnlyImages),
            .combine: .available(count: 4, selection: false),
            .exportPNG: .available(count: 2, selection: false),
            .exportJPEG: .available(count: 2, selection: false),
        ])
        #expect(state.hasBothKinds)
    }

    @Test func twoSelectedPDFs() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        reactor.action(.select(ids[0], .none))
        reactor.action(.select(ids[2], .command))

        #expect(availabilities(reactor.state) == [
            .merge: .available(count: 2, selection: true),
            .split: .available(count: 2, selection: true),
            .convert: .unavailable(.needsImages(selection: true)),
            .combine: .unavailable(.needsBothKinds(selection: true)),
            .exportPNG: .available(count: 2, selection: true),
            .exportJPEG: .available(count: 2, selection: true),
        ])
    }

    @Test func oneSelectedPDF() async {
        let reactor = await makeMixedReactor()
        reactor.action(.select(reactor.state.items[0].id, .none))

        #expect(availabilities(reactor.state) == [
            .merge: .unavailable(.needsTwoPDFs(selection: true)),
            .split: .available(count: 1, selection: true),
            .convert: .unavailable(.needsImages(selection: true)),
            .combine: .unavailable(.needsBothKinds(selection: true)),
            .exportPNG: .available(count: 1, selection: true),
            .exportJPEG: .available(count: 1, selection: true),
        ])
    }

    @Test func selectedImages() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        reactor.action(.select(ids[1], .none))
        reactor.action(.select(ids[3], .command))

        #expect(availabilities(reactor.state) == [
            .merge: .unavailable(.needsTwoPDFs(selection: true)),
            .split: .unavailable(.needsPDF(selection: true)),
            .convert: .available(count: 2, selection: true),
            .combine: .unavailable(.needsBothKinds(selection: true)),
            .exportPNG: .unavailable(.needsPDFForImages(selection: true)),
            .exportJPEG: .unavailable(.needsPDFForImages(selection: true)),
        ])
    }

    @Test func explicitIDsOverrideTheSelection() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        reactor.action(.select(ids[0], .none))

        #expect(reactor.state.availability(of: .convert, ids: [ids[1]]) == .available(count: 1, selection: true))
        #expect(reactor.state.availability(of: .convert, ids: []) == .unavailable(.needsImages(selection: true)))
    }

    @Test func everythingIsBusyWhileExporting() async {
        let export = MockExportService(isGated: true)
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let reactor = await makeMixedReactor(panels: panels, export: export)

        let running = Task { await reactor.action(.perform(.combine)) }
        while reactor.state.activity == nil { await Task.yield() }

        for action in DocumentAction.allCases {
            #expect(reactor.state.availability(of: action) == .unavailable(.busy))
        }
        export.release()
        await running.value
        #expect(reactor.state.availability(of: .combine).isAvailable)
    }

    // MARK: - Performing

    @Test func unavailableActionDoesNothing() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = await makeMixedReactor(panels: panels, export: export)

        await reactor.action(.perform(.merge))
        await reactor.action(.perform(.convert))

        #expect(export.calls.isEmpty)
        #expect(panels.requestedNames.isEmpty)
    }

    @Test func performOnExplicitIDsUsesOnlyThoseFiles() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = await makeMixedReactor(panels: panels, export: export)
        let ids = reactor.state.items.map(\.id)

        await reactor.action(.perform(.convert, ids: [ids[3]]))

        #expect(export.calls == [.convert(urls: [secondPNG], rotations: [.zero], destination: destination)])
        #expect(panels.requestedNames == [DesignSystem.FileNames.convertedImagesPDF])
    }

    @Test func mergeOnlyTakesTheSelectedPDFs() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = await makeMixedReactor(panels: panels, export: export)
        let ids = reactor.state.items.map(\.id)
        reactor.action(.select(ids[2], .none))
        reactor.action(.select(ids[0], .command))

        await reactor.action(.perform(.merge))

        #expect(export.calls == [.merge(
            urls: [TestFixtures.samplePDF, TestFixtures.sample2PDF],
            rotations: [.none, .none],
            destination: destination
        )])
    }

    /// Converting never adds its output to the list; the banner offers that instead.
    @Test func exportLeavesTheListUnchanged() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let reactor = await makeMixedReactor(panels: panels)
        let before = reactor.state.items

        await reactor.action(.perform(.combine))

        #expect(reactor.state.items == before)
    }

    // MARK: - Strings

    @Test func tooltipsSayWhatWillHappen() {
        #expect(
            DesignSystem.Help.action(.merge, .available(count: 3, selection: true))
                == "Merge PDFs (⌥⌘M)\nMerge 3 selected PDFs into one PDF"
        )
        #expect(
            DesignSystem.Help.action(.convert, .available(count: 1, selection: false))
                == "Convert to PDF (⌥⌘I)\nTurn 1 image into a PDF"
        )
        #expect(
            DesignSystem.Help.action(.split, .available(count: 2, selection: false))
                == "Split PDF (⌥⌘S)\nSave each page of all 2 PDFs as its own PDF"
        )
        #expect(
            DesignSystem.Help.action(.combine, .available(count: 4, selection: true))
                == "Combine into PDF (⌥⌘C)\nCombine 4 selected files into one PDF, in order"
        )
    }

    @Test func tooltipsSayWhyWhenDimmed() {
        #expect(
            DesignSystem.Help.action(.merge, .unavailable(.needsTwoPDFs(selection: false)))
                == "Merge PDFs (⌥⌘M)\nAdd at least two PDFs to merge"
        )
        #expect(DesignSystem.Actions.reason(.needsTwoPDFs(selection: true)) == "Select at least two PDFs to merge")
        #expect(DesignSystem.Actions.reason(.needsPDF(selection: false)) == "Add a PDF to split")
        #expect(DesignSystem.Actions.reason(.needsImages(selection: true)) == "Select images to convert")
    }

    @Test(arguments: [
        "action.merge", "action.split", "action.convert", "action.combine",
        "menu.merge", "menu.split", "menu.convert", "menu.combine",
        "action.merge.detail.selected", "action.merge.detail.all",
        "action.split.detail.selected", "action.split.detail.all",
        "action.convert.detail.selected", "action.convert.detail.all",
        "action.combine.detail.selected", "action.combine.detail.all",
        "action.reason.busy", "action.reason.merge.select", "action.reason.merge.add",
        "action.reason.merge.pdfsOnly", "action.reason.split.select", "action.reason.split.add",
        "action.reason.convert.select", "action.reason.convert.add", "action.reason.convert.imagesOnly",
        "action.reason.combine.select", "action.reason.combine.add",
        "menu.actions.title", "window.title", "window.subtitle.selection",
        "workspace.rotateSelectedLeft", "workspace.rotateSelectedRight",
        "workspace.rotateAllLeft", "workspace.rotateAllRight",
        "rotate.help.selectedLeft", "rotate.help.selectedRight", "rotate.help.allLeft", "rotate.help.allRight",
        "rotate.menu.help", "rotate.section.selected", "rotate.section.all",
    ])
    func actionKeyIsInTheCatalog(_ key: String) {
        let missing = "\u{1}missing"
        let value = Bundle.main.localizedString(forKey: key, value: missing, table: "Localizable")
        #expect(value != missing, "\(key) is not in Localizable.xcstrings")
    }

    // MARK: - Actions menu

    @Test func menuListsEveryActionInOrder() {
        #expect(ActionsMenu.items(for: nil).map(\.title) == [
            "Add Files…", "Merge PDFs…", "Split PDF…", "Convert to PDF…", "Combine into PDF…",
            "Export as PNG…", "Export as JPEG…",
            "Rotate Left", "Rotate Right", "Rotate All Left", "Rotate All Right",
            "Show Pages…", "Quick Look", "Remove", "Remove All…",
        ])
        #expect(ActionsMenu.items(for: nil).allSatisfy { !$0.isEnabled })
    }

    @Test func menuShortcutsMatchTheTooltipsAndReference() {
        let expected: [ActionsMenu.Command: String] = [
            .addFiles: DesignSystem.Help.Shortcut.addFiles,
            .merge: DesignSystem.Help.Shortcut.merge,
            .split: DesignSystem.Help.Shortcut.split,
            .convert: DesignSystem.Help.Shortcut.convert,
            .combine: DesignSystem.Help.Shortcut.combine,
            .exportPNG: DesignSystem.Help.Shortcut.exportPNG,
            .exportJPEG: DesignSystem.Help.Shortcut.exportJPEG,
            .rotateLeft: DesignSystem.Help.Shortcut.rotateLeft,
            .rotateRight: DesignSystem.Help.Shortcut.rotateRight,
            .rotateAllLeft: DesignSystem.Help.Shortcut.rotateAllLeft,
            .rotateAllRight: DesignSystem.Help.Shortcut.rotateAllRight,
            .showPages: DesignSystem.Help.Shortcut.showPages,
            .remove: DesignSystem.Help.Shortcut.remove,
            .removeAll: DesignSystem.Help.Shortcut.removeAll,
        ]
        for (command, shortcut) in expected {
            #expect(ActionsMenu.displayShortcut(command) == shortcut, "\(command)")
        }
        #expect(DesignSystem.Help.Shortcut.quickLook.contains(ActionsMenu.displayShortcut(.quickLook)))
        let references = DesignSystem.Shortcuts.sections.flatMap(\.entries).map(\.keys)
        for command in ActionsMenu.Command.allCases {
            let shortcut = ActionsMenu.displayShortcut(command)
            #expect(references.contains { $0.contains(shortcut) }, "\(shortcut) is missing from Keyboard Shortcuts")
        }
    }

    @Test func menuShortcutsAreUnique() {
        let shortcuts = ActionsMenu.Command.allCases.map(ActionsMenu.displayShortcut)
        #expect(Set(shortcuts).count == shortcuts.count)
    }

    @Test func menuEnablesWhatApplies() async {
        let reactor = await makeMixedReactor()
        func enabled() -> Set<ActionsMenu.Command> {
            Set(ActionsMenu.items(for: reactor.state).filter(\.isEnabled).map(\.command))
        }

        #expect(enabled() == [
            .addFiles, .split, .combine, .exportPNG, .exportJPEG, .rotateAllLeft, .rotateAllRight, .quickLook, .removeAll,
        ])

        reactor.action(.select(reactor.state.items[0].id, .none))
        #expect(enabled() == [
            .addFiles, .split, .exportPNG, .exportJPEG, .rotateLeft, .rotateRight, .rotateAllLeft, .rotateAllRight,
            .showPages, .quickLook, .remove, .removeAll,
        ])
    }

    @Test func menuRotateCommandsTargetTheRightFiles() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        reactor.action(.select(ids[1], .none))

        ActionsMenu.perform(.rotateRight, on: reactor)
        #expect(reactor.state.items.map(\.rotationAngle) == [.zero, .ninety, .zero, .zero])

        ActionsMenu.perform(.rotateAllLeft, on: reactor)
        #expect(reactor.state.items.map(\.rotationAngle) == [.twoSeventy, .zero, .twoSeventy, .twoSeventy])
    }

    @Test func menuShowPagesOpensTheFocusedPDF() async {
        let reactor = await makeMixedReactor()
        let pdf = reactor.state.items[2]
        reactor.action(.select(pdf.id, .none))

        ActionsMenu.perform(.showPages, on: reactor)

        #expect(reactor.state.pagesPDFID == pdf.id)
    }
}
