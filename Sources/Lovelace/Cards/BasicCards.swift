import SwiftUI

/// Icon tinted by the entity's current state — the single most important visual
/// cue on a dashboard.
struct EntityIcon: View {
    let entity: HAEntity?
    var overrideIcon: String?
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(entity.map(Theme.stateColor) ?? Theme.inactive)
            .frame(width: size * 1.4, height: size * 1.4)
    }

    private var symbol: String {
        if let overrideIcon {
            return IconMapper.symbol(forMDI: overrideIcon, domain: entity?.domain, state: entity?.state)
        }
        return entity?.symbolName ?? "questionmark.circle"
    }
}

/// `type: entities`
struct EntitiesCardView: View {
    let card: LovelaceCardConfig

    var body: some View {
        CardSurface(padding: 16) {
            VStack(alignment: .leading, spacing: 2) {
                if let title = card["title"]?.stringValue {
                    CardHeader(
                        title: title,
                        icon: card.icon.map { IconMapper.symbol(forMDI: $0) }
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                }

                ForEach(card.entityRows) { row in
                    EntityRowView(row: row, card: card)
                }
            }
        }
    }
}

struct EntityRowView: View {
    let row: LovelaceEntityRow
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        switch row.rowType ?? "" {
        case "divider":
            Divider().padding(.vertical, 6)
        case "section":
            Text(row.name ?? "")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 4)
        default:
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entityID = row.entityID {
            let entity = store.entity(entityID)
            CardButton(card: card, entityID: entityID, appearance: .row) {
                HStack(spacing: 14) {
                    EntityIcon(entity: entity, overrideIcon: row.icon, size: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name ?? entity?.friendlyName ?? entityID)
                            .font(.body)
                            .lineLimit(1)
                        if let secondary = secondaryText(for: entity) {
                            Text(secondary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 12)
                    Text(stateText(for: entity))
                        .font(.body.weight(.medium))
                        .foregroundStyle(entity?.isUnavailable == true ? Theme.unavailable : .primary)
                        .lineLimit(1)
                }
            }
        } else {
            EmptyView()
        }
    }

    private func stateText(for entity: HAEntity?) -> String {
        guard let entity else { return "—" }
        if let attribute = row.attribute {
            return entity.attributes[attribute]?.displayString ?? "—"
        }
        return entity.displayState
    }

