import Foundation

/// Home Assistant icons are Material Design Icons (`mdi:lightbulb`). Shipping
/// the MDI font would be the faithful option, but SF Symbols render correctly
/// against tvOS focus effects and dynamic type for free, so the icons that
/// actually show up in a dashboard are mapped over and everything else falls
/// back to a per-domain default.
enum IconMapper {
    static func symbol(forMDI icon: String?, domain: String? = nil, state: String? = nil) -> String {
        if let icon, icon.hasPrefix("mdi:") {
            let name = String(icon.dropFirst(4))
            if let mapped = table[name] { return mapped }
            // Many MDI names are `<base>-outline` / `-off` variants of one we know.
            for suffix in ["-outline", "-off", "-on", "-variant"] where name.hasSuffix(suffix) {
                let base = String(name.dropLast(suffix.count))
                if let mapped = table[base] { return mapped }
            }
        }
        return defaultSymbol(domain: domain, state: state)
    }

    static func defaultSymbol(domain: String?, state: String? = nil) -> String {
        switch domain ?? "" {
        case "light": return "lightbulb.fill"
        case "switch": return "switch.2"
        case "input_boolean": return "switch.2"
        case "fan": return "fanblades.fill"
        case "climate", "thermostat": return "thermometer.medium"
        case "water_heater": return "spigot.fill"
        case "humidifier": return "humidity.fill"
        case "cover": return "blinds.horizontal.closed"
        case "lock": return state == "unlocked" ? "lock.open.fill" : "lock.fill"
        case "media_player": return "play.tv.fill"
        case "camera": return "video.fill"
        case "scene": return "wand.and.stars"
        case "script": return "scroll.fill"
        case "automation": return "gearshape.2.fill"
        case "button", "input_button": return "hand.tap.fill"
        case "vacuum": return "hurricane"
        case "person", "device_tracker": return "person.fill"
        case "sun": return "sun.max.fill"
        case "weather": return "cloud.sun.fill"
        case "binary_sensor": return "dot.radiowaves.left.and.right"
        case "sensor": return "gauge.medium"
        case "number", "input_number": return "slider.horizontal.3"
        case "select", "input_select": return "list.bullet"
        case "text", "input_text": return "textformat"
        case "todo": return "checklist"
        case "calendar": return "calendar"
        case "alarm_control_panel": return "shield.fill"
        case "update": return "arrow.down.circle.fill"
        case "zone": return "mappin.and.ellipse"
        case "siren": return "speaker.wave.3.fill"
        case "valve": return "drop.fill"
        case "lawn_mower": return "leaf.fill"
        case "remote": return "av.remote.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    /// Icons chosen from a sensor's `device_class` when the entity has no
    /// explicit icon — this is what makes a temperature sensor look like a
    /// thermometer rather than a generic gauge.
    static func symbol(forDeviceClass deviceClass: String?, domain: String?, state: String?) -> String? {
        guard let deviceClass else { return nil }
        switch deviceClass {
        case "temperature": return "thermometer.medium"
        case "humidity", "moisture": return "humidity.fill"
        case "pressure", "atmospheric_pressure": return "barometer"
        case "battery": return "battery.100"
        case "power", "current", "energy", "voltage": return "bolt.fill"
        case "illuminance": return "sun.max.fill"
        case "motion", "occupancy", "presence": return "figure.walk.motion"
        case "door", "garage_door": return state == "on" ? "door.left.hand.open" : "door.left.hand.closed"
        case "window": return "window.vertical.open"
        case "opening": return "rectangle.portrait.and.arrow.right"
        case "smoke": return "smoke.fill"
        case "gas", "carbon_monoxide": return "aqi.medium"
        case "problem", "safety": return "exclamationmark.triangle.fill"
        case "connectivity": return "wifi"
        case "lock": return state == "on" ? "lock.open.fill" : "lock.fill"
        case "running": return "play.circle.fill"
        case "sound": return "waveform"
        case "water": return "drop.fill"
        case "timestamp": return "clock.fill"
        case "shutter", "blind", "curtain", "awning", "shade": return "blinds.horizontal.closed"
        case "signal_strength": return "antenna.radiowaves.left.and.right"
        case "wind_speed": return "wind"
        case "speed": return "speedometer"
        case "duration": return "timer"
        case "data_size", "data_rate": return "internaldrive.fill"
        default: return nil
        }
    }

    private static let table: [String: String] = [
        "lightbulb": "lightbulb.fill",
        "lightbulb-group": "lightbulb.2.fill",
        "ceiling-light": "light.recessed",
        "floor-lamp": "lamp.floor.fill",
        "desk-lamp": "lamp.desk.fill",
        "led-strip": "light.strip.2",
        "track-light": "light.panel",
        "lamp": "lamp.table.fill",
        "power-plug": "powerplug.fill",
        "power-socket": "powerplug.fill",
        "toggle-switch": "switch.2",
        "light-switch": "switch.2",
        "flash": "bolt.fill",
        "lightning-bolt": "bolt.fill",
        "power": "power",
        "fan": "fanblades.fill",
        "air-conditioner": "air.conditioner.horizontal.fill",
        "air-filter": "air.purifier.fill",
        "air-purifier": "air.purifier.fill",
        "fire": "flame.fill",
        "radiator": "heater.vertical.fill",
        "thermometer": "thermometer.medium",
        "thermostat": "thermometer.medium",
        "snowflake": "snowflake",
        "water-percent": "humidity.fill",
        "water": "drop.fill",
        "water-boiler": "spigot.fill",
        "weather-sunny": "sun.max.fill",
        "weather-night": "moon.stars.fill",
        "weather-cloudy": "cloud.fill",
        "weather-partly-cloudy": "cloud.sun.fill",
        "weather-rainy": "cloud.rain.fill",
        "weather-pouring": "cloud.heavyrain.fill",
        "weather-snowy": "cloud.snow.fill",
        "weather-fog": "cloud.fog.fill",
        "weather-lightning": "cloud.bolt.fill",
        "weather-windy": "wind",
        "white-balance-sunny": "sun.max.fill",
        "window-shutter": "blinds.horizontal.closed",
        "window-shutter-open": "blinds.horizontal.open",
        "window-closed": "window.vertical.closed",
        "window-open": "window.vertical.open",
        "garage": "door.garage.closed",
        "garage-open": "door.garage.open",
        "door": "door.left.hand.closed",
        "door-open": "door.left.hand.open",
        "door-closed": "door.left.hand.closed",
        "gate": "door.sliding.left.hand.closed",
        "blinds": "blinds.horizontal.closed",
        "curtains": "curtains.closed",
        "roller-shade": "window.shade.closed",
        "lock": "lock.fill",
        "lock-open": "lock.open.fill",
        "shield-home": "shield.fill",
        "shield-lock": "lock.shield.fill",
        "home": "house.fill",
        "home-assistant": "house.fill",
        "sofa": "sofa.fill",
        "bed": "bed.double.fill",
        "silverware-fork-knife": "fork.knife",
        "countertop": "sink.fill",
        "shower": "shower.fill",
        "toilet": "toilet.fill",
        "stairs": "figure.stairs",
        "car": "car.fill",
        "ev-station": "bolt.car.fill",
        "washing-machine": "washer.fill",
        "dishwasher": "dishwasher.fill",
        "fridge": "refrigerator.fill",
        "stove": "oven.fill",
        "microwave": "microwave.fill",
        "robot-vacuum": "hurricane",
        "television": "tv.fill",
        "television-classic": "tv.fill",
        "speaker": "hifispeaker.fill",
        "speaker-multiple": "hifispeaker.2.fill",
        "cast": "airplayaudio",
        "cast-connected": "airplayvideo",
        "music": "music.note",
        "play": "play.fill",
        "pause": "pause.fill",
        "stop": "stop.fill",
        "volume-high": "speaker.wave.3.fill",
        "volume-off": "speaker.slash.fill",
        "cctv": "video.fill",
        "camera": "camera.fill",
        "video": "video.fill",
        "doorbell": "bell.fill",
        "doorbell-video": "bell.badge.fill",
        "bell": "bell.fill",
        "bell-ring": "bell.badge.fill",
        "motion-sensor": "figure.walk.motion",
        "walk": "figure.walk",
        "run": "figure.run",
        "account": "person.fill",
        "account-group": "person.3.fill",
        "map-marker": "mappin.circle.fill",
        "map-marker-radius": "mappin.and.ellipse",
        "battery": "battery.100",
        "battery-charging": "battery.100.bolt",
        "battery-low": "battery.25",
        "wifi": "wifi",
        "wifi-off": "wifi.slash",
        "server": "server.rack",
        "server-network": "network",
        "router-wireless": "wifi.router.fill",
        "nas": "externaldrive.fill",
        "harddisk": "internaldrive.fill",
        "memory": "memorychip.fill",
        "cpu-64-bit": "cpu.fill",
        "chart-line": "chart.xyaxis.line",
        "chart-bar": "chart.bar.fill",
        "gauge": "gauge.medium",
        "counter": "number",
        "clock": "clock.fill",
        "clock-outline": "clock",
        "calendar": "calendar",
        "calendar-clock": "calendar.badge.clock",
        "timer": "timer",
        "alarm": "alarm.fill",
        "sleep": "moon.zzz.fill",
        "cog": "gearshape.fill",
        "tune": "slider.horizontal.3",
        "format-list-bulleted": "list.bullet",
        "playlist-check": "checklist",
        "text": "textformat",
        "information": "info.circle.fill",
        "alert": "exclamationmark.triangle.fill",
        "alert-circle": "exclamationmark.circle.fill",
        "check-circle": "checkmark.circle.fill",
        "close-circle": "xmark.circle.fill",
        "help-circle": "questionmark.circle.fill",
        "eye": "eye.fill",
        "leaf": "leaf.fill",
        "flower": "camera.macro",
        "sprout": "leaf.fill",
        "pine-tree": "tree.fill",
        "weather-sunset": "sunset.fill",
        "solar-power": "sun.max.trianglebadge.exclamationmark.fill",
        "transmission-tower": "bolt.horizontal.fill",
        "gas-cylinder": "flame.fill",
        "meter-electric": "bolt.square.fill",
        "package-variant": "shippingbox.fill",
        "email": "envelope.fill",
        "phone": "phone.fill",
        "cellphone": "iphone",
        "tablet": "ipad",
        "laptop": "laptopcomputer",
        "printer": "printer.fill",
        "update": "arrow.down.circle.fill",
        "restart": "arrow.clockwise",
        "download": "arrow.down.circle",
        "upload": "arrow.up.circle",
        "script-text": "scroll.fill",
        "robot": "gearshape.2.fill",
        "palette": "paintpalette.fill",
        "brightness-6": "sun.max.fill",
        "hand-back-right": "hand.raised.fill",
        "gesture-tap-button": "hand.tap.fill",
    ]
}
