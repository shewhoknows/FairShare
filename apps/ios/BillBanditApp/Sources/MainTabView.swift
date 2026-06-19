import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "sparkles") }

            NavigationStack {
                GroupsView()
            }
            .tabItem { Label("Groups", systemImage: "person.3") }

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(PaisaTheme.plum)
    }
}

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore
    @AppStorage(PaisaAppearanceMode.storageKey) private var appearanceModeRaw = PaisaAppearanceMode.system.rawValue

    private var appearanceModeBinding: Binding<PaisaAppearanceMode> {
        Binding {
            PaisaAppearanceMode(rawValue: appearanceModeRaw) ?? .system
        } set: { newValue in
            appearanceModeRaw = newValue.rawValue
        }
    }

    var body: some View {
        PaisaScreen {
            if case .signedIn(let user) = authStore.state {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.45)) {
                    VStack(alignment: .leading, spacing: 14) {
                        PaisaSectionHeader("Account", subtitle: "Signed in", systemImage: "person.crop.circle.fill")

                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.displayName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(PaisaTheme.ink)
                            if let email = user.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 10) {
                            PaisaPill(title: "Secure session", tint: PaisaTheme.leaf)
                            PaisaPill(title: "PaisaVasool", tint: PaisaTheme.plum)
                        }
                    }
                }
            }

            PaisaPanel(tint: PaisaTheme.sky.opacity(0.45)) {
                VStack(alignment: .leading, spacing: 14) {
                    PaisaSectionHeader("Appearance", subtitle: "Display mode", systemImage: "circle.lefthalf.filled")

                    Picker("Appearance", selection: appearanceModeBinding) {
                        ForEach(PaisaAppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("account.appearance.picker")
                }
            }

            PaisaPanel(tint: PaisaTheme.blush.opacity(0.45)) {
                VStack(alignment: .leading, spacing: 14) {
                    PaisaSectionHeader("Session", subtitle: "Device access", systemImage: "rectangle.portrait.and.arrow.right")
                    PaisaSecondaryButton("Log out", systemImage: "power", tint: PaisaTheme.coral) {
                        authStore.logout()
                    }
                }
            }
        }
        .navigationTitle("Account")
        .accessibilityIdentifier("account.screen")
    }
}
