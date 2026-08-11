import Foundation

/// A single Home Assistant entity state.
struct HAEntity: Identifiable, Hashable {
    let entityID: String
    var state: String
    var attributes: [String: JSONValue]
    var lastChanged: Date?
    var lastUpdated: Date?

    var id: String { entityID }

    init(
        entityID: String,
        state: String,
        attributes: [String: JSONValue] = [:],
        lastChanged: Date? = nil,
        lastUpdated: Date? = nil
    ) {
        self.entityID = entityID
        self.state = state
        self.attributes = attributes
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
    }

    init?(json: JSONValue) {
        guard let entityID = json["entity_id"]?.stringValue,
              let state = json["state"]?.stringValue
        else { return nil }
        self.entityID = entityID
        self.state = state
        self.attributes = json["attributes"]?.objectValue ?? [:]
        self.lastChanged = HADate.parse(json["last_changed"]?.stringValue)
        self.lastUpdated = HADate.parse(json["last_updated"]?.stringValue)
    }
}

// MARK: - Identity

extension HAEntity {
    var domain: String {
        guard let dot = entityID.firstIndex(of: ".") else { return entityID }
        return String(entityID[entityID.startIndex..<dot])
    }

    var objectID: String {
        guard let dot = entityID.firstIndex(of: ".") else { return entityID }
        return String(entityID[entityID.index(after: dot)...])
    }

    var friendlyName: String {
        attributes["friendly_name"]?.stringValue ?? objectID.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var icon: String? { attributes["icon"]?.stringValue }
    var deviceClass: String? { attributes["device_class"]?.stringValue }
    var unitOfMeasurement: String? { attributes["unit_of_measurement"]?.stringValue }
    var entityPicture: String? { attributes["entity_picture"]?.stringValue }
    var supportedFeatures: Int { attributes["supported_features"]?.intValue ?? 0 }

    func supports(_ feature: Int) -> Bool { supportedFeatures & feature != 0 }

    var symbolName: String {
        if let icon, icon.hasPrefix("mdi:") {
            return IconMapper.symbol(forMDI: icon, domain: domain, state: state)
        }
        if let bySpecificClass = IconMapper.symbol(forDeviceClass: deviceClass, domain: domain, state: state) {
            return bySpecificClass
        }
        return IconMapper.defaultSymbol(domain: domain, state: state)
    }
}

// MARK: - State semantics

extension HAEntity {
    var isUnavailable: Bool {
        state == "unavailable" || state == "unknown"
    }

    /// Whether the entity should be rendered in the "on" accent colour.
    var isActive: Bool {
        guard !isUnavailable else { return false }
        switch domain {
        case "climate", "water_heater", "humidifier":
            return state != "off"
        case "media_player":
            return !["off", "idle", "standby"].contains(state)
        case "cover", "valve":
            return state != "closed"
        case "lock":
            return state == "unlocked"
        case "alarm_control_panel":
            return state != "disarmed"
        case "vacuum", "lawn_mower":
            return !["docked", "off", "idle", "error"].contains(state)
        case "person", "device_tracker":
            return state == "home"
        case "sensor", "number", "input_number", "select", "input_select",
             "text", "input_text", "date", "time", "datetime", "weather",
             "sun", "update", "button", "input_button", "event", "image":
            return false
        default:
            return state == "on" || state == "open" || state == "home" || state == "active"
        }
    }

    /// Domains where a single click should flip the state rather than open the
    /// detail view.
    var isToggleable: Bool {
        guard !isUnavailable else { return false }
        switch domain {
        case "light", "switch", "input_boolean", "fan", "siren", "automation", "humidifier":
            return true
        case "media_player":
            return supports(MediaPlayerFeature.turnOn) || supports(MediaPlayerFeature.turnOff)
        default:
            return false
        }
    }

    /// Domains whose click action is "run this now".
    var isActivatable: Bool {
        ["scene", "script", "button", "input_button"].contains(domain)
    }

    /// Human readable state, localised for the values that appear on a
    /// dashboard often enough to matter.
    var displayState: String {
        if let unit = unitOfMeasurement, let value = Double(state) {
            return "\(HANumber.format(value)) \(unit)"
        }
        return GermanLabels.entityState(state)
    }
}

// MARK: - Domain feature bitmasks

enum LightFeature {
    static let effect = 4
    static let flash = 8
    static let transition = 32
}

enum CoverFeature {
    static let open = 1
    static let close = 2
    static let setPosition = 4
    static let stop = 8
    static let openTilt = 16
    static let closeTilt = 32
    static let stopTilt = 64
    static let setTiltPosition = 128
}

enum ClimateFeature {
    static let targetTemperature = 1
    static let targetTemperatureRange = 2
    static let targetHumidity = 4
    static let fanMode = 8
    static let presetMode = 16
    static let swingMode = 32
    static let auxHeat = 64
    static let turnOff = 128
    static let turnOn = 256
}

enum MediaPlayerFeature {
    static let pause = 1
    static let seek = 2
    static let volumeSet = 4
    static let volumeMute = 8
    static let previousTrack = 16
    static let nextTrack = 32
    static let turnOn = 128
    static let turnOff = 256
    static let playMedia = 512
    static let volumeStep = 1024
    static let selectSource = 2048
    static let stop = 4096
    static let play = 16384
    static let shuffle = 32768
    static let selectSoundMode = 65536
    static let repeatSet = 262144
}

enum FanFeature {
    static let setSpeed = 1
    static let oscillate = 2
    static let direction = 4
    static let presetMode = 8
}

enum VacuumFeature {
    static let pause = 4
    static let stop = 8
    static let returnHome = 16
    static let fanSpeed = 32
    static let start = 8192
}

// MARK: - Helpers

enum HANumber {
    static func format(_ value: Double, maximumFractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value == value.rounded() ? 0 : maximumFractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

enum HADate {
    /// Home Assistant emits ISO-8601 with six fractional digits, which
    /// `ISO8601DateFormatter` has historically been inconsistent about, so the
    /// fraction is normalised before parsing.
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }

        if let date = withFraction.date(from: string) ?? withoutFraction.date(from: string) {
            return date
        }

        guard let dot = string.firstIndex(of: "."),
              let fractionEnd = string[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" })
        else { return nil }

        let trimmed = string[string.startIndex..<dot] + string[fractionEnd...]
        return withoutFraction.date(from: String(trimmed))
    }

    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
