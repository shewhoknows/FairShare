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
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .register {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                }

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textContentType(mode == .login ? .password : .newPassword)

                if let message = authStore.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text(mode.rawValue)
                    }
                }
                .disabled(isSubmitting || email.isEmpty || password.isEmpty || (mode == .register && name.isEmpty))
            }
            .navigationTitle("FairShare")
        }
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

