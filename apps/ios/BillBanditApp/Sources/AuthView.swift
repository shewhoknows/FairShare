import SwiftUI

struct AuthView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    enum Mode: String, CaseIterable, Identifiable {
        case login = "Sign in"
        case register = "Create account"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            PaisaScreen {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.5)) {
                    VStack(alignment: .leading, spacing: 14) {
                        PaisaIconBadge(systemImage: "indianrupeesign.circle.fill", tint: PaisaTheme.plum)
                        Text("PaisaVasool")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(PaisaTheme.ink)
                        Text(mode == .login ? "Welcome back" : "Create your account")
                            .font(.headline.weight(.semibold))
                        Text(mode == .login ? "Pick up where you left off." : "Settle in with a fresh profile.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                PaisaPanel(tint: PaisaTheme.mint.opacity(0.42)) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if mode == .register {
                            PaisaFieldLabel("Name") {
                                TextField("Name", text: $name)
                                    .textContentType(.name)
                                    .paisaTextField()
                                    .accessibilityIdentifier("auth.name")
                            }
                        }

                        PaisaFieldLabel("Email") {
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .paisaTextField()
                                .accessibilityIdentifier("auth.email")
                        }

                        PaisaFieldLabel("Password") {
                            SecureField("Password", text: $password)
                                .textContentType(mode == .login ? .password : .newPassword)
                                .paisaTextField()
                                .accessibilityIdentifier("auth.password")
                        }

                        if let message = authStore.errorMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(PaisaTheme.coral)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PaisaTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        PaisaPrimaryButton(
                            mode.rawValue,
                            systemImage: mode == .login ? "arrow.right.circle.fill" : "sparkles",
                            isLoading: isSubmitting,
                            isDisabled: isSubmitting || email.isEmpty || password.isEmpty || (mode == .register && name.isEmpty)
                        ) {
                            Task { await submit() }
                        }
                        .accessibilityIdentifier("auth.submit")
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .accessibilityIdentifier("auth.screen")
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        switch mode {
        case .login:
            await authStore.login(email: email, password: password)
        case .register:
            await authStore.register(name: name, email: email, password: password)
        }
    }
}
