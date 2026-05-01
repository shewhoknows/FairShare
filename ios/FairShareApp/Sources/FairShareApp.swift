import SwiftUI

@main
struct FairShareApp: App {
    @State private var authStore = AuthStore.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
        }
    }
}

struct RootView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        Group {
            switch authStore.state {
            case .restoring:
                ProgressView("Loading FairShare")
            case .signedOut:
                AuthView()
            case .signedIn:
                MainTabView()
            }
        }
        .task {
            await authStore.restoreSession()
        }
    }
}

