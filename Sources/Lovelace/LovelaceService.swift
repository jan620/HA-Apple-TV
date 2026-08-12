import Combine
import Foundation
import OSLog

/// Loads the user's real Lovelace dashboards.
///
/// Home Assistant dashboards can be defined by a *strategy* — JavaScript that
/// runs in the frontend to build the config at display time. tvOS cannot
/// execute that, so whenever the server hands back a strategy dashboard (or no
/// config at all, which is what an untouched "Overview" does) the app builds an
/// equivalent view locally from the area registry.
@MainActor
final class LovelaceService: ObservableObject {
    @Published private(set) var dashboards: [LovelaceDashboard] = [.overview]
    @Published private(set) var configs: [String: LovelaceConfig] = [:]
    @Published private(set) var loadingDashboardID: String?
    @Published var errorMessage: String?

    private let client: HAWebSocketClient
    private let store: EntityStore
    private let logger = Logger(subsystem: "io.github.jan620.homedash", category: "lovelace")

    init(client: HAWebSocketClient, store: EntityStore) {
        self.client = client
        self.store = store
    }

    func reset() {
        configs.removeAll()
    }

    func loadDashboards() async {
        var result: [LovelaceDashboard] = [.overview]
        if let response = try? await client.send(["type": "lovelace/dashboards/list"]) {
            result += (response.arrayValue ?? []).compactMap(LovelaceDashboard.init(json:))
        }
        dashboards = result
    }

    @discardableResult
    func loadConfig(for dashboard: LovelaceDashboard, areaIDs: Set<String> = []) async -> LovelaceConfig {
        if let cached = configs[dashboard.id] { return cached }
        let config = await fetchConfig(for: dashboard, areaIDs: areaIDs)
        configs[dashboard.id] = config
        return config
    }

    func reloadConfig(for dashboard: LovelaceDashboard, areaIDs: Set<String> = []) async {
        configs[dashboard.id] = await fetchConfig(for: dashboard, areaIDs: areaIDs)
    }

    /// Re-fetches the dashboards already on screen. Called after a reconnect so
    /// edits made while the app was disconnected actually show up — the cache
    /// alone would keep serving the pre-outage config indefinitely.
    ///
    /// Entries are replaced in place rather than cleared first, so the UI never
    /// sees an empty config mid-refresh.
    func refreshLoadedConfigs() async {
        for id in Array(configs.keys) {
            guard let dashboard = dashboards.first(where: { $0.id == id }) else { continue }
            configs[id] = await fetchConfig(for: dashboard)
        }
    }

