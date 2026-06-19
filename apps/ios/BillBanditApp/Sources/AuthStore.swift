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
        let usesVolatileSession = ProcessInfo.processInfo.arguments.contains("--volatile-auth-session")
        let tokenStore: TokenStore = usesVolatileSession
            ? VolatileTokenStore()
            : KeychainTokenStore()
        let store = AuthStore(apiClient: client, tokenStore: tokenStore)
        tokenBox.token = store.token
        store.onTokenChanged = { tokenBox.token = $0 }
        BillBanditLog.auth(
            "event=auth.store.configured api_host=\(baseURL.host ?? "unknown") volatile_session=\(BillBanditLog.bool(usesVolatileSession))"
        )
        return store
    }

    private var onTokenChanged: ((String?) -> Void)?

    func restoreSession() async {
        guard case .restoring = state else { return }
        token = tokenStore.loadToken()
        onTokenChanged?(token)
        BillBanditLog.auth("event=auth.restore.start token_present=\(BillBanditLog.bool(token != nil))")
        guard token != nil else {
            state = .signedOut
            BillBanditLog.auth("event=auth.restore.finish result=signed_out reason=no_token")
            return
        }

        do {
            let response: UserResponse = try await apiClient.get("/api/mobile/auth/me")
            state = .signedIn(response.user)
            BillBanditLog.auth(
                "event=auth.restore.finish result=signed_in profile_complete=\(BillBanditLog.bool(response.user.isProfileComplete == true))"
            )
        } catch {
            BillBanditLog.auth("event=auth.restore.finish result=signed_out error=\(BillBanditLog.sanitizedError(error))")
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
        BillBanditLog.auth("event=auth.otp.start.request")
        do {
            let body = OTPStartRequest(identifier: identifier)
            let response: OTPChallengeResponse = try await apiClient.post("/api/mobile/auth/otp/start", body: body)
            otpChallenge = response
            BillBanditLog.auth("event=auth.otp.start.result success=true")
            return response
        } catch {
            BillBanditLog.auth("event=auth.otp.start.result success=false error=\(BillBanditLog.sanitizedError(error))")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func verifyOTP(challengeID: String, code: String) async -> AuthResponse? {
        errorMessage = nil
        BillBanditLog.auth("event=auth.otp.verify.request")
        do {
            let body = OTPVerifyRequest(challengeID: challengeID, code: code)
            let response: AuthResponse = try await apiClient.post("/api/mobile/auth/otp/verify", body: body)
            try applyAuthResponse(response)
            otpChallenge = nil
            BillBanditLog.auth(
                "event=auth.otp.verify.result success=true profile_complete=\(BillBanditLog.bool(response.user.isProfileComplete == true))"
            )
            return response
        } catch {
            BillBanditLog.auth("event=auth.otp.verify.result success=false error=\(BillBanditLog.sanitizedError(error))")
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
        BillBanditLog.auth(
            "event=auth.apple.request token_present=\(BillBanditLog.bool(identityToken.isEmpty == false)) code_present=\(BillBanditLog.bool(authorizationCode?.isEmpty == false)) name_present=\(BillBanditLog.bool(fullName?.isEmpty == false)) email_present=\(BillBanditLog.bool(email?.isEmpty == false))"
        )
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
            BillBanditLog.auth(
                "event=auth.apple.result success=true profile_complete=\(BillBanditLog.bool(response.user.isProfileComplete == true))"
            )
            return response
        } catch {
            BillBanditLog.auth("event=auth.apple.result success=false error=\(BillBanditLog.sanitizedError(error))")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func completeProfile(name: String, preferredName: String? = nil, upiID: String) async -> UserDTO? {
        errorMessage = nil
        BillBanditLog.auth(
            "event=auth.profile.complete.request name_present=\(BillBanditLog.bool(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)) preferred_name_present=\(BillBanditLog.bool(preferredName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)) upi_present=\(BillBanditLog.bool(upiID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false))"
        )
        do {
            let body = CompleteProfileRequest(name: name, preferredName: preferredName, upiID: upiID)
            let response: UserResponse = try await apiClient.put("/api/mobile/auth/profile", body: body)
            state = .signedIn(response.user)
            BillBanditLog.auth(
                "event=auth.profile.complete.result success=true profile_complete=\(BillBanditLog.bool(response.user.isProfileComplete == true))"
            )
            return response.user
        } catch {
            BillBanditLog.auth("event=auth.profile.complete.result success=false error=\(BillBanditLog.sanitizedError(error))")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func logout() {
        BillBanditLog.auth("event=auth.logout token_present=\(BillBanditLog.bool(token != nil))")
        tokenStore.clearToken()
        token = nil
        otpChallenge = nil
        onTokenChanged?(nil)
        state = .signedOut
    }

    private func authenticate(path: String, name: String?, email: String, password: String) async {
        errorMessage = nil
        BillBanditLog.auth(
            "event=auth.password.request path=\(BillBanditLog.sanitizedPath(path)) name_present=\(BillBanditLog.bool(name?.isEmpty == false))"
        )
        do {
            let body = AuthRequest(name: name, email: email, password: password)
            let response: AuthResponse = try await apiClient.post(path, body: body)
            try applyAuthResponse(response)
            BillBanditLog.auth(
                "event=auth.password.result success=true path=\(BillBanditLog.sanitizedPath(path)) profile_complete=\(BillBanditLog.bool(response.user.isProfileComplete == true))"
            )
        } catch {
            BillBanditLog.auth(
                "event=auth.password.result success=false path=\(BillBanditLog.sanitizedPath(path)) error=\(BillBanditLog.sanitizedError(error))"
            )
            errorMessage = error.localizedDescription
        }
    }

    private func applyAuthResponse(_ response: AuthResponse) throws {
        try tokenStore.saveToken(response.token)
        token = response.token
        onTokenChanged?(response.token)
        state = .signedIn(response.user)
        BillBanditLog.auth(
            "event=auth.session.applied token_saved=true profile_complete=\(BillBanditLog.bool(response.user.isProfileComplete == true))"
        )
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
