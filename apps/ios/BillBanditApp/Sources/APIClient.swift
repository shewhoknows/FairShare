import Foundation
import OSLog

enum BillBanditLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.eshabhoon.fairshare"

    private static let authLogger = Logger(subsystem: subsystem, category: "auth")
    private static let apiLogger = Logger(subsystem: subsystem, category: "api")
    private static let ledgerLogger = Logger(subsystem: subsystem, category: "ledger")

    static func auth(_ message: String) {
        authLogger.info("\(message, privacy: .public)")
        debugMirror(category: "auth", message: message)
    }

    static func api(_ message: String) {
        apiLogger.info("\(message, privacy: .public)")
        debugMirror(category: "api", message: message)
    }

    static func ledger(_ message: String) {
        ledgerLogger.info("\(message, privacy: .public)")
        debugMirror(category: "ledger", message: message)
    }

    static func sanitizedPath(_ rawPath: String) -> String {
        let path = rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? rawPath
        let normalizedPath = path.isEmpty ? "/" : path
        let segments = normalizedPath.split(separator: "/").map { segment -> String in
            let value = String(segment)
            if value.contains("@") { return ":value" }
            if value.count >= 16 { return ":id" }
            if value.allSatisfy(\.isNumber), value.isEmpty == false { return ":id" }
            return value
        }
        return "/" + segments.joined(separator: "/")
    }

    static func sanitizedError(_ error: Error) -> String {
        switch error {
        case APIError.invalidURL:
            return "invalid_url"
        case APIError.invalidResponse:
            return "invalid_response"
        case APIError.unauthorized:
            return "unauthorized"
        case APIError.server:
            return "server_error"
        case let urlError as URLError:
            return "url_error_\(urlError.code.rawValue)"
        case let decodingError as DecodingError:
            return decodingError.logCode
        case let encodingError as EncodingError:
            return encodingError.logCode
        default:
            return String(describing: type(of: error))
        }
    }

    static func bool(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    static func redactedID(_ value: String?) -> String {
        guard let value, value.isEmpty == false else { return "none" }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash).prefix(8).description
    }

    private static func debugMirror(category: String, message: String) {
        #if DEBUG
        let line = "[BillBandit][\(category)] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
        #endif
    }
}

private extension DecodingError {
    var logCode: String {
        switch self {
        case .typeMismatch:
            return "decoding_type_mismatch"
        case .valueNotFound:
            return "decoding_value_not_found"
        case .keyNotFound:
            return "decoding_key_not_found"
        case .dataCorrupted:
            return "decoding_data_corrupted"
        @unknown default:
            return "decoding_unknown"
        }
    }
}

private extension EncodingError {
    var logCode: String {
        switch self {
        case .invalidValue:
            return "encoding_invalid_value"
        @unknown default:
            return "encoding_unknown"
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid API URL"
        case .invalidResponse: "Invalid server response"
        case .unauthorized: "Your session expired. Please sign in again."
        case .server(let message): message
        }
    }
}

struct EmptyBody: Encodable {}

final class APIClient: Sendable {
    let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    init(baseURL: URL, session: URLSession = .shared, tokenProvider: @escaping @Sendable () -> String?) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func get<Response: Decodable>(_ path: String) async throws -> Response {
        try await request(path, method: "GET", body: Optional<EmptyBody>.none)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        try await request(path, method: "POST", body: body)
    }

    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        try await request(path, method: "PUT", body: body)
    }

    func delete<Response: Decodable>(_ path: String) async throws -> Response {
        try await request(path, method: "DELETE", body: Optional<EmptyBody>.none)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        let sanitizedPath = BillBanditLog.sanitizedPath(path)
        let startedAt = Date()
        guard let url = URL(string: path, relativeTo: baseURL) else {
            BillBanditLog.api("event=api.request.failure method=\(method) path=\(sanitizedPath) error=invalid_url")
            throw APIError.invalidURL
        }

        let encodedBody: Data?
        do {
            encodedBody = try body.map { try JSONEncoder.billBandit.encode($0) }
        } catch {
            BillBanditLog.api("event=api.request.failure method=\(method) path=\(sanitizedPath) error=\(BillBanditLog.sanitizedError(error))")
            throw error
        }

        let hasToken = tokenProvider() != nil
        BillBanditLog.api(
            "event=api.request.start method=\(method) path=\(sanitizedPath) auth=\(BillBanditLog.bool(hasToken)) body_bytes=\(encodedBody?.count ?? 0)"
        )

        if baseURL.scheme == "mock" {
            do {
                let data = try await MockBillBanditAPI.shared.requestData(
                    path: url.path,
                    method: method,
                    body: encodedBody,
                    hasToken: hasToken
                )
                BillBanditLog.api(
                    "event=api.request.finish method=\(method) path=\(sanitizedPath) transport=mock status=200 duration_ms=\(durationMS(since: startedAt)) response_bytes=\(data.count)"
                )
                return try decode(Response.self, from: data, method: method, path: sanitizedPath, startedAt: startedAt)
            } catch {
                BillBanditLog.api(
                    "event=api.request.failure method=\(method) path=\(sanitizedPath) transport=mock duration_ms=\(durationMS(since: startedAt)) error=\(BillBanditLog.sanitizedError(error))"
                )
                throw error
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = hasToken ? tokenProvider() : nil {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let encodedBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = encodedBody
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            BillBanditLog.api(
                "event=api.request.failure method=\(method) path=\(sanitizedPath) duration_ms=\(durationMS(since: startedAt)) error=\(BillBanditLog.sanitizedError(error))"
            )
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            BillBanditLog.api(
                "event=api.request.failure method=\(method) path=\(sanitizedPath) duration_ms=\(durationMS(since: startedAt)) error=invalid_response"
            )
            throw APIError.invalidResponse
        }

        BillBanditLog.api(
            "event=api.request.finish method=\(method) path=\(sanitizedPath) status=\(http.statusCode) duration_ms=\(durationMS(since: startedAt)) response_bytes=\(data.count)"
        )

        if http.statusCode == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(http.statusCode) {
            if let error = try? JSONDecoder.billBandit.decode(ErrorResponse.self, from: data) {
                throw APIError.server(error.error)
            }
            throw APIError.server("Request failed with status \(http.statusCode)")
        }
        return try decode(Response.self, from: data, method: method, path: sanitizedPath, startedAt: startedAt)
    }

    private func decode<Response: Decodable>(
        _ responseType: Response.Type,
        from data: Data,
        method: String,
        path: String,
        startedAt: Date
    ) throws -> Response {
        do {
            return try JSONDecoder.billBandit.decode(Response.self, from: data)
        } catch {
            BillBanditLog.api(
                "event=api.decode.failure method=\(method) path=\(path) duration_ms=\(durationMS(since: startedAt)) error=\(BillBanditLog.sanitizedError(error))"
            )
            throw error
        }
    }

    private func durationMS(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
    }
}

private struct ErrorResponse: Decodable {
    let error: String
}

extension JSONDecoder {
    static let billBandit: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()
}

extension JSONEncoder {
    static let billBandit: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()
}
