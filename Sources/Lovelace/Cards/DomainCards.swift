import SwiftUI

/// `type: light`
struct LightCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var coordinator: DashboardCoordinator
    @State private var brightness: Double = 0

    var body: some View {
        let entity = card.entityID.flatMap { store.entity($0) }

        CardSurface {
            VStack(spacing: 18) {
                Text(card["name"]?.stringValue ?? entity?.friendlyName ?? "Licht")
                    .font(.headline)
                    .lineLimit(1)

                Button {
                    guard let entity else { return }
                    Task { await store.performPrimaryAction(on: entity) }
                } label: {
                    EntityIcon(entity: entity, overrideIcon: card.icon, size: 70)
                        .padding(24)
                }
                .buttonStyle(.card)
                .onPlayPauseCommand {
                    if let entityID = card.entityID { coordinator.showMoreInfo(entityID) }
                }

                if let entity, entity.isActive {
                    RemoteSlider(
                        title: "Helligkeit",
                        value: $brightness,
                        range: 1...100,
                        step: 5,
                        unit: " %",
                        icon: "sun.max.fill"
                    ) { newValue in
                        Task {
                            await store.callService(
                                domain: "light",
                                service: "turn_on",
                                entity: entity,
                                data: ["brightness_pct": .number(newValue.rounded())]
                            )
                        }
                    }
                } else {
                    Text(entity?.displayState ?? "—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: currentBrightness) { _, newValue in
            brightness = newValue
        }
        .onAppear { brightness = currentBrightness }
    }

    private var currentBrightness: Double {
        guard let entity = card.entityID.flatMap({ store.entity($0) }),
              let raw = entity.attributes["brightness"]?.doubleValue
        else { return 0 }
        return (raw / 255 * 100).rounded()
    }
}

/// `type: thermostat`
struct ThermostatCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        if let entityID = card.entityID, let entity = store.entity(entityID) {
            CardSurface {
                ClimateControls(entity: entity, compact: true)
            }
        } else {
            UnsupportedCardView(type: card.type, reason: "Entität nicht gefunden.")
        }
    }
}

/// Shared between the thermostat card and the climate detail sheet.
struct ClimateControls: View {
    let entity: HAEntity
    var compact = false

    @EnvironmentObject private var store: EntityStore

    private var target: Double? { entity.attributes["temperature"]?.doubleValue }
    private var current: Double? { entity.attributes["current_temperature"]?.doubleValue }
    private var stepSize: Double { entity.attributes["target_temp_step"]?.doubleValue ?? 0.5 }
    private var minimum: Double { entity.attributes["min_temp"]?.doubleValue ?? 7 }
    private var maximum: Double { entity.attributes["max_temp"]?.doubleValue ?? 35 }
    private var unit: String { store.config?.temperatureUnit ?? "°C" }

