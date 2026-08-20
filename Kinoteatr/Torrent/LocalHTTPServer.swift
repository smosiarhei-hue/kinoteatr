import Foundation
import Network

final class LocalHTTPServer {
    private let folder: URL
    private let port: Int
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "local.http.server")

    init(folder: URL, port: Int = 0) {
        self.folder = folder
        self.port = port
    }

    var actualPort: Int {
        Int(listener?.port?.rawValue ?? 0)
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: port == 0 ? .any : .init(rawValue: UInt16(port))!)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener.start(queue: queue)
    }

    func stop() throws {
        listener?.cancel()
        listener = nil
    }

    func streamURL(for filename: String) -> URL {
        let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
        return URL(string: "http://127.0.0.1:\(actualPort)/\(encoded)")!
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self else { connection.cancel(); return }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let lines = request.split(whereSeparator: \.isNewline).map(String.init)
            let firstLine = lines.first ?? ""
            let parts = firstLine.split(separator: " ")
            let rawPath = parts.count > 1 ? String(parts[1]) : "/"
            let path = rawPath.removingPercentEncoding ?? rawPath
            var rangeStart: Int64?
            for line in lines {
                let lower = line.lowercased()
                if lower.hasPrefix("range:") {
                    rangeStart = Self.parseRangeStart(line, totalHint: nil)
                }
            }
            self.respond(file: path, rangeStart: rangeStart, on: connection)
        }
    }

    private static func parseRangeStart(_ header: String, totalHint: Int64?) -> Int64? {
        guard let eq = header.range(of: "=") else { return nil }
        let value = header[eq.upperBound...].trimmingCharacters(in: .whitespaces)
        let first = value.split(separator: "-").first.map(String.init) ?? ""
        return Int64(first)
    }

    private func respond(file: String, rangeStart: Int64?, on connection: NWConnection) {
        let name = (file as NSString).lastPathComponent
        guard !name.isEmpty, name != ".", name != ".." else {
            send404(connection)
            return
        }
        let url = folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path),
               let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[FileAttributeKey.size] as? Int64
        else {
            send404(connection)
            return
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            send404(connection)
            return
        }

        let start = rangeStart ?? 0
        if start > 0 {
            handle.seek(toFileOffset: UInt64(start))
        }
        let remaining = size - start

        let header: String
        if start > 0 {
            header = "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes \(start)-\(size - 1)/\(size)\r\nContent-Length: \(remaining)\r\nContent-Type: video/mp4\r\nAccept-Ranges: bytes\r\nCache-Control: no-cache\r\n\r\n"
        } else {
            header = "HTTP/1.1 200 OK\r\nContent-Length: \(size)\r\nContent-Type: video/mp4\r\nAccept-Ranges: bytes\r\nCache-Control: no-cache\r\n\r\n"
        }
        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] _ in
            self?.pump(handle, on: connection, remaining: remaining)
        })
    }

    private func pump(_ handle: FileHandle, on connection: NWConnection, remaining: Int64) {
        guard remaining > 0 else { handle.closeFile(); connection.cancel(); return }
        let chunkSize = min(256 * 1024, Int(remaining))
        let chunk = handle.readData(ofLength: chunkSize)
        guard !chunk.isEmpty else { handle.closeFile(); connection.cancel(); return }
        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else {
                handle.closeFile()
                connection.cancel()
                return
            }
            self.pump(handle, on: connection, remaining: remaining - Int64(chunk.count))
        })
    }

    private func send404(_ connection: NWConnection) {
        let body = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
        connection.send(content: Data(body.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
