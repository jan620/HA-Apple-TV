import SwiftUI

struct EntityIdentifier: Identifiable, Hashable {
    let id: String
}

/// The signed-in experience: a tab per Lovelace view, plus a settings tab that
/// doubles as the dashboard switcher.
struct DashboardScreen: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var lovelace: LovelaceService
    @EnvironmentObject private var coordinator: DashboardCoordinator

    @State private var dashboard: LovelaceDashboard = .overview
    @State private var selectedTab = Self.settingsTag

    private static let settingsTag = "__settings__"

    private var config: LovelaceConfig? {
        lovelace.configs[dashboard.id]
    }

    /// Subviews are reachable through navigation actions but are deliberately
    /// kept out of the tab bar, matching the web frontend.
    private var tabViews: [LovelaceViewConfig] {
        (config?.views ?? []).filter { !$0.isSubview }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabViews) { view in
                LovelaceViewRenderer(view: view)
                    .tabItem {
                        Label(
                            view.displayTitle,
                            systemImage: IconMapper.symbol(forMDI: view.icon, domain: nil)
                        )
                    }
                    .tag(view.id)
            }

            SettingsScreen(dashboard: $dashboard)
                .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
                .tag(Self.settingsTag)
        }
        .overlay(alignment: .top) { connectionBanner }
        .sheet(item: moreInfoBinding) { target in
            MoreInfoView(entityID: target.id)
        }
        .task(id: dashboard.id) {
            await lovelace.loadConfig(for: dashboard)
            applyPendingNavigation()
            // Anything still pending named a view this dashboard does not have.
            coordinator.requestedViewPath = nil
            selectFirstViewIfNeeded()
        }
        .onChange(of: coordinator.requestedDashboardPath) { path in
            guard let path else { return }
            coordinator.requestedDashboardPath = nil
            if let match = lovelace.dashboards.first(where: { $0.urlPath == path }) {
                // Switching dashboards re-runs the task above, which resolves
                // the view path once the new config has actually loaded.
                dashboard = match
            } else if path == "lovelace" {
                dashboard = .overview
            }
        }
        .onChange(of: coordinator.requestedViewPath) { _ in
            applyPendingNavigation()
        }
    }

    /// Consumes a pending view path only when the target view exists. A
    /// `navigate` action into another dashboard arrives long before that
    /// dashboard's config is loaded, so discarding it on the first miss would
    /// drop the navigation entirely.
    private func applyPendingNavigation() {
        guard let path = coordinator.requestedViewPath,
              let match = tabViews.first(where: { $0.path == path || $0.id == path })
        else { return }
        coordinator.requestedViewPath = nil
        selectedTab = match.id
    }

    private var moreInfoBinding: Binding<EntityIdentifier?> {
        Binding(
            get: { coordinator.moreInfoEntityID.map(EntityIdentifier.init) },
            set: { coordinator.moreInfoEntityID = $0?.id }
        )
    }

    private func selectFirstViewIfNeeded() {
        guard !tabViews.contains(where: { $0.id == selectedTab }) else { return }
        if let first = tabViews.first {
            selectedTab = first.id
        }
    }

    @ViewBuilder
    private var connectionBanner: some View {
        if case .disconnected(let message) = connection.connectionState {
            Label(
                message ?? "Verbindung unterbrochen – versuche erneut …",
                systemImage: "wifi.exclamationmark"
            )
            .font(.callout)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: Capsule())
            .padding(.top, 20)
        } else if connection.connectionState == .connecting {
            Label("Verbinde …", systemImage: "arrow.triangle.2.circlepath")
                .font(.callout)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 20)
        }
    }
}

struct SettingsScreen: View {
    @Binding var dashboard: LovelaceDashboard

    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var lovelace: LovelaceService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                header

                dashboardSection

                statusSection

                HStack(spacing: 20) {
                    Button("Dashboards neu laden") {
                        Task {
                            await lovelace.loadDashboards()
                            await lovelace.reloadConfig(for: dashboard)
                        }
                    }
                    Button("Abmelden", role: .destructive) {
                        Task {
                            connection.disconnect()
                            await auth.signOut()
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 50)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.config?.locationName ?? "Home Assistant")
                .font(.largeTitle.bold())
            if let server = auth.server {
                Text(server.baseURL.absoluteString)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dashboard")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(lovelace.dashboards) { entry in
                        Button {
                            dashboard = entry
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: IconMapper.symbol(forMDI: entry.icon, domain: nil))
                                Text(entry.title)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .foregroundStyle(entry.id == dashboard.id ? Theme.accent : .primary)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.vertical, 8)
            }

            if lovelace.configs[dashboard.id]?.isGenerated == true {
                Label(
                    """
                    Dieses Dashboard wird von Home Assistant per Strategie im Browser erzeugt. \
                    Da tvOS keine Web-Engine hat, zeigt die App stattdessen eine automatisch \
                    aus deinen Bereichen erzeugte Ansicht.
                    """,
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            statusRow("Verbindung", value: connectionText)
            statusRow("Home Assistant", value: connection.haVersion ?? store.config?.version ?? "—")
            statusRow("Entitäten", value: "\(store.entities.count)")
            statusRow("Bereiche", value: "\(store.areas.count)")

            if let error = store.lastServiceError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Theme.unavailable)
            }

            Text("Tipp: Mit der Play/Pause-Taste öffnest du auf jeder Kachel die Detailansicht.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.body)
        .frame(maxWidth: 700, alignment: .leading)
    }

    private var connectionText: String {
        switch connection.connectionState {
        case .idle: return "Getrennt"
        case .connecting: return "Verbinde …"
        case .connected: return "Verbunden"
        case .disconnected(let message): return message ?? "Unterbrochen"
        }
    }
}
