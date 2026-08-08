import SwiftUI

/// The detail sheet for a single entity — the equivalent of Home Assistant's
/// "more info" dialog, with the controls a remote can actually operate.
struct MoreInfoView: View {
    let entityID: String

    @EnvironmentObject private var store: EntityStore
    @Environment(\.dismiss) private var dismiss

    private var entity: HAEntity? { store.entity(entityID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                header

                if let entity {
                    controls(for: entity)
                    attributes(of: entity)
                } else {
                    Text("Diese Entität ist nicht mehr verfügbar.")
                        .foregroundStyle(.secondary)
                }

                Button("Schließen") { dismiss() }
                    .padding(.top, 10)
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 50)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            EntityIcon(entity: entity, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text(entity?.friendlyName ?? entityID)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text(entity?.displayState ?? "—")
                        .foregroundStyle(entity.map(Theme.stateColor) ?? .secondary)
                    if let area = store.areaName(for: entityID) {
                        Text("·")
                        Text(area)
                    }
                    if let changed = entity?.lastChanged {
                        Text("·")
                        Text(RelativeDateTimeFormatter.shared.localizedString(for: changed, relativeTo: Date()))
                    }
                }
                .font(.title3)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func controls(for entity: HAEntity) -> some View {
        switch entity.domain {
        case "light":
            LightDetailControls(entity: entity)
        case "climate":
            ClimateControls(entity: entity)
        case "cover", "valve":
            CoverDetailControls(entity: entity)
        case "media_player":
            MediaPlayerControls(entity: entity)
        case "fan":
            FanDetailControls(entity: entity)
        case "camera":
            CameraLiveView(entityID: entity.entityID)
                .frame(height: 560)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        case "vacuum", "lawn_mower":
            VacuumDetailControls(entity: entity)
        case "select", "input_select":
            SelectDetailControls(entity: entity)
        case "number", "input_number":
            NumberDetailControls(entity: entity)
        case "humidifier":
            HumidifierDetailControls(entity: entity)
        default:
            SimpleDetailControls(entity: entity)
        }
    }

    private func attributes(of entity: HAEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attribute")
                .font(.headline)

            ForEach(visibleAttributeKeys(of: entity), id: \.self) { key in
                HStack(alignment: .top) {
                    Text(key.replacingOccurrences(of: "_", with: " "))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                    Text(entity.attributes[key]?.displayString ?? "—")
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                }
                .font(.callout)
                Divider()
            }
        }
        .frame(maxWidth: 1100, alignment: .leading)
    }

    private func visibleAttributeKeys(of entity: HAEntity) -> [String] {
        var hidden = Self.hiddenAttributes
        // A TV is a shared screen. "Is someone home" is what a dashboard needs;
        // a housemate's exact coordinates and phone battery in front of whoever
        // is in the room is not.
        if entity.domain == "person" || entity.domain == "device_tracker" {
            hidden.formUnion(Self.locationAttributes)
        }
        return entity.attributes.keys.sorted().filter { !hidden.contains($0) }
    }

    /// Precise-location and device attributes of presence entities.
    private static let locationAttributes: Set<String> = [
        "latitude", "longitude", "gps_accuracy", "altitude", "course", "speed",
        "source", "battery_level", "mac", "ip",
    ]

    /// Attributes already surfaced elsewhere in the sheet, or pure plumbing.
    private static let hiddenAttributes: Set<String> = [
        "friendly_name", "icon", "supported_features", "entity_picture",
        "attribution", "device_class", "editable", "id",
    ]
}

// MARK: - Domain controls

