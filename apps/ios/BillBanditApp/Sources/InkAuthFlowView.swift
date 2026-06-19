import AuthenticationServices
import SwiftUI
import UIKit

enum InkAuthFlowStep: Equatable {
    case start
    case verify(identifier: String)
    case completeProfile(identifier: String?, draft: InkAuthProfileDraft)
}

struct InkAuthProfileDraft: Equatable {
    var name: String = ""
    var preferredName: String = ""
    var upiID: String = ""

    static let empty = InkAuthProfileDraft()

    var normalized: InkAuthProfileDraft {
        InkAuthProfileDraft(
            name: name.trimmedForAuth,
            preferredName: preferredName.trimmedForAuth,
            upiID: upiID.trimmedForAuth
        )
    }

    var isReady: Bool {
        !name.trimmedForAuth.isEmpty && !upiID.trimmedForAuth.isEmpty
    }
}

struct InkAuthFlowView: View {
    let step: InkAuthFlowStep
    var isSubmitting = false
    var message: String?
    var usesMockAppleButton = false
    var onSubmitIdentifier: (String) -> Void = { _ in }
    var onSignInWithAppleRequest: (ASAuthorizationAppleIDRequest) -> Void = { request in
        request.requestedScopes = [.fullName, .email]
    }
    var onSignInWithAppleCompletion: (Result<ASAuthorization, Error>) -> Void = { _ in }
    var onMockSignInWithApple: (() -> Void)?
    var onSubmitOTP: (String) -> Void = { _ in }
    var onResendOTP: ((String) -> Void)?
    var onCompleteProfile: (InkAuthProfileDraft) -> Void = { _ in }
    var onBack: (() -> Void)?

    @State private var identifier: String
    @State private var otpCode = ""
    @State private var profile: InkAuthProfileDraft

    init(
        step: InkAuthFlowStep = .start,
        isSubmitting: Bool = false,
        message: String? = nil,
        usesMockAppleButton: Bool = false,
        onSubmitIdentifier: @escaping (String) -> Void = { _ in },
        onSignInWithAppleRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void = { request in
            request.requestedScopes = [.fullName, .email]
        },
        onSignInWithAppleCompletion: @escaping (Result<ASAuthorization, Error>) -> Void = { _ in },
        onMockSignInWithApple: (() -> Void)? = nil,
        onSubmitOTP: @escaping (String) -> Void = { _ in },
        onResendOTP: ((String) -> Void)? = nil,
        onCompleteProfile: @escaping (InkAuthProfileDraft) -> Void = { _ in },
        onBack: (() -> Void)? = nil
    ) {
        self.step = step
        self.isSubmitting = isSubmitting
        self.message = message
        self.usesMockAppleButton = usesMockAppleButton
        self.onSubmitIdentifier = onSubmitIdentifier
        self.onSignInWithAppleRequest = onSignInWithAppleRequest
        self.onSignInWithAppleCompletion = onSignInWithAppleCompletion
        self.onMockSignInWithApple = onMockSignInWithApple
        self.onSubmitOTP = onSubmitOTP
        self.onResendOTP = onResendOTP
        self.onCompleteProfile = onCompleteProfile
        self.onBack = onBack

        let initialIdentifier: String
        let initialProfile: InkAuthProfileDraft
        switch step {
        case .start:
            initialIdentifier = ""
            initialProfile = .empty
        case .verify(let identifier):
            initialIdentifier = identifier
            initialProfile = .empty
        case .completeProfile(let identifier, let draft):
            initialIdentifier = identifier ?? ""
            initialProfile = draft
        }

        _identifier = State(initialValue: initialIdentifier)
        _profile = State(initialValue: initialProfile)
    }

    var body: some View {
        ZStack {
            InkAuthPalette.screen
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    InkAuthTopBar(canGoBack: onBack != nil, onBack: onBack)

                    switch step {
                    case .start:
                        InkAuthStartView(
                            identifier: $identifier,
                            isSubmitting: isSubmitting,
                            message: message,
                            onContinue: {
                                onSubmitIdentifier(identifier.trimmedForAuth)
                            },
                            usesMockAppleButton: usesMockAppleButton,
                            onSignInWithAppleRequest: onSignInWithAppleRequest,
                            onSignInWithAppleCompletion: onSignInWithAppleCompletion,
                            onMockSignInWithApple: onMockSignInWithApple
                        )
                    case .verify(let targetIdentifier):
                        InkOTPVerifyView(
                            identifier: targetIdentifier,
                            code: $otpCode,
                            isSubmitting: isSubmitting,
                            message: message,
                            onVerify: {
                                onSubmitOTP(otpCode.trimmedForAuth)
                            },
                            onResend: onResendOTP.map { callback in
                                { callback(targetIdentifier) }
                            }
                        )
                    case .completeProfile(let targetIdentifier, _):
                        InkProfileCompletionView(
                            identifier: targetIdentifier,
                            draft: $profile,
                            isSubmitting: isSubmitting,
                            message: message,
                            onComplete: {
                                onCompleteProfile(profile.normalized)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 32)
            }
        }
        .tint(InkAuthPalette.cream)
        .accessibilityIdentifier("inkAuth.screen")
        .onChange(of: step) { _, newStep in
            syncState(with: newStep)
        }
    }

    private func syncState(with step: InkAuthFlowStep) {
        switch step {
        case .start:
            otpCode = ""
        case .verify(let identifier):
            self.identifier = identifier
            otpCode = ""
        case .completeProfile(let identifier, let draft):
            self.identifier = identifier ?? self.identifier
            profile = draft
            otpCode = ""
        }
    }
}

struct InkAuthStartView: View {
    @Binding var identifier: String
    var isSubmitting = false
    var message: String?
    var onContinue: () -> Void
    var usesMockAppleButton: Bool
    var onSignInWithAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onSignInWithAppleCompletion: (Result<ASAuthorization, Error>) -> Void
    var onMockSignInWithApple: (() -> Void)?

