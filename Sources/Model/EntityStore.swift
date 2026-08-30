import Combine
import Foundation
import OSLog

/// The app's view of Home Assistant: every entity state plus enough of the
/// registries to group entities by area.
@MainActor
final class EntityStore: ObservableObject {
    @Published private(set) var entities: [String: HAEntity] = [:]
    @Published private(set) var areas: [HAArea] = []
    @Published private(set) var floors: [HAFloor] = []
    @Published private(set) var devices: [String: HADevice] = [:]
    @Published private(set) var registry: [String: HARegistryEntry] = [:]
    @Published private(set) var config: HAConfig?
    /// Registry access and admin-only dashboards depend on this.
    @Published private(set) var isAdmin = false
    @Published private(set) var currentUserName: String?
    @Published private(set) var hasLoadedStates = false
    /// True once states *and* registries are in place — dashboard generation
    /// depends on the area registry, so it must not run before this flips.
    @Published private(set) var isPrimed = false
    @Published var lastServiceError: String?

    private let client: HAWebSocketClient
    private let logger = Logger(subsystem: "io.roomglance.tvos", category: "store")
    private var stateSubscription: Int?

    init(client: HAWebSocketClient) {
        self.client = client
    }

    // MARK: Loading

    /// Fetches everything from scratch and (re)subscribes to state changes.
    /// Safe to call again after a reconnect.
    func prime() async {
        stateSubscription = nil

        if let response = try? await client.send(["type": "get_config"]) {
            config = HAConfig(json: response)
        }

        if let response = try? await client.send(["type": "auth/current_user"]) {
            isAdmin = response["is_admin"]?.boolValue ?? false
            currentUserName = response["name"]?.stringValue
        }

        do {
            let response = try await client.send(["type": "get_states"])
            var next: [String: HAEntity] = [:]
            for value in response.arrayValue ?? [] {
                guard let entity = HAEntity(json: value) else { continue }
                next[entity.entityID] = entity
            }
            entities = next
            hasLoadedStates = true
        } catch {
            logger.error("get_states fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }

        await loadRegistries()

        do {
            stateSubscription = try await client.subscribe([
                "type": "subscribe_events",
                "event_type": "state_changed",
            ]) { [weak self] event in
                self?.applyStateChanged(event)
            }
        } catch {
            logger.error("subscribe_events fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }

        isPrimed = true
    }

    /// Clears everything on sign-out so the next account never sees stale data.
    func clear() {
        entities.removeAll()
        areas.removeAll()
        floors.removeAll()
        devices.removeAll()
        registry.removeAll()
        config = nil
        isAdmin = false
        currentUserName = nil
        lastServiceError = nil
        hasLoadedStates = false
        isPrimed = false
        stateSubscription = nil
    }

    /// Registry access requires an admin account. A non-admin user still gets a
    /// fully working app — just without area grouping — so failures here are
    /// logged and ignored.
    private func loadRegistries() async {
        if let response = try? await client.send(["type": "config/area_registry/list"]) {
            areas = (response.arrayValue ?? [])
                .compactMap(HAArea.init(json:))
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        if let response = try? await client.send(["type": "config/floor_registry/list"]) {
            floors = (response.arrayValue ?? [])
                .compactMap(HAFloor.init(json:))
                .sorted { ($0.level ?? 0, $0.name) < ($1.level ?? 0, $1.name) }
        }

        if let response = try? await client.send(["type": "config/device_registry/list"]) {
            var next: [String: HADevice] = [:]
            for value in response.arrayValue ?? [] {
                guard let device = HADevice(json: value) else { continue }
                next[device.id] = device
            }
            devices = next
        }

        if let response = try? await client.send(["type": "config/entity_registry/list"]) {
            var next: [String: HARegistryEntry] = [:]
            for value in response.arrayValue ?? [] {
                guard let entry = HARegistryEntry(json: value) else { continue }
                next[entry.entityID] = entry
            }
            registry = next
        }
    }

    private func applyStateChanged(_ event: JSONValue) {
        guard let data = event["data"],
              let entityID = data["entity_id"]?.stringValue
        else { return }

        if let newState = data["new_state"], !newState.isNull, let entity = HAEntity(json: newState) {
            entities[entityID] = entity
        } else {
            entities.removeValue(forKey: entityID)
        }
    }

    // MARK: Lookup

    func entity(_ entityID: String) -> HAEntity? {
        entities[entityID]
    }

    func displayName(for entityID: String) -> String {
        if let name = registry[entityID]?.name, !name.isEmpty { return name }
        return entities[entityID]?.friendlyName ?? entityID
    }

    /// An entity's area comes from its own registry entry, falling back to the
    /// area of the device it belongs to.
    func areaID(for entityID: String) -> String? {
        if let direct = registry[entityID]?.areaID { return direct }
        guard let deviceID = registry[entityID]?.deviceID else { return nil }
        return devices[deviceID]?.areaID
    }

    func area(_ areaID: String?) -> HAArea? {
        guard let areaID else { return nil }
        return areas.first { $0.areaID == areaID }
    }

    func areaName(for entityID: String) -> String? {
        area(areaID(for: entityID))?.name
    }

    /// Entities that belong in a user-facing dashboard for the given area.
    func primaryEntities(inArea areaID: String) -> [HAEntity] {
        entities.values
            .filter { entity in
                guard self.areaID(for: entity.entityID) == areaID else { return false }
                guard let entry = registry[entity.entityID] else { return true }
                return entry.isPrimary
            }
            .sorted(by: Self.sortByName)
    }

    var primaryEntitiesWithoutArea: [HAEntity] {
        entities.values
            .filter { entity in
                guard areaID(for: entity.entityID) == nil else { return false }
                guard let entry = registry[entity.entityID] else { return true }
                return entry.isPrimary
            }
            .sorted(by: Self.sortByName)
    }

    private static func sortByName(_ lhs: HAEntity, _ rhs: HAEntity) -> Bool {
        if lhs.domain != rhs.domain { return lhs.domain < rhs.domain }
        return lhs.friendlyName.localizedCaseInsensitiveCompare(rhs.friendlyName) == .orderedAscending
    }

    // MARK: Services

    func callService(
        domain: String,
        service: String,
        entityIDs: [String] = [],
        data: [String: JSONValue] = [:]
    ) async {
        var payload: [String: JSONValue] = [
            "type": "call_service",
            "domain": .string(domain),
            "service": .string(service),
        ]
        if !data.isEmpty {
            payload["service_data"] = .object(data)
        }
        if !entityIDs.isEmpty {
            payload["target"] = .object(["entity_id": .strings(entityIDs)])
        }

        do {
            _ = try await client.send(payload)
            // Without this the settings screen keeps showing a single old
            // failure forever, long after everything works again.
            lastServiceError = nil
        } catch {
            logger.error("\(domain, privacy: .public).\(service, privacy: .public) fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            lastServiceError = error.localizedDescription
        }
    }

    func callService(domain: String, service: String, entity: HAEntity, data: [String: JSONValue] = [:]) async {
        await callService(domain: domain, service: service, entityIDs: [entity.entityID], data: data)
    }

    /// The action a single click performs on an entity, mirroring what Home
    /// Assistant's own tile card does.
    func performPrimaryAction(on entity: HAEntity) async {
        switch entity.domain {
        case "light", "switch", "input_boolean", "fan", "siren", "humidifier", "automation", "media_player", "cover", "valve":
            await callService(domain: entity.domain, service: "toggle", entity: entity)
        case "scene":
            await callService(domain: "scene", service: "turn_on", entity: entity)
        case "script":
            await callService(domain: "script", service: "toggle", entity: entity)
        case "button", "input_button":
            await callService(domain: entity.domain, service: "press", entity: entity)
        case "lock":
            await callService(
                domain: "lock",
                service: entity.state == "locked" ? "unlock" : "lock",
                entity: entity
            )
        case "vacuum":
            await callService(
                domain: "vacuum",
                service: entity.isActive ? "return_to_base" : "start",
                entity: entity
            )
        default:
            break
        }
    }
}