struct LightDetailControls: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore
    @State private var brightness: Double = 0
    @State private var colorTemperature: Double = 3000

    private var supportsColorTemperature: Bool {
        entity.attributes["supported_color_modes"]?.stringArrayValue?.contains("color_temp") ?? false
    }

    private var minKelvin: Double { entity.attributes["min_color_temp_kelvin"]?.doubleValue ?? 2000 }
    private var maxKelvin: Double { entity.attributes["max_color_temp_kelvin"]?.doubleValue ?? 6500 }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ToggleRow(entity: entity)

            if entity.isActive {
                RemoteSlider(
                    title: "Helligkeit",
                    value: $brightness,
                    range: 1...100,
                    step: 5,
                    unit: " %",
                    icon: "sun.max.fill"
                ) { value in
                    Task {
                        await store.callService(
                            domain: "light",
                            service: "turn_on",
                            entity: entity,
                            data: ["brightness_pct": .number(value.rounded())]
                        )
                    }
                }

                if supportsColorTemperature {
                    RemoteSlider(
                        title: "Farbtemperatur",
                        value: $colorTemperature,
                        range: minKelvin...maxKelvin,
                        step: 100,
                        unit: " K",
                        icon: "thermometer.sun.fill"
                    ) { value in
                        Task {
                            await store.callService(
                                domain: "light",
                                service: "turn_on",
                                entity: entity,
                                data: ["color_temp_kelvin": .number(value.rounded())]
                            )
                        }
                    }
                }

                if entity.supports(LightFeature.effect),
                   let effects = entity.attributes["effect_list"]?.stringArrayValue, !effects.isEmpty {
                    RemoteOptionPicker(
                        title: "Effekt",
                        options: effects,
                        selection: entity.attributes["effect"]?.stringValue
                    ) { effect in
                        Task {
                            await store.callService(
                                domain: "light",
                                service: "turn_on",
                                entity: entity,
                                data: ["effect": .string(effect)]
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            brightness = ((entity.attributes["brightness"]?.doubleValue ?? 0) / 255 * 100).rounded()
            colorTemperature = entity.attributes["color_temp_kelvin"]?.doubleValue ?? 3000
        }
    }
}

struct CoverDetailControls: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore
    @State private var position: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 20) {
                actionButton("chevron.up", service: "open_\(entity.domain)", enabled: entity.supports(CoverFeature.open))
                actionButton("stop.fill", service: "stop_\(entity.domain)", enabled: entity.supports(CoverFeature.stop))
                actionButton("chevron.down", service: "close_\(entity.domain)", enabled: entity.supports(CoverFeature.close))
            }

            if entity.supports(CoverFeature.setPosition) {
                RemoteSlider(
                    title: "Position (100 % = offen)",
                    value: $position,
                    range: 0...100,
                    step: 5,
                    unit: " %",
                    icon: "arrow.up.and.down"
                ) { value in
                    Task {
                        await store.callService(
                            domain: entity.domain,
                            service: "set_\(entity.domain)_position",
                            entity: entity,
                            data: ["position": .number(value.rounded())]
                        )
                    }
                }
            }

            if entity.supports(CoverFeature.setTiltPosition) {
                Text("Lamellen")
                    .font(.headline)
                HStack(spacing: 20) {
                    actionButton("arrow.up.left", service: "open_cover_tilt", enabled: true)
                    actionButton("stop.fill", service: "stop_cover_tilt", enabled: true)
                    actionButton("arrow.down.right", service: "close_cover_tilt", enabled: true)
                }
            }
        }
        .onAppear {
            position = entity.attributes["current_position"]?.doubleValue ?? 0
        }
    }

    @ViewBuilder
    private func actionButton(_ symbol: String, service: String, enabled: Bool) -> some View {
        if enabled {
            Button {
                Task { await store.callService(domain: entity.domain, service: service, entity: entity) }
            } label: {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 100, height: 66)
            }
            .buttonStyle(.card)
        }
    }
}

struct FanDetailControls: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore
    @State private var percentage: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ToggleRow(entity: entity)

            if entity.supports(FanFeature.setSpeed) {
                RemoteSlider(
                    title: "Stufe",
                    value: $percentage,
                    range: 0...100,
                    step: entity.attributes["percentage_step"]?.doubleValue ?? 10,
                    unit: " %",
                    icon: "fanblades.fill"
                ) { value in
                    Task {
                        await store.callService(
                            domain: "fan",
                            service: "set_percentage",
                            entity: entity,
                            data: ["percentage": .number(value.rounded())]
                        )
                    }
                }
            }

            if entity.supports(FanFeature.presetMode),
               let presets = entity.attributes["preset_modes"]?.stringArrayValue, !presets.isEmpty {
                RemoteOptionPicker(
                    title: "Voreinstellung",
                    options: presets,
                    selection: entity.attributes["preset_mode"]?.stringValue
                ) { preset in
                    Task {
                        await store.callService(
                            domain: "fan",
                            service: "set_preset_mode",
                            entity: entity,
                            data: ["preset_mode": .string(preset)]
                        )
                    }
                }
            }
        }
        .onAppear { percentage = entity.attributes["percentage"]?.doubleValue ?? 0 }
    }
}

