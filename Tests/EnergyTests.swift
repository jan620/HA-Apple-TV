import XCTest
@testable import HomeDash

/// The energy dashboard is rebuilt from raw statistics, so its parsing and its
/// derived flows carry the whole feature. The grid source in particular has two
/// shapes across Home Assistant versions.
final class EnergyPreferencesTests: XCTestCase {
    private func preferences(_ json: String) throws -> EnergyPreferences {
        EnergyPreferences(json: try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8)))
    }

    func testReadsTheFlowBasedGridShape() throws {
        let prefs = try preferences("""
        {
          "energy_sources": [{
            "type": "grid",
            "flow_from": [{"stat_energy_from": "sensor.import", "stat_cost": "sensor.import_cost"}],
            "flow_to": [{"stat_energy_to": "sensor.export", "stat_compensation": "sensor.export_money"}]
          }],
          "device_consumption": []
        }
        """)

        XCTAssertEqual(prefs.gridImportStats, ["sensor.import"])
        XCTAssertEqual(prefs.gridExportStats, ["sensor.export"])
        XCTAssertEqual(
            prefs.costStatisticIDs(for: prefs.gridImport, costSensors: [:]),
            ["sensor.import_cost"]
        )
        XCTAssertEqual(
            prefs.costStatisticIDs(for: prefs.gridExport, costSensors: [:]),
            ["sensor.export_money"]
        )
    }

    func testReadsTheFlatGridShape() throws {
        let prefs = try preferences("""
        {
          "energy_sources": [{
            "type": "grid",
            "stat_energy_from": "sensor.import",
            "stat_energy_to": "sensor.export",
            "stat_cost": "sensor.import_cost"
          }],
          "device_consumption": []
        }
        """)

        XCTAssertEqual(prefs.gridImportStats, ["sensor.import"])
        XCTAssertEqual(prefs.gridExportStats, ["sensor.export"])
    }

    /// When only a price is configured, Home Assistant generates the cost
    /// sensor and keeps the mapping in `energy/info` instead of the prefs.
    func testFallsBackToGeneratedCostSensors() throws {
        let prefs = try preferences("""
        {
          "energy_sources": [{
            "type": "grid",
            "flow_from": [{"stat_energy_from": "sensor.import", "stat_cost": null}]
          }],
          "device_consumption": []
        }
        """)

        XCTAssertEqual(prefs.costStatisticIDs(for: prefs.gridImport, costSensors: [:]), [])
        XCTAssertEqual(
            prefs.costStatisticIDs(
                for: prefs.gridImport,
                costSensors: ["sensor.import": "sensor.import_cost"]
            ),
            ["sensor.import_cost"]
        )
    }

    func testReadsSolarBatteryAndDevices() throws {
        let prefs = try preferences("""
        {
          "energy_sources": [
            {"type": "solar", "stat_energy_from": "sensor.pv"},
            {"type": "battery", "stat_energy_from": "sensor.batt_out", "stat_energy_to": "sensor.batt_in"}
          ],
          "device_consumption": [
            {"stat_consumption": "sensor.dishwasher", "name": "Spülmaschine"},
            {"stat_consumption": "sensor.dishwasher_motor", "included_in_stat": "sensor.dishwasher"}
          ]
        }
        """)

        XCTAssertEqual(prefs.solar, ["sensor.pv"])
        XCTAssertEqual(prefs.batteryDischarge, ["sensor.batt_out"])
        XCTAssertEqual(prefs.batteryCharge, ["sensor.batt_in"])
        XCTAssertEqual(prefs.devices.count, 2)
        XCTAssertNil(prefs.devices[0].includedInStat)
        XCTAssertEqual(prefs.devices[1].includedInStat, "sensor.dishwasher")
    }

    func testEmptyPreferencesAreRecognised() throws {
        XCTAssertTrue(try preferences(#"{"energy_sources":[],"device_consumption":[]}"#).isEmpty)
    }

    func testStatisticListIncludesCostsAndIsDeduplicated() throws {
        let prefs = try preferences("""
        {
          "energy_sources": [
            {"type": "grid", "flow_from": [{"stat_energy_from": "sensor.import", "stat_cost": "sensor.cost"}]},
            {"type": "solar", "stat_energy_from": "sensor.pv"}
          ],
          "device_consumption": [{"stat_consumption": "sensor.pv"}]
        }
        """)

        let ids = prefs.allStatisticIDs(costSensors: [:])
        XCTAssertEqual(Set(ids), ["sensor.import", "sensor.pv", "sensor.cost"])
        XCTAssertEqual(ids.count, Set(ids).count, "Statistik-IDs dürfen nicht doppelt angefragt werden")
    }
}

final class EnergySummaryTests: XCTestCase {
    func testConsumptionFollowsTheHomeAssistantDefinition() {
        var summary = EnergySummary()
        summary.gridImport = 10
        summary.gridExport = 2
        summary.solar = 6
        summary.batteryDischarge = 1
        summary.batteryCharge = 3

        // 10 - 2 + 6 + 1 - 3
        XCTAssertEqual(summary.consumption, 12, accuracy: 0.0001)
    }

    func testConsumptionNeverGoesNegative() {
        var summary = EnergySummary()
        summary.gridExport = 50
        XCTAssertEqual(summary.consumption, 0)
        XCTAssertNil(summary.selfSufficiency)
    }

    func testSelfSufficiencyIsTheShareNotDrawnFromTheGrid() {
        var summary = EnergySummary()
        summary.gridImport = 4
        summary.solar = 6
        // consumption = 10, of which 4 came from the grid
        XCTAssertEqual(try XCTUnwrap(summary.selfSufficiency), 0.6, accuracy: 0.0001)
    }

    func testFlowsBalanceAgainstTheirSources() throws {
        var summary = EnergySummary()
        summary.solar = 10
        summary.gridImport = 5
        summary.gridExport = 3
        summary.batteryCharge = 4
        summary.batteryDischarge = 2

        let links = summary.flowLinks
        func total(from node: EnergyNode) -> Double {
            links.filter { $0.source == node }.reduce(0) { $0 + $1.value }
        }
        func total(into node: EnergyNode) -> Double {
            links.filter { $0.target == node }.reduce(0) { $0 + $1.value }
        }

        // Every unit leaving a source has to arrive somewhere.
        XCTAssertEqual(total(from: .solar), summary.solar, accuracy: 0.0001)
        XCTAssertEqual(total(from: .grid), summary.gridImport, accuracy: 0.0001)
        XCTAssertEqual(total(from: .batteryOut), summary.batteryDischarge, accuracy: 0.0001)
        XCTAssertEqual(total(into: .batteryIn), summary.batteryCharge, accuracy: 0.0001)
        XCTAssertEqual(total(into: .gridExport), summary.gridExport, accuracy: 0.0001)
        XCTAssertEqual(total(into: .home), summary.consumption, accuracy: 0.0001)
    }

    func testNoFlowsWithoutData() {
        XCTAssertTrue(EnergySummary().flowLinks.isEmpty)
    }

    func testOnlyTopLevelDevicesCountTowardsTheTotal() {
        var summary = EnergySummary()
        summary.devices = [
            .init(statisticID: "a", name: "Küche", value: 10, depth: 0, shareOfParent: nil),
            .init(statisticID: "b", name: "Spülmaschine", value: 4, depth: 1, shareOfParent: 0.4),
            .init(statisticID: "c", name: "Bad", value: 5, depth: 0, shareOfParent: nil),
        ]
        summary.gridImport = 20

        // The nested device is already inside its parent's 10 kWh.
        XCTAssertEqual(summary.trackedDeviceTotal, 15, accuracy: 0.0001)
        XCTAssertEqual(summary.untrackedConsumption, 5, accuracy: 0.0001)
    }
}
