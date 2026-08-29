import SwiftUI

/// Dispatches a Lovelace card configuration to its native implementation.
///
/// The switch returns `AnyView` deliberately: a `@ViewBuilder` switch with this
/// many branches builds a deeply nested `_ConditionalContent` tree that slows
/// type checking to a crawl for no runtime benefit.
struct LovelaceCardView: View {
    let card: LovelaceCardConfig

    var body: some View {
        content
    }

    private var content: AnyView {
        switch card.type {
        // Lists and readouts
        case "entities", "entity-filter":
            return AnyView(EntitiesCardView(card: card))
        case "glance":
            return AnyView(GlanceCardView(card: card))
        case "button", "entity-button":
            return AnyView(ButtonCardView(card: card))
        case "tile":
            return AnyView(TileCardView(card: card))
        case "entity", "sensor":
            return AnyView(EntityStateCardView(card: card))
        case "heading":
            return AnyView(HeadingCardView(card: card))
        case "markdown":
            return AnyView(MarkdownCardView(card: card))
        case "gauge":
            return AnyView(GaugeCardView(card: card))
        case "history-graph":
            return AnyView(HistoryGraphCardView(card: card))

        // Domain specific
        case "light":
            return AnyView(LightCardView(card: card))
        case "thermostat":
            return AnyView(ThermostatCardView(card: card))
        case "humidifier":
            return AnyView(HumidifierCardView(card: card))
        case "media-control":
            return AnyView(MediaControlCardView(card: card))
        case "weather-forecast":
            return AnyView(WeatherCardView(card: card))
        case "alarm-panel":
            return AnyView(AlarmPanelCardView(card: card))

        // Media
        case "picture-entity":
            return AnyView(PictureEntityCardView(card: card))
        case "picture-glance":
            return AnyView(PictureGlanceCardView(card: card))
        case "picture":
            return AnyView(PictureCardView(card: card))

        // Layout
        case "grid":
            return AnyView(GridCardView(card: card))
        case "vertical-stack":
            return AnyView(VerticalStackCardView(card: card))
        case "horizontal-stack":
            return AnyView(HorizontalStackCardView(card: card))
        case "conditional":
            return AnyView(ConditionalCardView(card: card))
        case "area":
            return AnyView(AreaCardView(card: card))

        default:
            return AnyView(KnownUnsupportedCardView(card: card))
        }
    }
}

/// Badges are rendered as compact pills above a view's content.
struct LovelaceBadgeView: View {
    let badge: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        let entity = badge.entityID.flatMap { store.entity($0) }
        CardButton(card: badge, entityID: badge.entityID, defaultAction: .moreInfo) {
            HStack(spacing: 10) {
                EntityIcon(entity: entity, overrideIcon: badge.icon, size: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(entity?.displayState ?? "—")
                        .font(.headline)
                        .lineLimit(1)
                    Text(badge["name"]?.stringValue ?? entity?.friendlyName ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}
