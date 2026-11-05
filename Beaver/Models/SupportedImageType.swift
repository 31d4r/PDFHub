import UniformTypeIdentifiers

enum SupportedImageType: CaseIterable {
    case png
    case jpeg
    case tiff
    case heic
    case bmp
    case gif

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .heic: return .heic
        case .bmp: return .bmp
        case .gif: return .gif
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .png: return ["png"]
        case .jpeg: return ["jpg", "jpeg"]
        case .tiff: return ["tiff", "tif"]
        case .heic: return ["heic"]
        case .bmp: return ["bmp"]
        case .gif: return ["gif"]
        }
    }

    static var allUTTypes: [UTType] {
        allCases.map(\.utType)
    }

    static var allFileExtensions: [String] {
        allCases.flatMap(\.fileExtensions)
    }

    static func contains(fileExtension: String) -> Bool {
        allFileExtensions.contains(fileExtension.lowercased())
    }
}
