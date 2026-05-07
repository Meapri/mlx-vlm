import XCTest
import Foundation
@testable import MLXVLMServer

final class HTTPMessageCodecTests: XCTestCase {
    func testParsesSimplePostRequestWithBody() throws {
        let raw = """
        POST /api/generate HTTP/1.1\r
        Host: 127.0.0.1:11434\r
        Content-Type: application/json\r
        Content-Length: 15\r
        \r
        {"prompt":"hi"}
        """.replacingOccurrences(of: "\n        ", with: "")

        let request = try HTTPMessageCodec.parseRequest(Data(raw.utf8))

        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/generate")
        XCTAssertEqual(request.headers["host"], "127.0.0.1:11434")
        XCTAssertEqual(String(decoding: request.body, as: UTF8.self), "{\"prompt\":\"hi\"}")
    }

    func testSerializesHTTPResponseWithContentLength() {
        let response = HTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: Data("{}".utf8))

        let wire = String(decoding: HTTPMessageCodec.serialize(response), as: UTF8.self)

        XCTAssertTrue(wire.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(wire.contains("content-type: application/json\r\n"))
        XCTAssertTrue(wire.contains("content-length: 2\r\n"))
        XCTAssertTrue(wire.hasSuffix("\r\n\r\n{}"))
    }

    func testRejectsIncompleteRequest() {
        XCTAssertThrowsError(try HTTPMessageCodec.parseRequest(Data("GET / HTTP/1.1\r\n".utf8)))
    }
}