    private var canContinue: Bool {
        !identifier.trimmedForAuth.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            InkAuthHero(
                title: "BillBandit",
                subtitle: "SETTLE THE TAB",
                mascot: MascotWelcome(size: 272)
            )

            ReceiptCard(
                eyebrow: "Auth receipt",
                title: "Start with your email or phone",
                subtitle: "We will send a one-time code for this account.",
                barcodeValue: "AUTH-START"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    InkAuthField(
                        title: "Email or phone",
                        placeholder: "meera@billbandit.app",
                        text: $identifier,
                        systemImage: "at",
                        keyboardType: .emailAddress,
                        textContentType: .username,
                        autocapitalization: .never,
                        accessibilityIdentifier: "inkAuth.identifier"
                    )

                    if let message {
                        InkAuthMessage(text: message)
                    }

                    InkAuthPillButton(
                        title: "Send code",
                        systemImage: "arrow.right",
                        isLoading: isSubmitting,
                        isDisabled: !canContinue
                    ) {
                        onContinue()
                    }
                    .accessibilityIdentifier("inkAuth.continue")

                    InkAuthDividerLabel(text: "or")

                    if usesMockAppleButton {
                        Button {
                            onMockSignInWithApple?()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                Text("Sign in with Apple")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("inkAuth.apple")
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.58 : 1)
                    } else {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: onSignInWithAppleRequest,
                            onCompletion: onSignInWithAppleCompletion
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("inkAuth.apple")
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.58 : 1)
                    }
                }
            }
        }
    }
}

struct InkOTPVerifyView: View {
    let identifier: String
    @Binding var code: String
    var isSubmitting = false
    var message: String?
    var onVerify: () -> Void
    var onResend: (() -> Void)?

    private var canVerify: Bool {
        code.trimmedForAuth.count == 6
    }

    var body: some View {
        VStack(spacing: 16) {
            InkAuthHero(
                title: "Check your code",
                subtitle: "OTP RECEIPT",
                mascot: MascotPeek(size: 152)
            )

            ReceiptCard(
                eyebrow: "Verification",
                title: "Enter the 6 digit code",
                subtitle: "Sent to \(identifier)",
                barcodeValue: "OTP-\(identifier)"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    InkAuthField(
                        title: "One-time code",
                        placeholder: "000000",
                        text: $code,
                        systemImage: "number",
                        keyboardType: .numberPad,
                        textContentType: .oneTimeCode,
                        autocapitalization: .never,
                        accessibilityIdentifier: "inkAuth.otp"
                    )
                    .onChange(of: code) { _, newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(6))
                        if filtered != newValue {
                            code = filtered
                        }
                    }

                    if let message {
                        InkAuthMessage(text: message)
                    }

                    InkAuthPillButton(
                        title: "Verify code",
                        systemImage: "checkmark",
                        isLoading: isSubmitting,
                        isDisabled: !canVerify
                    ) {
                        onVerify()
                    }
                    .accessibilityIdentifier("inkAuth.verify")

                    if let onResend {
                        Button(action: onResend) {
                            Text("Resend code")
                                .font(InkAuthPalette.labelFont)
                                .tracking(1.1)
                                .foregroundStyle(InkReceiptTheme.rupeeBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)
                        .accessibilityIdentifier("inkAuth.resend")
                    }
                }
            }
        }
    }
}

struct InkProfileCompletionView: View {
    let identifier: String?
    @Binding var draft: InkAuthProfileDraft
    var isSubmitting = false
    var message: String?
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            InkAuthHero(
                title: "Finish your receipt",
                subtitle: "PROFILE STAMP",
                mascot: MascotThinking(size: 154)
            )

