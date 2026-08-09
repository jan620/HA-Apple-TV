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

    /// An energy stream and, where configured, the statistic holding its money
    /// value. When the user entered a price instead of a cost statistic, Home
    /// Assistant creates the cost sensor itself and keeps the mapping in
    /// `energy/info` rather than writing it back here — hence the optional.
    struct Flow: Equatable {
        let energyStatisticID: String
        let costStatisticID: String?
    }

    var gridImport: [Flow] = []
    var gridExport: [Flow] = []
    var solar: [String] = []
    /// Battery discharge — energy flowing out of the battery into the house.
    var batteryDischarge: [String] = []
    /// Battery charge — energy flowing into the battery.
    var batteryCharge: [String] = []
    var gas: [Flow] = []
    var water: [Flow] = []
    var devices: [Device] = []

    var gridImportStats: [String] { gridImport.map(\.energyStatisticID) }
    var gridExportStats: [String] { gridExport.map(\.energyStatisticID) }
    var gasStats: [String] { gas.map(\.energyStatisticID) }
    var waterStats: [String] { water.map(\.energyStatisticID) }

    var isEmpty: Bool {
        gridImport.isEmpty && gridExport.isEmpty && solar.isEmpty
            && batteryDischarge.isEmpty && batteryCharge.isEmpty
            && gas.isEmpty && water.isEmpty && devices.isEmpty
    }

    /// Resolves a flow's money statistic, falling back to the sensor Home
    /// Assistant generated from a configured price.
    func costStatisticIDs(for flows: [Flow], costSensors: [String: String]) -> [String] {
        flows.compactMap { $0.costStatisticID ?? costSensors[$0.energyStatisticID] }
    }

    /// Every statistic the summary needs, deduplicated.
    func allStatisticIDs(costSensors: [String: String]) -> [String] {
        var seen = Set<String>()
        let energy = gridImportStats + gridExportStats + solar
            + batteryDischarge + batteryCharge + gasStats + waterStats
            + devices.map(\.statisticID)
        let money = costStatisticIDs(for: gridImport, costSensors: costSensors)
            + costStatisticIDs(for: gridExport, costSensors: costSensors)
            + costStatisticIDs(for: gas, costSensors: costSensors)
            + costStatisticIDs(for: water, costSensors: costSensors)
        return (energy + money).filter { seen.insert($0).inserted }
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
                appendFlow(energy: source["stat_energy_from"], cost: source["stat_cost"], to: &gas)
            case "water":
                appendFlow(energy: source["stat_energy_from"], cost: source["stat_cost"], to: &water)
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
        appendFlow(energy: source["stat_energy_from"], cost: source["stat_cost"], to: &gridImport)
        appendFlow(energy: source["stat_energy_to"], cost: source["stat_compensation"], to: &gridExport)

        // Established shape: one entry per tariff/flow.
        for flow in source["flow_from"]?.arrayValue ?? [] {
            appendFlow(energy: flow["stat_energy_from"], cost: flow["stat_cost"], to: &gridImport)
        }
        for flow in source["flow_to"]?.arrayValue ?? [] {
            appendFlow(energy: flow["stat_energy_to"], cost: flow["stat_compensation"], to: &gridExport)
        }
    }

    private func appendFlow(energy: JSONValue?, cost: JSONValue?, to list: inout [Flow]) {
        guard let id = energy?.stringValue, !id.isEmpty,
              !list.contains(where: { $0.energyStatisticID == id })
        else { return }
        let costID = cost?.stringValue
        list.append(Flow(energyStatisticID: id, costStatisticID: costID?.isEmpty == false ? costID : nil))
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

    /// Money values, in the instance's configured currency.
    var gridCost: Double = 0
    /// Earnings from feeding back into the grid.
    var gridCompensation: Double = 0
    var gasCost: Double = 0
    var waterCost: Double = 0

    var netCost: Double {
        gridCost + gasCost + waterCost - gridCompensation
    }

    var hasCostData: Bool {
        gridCost != 0 || gridCompensation != 0 || gasCost != 0 || waterCost != 0
    }

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
