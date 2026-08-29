import Combine
import Foundation
import Network

/// Finds Home Assistant instances announced on the local network so the user
/// does not have to type a URL with the Siri Remote.
///
/// Requires the `NSLocalNetworkUsageDescription` and `NSBonjourServices` keys in
/// Info.plist; tvOS prompts for local network access the first time this runs.
@MainActor
final class ServiceDiscovery: ObservableObject {
    struct Instance: Identifiable, Hashable {
        let id: String
        let name: String
        let url: URL
        let version: String?
    }

    @Published private(set) var instances: [Instance] = []
    @Published private(set) var isSearching = false

    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = false

        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_home-assistant._tcp", domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed, .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.apply(results)
            }
        }

        self.browser = browser
        isSearching = true
        browser.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func apply(_ results: Set<NWBrowser.Result>) {
        instances = results
            .compactMap(Self.instance(from:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func instance(from result: NWBrowser.Result) -> Instance? {
        guard case .service(let serviceName, _, _, _) = result.endpoint,
              case .bonjour(let txt) = result.metadata
        else { return nil }

        // Home Assistant publishes its own reachable URL in the TXT record. That
        // is more reliable than resolving the service, because it already
        // reflects the scheme and port the instance is actually served on.
        let candidate = txt["internal_url"] ?? txt["base_url"] ?? txt["external_url"]
        guard let candidate, let url = HAServer.normalizedURL(from: candidate) else { return nil }

        return Instance(
            id: txt["uuid"] ?? url.absoluteString,
            name: txt["location_name"] ?? serviceName,
            url: url,
            version: txt["version"]
        )
    }
}
