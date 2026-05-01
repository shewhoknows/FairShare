import Foundation
import Observation

@Observable
@MainActor
final class AuthStore {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(UserDTO)
    }

    private(set) var state: State = .restoring
    private(set) var token: String?
    var errorMessage: String?

    let apiClient: APIClient
    private let tokenStore: TokenStore

    init(apiClient: APIClient, tokenStore: TokenStore) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    static func live() -> AuthStore {
        let tokenBox = TokenBox()
        let baseURLString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let baseURL = URL(string: baseURLString ?? "http://localhost:3000")!
        let client = APIClient(baseURL: baseURL) { tokenBox.token }
        let store = AuthStore(apiClient: client, tokenStore: KeychainTokenStore())
        tokenBox.token = store.token
        store.onTokenChanged = { tokenBox.token = $0 }
        return store
    }

    private var onTokenChanged: ((String?) -> Void)?

    func restoreSession() async {
        guard case .restoring = state else { return }
        token = tokenStore.loadToken()
        onTokenChanged?(token)
        guard token != nil else {
            state = .signedOut
            return
        }

        do {
            let response: UserResponse = try await apiClient.get("/api/mobile/auth/me")
            state = .signedIn(response.user)
        } catch {
            tokenStore.clearToken()
            token = nil
            onTokenChanged?(nil)
            state = .signedOut
        }
    }

    func login(email: String, password: String) async {
        await authenticate(path: "/api/mobile/auth/login", name: nil, email: email, password: password)
    }

    func register(name: String, email: String, password: String) async {
        await authenticate(path: "/api/mobile/auth/register", name: name, email: email, password: password)
    }

    func logout() {
        tokenStore.clearToken()
        token = nil
        onTokenChanged?(nil)
        state = .signedOut
    }

    private func authenticate(path: String, name: String?, email: String, password: String) async {
        errorMessage = nil
        do {
            let body = AuthRequest(name: name, email: email, password: password)
            let response: AuthResponse = try await apiClient.post(path, body: body)
            try tokenStore.saveToken(response.token)
            token = response.token
            onTokenChanged?(response.token)
            state = .signedIn(response.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private final class TokenBox: @unchecked Sendable {
    var token: String?
}

private struct AuthRequest: Encodable {
    let name: String?
    let email: String
    let password: String
}

