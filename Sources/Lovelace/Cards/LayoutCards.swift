import SwiftUI

/// `type: grid`
struct GridCardView: View {
    let card: LovelaceCardConfig

    private var columnCount: Int {
        max(1, card["columns"]?.intValue ?? 2)
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount),
            spacing: 20
        ) {
            ForEach(card.childCards) { child in
                LovelaceCardView(card: child)
            }
        }
    }
}

/// `type: vertical-stack`
struct VerticalStackCardView: View {
    let card: LovelaceCardConfig

    var body: some View {
        VStack(spacing: 20) {
            ForEach(card.childCards) { child in
                LovelaceCardView(card: child)
            }
        }
    }
}

/// `type: horizontal-stack`
struct HorizontalStackCardView: View {
    let card: LovelaceCardConfig

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach(card.childCards) { child in
                LovelaceCardView(card: child)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// `type: conditional`
struct ConditionalCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        if conditionsMet, let child = childCard {
            LovelaceCardView(card: child)
        }
    }

    private var childCard: LovelaceCardConfig? {
        guard let raw = card["card"] else { return nil }
        return LovelaceCardConfig(json: raw, id: "\(card.id).conditional")
    }

    private var conditionsMet: Bool {
        let conditions = card["conditions"]?.arrayValue ?? []
        guard !conditions.isEmpty else { return true }
        return conditions.allSatisfy(evaluate)
    }

    private func evaluate(_ condition: JSONValue) -> Bool {
        // Conditions gained an explicit `condition:` discriminator in 2023.11;
        // before that, the presence of `state`/`state_not` implied a state test.
        let kind = condition["condition"]?.stringValue ?? "state"
        switch kind {
        case "state":
            guard let entityID = condition["entity"]?.stringValue,
                  let entity = store.entity(entityID)
            else { return false }
            let value = condition["attribute"]?.stringValue
                .flatMap { entity.attributes[$0]?.displayString } ?? entity.state
            if let expected = condition["state"] {
                return expected.stringArrayValue?.contains(value) ?? false
            }
            if let excluded = condition["state_not"] {
                return !(excluded.stringArrayValue?.contains(value) ?? false)
            }
            return true
        case "numeric_state":
            guard let entityID = condition["entity"]?.stringValue,
                  let entity = store.entity(entityID),
                  let value = Double(entity.state)
            else { return false }
            if let above = condition["above"]?.doubleValue, !(value > above) { return false }
            if let below = condition["below"]?.doubleValue, !(value < below) { return false }
            return true
        case "and":
            return (condition["conditions"]?.arrayValue ?? []).allSatisfy(evaluate)
        case "or":
            return (condition["conditions"]?.arrayValue ?? []).contains(where: evaluate)
        case "not":
            return !(condition["conditions"]?.arrayValue ?? []).contains(where: evaluate)
        case "screen", "user":
            // Screen-size and per-user conditions have no meaning on a shared TV.
            return true
        default:
            return true
        }
    }
}

/// `type: area`
struct AreaCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var coordinator: DashboardCoordinator

    var body: some View {
        let areaID = card["area"]?.stringValue
        let area = store.area(areaID)
        let entities = areaID.map { store.primaryEntities(inArea: $0) } ?? []
        let active = entities.filter(\.isActive)

        CardSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: IconMapper.symbol(forMDI: area?.icon ?? card.icon, domain: nil))
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                    Text(area?.name ?? areaID ?? "Bereich")
                        .font(.title3.bold())
                    Spacer(minLength: 0)
                }

                if active.isEmpty {
                    Text("Nichts aktiv")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(active.prefix(4).map(\.friendlyName).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.active)
                        .lineLimit(2)
                }

                if !sensorSummary.isEmpty {
                    HStack(spacing: 18) {
                        ForEach(sensorSummary, id: \.entityID) { sensor in
                            Label(sensor.displayState, systemImage: sensor.symbolName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var sensorSummary: [HAEntity] {
        guard let areaID = card["area"]?.stringValue else { return [] }
        return store.primaryEntities(inArea: areaID)
            .filter { $0.domain == "sensor" && ["temperature", "humidity"].contains($0.deviceClass ?? "") }
            .prefix(2)
            .map { $0 }
    }
}

/// Views the app deliberately does not implement, rendered as an explicit note
/// rather than a blank space so the dashboard stays self-explanatory.
struct KnownUnsupportedCardView: View {
    let card: LovelaceCardConfig

    var body: some View {
        UnsupportedCardView(type: card.type, reason: Self.reason(for: card.type))
    }

    private static func reason(for type: String) -> String? {
        if type.hasPrefix("custom:") {
            return "Custom Cards sind JavaScript-Erweiterungen des Web-Frontends und laufen auf tvOS nicht."
        }
        switch type {
        case "iframe":
            return "tvOS enthält keine Web-Engine, mit der eingebettete Seiten dargestellt werden könnten."
        case "energy-distribution", "energy-usage-graph", "energy-solar-graph",
             "energy-sources-table", "energy-date-selection", "energy-devices-graph":
            return "Energie-Karten sind noch nicht umgesetzt."
        case "map":
            return "Kartenansichten sind noch nicht umgesetzt."
        case "logbook":
            return "Das Logbuch ist noch nicht umgesetzt."
        case "statistics-graph":
            return "Statistik-Diagramme sind noch nicht umgesetzt; einfache Verläufe zeigt „history-graph“."
        case "todo-list":
            return "Aufgabenlisten sind noch nicht umgesetzt."
        default:
            return nil
        }
    }
}
