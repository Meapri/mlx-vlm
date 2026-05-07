import Foundation

public struct HTTPRequest: Equatable, Sendable {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method.uppercased()
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public let statusCode: Int
    public let reasonPhrase: String
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, reasonPhrase: String? = nil, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.reasonPhrase = reasonPhrase ?? HTTPResponse.defaultReasonPhrase(for: statusCode)
        self.headers = headers
        self.body = body
    }

    public func headerValue(_ name: String) -> String? {
        headers.first { $0.key.lowercased() == name.lowercased() }?.value
    }

    public static func json<T: Encodable>(_ value: T, encoder: JSONEncoder, statusCode: Int = 200) throws -> HTTPResponse {
        try HTTPResponse(
            statusCode: statusCode,
            headers: ["content-type": "application/json"],
            body: encoder.encode(value)
        )
    }

    public static func text(_ value: String, statusCode: Int = 200, contentType: String = "text/plain; charset=utf-8") -> HTTPResponse {
        HTTPResponse(statusCode: statusCode, headers: ["content-type": contentType], body: Data(value.utf8))
    }

    public static func notFound() -> HTTPResponse {
        text("not found", statusCode: 404)
    }

    public static func badRequest(_ message: String) -> HTTPResponse {
        text(message, statusCode: 400)
    }

    public static func internalServerError(_ message: String) -> HTTPResponse {
        text(message, statusCode: 500)
    }

    private static func defaultReasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: "OK"
        case 400: "Bad Request"
        case 404: "Not Found"
        case 500: "Internal Server Error"
        default: "OK"
        }
    }
}
