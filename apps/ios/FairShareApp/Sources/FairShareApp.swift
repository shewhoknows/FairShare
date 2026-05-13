import SwiftUI

@main
struct FairShareApp: App {
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
        Group {
            switch authStore.state {
            case .restoring:
                ZStack {
                    PaisaBackground()

                    PaisaPanel(tint: PaisaTheme.sky.opacity(0.45)) {
                        VStack(alignment: .leading, spacing: 14) {
                            PaisaIconBadge(systemImage: "indianrupeesign.circle.fill", tint: PaisaTheme.plum)
                            Text("PaisaVasool")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(PaisaTheme.ink)
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Restoring your session")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                }
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
