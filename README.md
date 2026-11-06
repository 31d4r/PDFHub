# Beaver

![Beaver](Images/BeaverIcon.png)

Beaver is an open-source app for working with PDF files on Mac, iPhone and iPad. You can turn photos and scans into a PDF, split a PDF into separate documents, merge several PDFs into one, pull selected pages out as their own PDF, or save pages as PNG or JPEG images, which is useful when you only need one page, or a picture to send in Messages. On iPhone and iPad you can also scan paper with the camera.

Perfect for privacy-conscious users -> All processing happens locally on your Mac, iPhone or iPad. Your documents never leave your device, making it ideal for sensitive documents like visa applications, legal papers, medical records, or any confidential information you need to convert or manage.

## Features

- Convert one or more images into a single PDF
- Split a PDF into separate page documents
- Merge multiple PDFs into one
- Export selected pages as a new PDF: extract one page, or several, without splitting the whole file
- Export pages as PNG or JPEG images (one file per page): PNG for sharp text, JPEG for smaller files
- iPhone and iPad: add photos in the order you pick them, PDFs and images from Files, or files
  dragged in on iPad
- iPhone and iPad: scan paper with the document camera, or find and flatten the page in a photo
  you already took. Review each page with Original, Enhanced, Grayscale or Black & White, fix the
  corners, rotate, reorder, retake and rename before saving
- 100% local processing -> Your files never leave your device


## Built With

- SwiftUI, PDFKit, ImageIO, Core Image, Vision and VisionKit
- [AsyncReactor](https://github.com/diamirio/AsyncReactor) for state management
- Swift 6 language mode with strict concurrency

## Requirements

- macOS 14 Sonoma or later
- iOS and iPadOS 17 or later
- Xcode 26 or later to build (Swift 6.2)

## Getting Started

To run the project locally:

1. Clone the repository
2. Open `Beaver.xcodeproj` in Xcode
3. Select the `Beaver` scheme and build and run on My Mac, an iPhone or iPad simulator, or a device

### Running on your iPhone or iPad

1. Connect the device, or pair it over Wi-Fi in Window > Devices and Simulators, and turn on
   Developer Mode on the device (Settings > Privacy & Security > Developer Mode).
2. In the Beaver target's Signing & Capabilities, keep Automatically manage signing on. The project
   uses team `89ZNTTCP5L` and bundle ID `com.eldartutnjic.Beaver`; pick your own team if you build
   under a different account, and change the bundle ID if that one is taken.
3. Choose the device as the run destination and press Run (⌘R). The first launch may ask you to
   trust the developer in Settings > General > VPN & Device Management.

The simulator has no camera, so Scan Document is dimmed there and says why; Scan from Photo works
everywhere.

## Testing

Run the tests in Xcode with Product > Test (⌘U), or from the command line:

```sh
xcodebuild -project Beaver.xcodeproj -scheme Beaver -destination 'platform=macOS' \
  -derivedDataPath /tmp/beaver-dd test CODE_SIGNING_ALLOWED=NO
```

The same suite runs on the iOS simulator:

```sh
xcodebuild -project Beaver.xcodeproj -scheme Beaver \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/beaver-ios-dd test CODE_SIGNING_ALLOWED=NO
```

See [docs/testing.md](docs/testing.md) for details.

## Privacy

Beaver has no network code, no analytics and no tracking. It only reads files you choose or drop
onto it, and only writes where you tell it to save. On iPhone and iPad it uses the camera only while
you scan, and the Photos picker gives it only the photos you pick. The app ships a privacy manifest
declaring that no data is collected; its one listed API is UserDefaults, for the thumbnail size.

## Screenshots

### iPhone

| Empty workspace | Your documents | Select and rotate |
|:---:|:---:|:---:|
| <img src="Screenshots/iOS/01-empty-workspace.png" alt="Empty workspace" width="220" /> | <img src="Screenshots/iOS/02-workspace.png" alt="Workspace with documents" width="220" /> | <img src="Screenshots/iOS/03-selection.png" alt="Selecting documents" width="220" /> |

| Scan review and filters | Actions | Saved, ready to share |
|:---:|:---:|:---:|
| <img src="Screenshots/iOS/04-scan-review.png" alt="Scan review and filters" width="220" /> | <img src="Screenshots/iOS/05-actions-menu.png" alt="Actions menu" width="220" /> | <img src="Screenshots/iOS/06-saved-banner.png" alt="Saved banner with Share and Show in Files" width="220" /> |

### Mac

<p align="center">
  <img src="Screenshots/macOS/01-empty-workspace.png" alt="Fresh launch: empty workspace with Choose Files and drag-and-drop hints" width="820" />
</p>
<p align="center"><em>A fresh launch</em></p>

| Your documents | Select, rotate and merge |
|:---:|:---:|
| <img src="Screenshots/macOS/02-workspace.png" alt="PDFs and an image together, with Split and Combine actions" width="440" /> | <img src="Screenshots/macOS/03-selection-and-rotation.png" alt="Selected PDFs with accent rings, a 90-degree rotation badge and Merge PDFs enabled" width="440" /> |

| Split a PDF | Convert an image to PDF |
|:---:|:---:|
| <img src="Screenshots/macOS/04-split-pdf.png" alt="A selected three-page lease ready to split into individual PDFs" width="440" /> | <img src="Screenshots/macOS/06-image-to-pdf.png" alt="A selected cafe receipt image with Convert to PDF enabled" width="440" /> |

<p align="center">
  <img src="Screenshots/macOS/05-page-organizer.png" alt="All three lease pages in the page organizer with per-page rotation controls" width="820" />
</p>
<p align="center"><em>Organize document pages</em></p>

## Project Status

This project has been released and is actively maintained with ongoing updates.

## License

Beaver's source code is released under the [MIT License](LICENSE).

The name "Beaver", the app icon and other branding are not covered by the license. If you publish
your own build or fork, please give it a different name and icon.

## Author

Made by [31d4r (Eldar Tutnjic)](https://github.com/31d4r)
