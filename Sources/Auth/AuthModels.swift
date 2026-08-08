import Foundation

/// A configured Home Assistant instance.
struct HAServer: Codable, Hashable {
    var baseURL: URL
    var name: String
    /// Home installs frequently terminate TLS with a self-signed certificate.
    /// Opting in is a deliberate, per-server decision surfaced in the setup UI.
    var allowsUntrustedCertificate: Bool

    init(baseURL: URL, name: String, allowsUntrustedCertificate: Bool = false) {
        self.baseURL = baseURL
        self.name = name
        self.allowsUntrustedCertificate = allowsUntrustedCertificate
    }

    /// Accepts what a user can reasonably type on a TV remote: `homeassistant.local:8123`,
    /// `http://192.168.1.10:8123`, `https://abc.ui.nabu.casa/`.
    static func normalizedURL(from input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if !text.contains("://") {
            // Nabu Casa and other public hostnames are TLS; anything that looks
            // like a LAN address is far more likely to be plain http. The
            // 172.16–172.31 range matters: plain `172.` would also capture
            // public addresses and silently downgrade them to cleartext.
            text = (isPrivateAddress(text) ? "http://" : "https://") + text
        }

        while text.hasSuffix("/") {
            text.removeLast()
        }

        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty
        else { return nil }

        components.scheme = scheme
        components.query = nil
        components.fragment = nil
        return components.url
    }

    /// RFC 1918 ranges plus loopback and mDNS names — the addresses where a
    /// Home Assistant install realistically serves plain HTTP.
    private static func isPrivateAddress(_ text: String) -> Bool {
        let host = text.split(separator: "/").first.map(String.init) ?? text
        let hostname = host.split(separator: ":").first.map(String.init) ?? host

        if hostname == "localhost" || hostname.hasSuffix(".local") || hostname == "127.0.0.1" {
            return true
        }
        if hostname.hasPrefix("192.168.") || hostname.hasPrefix("10.") {
            return true
        }

        let octets = hostname.split(separator: ".")
        guard octets.count == 4, octets[0] == "172", let second = Int(octets[1]) else {
            return false
        }
        return (16...31).contains(second)
    }

    /// IndieAuth requires the client identifier to be a URL. Home Assistant
    /// skips the network round-trip that would normally verify it when the
    /// redirect URI shares the client ID's scheme and host, so using the
    /// instance's own origin for both makes the flow work offline — including
    /// for instances reachable only by IP.
    var origin: URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }
        components.path = "/"
        components.query = nil
        components.fragment = nil
        return components.url ?? baseURL
    }

    var clientID: String { origin.absoluteString }
    var redirectURI: String { origin.absoluteString }

    func url(path: String, queryItems: [URLQueryItem] = []) -> URL {
        let base = baseURL.absoluteString
        let suffix = path.hasPrefix("/") ? path : "/" + path
        guard var components = URLComponents(string: base + suffix) else {
            return baseURL
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        return components.url ?? baseURL
    }

    var webSocketURL: URL {
        let url = self.url(path: "/api/websocket")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        return components.url ?? url
    }
}

/// Access + refresh token pair issued by `/auth/token`.
struct HATokens: Codable, Hashable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    /// Treated as expired slightly early so an in-flight request never races
    /// the expiry boundary.
    func isValid(at date: Date = Date()) -> Bool {
        expiresAt.timeIntervalSince(date) > 30
    }
}

/// One entry of `GET /auth/providers`.
struct AuthProvider: Codable, Hashable, Identifiable {
    let name: String
    let id: String?
    let type: String

    /// The `handler` tuple the login flow expects.
    var handler: JSONValue {
        .array([.string(type), id.map(JSONValue.string) ?? .null])
    }
}

/// One step of `POST /auth/login_flow[/{flow_id}]`.
struct LoginFlowStep: Decodable {
    /// `form`, `create_entry` or `abort`.
    let type: String
    let flowID: String?
    let stepID: String?
    let dataSchema: [LoginFlowField]
    let errors: [String: String]
    let reason: String?
    /// On `create_entry` this carries the authorization code.
    let result: JSONValue?

    var authorizationCode: String? {
        guard type == "create_entry" else { return nil }
        return result?.stringValue
    }

    var errorMessage: String? {
        if let reason { return reason }
        return errors["base"] ?? errors.values.first
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case flowID = "flow_id"
        case stepID = "step_id"
        case dataSchema = "data_schema"
        case errors
        case reason
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        flowID = try container.decodeIfPresent(String.self, forKey: .flowID)
        stepID = try container.decodeIfPresent(String.self, forKey: .stepID)
        dataSchema = (try? container.decode([LoginFlowField].self, forKey: .dataSchema)) ?? []
        errors = (try? container.decode([String: String].self, forKey: .errors)) ?? [:]
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        result = try container.decodeIfPresent(JSONValue.self, forKey: .result)
    }
}

/// A single field of a login step, as serialised from the provider's voluptuous
/// schema.
struct LoginFlowField: Decodable, Hashable, Identifiable {
    let name: String
    let type: String?
    let required: Bool?
    let format: String?
    let options: JSONValue?

    var id: String { name }

    var isSecure: Bool {
        format == "password" || name.lowercased().contains("password")
    }

    var isSelection: Bool { type == "select" }

    var isBoolean: Bool { type == "boolean" }

    /// `select` fields arrive either as `[[value, label], …]` or `[value, …]`.
    var selectOptions: [(value: String, label: String)] {
        guard let entries = options?.arrayValue else { return [] }
        return entries.compactMap { entry in
            if let pair = entry.arrayValue, let value = pair.first?.stringValue {
                return (value, pair.count > 1 ? (pair[1].stringValue ?? value) : value)
            }
            if let value = entry.stringValue {
                return (value, value)
            }
            return nil
        }
    }

    /// Field names come from Home Assistant's auth providers and are stable, so
    /// the common ones get a German label instead of a raw key.
    var localizedLabel: String {
        switch name {
        case "username": return "Benutzername"
        case "password": return "Passwort"
        case "code": return "Bestätigungscode"
        default: return name.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