            ReceiptCard(
                eyebrow: "Profile",
                title: "Complete your BillBandit profile",
                subtitle: identifier.map { "Signing in as \($0)" },
                barcodeValue: "PROFILE"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    InkAuthField(
                        title: "Name",
                        placeholder: "Meera Kapoor",
                        text: $draft.name,
                        systemImage: "person",
                        textContentType: .name,
                        accessibilityIdentifier: "inkAuth.name"
                    )

                    InkAuthField(
                        title: "Preferred name",
                        placeholder: "Meera",
                        text: $draft.preferredName,
                        systemImage: "person.text.rectangle",
                        textContentType: .nickname,
                        accessibilityIdentifier: "inkAuth.preferredName"
                    )

                    InkAuthField(
                        title: "UPI ID",
                        placeholder: "meera@upi",
                        text: $draft.upiID,
                        systemImage: "indianrupeesign.circle",
                        keyboardType: .emailAddress,
                        textContentType: .username,
                        autocapitalization: .never,
                        accessibilityIdentifier: "inkAuth.upi"
                    )

                    if let message {
                        InkAuthMessage(text: message)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        InkAuthSeal(text: "BILL\nBANDIT")

                        InkAuthPillButton(
                            title: "Save profile",
                            systemImage: "checkmark.seal",
                            isLoading: isSubmitting,
                            isDisabled: isSubmitting || !draft.isReady
                        ) {
                            onComplete()
                        }
                        .accessibilityIdentifier("inkAuth.completeProfile")
                    }
                }
            }
        }
    }
}

private struct InkAuthTopBar: View {
    let canGoBack: Bool
    let onBack: (() -> Void)?

    var body: some View {
        HStack {
            if canGoBack {
                Button {
                    onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(InkAuthPalette.cream.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("inkAuth.back")
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()

            Text("AUTH")
                .font(InkAuthPalette.labelFont)
                .tracking(4.2)
                .foregroundStyle(InkAuthPalette.cream)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .foregroundStyle(InkAuthPalette.cream)
    }
}

private struct InkAuthHero<Mascot: View>: View {
    let title: String
    let subtitle: String
    let mascot: Mascot

    var body: some View {
        VStack(spacing: 10) {
            mascot
                .frame(maxWidth: .infinity)

            VStack(spacing: 5) {
                Text(subtitle.uppercased())
                    .font(InkAuthPalette.labelFont)
                    .tracking(1.8)
                    .foregroundStyle(InkAuthPalette.periwinkle)

                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(InkAuthPalette.cream)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
            }
        }
    }
}

private struct InkAuthField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var systemImage: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .words
    var accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(InkAuthPalette.labelFont)
                .tracking(1.0)
                .foregroundStyle(InkReceiptTheme.structureInk)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(InkReceiptTheme.rupeeBlue)
                        .frame(width: 18)
                }

                TextField(placeholder, text: $text)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(InkReceiptTheme.structureInk)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityIdentifier(accessibilityIdentifier)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .accessibilityIdentifier("keyboard.done")
                        }
                    }
            }
            .padding(.vertical, 10)

            PerforationDivider(color: InkReceiptTheme.structureInk.opacity(0.30))
        }
    }
}

private struct InkAuthPillButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .tint(InkReceiptTheme.receiptCream)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(.system(size: 17, weight: .bold, design: .serif))
            .foregroundStyle(InkReceiptTheme.receiptCream)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(InkReceiptTheme.structureInk, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.52 : 1)
        .accessibilityLabel(title)
    }
}

private struct InkAuthDividerLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            PerforationDivider()
            Text(text.uppercased())
                .font(InkAuthPalette.labelFont)
                .foregroundStyle(InkReceiptTheme.fadedInk)
                .tracking(1.1)
            PerforationDivider()
        }
    }
}

private struct InkAuthMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(InkReceiptTheme.bodyFont)
            .foregroundStyle(InkReceiptTheme.dangerInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InkReceiptTheme.dangerInk.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(InkReceiptTheme.dangerInk.opacity(0.28), lineWidth: 1)
            }
            .accessibilityIdentifier("inkAuth.message")
    }
}

private struct InkAuthSeal: View {
    let text: String

    var body: some View {
        ZStack {
            Circle().stroke(InkReceiptTheme.rupeeBlue, lineWidth: 1.5)
            Circle().stroke(InkReceiptTheme.rupeeBlue.opacity(0.56), lineWidth: 1)
                .padding(5)
            Text(text)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .multilineTextAlignment(.center)
                .foregroundStyle(InkReceiptTheme.rupeeBlue)
                .padding(10)
        }
        .frame(width: 62, height: 62)
        .accessibilityHidden(true)
    }
}

private enum InkAuthPalette {
    static let cream = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let periwinkle = Color(red: 0.64, green: 0.68, blue: 0.94)

    static let screen = LinearGradient(
        colors: [
            Color(red: 0.14, green: 0.19, blue: 0.88),
            Color(red: 0.11, green: 0.16, blue: 0.82),
            Color(red: 0.04, green: 0.12, blue: 0.64)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let labelFont = Font.system(size: 11, weight: .heavy, design: .monospaced)
}

private extension String {
    var trimmedForAuth: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview("Ink Auth Start") {
    InkAuthFlowView(step: .start)
}

#Preview("Ink OTP") {
    InkAuthFlowView(step: .verify(identifier: "meera@billbandit.app"))
}

#Preview("Ink Profile") {
    InkAuthFlowView(
        step: .completeProfile(
            identifier: "meera@billbandit.app",
            draft: InkAuthProfileDraft(name: "Meera Kapoor", preferredName: "Meera", upiID: "meera@upi")
        )
    )
}
