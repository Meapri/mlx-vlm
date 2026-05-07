import Foundation
import Network

public final class OllamaNetworkServer: @unchecked Sendable {
    private let host: String
    private let port: Int
    private let router: OllamaHTTPRouter
    private let queue: DispatchQueue
    private var listener: NWListener?

    public init(
        host: String = ServerShell.defaultHost,
        port: Int = ServerShell.defaultPort,
        router: OllamaHTTPRouter,
        queue: DispatchQueue = DispatchQueue(label: "mlx-vlm-swift.http")
    ) {
        self.host = host
        self.port = port
        self.router = router
        self.queue = queue
    }

    public func start() throws {
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
        let listener = try NWListener(using: .tcp, on: nwPort)
        self.listener = listener

        listener.newConnectionHandler = { [router, queue] connection in
            connection.start(queue: queue)
            Self.receive(on: connection, router: router)
        }
        listener.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    public func runForever() throws -> Never {
        try start()
        dispatchMain()
    }

    private static func receive(on connection: NWConnection, router: OllamaHTTPRouter) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024 * 1024) { data, _, _, error in
            Task {
                let response: HTTPResponse
                if let error {
                    response = HTTPResponse.internalServerError(error.localizedDescription)
                } else if let data, !data.isEmpty {
                    do {
                        let request = try HTTPMessageCodec.parseRequest(data)
                        if Self.mayStream(request) {
                            let headers = HTTPMessageCodec.serializeHeaders(
                                statusCode: 200,
                                reasonPhrase: "OK",
                                headers: ["content-type": "application/x-ndjson"]
                            )
                            try await Self.send(headers, on: connection)
                        }
                        if try await router.stream(request, send: { chunk in
                            try await Self.send(chunk, on: connection)
                        }) {
                            connection.cancel()
                            return
                        }
                        response = try await router.handle(request)
                    } catch let decodingError as DecodingError {
                        response = HTTPResponse.badRequest(String(describing: decodingError))
                    } catch let codecError as HTTPMessageCodecError {
                        response = HTTPResponse.badRequest(codecError.localizedDescription)
                    } catch {
                        response = HTTPResponse.internalServerError(error.localizedDescription)
                    }
                } else {
                    response = HTTPResponse.badRequest("empty request")
                }

                let wire = HTTPMessageCodec.serialize(response)
                connection.send(content: wire, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private static func mayStream(_ request: HTTPRequest) -> Bool {
        guard request.method == "POST", request.path == "/api/generate" || request.path == "/api/chat" else {
            return false
        }
        guard let body = String(data: request.body, encoding: .utf8) else {
            return false
        }
        return body.contains("\"stream\":true") || body.contains("\"stream\": true")
    }

    private static func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
