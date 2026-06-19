import AuthenticationServices
import Combine
import SwiftUI

@main
struct BillBanditApp: App {
    @State private var authStore = AuthStore.live()
    @StateObject private var liveDesignOverrides = LiveDesignOverrides.cockpit()
    @AppStorage(PaisaAppearanceMode.storageKey) private var appearanceModeRaw = PaisaAppearanceMode.system.rawValue

    private var appearanceMode: PaisaAppearanceMode {
        PaisaAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environmentObject(liveDesignOverrides)
                .preferredColorScheme(appearanceMode.colorScheme)
                .task {
                    liveDesignOverrides.startPolling()
                }
        }
    }
}

struct LiveDesignOverrideValue: Codable, Equatable {
    var kind: String
    var value: String
}

private struct LiveDesignOverrideSnapshot: Decodable {
    var revision: Int
    var overrides: [String: LiveDesignOverrideValue]
}

@MainActor
final class LiveDesignOverrides: ObservableObject {
    @Published private(set) var revision = 0
    @Published private var overrides: [String: LiveDesignOverrideValue] = [:]

    static let disabled = LiveDesignOverrides(isEnabled: false)

    private let isEnabled: Bool
    private let endpoint: URL
    private var pollTask: Task<Void, Never>?

    init(isEnabled: Bool, endpoint: URL = URL(string: "http://127.0.0.1:8787/api/ios/live-overrides")!) {
        self.isEnabled = isEnabled
        self.endpoint = endpoint
    }

    static func cockpit() -> LiveDesignOverrides {
        #if DEBUG
        LiveDesignOverrides(isEnabled: true)
        #else
        LiveDesignOverrides(isEnabled: false)
        #endif
    }

    func startPolling() {
        guard isEnabled, pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshOnce()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func text(_ key: String, fallback: String) -> String {
        guard let override = overrides[key], override.kind == "text", override.value.isEmpty == false else {
            return fallback
        }
        return override.value
    }

    func color(_ key: String, fallback: Color) -> Color {
        guard let override = overrides[key], override.kind == "color", let color = Self.color(from: override.value) else {
            return fallback
        }
        return color
    }

    func number(_ key: String, fallback: CGFloat) -> CGFloat {
        guard let override = overrides[key], override.kind == "number", let value = Double(override.value) else {
            return fallback
        }
        return CGFloat(value)
    }

    func bool(_ key: String, fallback: Bool = false) -> Bool {
        guard let override = overrides[key], override.kind == "bool" else {
            return fallback
        }
        switch override.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "on":
            return true
        case "false", "0", "no", "off":
            return false
        default:
            return fallback
        }
    }

    private func refreshOnce() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let snapshot = try JSONDecoder().decode(LiveDesignOverrideSnapshot.self, from: data)
            guard snapshot.revision != revision else { return }
            revision = snapshot.revision
            overrides = snapshot.overrides
        } catch {
            return
        }
    }

    private static func color(from rawValue: String) -> Color? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "black": return .black
        case "white": return .white
        case "clear", "transparent": return .clear
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        default: break
        }

        let hex = normalized.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else {
            return nil
        }
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        if hex.count == 8 {
            alpha = Double((value >> 24) & 0xff) / 255.0
            red = Double((value >> 16) & 0xff) / 255.0
            green = Double((value >> 8) & 0xff) / 255.0
            blue = Double(value & 0xff) / 255.0
        } else {
            alpha = 1
            red = Double((value >> 16) & 0xff) / 255.0
            green = Double((value >> 8) & 0xff) / 255.0
            blue = Double(value & 0xff) / 255.0
        }
        return Color(red: red, green: green, blue: blue, opacity: alpha)
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
    @State private var authStep: InkAuthFlowStep
    @State private var authMessage: String?
    @State private var isSubmitting = false
    @State private var didStartRestore = false

    init(options: AppLaunchOptions) {
        self.options = options
        _signedOutDestination = State(initialValue: options.startsAtAuth ? .auth : .welcome)
        _authStep = State(initialValue: options.authInitialStep)
    }

    var body: some View {
        Group {
            if options.forcesAuthLoading {
                InkAuthLoadingView()
            } else {
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
        arguments.contains("--root=auth") || arguments.contains { $0.hasPrefix("--ink-auth-step=") }
    }

    var forcesAuthLoading: Bool {
        arguments.contains("--root=auth-loading")
    }

    var authInitialStep: InkAuthFlowStep {
        guard let rawValue = arguments.first(where: { $0.hasPrefix("--ink-auth-step=") })?
            .dropFirst("--ink-auth-step=".count)
        else {
            return .start
        }

        let identifier = "meera.docs@example.com"
        switch String(rawValue) {
        case "verify":
            return .verify(identifier: identifier)
        case "profile":
            return .completeProfile(
                identifier: identifier,
                draft: InkAuthProfileDraft(
                    name: "Meera Kapoor",
                    preferredName: "Meera",
                    upiID: ""
                )
            )
        default:
            return .start
        }
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
