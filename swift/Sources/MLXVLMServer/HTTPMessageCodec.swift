import Foundation

public enum HTTPMessageCodecError: LocalizedError, Equatable, Sendable {
    case incompleteRequest
    case invalidRequestLine
    case invalidHeaderEncoding

    public var errorDescription: String? {
        switch self {
        case .incompleteRequest:
            return "HTTP request is incomplete."
        case .invalidRequestLine:
            return "HTTP request line is invalid."
        case .invalidHeaderEncoding:
            return "HTTP headers must be UTF-8 encoded."
        }
    }
}

public enum HTTPMessageCodec {
    public static func parseRequest(_ data: Data) throws -> HTTPRequest {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: delimiter) else {
            throw HTTPMessageCodecError.incompleteRequest
        }

        let headerData = data[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw HTTPMessageCodecError.invalidHeaderEncoding
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw HTTPMessageCodecError.invalidRequestLine
        }
        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count >= 2 else {
            throw HTTPMessageCodecError.invalidRequestLine
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                headers[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        let bodyStart = headerRange.upperBound
        let body = Data(data[bodyStart...])
        return HTTPRequest(method: requestParts[0], path: requestParts[1], headers: headers, body: body)
    }

    public static func serialize(_ response: HTTPResponse) -> Data {
        var headers = response.headers.reduce(into: [String: String]()) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
        headers["content-length"] = "\(response.body.count)"
        headers["connection"] = headers["connection"] ?? "close"

        var wire = "HTTP/1.1 \(response.statusCode) \(response.reasonPhrase)\r\n"
        for key in headers.keys.sorted() {
            if let value = headers[key] {
                wire += "\(key): \(value)\r\n"
            }
        }
        wire += "\r\n"

        var data = Data(wire.utf8)
        data.append(response.body)
        return data
    }
}
