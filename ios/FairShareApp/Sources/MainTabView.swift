import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "chart.pie") }

            NavigationStack {
                GroupsView()
            }
            .tabItem { Label("Groups", systemImage: "person.3") }

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        Form {
            if case .signedIn(let user) = authStore.state {
                Section("Signed in") {
                    Text(user.displayName)
                    if let email = user.email {
                        Text(email)
                    }
                }
            }

            Button("Log out", role: .destructive) {
                authStore.logout()
            }
        }
        .navigationTitle("Account")
    }
}

