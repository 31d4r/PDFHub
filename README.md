# Beaver

![Beaver](Images/BeaverIcon.png)

Beaver is an open-source macOS app for working with PDF files. You can convert one or more images into a single PDF, split a PDF into multiple documents, or merge multiple PDFs into one.

Perfect for privacy-conscious users -> All processing happens locally on your Mac. Your documents never leave your device, making it ideal for sensitive documents like visa applications, legal papers, medical records, or any confidential information you need to convert or manage.

## Features

- Convert images to PDF
- Split PDF into separate pages
- Merge multiple PDFs into one
- 100% local processing -> Your files never leave your device


## Built With

- SwiftUI, PDFKit and ImageIO
- [AsyncReactor](https://github.com/diamirio/AsyncReactor) for state management
- Swift 6 language mode with strict concurrency

## Requirements

- macOS 14 Sonoma or later
- Xcode 26 or later to build (Swift 6.2)

## Getting Started

To run the project locally:

1. Clone the repository
2. Open `Beaver.xcodeproj` in Xcode
3. Select the `Beaver` scheme and build and run on My Mac

## Testing

Run the tests in Xcode with Product > Test (⌘U), or from the command line:

```sh
xcodebuild -project Beaver.xcodeproj -scheme Beaver -destination 'platform=macOS' \
  -derivedDataPath /tmp/beaver-dd test CODE_SIGNING_ALLOWED=NO
```

See [docs/testing.md](docs/testing.md) for details.

## Privacy

Beaver has no network code, no analytics and no tracking. It only reads files you choose or drop
onto it, and only writes where you tell it to save. The app ships a privacy manifest declaring that
no data is collected.

## Screenshots

![Main Screen](Screenshots/Beaver1.png)
![Split PDF Feature](Screenshots/Beaver2.png)
![Images to PDF Feature](Screenshots/Beaver3.png)

## Project Status

This project has been released and is actively maintained with ongoing updates.

## License

MIT License

Copyright (c) 2025 Eldar Tutnjic

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Author

Made by [31d4r (Eldar Tutnjic)](https://github.com/31d4r)
