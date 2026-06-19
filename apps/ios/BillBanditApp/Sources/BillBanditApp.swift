import AuthenticationServices
import SwiftUI

@main
struct BillBanditApp: App {
    @State private var authStore = AuthStore.live()
    @AppStorage(PaisaAppearanceMode.storageKey) private var appearanceModeRaw = PaisaAppearanceMode.system.rawValue

    private var appearanceMode: PaisaAppearanceMode {
        PaisaAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}

struct RootView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        if AppLaunchOptions.current.usesPrototypeRoot {
            BillBanditInkPrototypeView()
                .statusBarHidden(true)
        } else {
            AuthenticatedBillBanditRootView(options: .current)
                .environment(authStore)
                .statusBarHidden(true)
        }
    }
}

private struct AuthenticatedBillBanditRootView: View {
    @Environment(AuthStore.self) private var authStore
    let options: AppLaunchOptions

    @State private var signedOutDestination: SignedOutDestination
    @State private var authStep = InkAuthFlowStep.start
    @State private var authMessage: String?
    @State private var isSubmitting = false
    @State private var didStartRestore = false

    init(options: AppLaunchOptions) {
        self.options = options
        _signedOutDestination = State(initialValue: options.startsAtAuth ? .auth : .welcome)
    }

    var body: some View {
        Group {
            switch authStore.state {
            case .restoring:
                InkAuthLoadingView()
            case .signedOut:
                signedOutView
            case .signedIn(let user):
                if user.isProfileComplete == true {
                    BillBanditInkPrototypeView(
                        initialScreen: .tripsEmpty,
                        apiClient: authStore.apiClient,
                        currentUser: user
                    )
                } else {
                    authFlow(profileUser: user)
                }
            }
        }
        .task {
            guard !didStartRestore else { return }
            didStartRestore = true
            if options.resetsAuthSession {
                authStore.logout()
            } else {
                await authStore.restoreSession()
            }
        }
    }

    @ViewBuilder
    private var signedOutView: some View {
        switch signedOutDestination {
        case .welcome:
            BillBanditInkPrototypeView(
                initialScreen: .welcome,
                onWelcomeLogin: {
                    authMessage = nil
                    authStep = .start
                    signedOutDestination = .auth
                },
                onWelcomeCreateAccount: {
                    authMessage = nil
                    authStep = .start
                    signedOutDestination = .auth
                }
            )
        case .auth:
            authFlow(profileUser: nil)
        }
    }

    private func authFlow(profileUser: UserDTO?) -> some View {
        let profileStep: InkAuthFlowStep = {
            guard let profileUser, profileUser.isProfileComplete != true else { return authStep }
            return .completeProfile(
                identifier: profileUser.email ?? profileUser.phone,
                draft: InkAuthProfileDraft(
                    name: profileUser.name ?? "",
                    preferredName: profileUser.preferredName ?? "",
                    upiID: profileUser.upiID ?? ""
                )
            )
        }()

        return InkAuthFlowView(
            step: profileStep,
            isSubmitting: isSubmitting,
            message: authMessage ?? authStore.errorMessage,
            usesMockAppleButton: options.appleAuthMode != .system,
            onSubmitIdentifier: { identifier in
                Task { await startOTP(identifier: identifier) }
            },
            onSignInWithAppleRequest: configureAppleRequest,
            onSignInWithAppleCompletion: handleAppleCompletion,
            onMockSignInWithApple: {
                Task { await handleMockAppleSignIn() }
            },
            onSubmitOTP: { code in
                Task { await verifyOTP(code: code) }
            },
            onResendOTP: { identifier in
                Task { await startOTP(identifier: identifier) }
            },
            onCompleteProfile: { draft in
                Task { await completeProfile(draft) }
            },
            onBack: {
                handleAuthBack()
            }
        )
    }

    private func startOTP(identifier: String) async {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            authMessage = "Enter an email address or phone number."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        authMessage = nil

        if await authStore.startOTP(identifier: normalized) != nil {
            authStep = .verify(identifier: normalized)
        }
        authMessage = authStore.errorMessage
    }

