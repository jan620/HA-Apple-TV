import Foundation

enum HAAuthError: LocalizedError {
    case invalidResponse
    case http(status: Int, message: String?)
    case flowAborted(String?)
    case noProviders
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unerwartete Antwort vom Home Assistant Server."
        case .http(let status, let message):
            if let message, !message.isEmpty {
                return "Server antwortete mit \(status): \(message)"
            }
            return "Server antwortete mit HTTP \(status)."
        case .flowAborted(let reason):
            return "Anmeldung abgebrochen\(reason.map { " (\($0))" } ?? "")."
        case .noProviders:
            return "Der Server meldet keine Anmelde-Provider. Ist die Ersteinrichtung (Onboarding) abgeschlossen?"
        case .notAuthenticated:
            return "Nicht angemeldet."
        }
    }
}

/// Accepts any server certificate. Only installed when the user explicitly
/// enables it for a server, which is the practical escape hatch for the
/// self-signed certificates common on home installs.
private final class PermissiveTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

enum HASessionFactory {
    static func makeSession(allowsUntrustedCertificate: Bool) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        guard allowsUntrustedCertificate else {
            return URLSession(configuration: configuration)
        }
        return URLSession(
            configuration: configuration,
            delegate: PermissiveTrustDelegate(),
            delegateQueue: nil
        )
    }
}

/// Implements Home Assistant's IndieAuth-flavoured OAuth 2 flow without a web
/// view — tvOS has no WebKit, so the login page is reproduced natively from the
/// step descriptions the server returns.
struct HAAuthClient {
    let server: HAServer
    let session: URLSession

    init(server: HAServer, session: URLSession? = nil) {
        self.server = server
        self.session = session ?? HASessionFactory.makeSession(
            allowsUntrustedCertificate: server.allowsUntrustedCertificate
        )
    }

    // MARK: Login flow

    func providers() async throws -> [AuthProvider] {
        let request = URLRequest(url: server.url(path: "/auth/providers"))
        let data = try await perform(request)
        let providers = try JSONDecoder().decode([AuthProvider].self, from: data)
        guard !providers.isEmpty else { throw HAAuthError.noProviders }
        return providers
    }

    func startLogin(with provider: AuthProvider) async throws -> LoginFlowStep {
        let body: JSONValue = .object([
            "client_id": .string(server.clientID),
            "handler": provider.handler,
            "redirect_uri": .string(server.redirectURI),
            "type": .string("authorize"),
        ])
        return try await postJSON(url: server.url(path: "/auth/login_flow"), body: body)
    }

    func submit(flowID: String, input: [String: JSONValue]) async throws -> LoginFlowStep {
        var payload = input
        payload["client_id"] = .string(server.clientID)
        return try await postJSON(
            url: server.url(path: "/auth/login_flow/\(flowID)"),
            body: .object(payload)
        )
    }

    /// Abandons a flow the user backed out of, so it does not linger server-side.
    func deleteFlow(flowID: String) async {
        var request = URLRequest(url: server.url(path: "/auth/login_flow/\(flowID)"))
        request.httpMethod = "DELETE"
        _ = try? await session.data(for: request)
    }

    // MARK: Tokens

    func exchange(authorizationCode code: String) async throws -> HATokens {
        let response: TokenResponse = try await postForm([
            "grant_type": "authorization_code",
            "code": code,
            "client_id": server.clientID,
        ])
        guard let refreshToken = response.refreshToken else {
            throw HAAuthError.invalidResponse
        }
        return HATokens(
            accessToken: response.accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
    }

    func refresh(using refreshToken: String) async throws -> HATokens {
        let response: TokenResponse = try await postForm([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": server.clientID,
        ])
        // The refresh grant does not re-issue the refresh token; the existing
        // one stays valid until revoked.
        return HATokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
    }

    func revoke(refreshToken: String) async {
        var request = URLRequest(url: server.url(path: "/auth/revoke"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(["token": refreshToken, "action": "revoke"])
        _ = try? await session.data(for: request)
    }

    // MARK: Plumbing

    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: TimeInterval
        let refreshToken: String?

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }

    private struct ErrorResponse: Decodable {
        let error: String?
        let errorDescription: String?
        let message: String?

        private enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
            case message
        }

        var text: String? {
            errorDescription ?? message ?? error
        }
    }

    private func postJSON(url: URL, body: JSONValue) async throws -> LoginFlowStep {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await perform(request)
        return try JSONDecoder().decode(LoginFlowStep.self, from: data)
    }

    private func postForm(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: server.url(path: "/auth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(fields)
        let data = try await perform(request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HAAuthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw HAAuthError.http(status: http.statusCode, message: decoded?.text)
        }
        return data
    }

    private static func formEncode(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}
