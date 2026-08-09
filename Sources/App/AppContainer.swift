import Combine
import Foundation

/// Wires the object graph together and keeps the connection lifecycle in one
/// place. Everything downstream reads these through `@EnvironmentObject`.
@MainActor
final class AppContainer: ObservableObject {
    let auth: AuthManager
    let connection: HAWebSocketClient
    let store: EntityStore
    let lovelace: LovelaceService
    let coordinator: DashboardCoordinator
    let preferences: AppPreferences

    init() {
        let auth = AuthManager()
        let connection = HAWebSocketClient(auth: auth)
        let store = EntityStore(client: connection)

        self.auth = auth
        self.connection = connection
        self.store = store
        self.lovelace = LovelaceService(client: connection, store: store)
        self.coordinator = DashboardCoordinator()
        self.preferences = AppPreferences()

        connection.onConnected = { [weak self] in
            guard let self else { return }
            await self.store.prime()
            await self.lovelace.loadDashboards()
            // No-op on the first connect; after a reconnect it picks up
            // dashboard edits made while the app was offline.
            await self.lovelace.refreshLoadedConfigs()
        }
    }

    /// Called when the authentication state changes.
    func syncConnection(for state: AuthManager.State) {
        switch state {
        case .authenticated:
            connection.connect()
        case .needsLogin:
            connection.disconnect()
            store.clear()
            lovelace.reset()
        case .unconfigured:
            // A different server means different dashboards and areas, so the
            // onboarding choices no longer apply. A plain sign-out keeps them.
            connection.disconnect()
            store.clear()
            lovelace.reset()
            preferences.reset()
        }
    }
}