    private func fetchConfig(for dashboard: LovelaceDashboard, areaIDs: Set<String> = []) async -> LovelaceConfig {
        // The rooms entry has no server-side counterpart to fetch.
        guard !dashboard.isRooms else {
            return generatedConfig(title: dashboard.title, limitedTo: areaIDs)
        }

        loadingDashboardID = dashboard.id
        defer { loadingDashboardID = nil }

        var payload: [String: JSONValue] = ["type": "lovelace/config"]
        if let urlPath = dashboard.urlPath {
            payload["url_path"] = .string(urlPath)
        }

        var config: LovelaceConfig
        do {
            let response = try await client.send(payload)
            config = LovelaceConfig(json: response)
            if config.needsGeneratedFallback {
                logger.info("Dashboard \(dashboard.title, privacy: .public) ist strategiebasiert – erzeuge Ansicht lokal")
                config = generatedConfig(title: config.title ?? dashboard.title)
            }
        } catch let error as HAConnectionError where error.isConfigNotFound {
            // The default dashboard has no stored config until the user edits
            // it; Home Assistant generates it on the fly, and so do we.
            config = generatedConfig(title: dashboard.title)
        } catch {
            logger.error("lovelace/config fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            config = generatedConfig(title: dashboard.title)
        }

        return config
    }

    // MARK: Local dashboard generation

    /// Mirrors Home Assistant's "original states" strategy: one view per area,
    /// controls grouped by domain, sensors collected in a list.
    /// - Parameter areaIDs: restricts the result to these areas; empty means all.
    func generatedConfig(title: String, limitedTo areaIDs: Set<String> = []) -> LovelaceConfig {
        var views: [LovelaceViewConfig] = []

        for area in store.areas where areaIDs.isEmpty || areaIDs.contains(area.areaID) {
            let entities = store.primaryEntities(inArea: area.areaID)
            guard !entities.isEmpty else { continue }
            views.append(
                makeView(
                    id: "generated.area.\(area.areaID)",
                    title: area.name,
                    icon: area.icon,
                    entities: entities
                )
            )
        }

        // Only when showing everything: with an explicit area selection, a
        // catch-all view would smuggle back exactly what the user deselected.
        let unassigned = areaIDs.isEmpty ? store.primaryEntitiesWithoutArea : []
        if !unassigned.isEmpty {
            views.append(
                makeView(
                    id: "generated.area.none",
                    title: views.isEmpty ? "Zuhause" : "Weitere",
                    icon: "mdi:home",
                    entities: unassigned
                )
            )
        }

        if views.isEmpty, areaIDs.isEmpty {
            views.append(
                makeView(
                    id: "generated.all",
                    title: "Zuhause",
                    icon: "mdi:home",
                    entities: store.entities.values.sorted { $0.entityID < $1.entityID }
                )
            )
        }

        return LovelaceConfig(title: title, views: views, isGenerated: true)
    }

    private func makeView(id: String, title: String, icon: String?, entities: [HAEntity]) -> LovelaceViewConfig {
        var cards: [LovelaceCardConfig] = []
        var cardIndex = 0

        func appendCard(_ dictionary: [String: JSONValue]) {
            cards.append(LovelaceCardConfig(json: .object(dictionary), id: "\(id).card.\(cardIndex)"))
            cardIndex += 1
        }

        let grouped = Dictionary(grouping: entities, by: \.domain)

        // Cameras get the most screen real estate — this is a TV, after all.
        if let cameras = grouped["camera"], !cameras.isEmpty {
            for camera in cameras {
                appendCard([
                    "type": "picture-entity",
                    "entity": .string(camera.entityID),
                    "camera_image": .string(camera.entityID),
                ])
            }
        }

        for domain in Self.controlDomainOrder {
            guard let members = grouped[domain], !members.isEmpty else { continue }
            appendCard([
                "type": "heading",
                "heading": .string(Self.domainTitle(domain)),
                "heading_style": "subtitle",
            ])
            appendCard([
                "type": "grid",
                "columns": .number(2),
                "square": .bool(false),
                "cards": .array(members.map { entity in
                    .object([
                        "type": "tile",
                        "entity": .string(entity.entityID),
                    ])
                }),
            ])
        }

        let informational = Self.informationalDomainOrder
            .compactMap { grouped[$0] }
            .flatMap { $0 }
        if !informational.isEmpty {
            appendCard([
                "type": "entities",
                "title": "Status & Sensoren",
                "entities": .array(informational.map { .string($0.entityID) }),
            ])
        }

        let handled = Set(Self.controlDomainOrder + Self.informationalDomainOrder + ["camera"])
        let remaining = entities.filter { !handled.contains($0.domain) }
        if !remaining.isEmpty {
            appendCard([
                "type": "entities",
                "title": "Weitere",
                "entities": .array(remaining.map { .string($0.entityID) }),
            ])
        }

        return LovelaceViewConfig(
            id: id,
            title: title,
            path: id,
            icon: icon,
            type: "masonry",
            cards: cards
        )
    }

    private static let controlDomainOrder = [
        "light", "switch", "fan", "cover", "climate", "water_heater", "humidifier",
        "media_player", "lock", "alarm_control_panel", "vacuum", "lawn_mower",
        "scene", "script", "input_boolean", "button", "input_button", "valve", "siren",
    ]

    private static let informationalDomainOrder = [
        "sensor", "binary_sensor", "person", "device_tracker", "weather", "sun",
        "number", "input_number", "select", "input_select", "update", "todo", "calendar",
    ]

    private static func domainTitle(_ domain: String) -> String {
        GermanLabels.domainTitle(domain)
    }
}
