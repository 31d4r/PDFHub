import Foundation

protocol FileIOServiceProtocol {
    func write(data: Data, to url: URL) throws
    func fileExists(at url: URL) -> Bool
}

struct FileIOService: FileIOServiceProtocol {
    func write(data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