    var body: some View {
        VStack(spacing: 22) {
            Text(entity.friendlyName)
                .font(.headline)
                .lineLimit(1)

            if let current {
                Text("Aktuell \(HANumber.format(current)) \(unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            RemoteStepper(
                title: "Soll · \(entity.displayState)",
                valueText: target.map { "\(HANumber.format($0))\(unit)" } ?? "—"
            ) {
                adjustTarget(by: -stepSize)
            } onIncrease: {
                adjustTarget(by: stepSize)
            }

            if !compact {
                if let modes = entity.attributes["hvac_modes"]?.stringArrayValue, !modes.isEmpty {
                    RemoteOptionPicker(
                        title: "Betriebsart",
                        options: modes,
                        selection: entity.state,
                        label: Self.modeLabel
                    ) { mode in
                        Task {
                            await store.callService(
                                domain: "climate",
                                service: "set_hvac_mode",
                                entity: entity,
                                data: ["hvac_mode": .string(mode)]
                            )
                        }
                    }
                }

                if entity.supports(ClimateFeature.presetMode),
                   let presets = entity.attributes["preset_modes"]?.stringArrayValue,
                   !presets.isEmpty {
                    RemoteOptionPicker(
                        title: "Voreinstellung",
                        options: presets,
                        selection: entity.attributes["preset_mode"]?.stringValue
                    ) { preset in
                        Task {
                            await store.callService(
                                domain: "climate",
                                service: "set_preset_mode",
                                entity: entity,
                                data: ["preset_mode": .string(preset)]
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func adjustTarget(by delta: Double) {
        let base = target ?? current ?? minimum
        let next = min(max(base + delta, minimum), maximum)
        Task {
            await store.callService(
                domain: "climate",
                service: "set_temperature",
                entity: entity,
                data: ["temperature": .number(next)]
            )
        }
    }

    static func modeLabel(_ mode: String) -> String {
        switch mode {
        case "off": return "Aus"
        case "heat": return "Heizen"
        case "cool": return "Kühlen"
        case "heat_cool": return "Auto"
        case "auto": return "Automatik"
        case "dry": return "Entfeuchten"
        case "fan_only": return "Lüften"
        default: return mode.capitalized
        }
    }
}

/// `type: humidifier`
struct HumidifierCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore
    @State private var humidity: Double = 50

    var body: some View {
        if let entityID = card.entityID, let entity = store.entity(entityID) {
            CardSurface {
                VStack(spacing: 18) {
                    Text(entity.friendlyName).font(.headline)
                    Text(entity.displayState)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    RemoteSlider(
                        title: "Ziel-Luftfeuchte",
                        value: $humidity,
                        range: (entity.attributes["min_humidity"]?.doubleValue ?? 0)...(entity.attributes["max_humidity"]?.doubleValue ?? 100),
                        step: 5,
                        unit: " %",
                        icon: "humidity.fill"
                    ) { newValue in
                        Task {
                            await store.callService(
                                domain: "humidifier",
                                service: "set_humidity",
                                entity: entity,
                                data: ["humidity": .number(newValue.rounded())]
                            )
                        }
                    }
                }
            }
            .onAppear {
                humidity = entity.attributes["humidity"]?.doubleValue ?? 50
            }
        } else {
            UnsupportedCardView(type: card.type, reason: "Entität nicht gefunden.")
        }
    }
}

/// `type: media-control`
struct MediaControlCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        if let entityID = card.entityID, let entity = store.entity(entityID) {
            CardSurface {
                MediaPlayerControls(entity: entity, compact: true)
            }
        } else {
            UnsupportedCardView(type: card.type, reason: "Entität nicht gefunden.")
        }
    }
}

/// Shared between the media-control card and the detail sheet.
struct MediaPlayerControls: View {
    let entity: HAEntity
    var compact = false

    @EnvironmentObject private var store: EntityStore
    @State private var volume: Double = 0

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                if let picture = entity.entityPicture {
                    HARemoteImage(path: picture, contentMode: .fit)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(entity.friendlyName)
                        .font(.headline)
                        .lineLimit(1)
                    if let title = entity.attributes["media_title"]?.stringValue {
                        Text(title)
                            .font(.title3)
                            .lineLimit(2)
                    }
                    if let artist = entity.attributes["media_artist"]?.stringValue
                        ?? entity.attributes["media_series_title"]?.stringValue {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(entity.displayState)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            transportControls

            if entity.supports(MediaPlayerFeature.volumeSet) {
                RemoteSlider(
                    title: "Lautstärke",
                    value: $volume,
                    range: 0...100,
                    step: 5,
                    unit: " %",
                    icon: "speaker.wave.2.fill"
                ) { newValue in
                    Task {
                        await store.callService(
                            domain: "media_player",
                            service: "volume_set",
                            entity: entity,
                            data: ["volume_level": .number(newValue.rounded() / 100)]
                        )
                    }
                }
            }

            if !compact, entity.supports(MediaPlayerFeature.selectSource),
               let sources = entity.attributes["source_list"]?.stringArrayValue, !sources.isEmpty {
                RemoteOptionPicker(
                    title: "Quelle",
                    options: sources,
                    selection: entity.attributes["source"]?.stringValue
                ) { source in
                    Task {
                        await store.callService(
                            domain: "media_player",
                            service: "select_source",
                            entity: entity,
                            data: ["source": .string(source)]
                        )
                    }
                }
            }
        }
        .onAppear { volume = (entity.attributes["volume_level"]?.doubleValue ?? 0) * 100 }
    }

    private var transportControls: some View {
        HStack(spacing: 20) {
            if entity.supports(MediaPlayerFeature.previousTrack) {
                transportButton("backward.end.fill", service: "media_previous_track")
            }
            transportButton(
                entity.state == "playing" ? "pause.fill" : "play.fill",
                service: "media_play_pause"
            )
            if entity.supports(MediaPlayerFeature.stop) {
                transportButton("stop.fill", service: "media_stop")
            }
            if entity.supports(MediaPlayerFeature.nextTrack) {
                transportButton("forward.end.fill", service: "media_next_track")
            }
            if entity.supports(MediaPlayerFeature.volumeMute) {
                transportButton(
                    entity.attributes["is_volume_muted"]?.boolValue == true
                        ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    service: "volume_mute",
                    data: ["is_volume_muted": .bool(!(entity.attributes["is_volume_muted"]?.boolValue ?? false))]
                )
            }
        }
    }

    private func transportButton(
        _ symbol: String,
        service: String,
        data: [String: JSONValue] = [:]
    ) -> some View {
        Button {
            Task {
                await store.callService(
                    domain: "media_player",
                    service: service,
                    entity: entity,
                    data: data
                )
            }
        } label: {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 64, height: 54)
        }
        .buttonStyle(.card)
    }
}

/// `type: weather-forecast`
struct WeatherCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var connection: HAWebSocketClient
    @StateObject private var forecast = WeatherForecastSubscription()

    private var forecastType: String {
        card["forecast_type"]?.stringValue ?? "daily"
    }

    var body: some View {
        if let entityID = card.entityID, let entity = store.entity(entityID) {
            CardSurface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 18) {
                        Image(systemName: Self.symbol(for: entity.state))
                            .font(.system(size: 54))
                            .symbolRenderingMode(.multicolor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card["name"]?.stringValue ?? entity.friendlyName)
                                .font(.headline)
                            if let temperature = entity.attributes["temperature"]?.doubleValue {
                                Text("\(HANumber.format(temperature)) \(entity.attributes["temperature_unit"]?.stringValue ?? "°C")")
                                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                            }
                            Text(Self.conditionLabel(entity.state))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    if card["show_forecast"]?.boolValue != false, !forecast.entries.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                ForEach(forecast.entries.prefix(7)) { entry in
                                    VStack(spacing: 8) {
                                        Text(Self.dayLabel(entry.date, type: forecastType))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: Self.symbol(for: entry.condition ?? ""))
                                            .font(.title2)
                                            .symbolRenderingMode(.multicolor)
                                        Text(entry.temperature.map { HANumber.format($0) + "°" } ?? "—")
                                            .font(.headline)
                                        if let low = entry.templow {
                                            Text(HANumber.format(low) + "°")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 90)
                                }
                            }
                        }
                    }
                }
            }
            .focusableCard()
            .task(id: entityID) {
                await forecast.start(entityID: entityID, type: forecastType, client: connection)
            }
            .onDisappear {
                let client = connection
                Task { await forecast.stop(client: client) }
            }
        } else {
            UnsupportedCardView(type: card.type, reason: "Entität nicht gefunden.")
        }
    }

    static func symbol(for condition: String) -> String {
        switch condition {
        case "clear-night": return "moon.stars.fill"
        case "cloudy": return "cloud.fill"
        case "fog": return "cloud.fog.fill"
        case "hail": return "cloud.hail.fill"
        case "lightning": return "cloud.bolt.fill"
        case "lightning-rainy": return "cloud.bolt.rain.fill"
        case "partlycloudy": return "cloud.sun.fill"
        case "pouring": return "cloud.heavyrain.fill"
        case "rainy": return "cloud.rain.fill"
        case "snowy": return "cloud.snow.fill"
        case "snowy-rainy": return "cloud.sleet.fill"
        case "sunny": return "sun.max.fill"
        case "windy", "windy-variant": return "wind"
        case "exceptional": return "exclamationmark.triangle.fill"
        default: return "cloud.fill"
        }
    }

    static func conditionLabel(_ condition: String) -> String {
        switch condition {
        case "clear-night": return "Klare Nacht"
        case "cloudy": return "Bewölkt"
        case "fog": return "Nebel"
        case "hail": return "Hagel"
        case "lightning", "lightning-rainy": return "Gewitter"
        case "partlycloudy": return "Teilweise bewölkt"
        case "pouring": return "Starkregen"
        case "rainy": return "Regen"
        case "snowy": return "Schnee"
        case "snowy-rainy": return "Schneeregen"
        case "sunny": return "Sonnig"
        case "windy", "windy-variant": return "Windig"
        case "exceptional": return "Unwetter"
        default: return condition.capitalized
        }
    }

    private static func dayLabel(_ date: Date?, type: String) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = type == "daily" ? "EE" : "HH"
        return formatter.string(from: date) + (type == "daily" ? "" : " Uhr")
    }
}