    private func verifyOTP(code: String) async {
        guard let challenge = authStore.otpChallenge else {
            authMessage = "Request a fresh code before verifying."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        authMessage = nil

        if let response = await authStore.verifyOTP(challengeID: challenge.challengeID, code: code),
           response.user.isProfileComplete != true {
            authStep = .completeProfile(
                identifier: response.user.email ?? response.user.phone,
                draft: InkAuthProfileDraft(
                    name: response.user.name ?? "",
                    preferredName: response.user.preferredName ?? "",
                    upiID: response.user.upiID ?? ""
                )
            )
        }
        authMessage = authStore.errorMessage
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        Task {
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let identityTokenData = credential.identityToken,
                      let identityToken = String(data: identityTokenData, encoding: .utf8)
                else {
                    authMessage = "Apple did not return an identity token."
                    return
                }
                let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                let fullName = credential.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
                await signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    fullName: fullName,
                    email: credential.email
                )
            case .failure(let error):
                authMessage = error.localizedDescription
            }
        }
    }

    private func handleMockAppleSignIn() async {
        switch options.appleAuthMode {
        case .system:
            return
        case .success:
            await signInWithApple(
                identityToken: "mock-apple-token",
                authorizationCode: "mock-auth-code",
                fullName: "Meera Kapoor",
                email: "meera.apple@example.com"
            )
        case .failure:
            authMessage = "Sign in with Apple could not be completed."
        }
    }

    private func signInWithApple(identityToken: String, authorizationCode: String?, fullName: String?, email: String?) async {
        isSubmitting = true
        defer { isSubmitting = false }
        authMessage = nil

        if let response = await authStore.signInWithApple(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: fullName,
            email: email
        ), response.user.isProfileComplete != true {
            authStep = .completeProfile(
                identifier: response.user.email ?? response.user.phone,
                draft: InkAuthProfileDraft(
                    name: response.user.name ?? "",
                    preferredName: response.user.preferredName ?? "",
                    upiID: response.user.upiID ?? ""
                )
            )
        }
        authMessage = authStore.errorMessage
    }

    private func completeProfile(_ draft: InkAuthProfileDraft) async {
        let normalizedDraft = draft.normalized
        guard normalizedDraft.isReady else {
            authMessage = "Add your name and UPI ID to continue."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        authMessage = nil

        _ = await authStore.completeProfile(
            name: normalizedDraft.name,
            preferredName: normalizedDraft.preferredName.isEmpty ? nil : normalizedDraft.preferredName,
            upiID: normalizedDraft.upiID
        )
        authMessage = authStore.errorMessage
    }

    private func handleAuthBack() {
        authMessage = nil
        switch authStep {
        case .start:
            signedOutDestination = .welcome
        case .verify:
            authStep = .start
        case .completeProfile:
            if case .signedOut = authStore.state {
                authStep = .start
            }
        }
    }
}

private struct InkAuthLoadingView: View {
    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.16, blue: 0.82).ignoresSafeArea()
            VStack(spacing: 18) {
                MascotStamp(size: 92)
                Text("CHECKING RECEIPTS")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color(red: 0.64, green: 0.68, blue: 0.94))
                ProgressView()
                    .tint(Color(red: 0.96, green: 0.94, blue: 0.88))
            }
        }
        .accessibilityIdentifier("auth.loading")
    }
}

private enum SignedOutDestination {
    case welcome
    case auth
}

private struct AppLaunchOptions: Equatable {
    enum AppleAuthMode: Equatable {
        case system
        case success
        case failure
    }

    let arguments: [String]

    static var current: AppLaunchOptions {
        AppLaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    }

    var usesPrototypeRoot: Bool {
        arguments.contains { $0.hasPrefix("--ink-screen=") } || arguments.contains("--root=prototype")
    }

    var startsAtAuth: Bool {
        arguments.contains("--root=auth")
    }

    var resetsAuthSession: Bool {
        arguments.contains("--reset-auth-session")
    }

    var appleAuthMode: AppleAuthMode {
        if arguments.contains("--apple-auth=success") { return .success }
        if arguments.contains("--apple-auth=failure") { return .failure }
        return .system
    }
}
