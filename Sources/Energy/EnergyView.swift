import Charts
import SwiftUI

/// Native stand-in for Home Assistant's energy panel.
struct EnergyView: View {
    @EnvironmentObject private var energy: EnergyService
    @EnvironmentObject private var store: EntityStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gridSpacing) {
                periodPicker

                if energy.isLoading, energy.summary == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let summary = energy.summary, summary.hasAnyValue {
                    tiles(for: summary)
                    if summary.hasCostData {
                        costTiles(for: summary)
                    }
                    if !summary.flowLinks.isEmpty {
                        distribution(for: summary)
                    }
                    if !summary.buckets.isEmpty {
                        chart(for: summary)
                    }
                    if !summary.devices.isEmpty {
                        devices(for: summary)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.top, 30)
            .padding(.bottom, 80)
        }
        .task(id: energy.period) {
            await energy.loadSummary()
        }
    }

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EnergyService.Period.allCases) { option in
                    Button {
                        energy.period = option
                    } label: {
                        Text(option.title)
                            .font(.headline)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .foregroundStyle(option == energy.period ? Theme.accent : .primary)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func tiles(for summary: EnergySummary) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3),
            spacing: 20
        ) {
            tile("Verbrauch", value: summary.consumption, symbol: "house.fill", tint: Theme.accent)
            tile("Netzbezug", value: summary.gridImport, symbol: "bolt.horizontal.fill", tint: .orange)

            if summary.solar > 0 {
                tile("Solar", value: summary.solar, symbol: "sun.max.fill", tint: .yellow)
            }
            if summary.gridExport > 0 {
                tile("Einspeisung", value: summary.gridExport, symbol: "arrow.up.right", tint: .green)
            }
            if summary.batteryDischarge > 0 || summary.batteryCharge > 0 {
                tile("Batterie raus", value: summary.batteryDischarge, symbol: "battery.100.bolt", tint: .teal)
                tile("Batterie rein", value: summary.batteryCharge, symbol: "battery.50", tint: .teal)
            }
            if summary.gas > 0 {
                tile("Gas", value: summary.gas, symbol: "flame.fill", tint: .red, unit: "m³")
            }
            if summary.water > 0 {
                tile("Wasser", value: summary.water, symbol: "drop.fill", tint: .blue, unit: "m³")
            }
            if let share = summary.selfSufficiency {
                tile(
                    "Autarkie",
                    value: share * 100,
                    symbol: "leaf.fill",
                    tint: .green,
                    unit: "%"
                )
            }
        }
    }

    private func costTiles(for summary: EnergySummary) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3),
            spacing: 20
        ) {
            moneyTile(
                summary.netCost >= 0 ? "Kosten" : "Ertrag",
                value: abs(summary.netCost),
                symbol: "eurosign.circle.fill",
                tint: summary.netCost >= 0 ? Theme.accent : .green
            )
            if summary.gridCost != 0 {
                moneyTile("Strombezug", value: summary.gridCost, symbol: "bolt.horizontal.fill", tint: .orange)
            }
            if summary.gridCompensation != 0 {
                moneyTile("Einspeisung", value: summary.gridCompensation, symbol: "arrow.up.right", tint: .green)
            }
            if summary.gasCost != 0 {
                moneyTile("Gas", value: summary.gasCost, symbol: "flame.fill", tint: .red)
            }
            if summary.waterCost != 0 {
                moneyTile("Wasser", value: summary.waterCost, symbol: "drop.fill", tint: .blue)
            }
        }
    }

    private func moneyTile(
        _ title: String,
        value: Double,
        symbol: String,
        tint: Color
    ) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(formattedCurrency(value))
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    /// Home Assistant reports the instance currency as an ISO code.
    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = store.config?.currency ?? "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? HANumber.format(value, maximumFractionDigits: 2)
    }

    private func tile(
        _ title: String,
        value: Double,
        symbol: String,
        tint: Color,
        unit: String = "kWh"
    ) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text("\(HANumber.format(value, maximumFractionDigits: 2)) \(unit)")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private func chart(for summary: EnergySummary) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(title: "Verlauf", subtitle: energy.period.title)

                Chart {
                    ForEach(summary.buckets) { bucket in
                        BarMark(
                            x: .value("Zeit", bucket.date),
                            y: .value("kWh", bucket.gridImport)
                        )
                        .foregroundStyle(by: .value("Quelle", "Netz"))

                        if bucket.solar > 0 {
                            BarMark(
                                x: .value("Zeit", bucket.date),
                                y: .value("kWh", bucket.solar)
                            )
                            .foregroundStyle(by: .value("Quelle", "Solar"))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Netz": Color.orange,
                    "Solar": Color.yellow,
                ])
                .chartLegend(position: .bottom)
                .frame(height: 300)
            }
        }
    }

    private func distribution(for summary: EnergySummary) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Energieverteilung",
                    subtitle: "Woher die Energie kam und wohin sie ging"
                )
                EnergyDistributionView(links: summary.flowLinks)
            }
        }
    }

    private func devices(for summary: EnergySummary) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(title: "Geräte", subtitle: "Größte Verbraucher")

                ForEach(summary.devices.prefix(14)) { device in
                    HStack(spacing: 12) {
                        // Nested devices are sub-meters of the row above them.
                        if device.depth > 0 {
                            Rectangle()
                                .fill(Theme.inactive.opacity(0.5))
                                .frame(width: 2)
                                .padding(.leading, CGFloat(device.depth - 1) * 24)
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(device.name)
                            .lineLimit(1)
                            .foregroundStyle(device.depth > 0 ? .secondary : .primary)

                        Spacer(minLength: 20)

                        if let share = device.shareOfParent {
                            Text("\(Int((share * 100).rounded())) %")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("\(HANumber.format(device.value, maximumFractionDigits: 2)) kWh")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                    .frame(height: 34)
                    Divider()
                }

                if summary.untrackedConsumption > 0 {
                    HStack {
                        Text("Nicht erfasst")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 20)
                        Text("\(HANumber.format(summary.untrackedConsumption, maximumFractionDigits: 2)) kWh")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                    .padding(.top, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Für diesen Zeitraum liegen keine Energiedaten vor.")
                .font(.title3)
                .foregroundStyle(.secondary)
            if let error = energy.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(Theme.unavailable)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}
