import Foundation

protocol FileIOServiceProtocol {
    func write(data: Data, to url: URL) throws
}

struct FileIOService: FileIOServiceProtocol {
    func write(data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}

