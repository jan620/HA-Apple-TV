import Foundation

/// Every German label the app derives from a Home Assistant identifier.
///
/// These tables used to sit in five different files — entity states, HVAC
/// modes, weather conditions, alarm states and domain titles — which meant a
/// new translation had to be remembered in five places and could drift apart
/// unnoticed. Callers forward here.
enum GermanLabels {
    /// Entity states that show up on a dashboard often enough to be worth
    /// translating. Anything else is title-cased as-is.
    static func entityState(_ state: String) -> String {
        states[state] ?? state.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func climateMode(_ mode: String) -> String {
        climateModes[mode] ?? mode.capitalized
    }

    static func weatherCondition(_ condition: String) -> String {
        weatherConditions[condition] ?? condition.capitalized
    }

    static func weatherSymbol(_ condition: String) -> String {
        weatherSymbols[condition] ?? "cloud.fill"
    }

    /// `arm_home` → "Zuhause", for alarm panel buttons.
    static func alarmAction(_ action: String) -> String {
        alarmActions[action] ?? action.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func domainTitle(_ domain: String) -> String {
        domainTitles[domain] ?? domain.capitalized
    }

    // MARK: Tables

    private static let states: [String: String] = [
        "on": "An",
        "off": "Aus",
        "open": "Offen",
        "opening": "Öffnet",
        "closed": "Geschlossen",
        "closing": "Schließt",
        "home": "Zuhause",
        "not_home": "Abwesend",
        "unavailable": "Nicht verfügbar",
        "unknown": "Unbekannt",
        "locked": "Verriegelt",
        "unlocked": "Entriegelt",
        "locking": "Verriegelt …",
        "unlocking": "Entriegelt …",
        "jammed": "Blockiert",
        "playing": "Wiedergabe",
        "paused": "Pausiert",
        "buffering": "Puffert",
        "idle": "Bereit",
        "standby": "Standby",
        "heat": "Heizen",
        "cool": "Kühlen",
        "heat_cool": "Heizen/Kühlen",
        "auto": "Automatik",
        "dry": "Entfeuchten",
        "fan_only": "Nur Lüfter",
        "docked": "In Station",
        "cleaning": "Reinigt",
        "returning": "Kehrt zurück",
        "armed_home": "Aktiv (zuhause)",
        "armed_away": "Aktiv (abwesend)",
        "armed_night": "Aktiv (Nacht)",
        "disarmed": "Deaktiviert",
        "triggered": "Ausgelöst",
        "pending": "Verzögert",
        "arming": "Aktiviert …",
    ]

    private static let climateModes: [String: String] = [
        "off": "Aus",
        "heat": "Heizen",
        "cool": "Kühlen",
        "heat_cool": "Auto",
        "auto": "Automatik",
        "dry": "Entfeuchten",
        "fan_only": "Lüften",
    ]

    private static let weatherConditions: [String: String] = [
        "clear-night": "Klare Nacht",
        "cloudy": "Bewölkt",
        "fog": "Nebel",
        "hail": "Hagel",
        "lightning": "Gewitter",
        "lightning-rainy": "Gewitter",
        "partlycloudy": "Teilweise bewölkt",
        "pouring": "Starkregen",
        "rainy": "Regen",
        "snowy": "Schnee",
        "snowy-rainy": "Schneeregen",
        "sunny": "Sonnig",
        "windy": "Windig",
        "windy-variant": "Windig",
        "exceptional": "Unwetter",
    ]

    private static let weatherSymbols: [String: String] = [
        "clear-night": "moon.stars.fill",
        "cloudy": "cloud.fill",
        "fog": "cloud.fog.fill",
        "hail": "cloud.hail.fill",
        "lightning": "cloud.bolt.fill",
        "lightning-rainy": "cloud.bolt.rain.fill",
        "partlycloudy": "cloud.sun.fill",
        "pouring": "cloud.heavyrain.fill",
        "rainy": "cloud.rain.fill",
        "snowy": "cloud.snow.fill",
        "snowy-rainy": "cloud.sleet.fill",
        "sunny": "sun.max.fill",
        "windy": "wind",
        "windy-variant": "wind",
        "exceptional": "exclamationmark.triangle.fill",
    ]

    private static let alarmActions: [String: String] = [
        "arm_home": "Zuhause",
        "arm_away": "Abwesend",
        "arm_night": "Nacht",
        "arm_vacation": "Urlaub",
    ]

    private static let domainTitles: [String: String] = [
        "light": "Licht",
        "switch": "Schalter",
        "fan": "Lüfter",
        "cover": "Rollläden",
        "climate": "Klima",
        "water_heater": "Warmwasser",
        "humidifier": "Luftfeuchte",
        "media_player": "Medien",
        "lock": "Schlösser",
        "alarm_control_panel": "Alarm",
        "vacuum": "Staubsauger",
        "lawn_mower": "Rasenmäher",
        "scene": "Szenen",
        "script": "Skripte",
        "input_boolean": "Schalter (Helfer)",
        "button": "Taster",
        "input_button": "Taster",
        "valve": "Ventile",
        "siren": "Sirenen",
    ]
}