struct VacuumDetailControls: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        HStack(spacing: 20) {
            button("Start", symbol: "play.fill", service: "start")
            button("Pause", symbol: "pause.fill", service: "pause")
            button("Stopp", symbol: "stop.fill", service: "stop")
            button("Zur Station", symbol: "house.fill", service: "return_to_base")
        }
    }

    private func button(_ title: String, symbol: String, service: String) -> some View {
        Button {
            Task { await store.callService(domain: entity.domain, service: service, entity: entity) }
        } label: {
            Label(title, systemImage: symbol)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
        .buttonStyle(.card)
    }
}

struct SelectDetailControls: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        RemoteOptionPicker(
            title: "Auswahl",
            options: entity.attributes["options"]?.stringArrayValue ?? [],
            selection: entity.state
        ) { option in
            Task {
                await store.callService(
                    domain: entity.domain,
                    service: "select_option",
                    entity: entity,
                    data: ["option": .string(option)]
                )
            }
        }
    }
}

struct NumberDetailControls: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore
    @State private var value: Double = 0

    var body: some View {
        RemoteSlider(
            title: entity.friendlyName,
            value: $value,
            range: (entity.attributes["min"]?.doubleValue ?? 0)...(entity.attributes["max"]?.doubleValue ?? 100),
            step: entity.attributes["step"]?.doubleValue ?? 1,
            unit: entity.unitOfMeasurement.map { " \($0)" } ?? "",
            icon: "slider.horizontal.3"
        ) { newValue in
            Task {
                await store.callService(
                    domain: entity.domain,
                    service: "set_value",
                    entity: entity,
                    data: ["value": .number(newValue)]
                )
            }
        }
        .onAppear { value = Double(entity.state) ?? 0 }
    }
}

struct HumidifierDetailControls: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore
    @State private var humidity: Double = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ToggleRow(entity: entity)
            RemoteSlider(
                title: "Ziel-Luftfeuchte",
                value: $humidity,
                range: (entity.attributes["min_humidity"]?.doubleValue ?? 0)...(entity.attributes["max_humidity"]?.doubleValue ?? 100),
                step: 5,
                unit: " %",
                icon: "humidity.fill"
            ) { value in
                Task {
                    await store.callService(
                        domain: "humidifier",
                        service: "set_humidity",
                        entity: entity,
                        data: ["humidity": .number(value.rounded())]
                    )
                }
            }
        }
        .onAppear { humidity = entity.attributes["humidity"]?.doubleValue ?? 50 }
    }
}

/// Fallback: whatever primary action the domain has, or nothing at all for
/// read-only entities like sensors.
struct SimpleDetailControls: View {
    let entity: HAEntity

    var body: some View {
        if entity.isToggleable || entity.isActivatable || entity.domain == "lock" {
            ToggleRow(entity: entity)
        }
    }
}

/// The single big action button shared by every toggleable domain.
struct ToggleRow: View {
    let entity: HAEntity

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        Button {
            Task { await store.performPrimaryAction(on: entity) }
        } label: {
            Label(title, systemImage: symbol)
                .font(.title3)
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
        }
        .buttonStyle(.card)
    }

    private var title: String {
        switch entity.domain {
        case "scene": return "Szene aktivieren"
        case "script": return "Skript ausführen"
        case "button", "input_button": return "Auslösen"
        case "lock": return entity.state == "locked" ? "Entriegeln" : "Verriegeln"
        default: return entity.isActive ? "Ausschalten" : "Einschalten"
        }
    }

    private var symbol: String {
        switch entity.domain {
        case "scene": return "wand.and.stars"
        case "script": return "play.fill"
        case "button", "input_button": return "hand.tap.fill"
        case "lock": return entity.state == "locked" ? "lock.open.fill" : "lock.fill"
        default: return "power"
        }
    }
}
