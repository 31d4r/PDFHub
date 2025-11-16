import Foundation

struct PDFRotationMapper {
    static func mapRotationAngles(urls: [URL], from pdfs: [PDF]) -> [URL: Int] {
        Dictionary(uniqueKeysWithValues: urls.map { url in
            (url, pdfs.first(where: { $0.pdfURL == url })?.rotationAngle ?? 0)
        })
    }
}

