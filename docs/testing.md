# Testing

## Canonical command

Run the full build and test suite from a clean derived data folder:

```sh
rm -rf /tmp/beaver-dd
xcodebuild \
  -project Beaver.xcodeproj \
  -scheme Beaver \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/beaver-dd \
  test CODE_SIGNING_ALLOWED=NO
```

`CODE_SIGNING_ALLOWED=NO` lets the suite run without a development team. Add
`-resultBundlePath /tmp/beaver-result.xcresult` to keep a result bundle, then read the totals with:

```sh
xcrun xcresulttool get test-results summary --path /tmp/beaver-result.xcresult
```

Do not pass `SWIFT_VERSION` on the command line. The app and test targets set Swift 6 in the
project, and overriding it globally would also apply to the AsyncReactor package, which does not
build in Swift 6 language mode.

## Writing tests

- New tests use [Swift Testing](https://developer.apple.com/documentation/testing) (`import Testing`,
  `@Test`, `#expect`). A few older tests still use XCTest; both run in the same target.
- Tests that touch `BeaverReactor` are `@MainActor`.
- Inject the mocks in `BeaverTests/Mocks` instead of showing real panels or writing files:
  `MockFilePanelService`, `MockImageService`, `MockFileIOService` and `MockExportService`.
  `MockExportService(isGated: true)` holds each export until `release()`, so a test can check
  the in-progress state.
- Tests that write real files create a unique folder under `FileManager.default.temporaryDirectory`
  and remove it with `defer`.
- Fixtures live in `BeaverTests/Fixtures` (`sample.pdf`, `sample2.pdf`, `sample.png`) and are
  reached through `TestFixtures`.

## Manual checks

Automated tests do not cover these, so check them by hand before a release:

- Drag PDFs and images from Finder onto each screen.
- Menu bar commands and their shortcuts in the File and PDF menus.
- Dark mode, larger text sizes and VoiceOver labels.
- A signed, sandboxed build: open, merge, split and convert files in folders outside the container.