/// `type: alarm-panel`
struct AlarmPanelCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    private var states: [String] {
        card["states"]?.stringArrayValue ?? ["arm_home", "arm_away"]
    }

    var body: some View {
        if let entityID = card.entityID, let entity = store.entity(entityID) {
            CardSurface {
                VStack(spacing: 18) {
                    Text(card["name"]?.stringValue ?? entity.friendlyName)
                        .font(.headline)
                    Text(entity.displayState)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(entity.state == "disarmed" ? Theme.inactive : Theme.active)

                    HStack(spacing: 16) {
                        ForEach(states, id: \.self) { state in
                            Button(Self.label(for: state)) {
                                Task {
                                    await store.callService(
                                        domain: "alarm_control_panel",
                                        service: "alarm_\(state)",
                                        entity: entity
                                    )
                                }
                            }
                            .buttonStyle(.card)
                        }
                        Button("Deaktivieren") {
                            Task {
                                await store.callService(
                                    domain: "alarm_control_panel",
                                    service: "alarm_disarm",
                                    entity: entity
                                )
                            }
                        }
                        .buttonStyle(.card)
                    }

                    if entity.attributes["code_format"]?.isNull == false {
                        Text("Diese Alarmanlage verlangt einen Code. Die Code-Eingabe ist noch nicht umgesetzt.")
                            .font(.caption)
                            .foregroundStyle(Theme.unavailable)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        } else {
            UnsupportedCardView(type: card.type, reason: "Entität nicht gefunden.")
        }
    }

    private static func label(for state: String) -> String {
        switch state {
        case "arm_home": return "Zuhause"
        case "arm_away": return "Abwesend"
        case "arm_night": return "Nacht"
        case "arm_vacation": return "Urlaub"
        default: return state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
