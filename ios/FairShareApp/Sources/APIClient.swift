import Foundation

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
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        let encodedBody = try body.map { try JSONEncoder.fairShare.encode($0) }
        if baseURL.scheme == "mock" {
            let data = try await MockFairShareAPI.shared.requestData(
                path: url.path,
                method: method,
                body: encodedBody,
                hasToken: tokenProvider() != nil
            )
            return try JSONDecoder.fairShare.decode(Response.self, from: data)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let encodedBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = encodedBody
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(http.statusCode) {
            if let error = try? JSONDecoder.fairShare.decode(ErrorResponse.self, from: data) {
                throw APIError.server(error.error)
            }
            throw APIError.server("Request failed with status \(http.statusCode)")
        }
        return try JSONDecoder.fairShare.decode(Response.self, from: data)
    }
}

private struct ErrorResponse: Decodable {
    let error: String
}

extension JSONDecoder {
    static let fairShare: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()
}

extension JSONEncoder {
    static let fairShare: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()
}
