import Foundation

/// The statistic IDs behind Home Assistant's energy dashboard, flattened out of
/// `energy/get_prefs`.
///
/// The grid source has been expressed two ways across releases: as `flow_from`
/// / `flow_to` arrays, and as `stat_energy_from` / `stat_energy_to` directly on
/// the source. Both are read here rather than betting on one.
struct EnergyPreferences: Equatable {
    struct Device: Identifiable, Equatable {
        let statisticID: String
        let name: String?
        var id: String { statisticID }
    }

    var gridImport: [String] = []
    var gridExport: [String] = []
    var solar: [String] = []
    /// Battery discharge — energy flowing out of the battery into the house.
    var batteryDischarge: [String] = []
    /// Battery charge — energy flowing into the battery.
    var batteryCharge: [String] = []
    var gas: [String] = []
    var water: [String] = []
    var devices: [Device] = []

    var isEmpty: Bool {
        gridImport.isEmpty && gridExport.isEmpty && solar.isEmpty
            && batteryDischarge.isEmpty && batteryCharge.isEmpty
            && gas.isEmpty && water.isEmpty && devices.isEmpty
    }

    /// Every statistic the summary needs, deduplicated.
    var allStatisticIDs: [String] {
        var seen = Set<String>()
        return (gridImport + gridExport + solar + batteryDischarge + batteryCharge
            + gas + water + devices.map(\.statisticID))
            .filter { seen.insert($0).inserted }
    }

    init() {}

    init(json: JSONValue) {
        for source in json["energy_sources"]?.arrayValue ?? [] {
            switch source["type"]?.stringValue ?? "" {
            case "grid":
                appendGrid(source)
            case "solar":
                append(source["stat_energy_from"], to: &solar)
            case "battery":
                append(source["stat_energy_from"], to: &batteryDischarge)
                append(source["stat_energy_to"], to: &batteryCharge)
            case "gas":
                append(source["stat_energy_from"], to: &gas)
            case "water":
                append(source["stat_energy_from"], to: &water)
            default:
                break
            }
        }

        for entry in json["device_consumption"]?.arrayValue ?? [] {
            guard let statisticID = entry["stat_consumption"]?.stringValue else { continue }
            devices.append(Device(statisticID: statisticID, name: entry["name"]?.stringValue))
        }
    }

    private mutating func appendGrid(_ source: JSONValue) {
        // Newer shape: the statistics sit on the source itself.
        append(source["stat_energy_from"], to: &gridImport)
        append(source["stat_energy_to"], to: &gridExport)

        // Established shape: one entry per tariff/flow.
        for flow in source["flow_from"]?.arrayValue ?? [] {
            append(flow["stat_energy_from"], to: &gridImport)
        }
        for flow in source["flow_to"]?.arrayValue ?? [] {
            append(flow["stat_energy_to"], to: &gridExport)
        }
    }

    private func append(_ value: JSONValue?, to list: inout [String]) {
        guard let id = value?.stringValue, !id.isEmpty, !list.contains(id) else { return }
        list.append(id)
    }
}

/// Aggregated energy figures for one time range.
struct EnergySummary: Equatable {
    struct Bucket: Identifiable, Equatable {
        let date: Date
        let gridImport: Double
        let gridExport: Double
        let solar: Double
        var id: Date { date }
    }

    struct DeviceUsage: Identifiable, Equatable {
        let name: String
        let value: Double
        var id: String { name }
    }

    var gridImport: Double = 0
    var gridExport: Double = 0
    var solar: Double = 0
    var batteryCharge: Double = 0
    var batteryDischarge: Double = 0
    var gas: Double = 0
    var water: Double = 0
    var devices: [DeviceUsage] = []
    var buckets: [Bucket] = []

    /// Home Assistant's own definition: everything that arrived minus what went
    /// back out.
    var consumption: Double {
        max(gridImport - gridExport + solar + batteryDischarge - batteryCharge, 0)
    }

    /// Share of consumption that did not come from the grid.
    var selfSufficiency: Double? {
        let total = consumption
        guard total > 0 else { return nil }
        return max(min((total - gridImport) / total, 1), 0)
    }

    var hasAnyValue: Bool {
        gridImport > 0 || gridExport > 0 || solar > 0
            || batteryDischarge > 0 || batteryCharge > 0
            || gas > 0 || water > 0 || !devices.isEmpty
    }
}
