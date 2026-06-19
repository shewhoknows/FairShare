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
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

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
            LinearGradient(
                colors: [
                    liveOverrides.color("auth.screen.start", fallback: Color(red: 0.14, green: 0.19, blue: 0.88)),
                    liveOverrides.color("auth.screen.middle", fallback: Color(red: 0.11, green: 0.16, blue: 0.82)),
                    liveOverrides.color("auth.screen.end", fallback: Color(red: 0.04, green: 0.12, blue: 0.64))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: liveOverrides.number("auth.contentSpacing", fallback: 18)) {
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
                .padding(.horizontal, liveOverrides.number("auth.padding.horizontal", fallback: 20))
                .padding(.top, liveOverrides.number("auth.padding.top", fallback: 22))
                .padding(.bottom, liveOverrides.number("auth.padding.bottom", fallback: 32))
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
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

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
        VStack(spacing: liveOverrides.number("auth.start.spacing", fallback: 16)) {
            InkAuthHero(
                overrideID: "auth.start.hero",
                title: "BillBandit",
                subtitle: "SETTLE THE TAB",
                mascot: MascotWelcome(size: 272)
            )

            ReceiptCard(
                eyebrow: liveOverrides.text("auth.start.receipt.eyebrow", fallback: "Auth receipt"),
                title: liveOverrides.text("auth.start.receipt.title", fallback: "Start with your email or phone"),
                subtitle: liveOverrides.text("auth.start.receipt.subtitle", fallback: "We will send a one-time code for this account."),
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
                        accessibilityIdentifier: "inkAuth.identifier",
                        submitLabel: .continue,
                        onSubmit: {
                            if canContinue {
                                onContinue()
                            }
                        }
                    )

                    if let message {
                        InkAuthMessage(text: message)
                    }

                    InkAuthPillButton(
                        title: "Send code",
                        systemImage: "arrow.right",
                        isLoading: isSubmitting,
                        isDisabled: !canContinue,
                        overrideID: "auth.start.continueButton"
                    ) {
                        onContinue()
                    }
                    .accessibilityIdentifier("inkAuth.continue")

                    if liveOverrides.bool("auth.start.divider.hidden") == false {
                        InkAuthDividerLabel(text: liveOverrides.text("auth.start.divider.title", fallback: "or"))
                    }

                    if usesMockAppleButton {
                        Button {
                            onMockSignInWithApple?()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                Text(liveOverrides.text("auth.start.appleButton.title", fallback: "Sign in with Apple"))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(liveOverrides.color("auth.start.appleButton.foreground", fallback: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(liveOverrides.color("auth.start.appleButton.background", fallback: .black), in: Capsule())
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
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

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
        VStack(spacing: liveOverrides.number("auth.verify.spacing", fallback: 16)) {
            InkAuthHero(
                overrideID: "auth.verify.hero",
                title: "Check your code",
                subtitle: "OTP RECEIPT",
                mascot: MascotPeek(size: 152)
            )

            ReceiptCard(
                eyebrow: liveOverrides.text("auth.verify.receipt.eyebrow", fallback: "Verification"),
                title: liveOverrides.text("auth.verify.receipt.title", fallback: "Enter the 6 digit code"),
                subtitle: liveOverrides.text("auth.verify.receipt.subtitle", fallback: "Sent to \(identifier)"),
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
                        accessibilityIdentifier: "inkAuth.otp",
                        submitLabel: .go,
                        submitsFromKeyboardToolbar: true,
                        onSubmit: {
                            if canVerify {
                                onVerify()
                            }
                        }
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
                        isDisabled: !canVerify,
                        overrideID: "auth.verify.submitButton"
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
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let identifier: String?
    @Binding var draft: InkAuthProfileDraft
    var isSubmitting = false
    var message: String?
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: liveOverrides.number("auth.profile.spacing", fallback: 16)) {
            InkAuthHero(
                overrideID: "auth.profile.hero",
                title: "Finish your receipt",
                subtitle: "PROFILE STAMP",
                mascot: MascotThinking(size: 154)
            )

            ReceiptCard(
                eyebrow: liveOverrides.text("auth.profile.receipt.eyebrow", fallback: "Profile"),
                title: liveOverrides.text("auth.profile.receipt.title", fallback: "Complete your BillBandit profile"),
                subtitle: liveOverrides.text("auth.profile.receipt.subtitle", fallback: identifier.map { "Signing in as \($0)" } ?? ""),
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
                        accessibilityIdentifier: "inkAuth.upi",
                        submitLabel: .done,
                        onSubmit: {
                            if draft.isReady {
                                onComplete()
                            }
                        }
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
                            isDisabled: isSubmitting || !draft.isReady,
                            overrideID: "auth.profile.saveButton"
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
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

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

            Text(liveOverrides.text("auth.topBar.title", fallback: "AUTH").uppercased())
                .font(InkAuthPalette.labelFont)
                .tracking(liveOverrides.number("auth.topBar.tracking", fallback: 4.2))
                .foregroundStyle(liveOverrides.color("auth.topBar.color", fallback: InkAuthPalette.cream))

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .foregroundStyle(InkAuthPalette.cream)
    }
}

private struct InkAuthHero<Mascot: View>: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    var overrideID: String?
    let title: String
    let subtitle: String
    let mascot: Mascot

    var body: some View {
        VStack(spacing: liveOverrides.number("\(overrideID ?? "").spacing", fallback: 10)) {
            if liveOverrides.bool("\(overrideID ?? "").mascot.hidden") == false {
                mascot
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: liveOverrides.number("\(overrideID ?? "").titleSpacing", fallback: 5)) {
                if liveOverrides.bool("\(overrideID ?? "").subtitle.hidden") == false {
                    Text(liveOverrides.text("\(overrideID ?? "").subtitle", fallback: subtitle).uppercased())
                        .font(InkAuthPalette.labelFont)
                        .tracking(1.8)
                        .foregroundStyle(liveOverrides.color("\(overrideID ?? "").subtitleColor", fallback: InkAuthPalette.periwinkle))
                }

                let resolvedTitle = liveOverrides.text("\(overrideID ?? "").title", fallback: title)
                if !resolvedTitle.isEmpty, liveOverrides.bool("\(overrideID ?? "").title.hidden") == false {
                    Text(resolvedTitle)
                        .font(.system(size: liveOverrides.number("\(overrideID ?? "").titleFontSize", fallback: 34), weight: .semibold, design: .serif))
                        .foregroundStyle(liveOverrides.color("\(overrideID ?? "").titleColor", fallback: InkAuthPalette.cream))
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
    var submitLabel: SubmitLabel = .done
    var submitsFromKeyboardToolbar = false
    var onSubmit: () -> Void = {}

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
                    .submitLabel(submitLabel)
                    .onSubmit {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        onSubmit()
                    }
                    .accessibilityIdentifier(accessibilityIdentifier)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                if submitsFromKeyboardToolbar {
                                    onSubmit()
                                }
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
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let title: String
    var systemImage: String?
    var isLoading = false
    var isDisabled = false
    var overrideID: String?
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if liveOverrides.bool("\(overrideID ?? "").hidden") == false {
            Button(action: action) {
                HStack(spacing: 9) {
                    if isLoading {
                        ProgressView()
                            .tint(InkReceiptTheme.receiptCream)
                    } else if let systemImage {
                        Image(systemName: systemImage)
                            .imageScale(.medium)
                    }

                    Text(liveOverrides.text("\(overrideID ?? "").title", fallback: title))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.system(size: liveOverrides.number("\(overrideID ?? "").fontSize", fallback: 17), weight: .bold, design: .serif))
                .foregroundStyle(liveOverrides.color("\(overrideID ?? "").foreground", fallback: InkReceiptTheme.receiptCream))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, liveOverrides.number("\(overrideID ?? "").paddingVertical", fallback: 14))
                .background(liveOverrides.color("\(overrideID ?? "").background", fallback: InkReceiptTheme.structureInk), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || isLoading)
            .opacity(isDisabled ? 0.52 : 1)
            .accessibilityLabel(liveOverrides.text("\(overrideID ?? "").title", fallback: title))
        }
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
        .environmentObject(LiveDesignOverrides.disabled)
}

#Preview("Ink OTP") {
    InkAuthFlowView(step: .verify(identifier: "meera@billbandit.app"))
        .environmentObject(LiveDesignOverrides.disabled)
}

#Preview("Ink Profile") {
    InkAuthFlowView(
        step: .completeProfile(
            identifier: "meera@billbandit.app",
            draft: InkAuthProfileDraft(name: "Meera Kapoor", preferredName: "Meera", upiID: "meera@upi")
        )
    )
    .environmentObject(LiveDesignOverrides.disabled)
}