    private func secondaryText(for entity: HAEntity?) -> String? {
        guard let entity else { return nil }
        switch row.secondaryInfo ?? "" {
        case "last-changed":
            guard let date = entity.lastChanged else { return nil }
            return RelativeDateTimeFormatter.shared.localizedString(for: date, relativeTo: Date())
        case "entity-id":
            return entity.entityID
        default:
            return nil
        }
    }
}

/// `type: glance`
struct GlanceCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    private var columns: [GridItem] {
        let count = card["columns"]?.intValue ?? 4
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, count))
    }

    var body: some View {
        CardSurface(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                if let title = card["title"]?.stringValue {
                    CardHeader(title: title).padding(.horizontal, 8)
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(card.entityRows) { row in
                        if let entityID = row.entityID {
                            let entity = store.entity(entityID)
                            CardButton(card: card, entityID: entityID, appearance: .row) {
                                VStack(spacing: 6) {
                                    Text(row.name ?? entity?.friendlyName ?? entityID)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    EntityIcon(entity: entity, overrideIcon: row.icon, size: 28)
                                    Text(entity?.displayState ?? "—")
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// `type: button` / `type: entity-button`
struct ButtonCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        let entity = card.entityID.flatMap { store.entity($0) }
        CardButton(card: card, entityID: card.entityID) {
            VStack(spacing: 12) {
                EntityIcon(entity: entity, overrideIcon: card.icon, size: 44)
                Text(card["name"]?.stringValue ?? entity?.friendlyName ?? "Aktion")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if card["show_state"]?.boolValue == true, let entity {
                    Text(entity.displayState)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

/// `type: tile`
struct TileCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        let entity = card.entityID.flatMap { store.entity($0) }
        CardButton(card: card, entityID: card.entityID) {
            HStack(spacing: 16) {
                EntityIcon(entity: entity, overrideIcon: card.icon, size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card["name"]?.stringValue ?? entity?.friendlyName ?? card.entityID ?? "—")
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle(for: entity))
                        .font(.subheadline)
                        .foregroundStyle(entity?.isUnavailable == true ? Theme.unavailable : .secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
    }

    private func subtitle(for entity: HAEntity?) -> String {
        guard let entity else { return "—" }
        if entity.domain == "light", entity.isActive,
           let brightness = entity.attributes["brightness"]?.doubleValue {
            return "\(entity.displayState) · \(Int((brightness / 255 * 100).rounded())) %"
        }
        return entity.displayState
    }
}

/// `type: entity` — a large single-value readout.
struct EntityStateCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        let entity = card.entityID.flatMap { store.entity($0) }
        CardButton(card: card, entityID: card.entityID, defaultAction: .moreInfo) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    EntityIcon(entity: entity, overrideIcon: card.icon, size: 26)
                    Spacer()
                }
                Text(entity?.displayState ?? "—")
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(card["name"]?.stringValue ?? entity?.friendlyName ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// `type: heading`
struct HeadingCardView: View {
    let card: LovelaceCardConfig

    var body: some View {
        let text = card["heading"]?.stringValue ?? card["title"]?.stringValue ?? ""
        let isTitle = (card["heading_style"]?.stringValue ?? "title") == "title"

        HStack(spacing: 12) {
            if let icon = card.icon {
                Image(systemName: IconMapper.symbol(forMDI: icon))
                    .foregroundStyle(Theme.accent)
            }
            Text(text)
                .font(isTitle ? .title2.bold() : .headline)
                .foregroundStyle(isTitle ? .primary : .secondary)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }
}

/// `type: markdown` — content is rendered server-side because it is usually a
/// Jinja2 template.
struct MarkdownCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var connection: HAWebSocketClient
    @StateObject private var renderer = TemplateRenderer()

    private var template: String {
        card["content"]?.stringValue ?? ""
    }

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                if let title = card["title"]?.stringValue {
                    CardHeader(title: title)
                }
                Text(attributed)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: template) {
            await renderer.start(template: template, client: connection)
        }
        .onDisappear {
            let client = connection
            Task { await renderer.stop(client: client) }
        }
    }

    private var attributed: AttributedString {
        let source = renderer.rendered.isEmpty ? template : renderer.rendered
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}

/// `type: gauge`
struct GaugeCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        let entity = card.entityID.flatMap { store.entity($0) }
        let minimum = card["min"]?.doubleValue ?? 0
        let maximum = card["max"]?.doubleValue ?? 100
        let value = entity.flatMap { Double($0.state) }

        CardButton(card: card, entityID: card.entityID, defaultAction: .moreInfo) {
            VStack(spacing: 14) {
                ZStack {
                    // A 270° arc: trim to three quarters and rotate the ring so
                    // the gap sits at the bottom. Only the ring rotates — the
                    // readout inside stays upright.
                    ZStack {
                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(Theme.cardBackgroundElevated, style: .init(lineWidth: 16, lineCap: .round))
                        Circle()
                            .trim(from: 0, to: 0.75 * fraction(value, minimum, maximum))
                            .stroke(severityColor(value), style: .init(lineWidth: 16, lineCap: .round))
                    }
                    .rotationEffect(.degrees(135))

                    VStack(spacing: 2) {
                        Text(value.map { HANumber.format($0) } ?? "—")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                        if let unit = card["unit"]?.stringValue ?? entity?.unitOfMeasurement {
                            Text(unit)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 170)

                Text(card["name"]?.stringValue ?? entity?.friendlyName ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
        }
    }

    private func fraction(_ value: Double?, _ minimum: Double, _ maximum: Double) -> Double {
        guard let value, maximum > minimum else { return 0 }
        return min(max((value - minimum) / (maximum - minimum), 0), 1)
    }

    /// `severity: {green: …, yellow: …, red: …}` colours the arc by threshold.
    private func severityColor(_ value: Double?) -> Color {
        guard let value, let severity = card["severity"]?.objectValue else { return Theme.accent }
        let thresholds: [(Double, Color)] = [
            (severity["red"]?.doubleValue ?? .infinity, .red),
            (severity["yellow"]?.doubleValue ?? .infinity, .yellow),
            (severity["green"]?.doubleValue ?? -.infinity, .green),
        ]
        for (threshold, color) in thresholds where value >= threshold {
            return color
        }
        return Theme.accent
    }
}

extension RelativeDateTimeFormatter {
    static let shared: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
