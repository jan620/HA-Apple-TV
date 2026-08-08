import Foundation

/// Registry payloads carry a lot of fields that change between Home Assistant
/// releases, so each model decodes leniently from `JSONValue` and requires only
/// the handful of keys this app actually depends on.

struct HAArea: Identifiable, Hashable {
    let areaID: String
    let name: String
    let icon: String?
    let floorID: String?

    var id: String { areaID }

    init?(json: JSONValue) {
        guard let areaID = json["area_id"]?.stringValue else { return nil }
        self.areaID = areaID
        self.name = json["name"]?.stringValue ?? areaID
        self.icon = json["icon"]?.stringValue
        self.floorID = json["floor_id"]?.stringValue
    }
}

struct HAFloor: Identifiable, Hashable {
    let floorID: String
    let name: String
    let icon: String?
    let level: Int?

    var id: String { floorID }

    init?(json: JSONValue) {
        guard let floorID = json["floor_id"]?.stringValue else { return nil }
        self.floorID = floorID
        self.name = json["name"]?.stringValue ?? floorID
        self.icon = json["icon"]?.stringValue
        self.level = json["level"]?.intValue
    }
}

struct HADevice: Identifiable, Hashable {
    let id: String
    let name: String?
    let nameByUser: String?
    let areaID: String?

    var displayName: String? { nameByUser ?? name }

    init?(json: JSONValue) {
        guard let id = json["id"]?.stringValue else { return nil }
        self.id = id
        self.name = json["name"]?.stringValue
        self.nameByUser = json["name_by_user"]?.stringValue
        self.areaID = json["area_id"]?.stringValue
    }
}

struct HARegistryEntry: Identifiable, Hashable {
    let entityID: String
    let deviceID: String?
    let areaID: String?
    let name: String?
    let entityCategory: String?
    let isHidden: Bool
    let isDisabled: Bool

    var id: String { entityID }

    /// Config and diagnostic entities clutter a TV dashboard, and Home
    /// Assistant hides them from its own auto-generated views too.
    var isPrimary: Bool {
        !isHidden && !isDisabled && entityCategory == nil
    }

    init?(json: JSONValue) {
        guard let entityID = json["entity_id"]?.stringValue else { return nil }
        self.entityID = entityID
        self.deviceID = json["device_id"]?.stringValue
        self.areaID = json["area_id"]?.stringValue
        self.name = json["name"]?.stringValue ?? json["original_name"]?.stringValue
        self.entityCategory = json["entity_category"]?.stringValue
        self.isHidden = !(json["hidden_by"]?.isNull ?? true)
        self.isDisabled = !(json["disabled_by"]?.isNull ?? true)
    }
}

struct HAConfig: Hashable {
    let locationName: String
    let version: String?
    let temperatureUnit: String
    let currency: String?
    let language: String?

    init(json: JSONValue) {
        locationName = json["location_name"]?.stringValue ?? "Home Assistant"
        version = json["version"]?.stringValue
        temperatureUnit = json["unit_system"]?["temperature"]?.stringValue ?? "°C"
        currency = json["currency"]?.stringValue
        language = json["language"]?.stringValue
    }
}
