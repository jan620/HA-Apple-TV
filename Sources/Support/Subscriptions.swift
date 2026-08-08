import Combine
import Foundation

/// Renders a Jinja2 template server-side and keeps it up to date.
///
/// Markdown cards lean on templates heavily, and evaluating them is something
/// only Home Assistant can do — `render_template` pushes a new result whenever
/// any referenced entity changes.
@MainActor
final class TemplateRenderer: ObservableObject {
    @Published private(set) var rendered: String = ""
    @Published private(set) var errorMessage: String?

    private var subscriptionID: Int?

    func start(template: String, client: HAWebSocketClient) async {
        await stop(client: client)
        guard !template.isEmpty else { return }

        do {
            subscriptionID = try await client.subscribe([
                "type": "render_template",
                "template": .string(template),
                "report_errors": .bool(false),
            ]) { [weak self] event in
                guard let self else { return }
                if let result = event["result"] {
                    self.rendered = result.stringValue ?? result.displayString
                    self.errorMessage = nil
                } else if let error = event["error"]?.stringValue {
                    self.errorMessage = error
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop(client: HAWebSocketClient) async {
        guard let subscriptionID else { return }
        self.subscriptionID = nil
        await client.unsubscribe(subscriptionID)
    }
}

/// One forecast entry from `weather/subscribe_forecast`.
struct WeatherForecastEntry: Identifiable, Hashable {
    let id: String
    let date: Date?
    let condition: String?
    let temperature: Double?
    let templow: Double?
    let precipitation: Double?

    init?(json: JSONValue) {
        guard let datetime = json["datetime"]?.stringValue else { return nil }
        id = datetime
        date = HADate.parse(datetime)
        condition = json["condition"]?.stringValue
        temperature = json["temperature"]?.doubleValue
        templow = json["templow"]?.doubleValue
        precipitation = json["precipitation"]?.doubleValue
    }
}

/// Weather forecasts stopped being entity attributes in 2024.4 — they are a
/// subscription now.
@MainActor
final class WeatherForecastSubscription: ObservableObject {
    @Published private(set) var entries: [WeatherForecastEntry] = []

    private var subscriptionID: Int?

    func start(entityID: String, type: String, client: HAWebSocketClient) async {
        await stop(client: client)
        do {
            subscriptionID = try await client.subscribe([
                "type": "weather/subscribe_forecast",
                "entity_id": .string(entityID),
                "forecast_type": .string(type),
            ]) { [weak self] event in
                guard let self, let list = event["forecast"]?.arrayValue else { return }
                self.entries = list.compactMap(WeatherForecastEntry.init(json:))
            }
        } catch {
            entries = []
        }
    }

    func stop(client: HAWebSocketClient) async {
        guard let subscriptionID else { return }
        self.subscriptionID = nil
        await client.unsubscribe(subscriptionID)
    }
}

/// A single entity's recent numeric history, used by the history graph card.
@MainActor
final class HistoryLoader: ObservableObject {
    struct Sample: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    @Published private(set) var samplesByEntity: [String: [Sample]] = [:]
    @Published private(set) var isLoading = false

    func load(entityIDs: [String], hours: Int, client: HAWebSocketClient) async {
        guard !entityIDs.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let end = Date()
        let start = end.addingTimeInterval(-Double(hours) * 3600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let payload: [String: JSONValue] = [
            "type": "history/history_during_period",
            "start_time": .string(formatter.string(from: start)),
            "end_time": .string(formatter.string(from: end)),
            "entity_ids": .strings(entityIDs),
            "minimal_response": .bool(true),
            "no_attributes": .bool(true),
        ]

        guard let response = try? await client.send(payload),
              let byEntity = response.objectValue
        else { return }

        var result: [String: [Sample]] = [:]
        for (entityID, values) in byEntity {
            var samples: [Sample] = []
            for entry in values.arrayValue ?? [] {
                // `minimal_response` compresses entries to {s: state, lu: epoch}
                // after the first, which keeps large ranges manageable.
                guard let state = (entry["s"] ?? entry["state"])?.stringValue,
                      let value = Double(state)
                else { continue }
                let timestamp = (entry["lu"] ?? entry["last_updated"])?.doubleValue ?? 0
                samples.append(Sample(date: Date(timeIntervalSince1970: timestamp), value: value))
            }
            result[entityID] = samples.sorted { $0.date < $1.date }
        }
        samplesByEntity = result
    }
}
