import SwiftUI

@main
struct HomeAssistantTVApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.auth)
                .environmentObject(container.connection)
                .environmentObject(container.store)
                .environmentObject(container.lovelace)
                .environmentObject(container.coordinator)
                .environmentObject(container.preferences)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        content
            .task(id: auth.state) {
                container.syncConnection(for: auth.state)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch auth.state {
        case .unconfigured:
            ServerSetupView()
        case .needsLogin:
            LoginFlowView()
        case .authenticated:
            if !store.isPrimed {
                ConnectingView()
            } else if !preferences.hasCompletedOnboarding {
                // Runs once after the first login, and again whenever the user
                // asks to reconfigure from the settings tab.
                OnboardingView()
            } else {
                DashboardScreen()
            }
        }
    }
}

struct ConnectingView: View {
    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var store: EntityStore

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "house.fill")
                .font(.system(size: 90))
                .foregroundStyle(Theme.accent)

            Text(auth.server?.name ?? "Home Assistant")
                .font(.largeTitle.bold())

            Text(statusText)
                .font(.title3)
                .foregroundStyle(.secondary)

            ProgressView()

            if case .disconnected = connection.connectionState {
                Button("Abmelden", role: .destructive) {
                    Task {
                        connection.disconnect()
                        await auth.signOut()
                    }
                }
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusText: String {
        switch connection.connectionState {
        case .idle, .connecting:
            return "Verbinde mit Home Assistant …"
        case .connected:
            // Priming runs in two visible stages; on a large instance the
            // registry step takes long enough to be worth naming.
            return store.hasLoadedStates
                ? "Lade Bereiche und Dashboards …"
                : "Lade Entitäten …"
        case .disconnected(let message):
            return message ?? "Verbindung unterbrochen – neuer Versuch läuft."
        }
    }
}
