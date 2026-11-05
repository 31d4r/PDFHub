import Foundation

public protocol FileIOServiceProtocol: Sendable {
    func write(data: Data, to url: URL) throws
    func fileExists(at url: URL) -> Bool
}

public struct FileIOService: FileIOServiceProtocol {
    public init() {}

    public func write(data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

