import SwiftUI

private struct PrimaryBlueButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Ink.serif(18, weight: .semibold))
                .foregroundStyle(Ink.Blue.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Ink.Blue.cobalt, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Ink.Blue.cream.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct WelcomeInkScreen: View {
    let onLogin: () -> Void
    let onCreateAccount: () -> Void

    var body: some View {
        InkAppShell(title: "", contentSpacing: 14, showsTopBar: false) {
            Spacer(minLength: 30)

            Text("BillBandit")
                .font(Ink.serif(72, weight: .semibold))
                .foregroundStyle(Ink.Blue.cobalt)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .background(Ink.Blue.cream, in: Capsule())
                .padding(.horizontal, 12)
                .accessibilityAddTraits(.isHeader)

            MascotWelcome(size: 244)
                .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                SerifTitle(text: "The trip ends", size: 38)
                Text("The tab settles itself")
                    .font(Ink.serif(34).italic())
                    .foregroundStyle(Ink.Blue.cream)
                    .multilineTextAlignment(.center)
            }
            .multilineTextAlignment(.center)

            HStack {
                Rectangle().fill(Ink.Blue.cream.opacity(0.7)).frame(height: 1)
                Text("✦").foregroundStyle(Ink.Blue.cream)
                Rectangle().fill(Ink.Blue.cream.opacity(0.7)).frame(height: 1)
            }
            .frame(width: 240)
            .padding(.vertical, 2)

            VStack(spacing: 12) {
                PrimaryBlueButton(title: "Get Started", action: onCreateAccount)
                    .accessibilityIdentifier("welcome.getStarted")
                    .accessibilityHint("Starts account creation so you can begin using BillBandit.")

                Button("Login", action: onLogin)
                    .font(Ink.serif(17, weight: .semibold))
                    .foregroundStyle(Ink.Blue.cream)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("welcome.login")
            }
            .padding(.top, 18)
        }
    }
}
