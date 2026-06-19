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
    private(set) var otpChallenge: OTPChallengeResponse?
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
        let tokenStore: TokenStore = ProcessInfo.processInfo.arguments.contains("--volatile-auth-session")
            ? VolatileTokenStore()
            : KeychainTokenStore()
        let store = AuthStore(apiClient: client, tokenStore: tokenStore)
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

    @discardableResult
    func startOTP(identifier: String) async -> OTPChallengeResponse? {
        errorMessage = nil
        do {
            let body = OTPStartRequest(identifier: identifier)
            let response: OTPChallengeResponse = try await apiClient.post("/api/mobile/auth/otp/start", body: body)
            otpChallenge = response
            return response
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func verifyOTP(challengeID: String, code: String) async -> AuthResponse? {
        errorMessage = nil
        do {
            let body = OTPVerifyRequest(challengeID: challengeID, code: code)
            let response: AuthResponse = try await apiClient.post("/api/mobile/auth/otp/verify", body: body)
            try applyAuthResponse(response)
            otpChallenge = nil
            return response
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func signInWithApple(
        identityToken: String,
        authorizationCode: String? = nil,
        nonce: String? = nil,
        fullName: String? = nil,
        email: String? = nil
    ) async -> AuthResponse? {
        errorMessage = nil
        do {
            let body = AppleSignInRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce,
                fullName: fullName,
                email: email
            )
            let response: AuthResponse = try await apiClient.post("/api/mobile/auth/apple", body: body)
            try applyAuthResponse(response)
            return response
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func completeProfile(name: String, preferredName: String? = nil, upiID: String) async -> UserDTO? {
        errorMessage = nil
        do {
            let body = CompleteProfileRequest(name: name, preferredName: preferredName, upiID: upiID)
            let response: UserResponse = try await apiClient.put("/api/mobile/auth/profile", body: body)
            state = .signedIn(response.user)
            return response.user
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func logout() {
        tokenStore.clearToken()
        token = nil
        otpChallenge = nil
        onTokenChanged?(nil)
        state = .signedOut
    }

    private func authenticate(path: String, name: String?, email: String, password: String) async {
        errorMessage = nil
        do {
            let body = AuthRequest(name: name, email: email, password: password)
            let response: AuthResponse = try await apiClient.post(path, body: body)
            try applyAuthResponse(response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyAuthResponse(_ response: AuthResponse) throws {
        try tokenStore.saveToken(response.token)
        token = response.token
        onTokenChanged?(response.token)
        state = .signedIn(response.user)
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
