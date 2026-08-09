import Charts
import SwiftUI

/// `type: history-graph`
///
/// Only numeric states are plotted — Home Assistant's own card also draws
/// timelines for discrete states, which is left for a later iteration.
struct HistoryGraphCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var store: EntityStore
    @StateObject private var loader = HistoryLoader()

    private var entityIDs: [String] {
        card.entityRows.compactMap(\.entityID)
    }

    private var hours: Int {
        card["hours_to_show"]?.intValue ?? 24
    }

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(
                    title: card["title"]?.stringValue ?? "Verlauf",
                    subtitle: "Letzte \(hours) h"
                )

                if loader.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if plottedEntityIDs.isEmpty {
                    Text("Keine numerischen Verlaufsdaten für diese Entitäten.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
                } else {
                    chart
                }
            }
        }
        .focusableCard()
        .task(id: "\(entityIDs.joined(separator: ","))|\(hours)") {
            await loader.load(entityIDs: entityIDs, hours: hours, client: connection)
        }
    }

    private var plottedEntityIDs: [String] {
        entityIDs.filter { !(loader.samplesByEntity[$0] ?? []).isEmpty }
    }

    private var chart: some View {
        Chart {
            ForEach(plottedEntityIDs, id: \.self) { entityID in
                ForEach(loader.samplesByEntity[entityID] ?? []) { sample in
                    LineMark(
                        x: .value("Zeit", sample.date),
                        y: .value("Wert", sample.value)
                    )
                    .foregroundStyle(by: .value("Entität", store.displayName(for: entityID)))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartLegend(position: .bottom)
        .frame(height: 240)
    }
}
