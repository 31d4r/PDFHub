import UniformTypeIdentifiers

public enum SupportedImageType: CaseIterable, Sendable {
    case png
    case jpeg
    case tiff
    case heic
    case bmp
    case gif

    public var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .heic: return .heic
        case .bmp: return .bmp
        case .gif: return .gif
        }
    }

    public var fileExtensions: [String] {
        switch self {
        case .png: return ["png"]
        case .jpeg: return ["jpg", "jpeg"]
        case .tiff: return ["tiff", "tif"]
        case .heic: return ["heic"]
        case .bmp: return ["bmp"]
        case .gif: return ["gif"]
        }
    }

    public static var allUTTypes: [UTType] {
        allCases.map(\.utType)
    }

    public static var allFileExtensions: [String] {
        allCases.flatMap(\.fileExtensions)
    }

    public static func contains(fileExtension: String) -> Bool {
        allFileExtensions.contains(fileExtension.lowercased())
    }
}
