import Combine
import Foundation
import OSLog

/// Rebuilds Home Assistant's energy dashboard from its raw data.
///
/// The energy panel is not a Lovelace dashboard — it is a built-in panel the
/// frontend assembles in JavaScript from energy-specific cards, so it never
/// appears in `lovelace/dashboards/list` and cannot be rendered by the generic
/// card renderer. The numbers themselves come from long-term statistics, which
/// are perfectly reachable over the WebSocket API.
@MainActor
final class EnergyService: ObservableObject {
    enum Period: String, CaseIterable, Identifiable {
        case today
        case yesterday
        case week
        case month

        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: return "Heute"
            case .yesterday: return "Gestern"
            case .week: return "7 Tage"
            case .month: return "Monat"
            }
        }

        /// Hourly buckets read well for a day; anything longer needs daily ones.
        var statisticsPeriod: String {
            switch self {
            case .today, .yesterday: return "hour"
            case .week, .month: return "day"
            }
        }

        func range(now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
            let startOfToday = calendar.startOfDay(for: now)
            switch self {
            case .today:
                return (startOfToday, now)
            case .yesterday:
                let start = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
                return (start, startOfToday)
            case .week:
                let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
                return (start, now)
            case .month:
                let components = calendar.dateComponents([.year, .month], from: now)
                let start = calendar.date(from: components) ?? startOfToday
                return (start, now)
            }
        }
    }

    @Published private(set) var preferences: EnergyPreferences?
    /// Energy statistic ID → cost sensor entity ID, for prices that Home
    /// Assistant turned into a generated cost sensor.
    @Published private(set) var costSensors: [String: String] = [:]
    @Published private(set) var summary: EnergySummary?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var period: Period = .today

    /// True once the instance reports a configured energy dashboard.
    var isConfigured: Bool {
        guard let preferences else { return false }
        return !preferences.isEmpty
    }

    private let client: HAWebSocketClient
    private let logger = Logger(subsystem: "io.homeassistant.tvos", category: "energy")

    init(client: HAWebSocketClient) {
        self.client = client
    }

    func reset() {
        preferences = nil
        costSensors = [:]
        summary = nil
        errorMessage = nil
    }

    /// Probes whether this instance has an energy dashboard at all. Failure is
    /// the normal answer for an install that never set one up.
    func loadPreferences() async {
        do {
            let response = try await client.send(["type": "energy/get_prefs"])
            preferences = EnergyPreferences(json: response)
        } catch {
            logger.info("Kein Energie-Dashboard konfiguriert: \(error.localizedDescription, privacy: .public)")
            preferences = nil
            costSensors = [:]
            return
        }

        // Where the user entered a price rather than a cost statistic, Home
        // Assistant generates the cost sensor and keeps the mapping here
        // instead of writing it back into the preferences.
        if let info = try? await client.send(["type": "energy/info"]),
           let mapping = info["cost_sensors"]?.objectValue {
            costSensors = mapping.compactMapValues(\.stringValue)
        } else {
            costSensors = [:]
        }
    }

    func loadSummary() async {
        guard let preferences, !preferences.isEmpty else { return }

        let statisticIDs = preferences.allStatisticIDs(costSensors: costSensors)
        guard !statisticIDs.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let range = period.range()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let payload: [String: JSONValue] = [
            "type": "recorder/statistics_during_period",
            "start_time": .string(formatter.string(from: range.start)),
            "end_time": .string(formatter.string(from: range.end)),
            "statistic_ids": .strings(statisticIDs),
            "period": .string(period.statisticsPeriod),
            // `change` is the delta per bucket — exactly what the energy
            // dashboard charts, and it saves differencing cumulative sums.
            "types": .array([.string("change")]),
        ]

        do {
            let response = try await client.send(payload)
            summary = Self.summarize(
                response: response,
                preferences: preferences,
                costSensors: costSensors
            )
            errorMessage = nil
        } catch {
            logger.error("Energie-Statistiken fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Aggregation

    private static func summarize(
        response: JSONValue,
        preferences: EnergyPreferences,
        costSensors: [String: String]
    ) -> EnergySummary {
        let byStatistic = response.objectValue ?? [:]

        func total(of ids: [String]) -> Double {
            ids.reduce(0) { runningTotal, id in
                runningTotal + (byStatistic[id]?.arrayValue ?? [])
                    .reduce(0) { $0 + ($1["change"]?.doubleValue ?? 0) }
            }
        }

        func cost(of flows: [EnergyPreferences.Flow]) -> Double {
            total(of: preferences.costStatisticIDs(for: flows, costSensors: costSensors))
        }

        var summary = EnergySummary()
        summary.gridImport = total(of: preferences.gridImportStats)
        summary.gridExport = total(of: preferences.gridExportStats)
        summary.solar = total(of: preferences.solar)
        summary.batteryDischarge = total(of: preferences.batteryDischarge)
        summary.batteryCharge = total(of: preferences.batteryCharge)
        summary.gas = total(of: preferences.gasStats)
        summary.water = total(of: preferences.waterStats)

        summary.gridCost = cost(of: preferences.gridImport)
        summary.gridCompensation = cost(of: preferences.gridExport)
        summary.gasCost = cost(of: preferences.gas)
        summary.waterCost = cost(of: preferences.water)

        summary.devices = preferences.devices
            .map { device in
                EnergySummary.DeviceUsage(
                    name: device.name ?? Self.readableName(from: device.statisticID),
                    value: total(of: [device.statisticID])
                )
            }
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }

        summary.buckets = buckets(byStatistic: byStatistic, preferences: preferences)
        return summary
    }

    /// Groups the per-statistic series into one entry per time bucket so the
    /// chart can plot grid and solar side by side.
    private static func buckets(
        byStatistic: [String: JSONValue],
        preferences: EnergyPreferences
    ) -> [EnergySummary.Bucket] {
        var gridImport: [Date: Double] = [:]
        var gridExport: [Date: Double] = [:]
        var solar: [Date: Double] = [:]

        func accumulate(_ ids: [String], into target: inout [Date: Double]) {
            for id in ids {
                for entry in byStatistic[id]?.arrayValue ?? [] {
                    guard let start = entry["start"]?.doubleValue else { continue }
                    // Statistics timestamps are milliseconds since the epoch.
                    let date = Date(timeIntervalSince1970: start / 1000)
                    target[date, default: 0] += entry["change"]?.doubleValue ?? 0
                }
            }
        }

        accumulate(preferences.gridImportStats, into: &gridImport)
        accumulate(preferences.gridExportStats, into: &gridExport)
        accumulate(preferences.solar, into: &solar)

        let dates = Set(gridImport.keys).union(gridExport.keys).union(solar.keys)
        return dates.sorted().map { date in
            EnergySummary.Bucket(
                date: date,
                gridImport: gridImport[date] ?? 0,
                gridExport: gridExport[date] ?? 0,
                solar: solar[date] ?? 0
            )
        }
    }

    /// `sensor.grid_import_energy` → "Grid Import Energy" for devices that were
    /// never given a friendly name in the energy settings.
    private static func readableName(from statisticID: String) -> String {
        let object = statisticID.split(separator: ".").last.map(String.init) ?? statisticID
        return object.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
