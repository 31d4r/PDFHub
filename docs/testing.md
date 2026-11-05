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

### iOS simulator

The same target and tests build for iPhone and iPad. List the simulators with
`xcrun simctl list devices available`, then:

```sh
rm -rf /tmp/beaver-ios-dd
xcodebuild \
  -project Beaver.xcodeproj \
  -scheme Beaver \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/beaver-ios-dd \
  test CODE_SIGNING_ALLOWED=NO
```

To build once and run the tests again without rebuilding, use `build-for-testing`, then
`test-without-building -xctestrun /tmp/beaver-ios-dd/Build/Products/Beaver_Beaver_iphonesimulator*.xctestrun`
with the same destination.

Both builds should finish with no Swift warnings:

```sh
grep -E "\.swift:[0-9]+:[0-9]+: warning:" build.log
```

Do not pass `SWIFT_VERSION` on the command line. The app and test targets set Swift 6 in the
project, and overriding it globally would also apply to the AsyncReactor package, which does not
build in Swift 6 language mode.

## Writing tests

- New tests use [Swift Testing](https://developer.apple.com/documentation/testing) (`import Testing`,
  `@Test`, `#expect`). A few older tests still use XCTest; both run in the same target.
- Tests that touch `BeaverReactor` are `@MainActor`.
- Inject the mocks in `BeaverTests/Mocks` instead of showing real panels or writing files:
  `MockSaveLocationProvider`, `MockImageService`, `MockFileIOService` and `MockExportService`.
  `MockExportService(isGated: true)` holds each export until `release()`, so a test can check
  the in-progress state.
- Tests that write real files create a unique folder under `FileManager.default.temporaryDirectory`
  and remove it with `defer`.
- Scanning code is in `BeaverCore/Sources/BeaverCore/Scanning` and is tested with generated images
  (`ScanProcessingTests`), so it runs the same on macOS and the simulator. `ScanReactorTests` cover
  the review: filters, rotation, order, corners, retake, rename and saving.
- Code that only exists on iOS sits behind `#if os(iOS)`. Keep logic in reactors and BeaverCore,
  which build on both platforms, so the macOS run tests it too.
- Fixtures live in `BeaverTests/Fixtures` (`sample.pdf`, `sample2.pdf`, `sample.png`) and are
  reached through `TestFixtures`.

## Manual checks

Automated tests do not cover these, so check them by hand before a release:

- Drag PDFs and images from Finder onto each screen.
- Menu bar commands and their shortcuts in the File and PDF menus.
- Dark mode, larger text sizes and VoiceOver labels.
- A signed, sandboxed build: open, merge, split and convert files in folders outside the container.

On an iPhone or iPad (the simulator has no camera):

- Scan Document: the first scan asks for the camera; pages are found and captured; Retake and Scan
  More Pages work from the review; with the camera turned off in Settings, Beaver offers Open Settings.
- Scan from Photo on real photos of paper: the page is found, flattened, and each filter looks right.
- Crop: drag each corner, and with VoiceOver use the Move Up/Down/Left/Right actions.
- HEIC photos and photos still in iCloud from the Photos picker; Save to Files and Share.
- iPad: drag PDFs and images in from Files, in both orientations and in Split View.
- Haptics when changing filters, rotating, saving and on errors.
