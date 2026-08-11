import Foundation

enum HAAuthError: LocalizedError {
    case invalidResponse
    case http(status: Int, message: String?)
    case notHomeAssistant(path: String, status: Int, contentType: String?, preview: String)
    case unexpectedPayload(path: String, preview: String)
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
        case .notHomeAssistant(let path, let status, let contentType, let preview):
            return """
            Unter dieser Adresse antwortet kein Home Assistant.
            \(path) lieferte HTTP \(status) als \(contentType ?? "unbekannten Inhaltstyp") statt JSON.
            Prüfe Adresse und Port — und ob ein Reverse Proxy die Home-Assistant-API wirklich durchreicht.
            Antwort beginnt mit: \(preview)
            """
        case .unexpectedPayload(let path, let preview):
            return """
            \(path) hat geantwortet, aber nicht in der erwarteten Form.
            Läuft dort eine andere Home-Assistant-Version oder ein Zwischenserver?
            Antwort beginnt mit: \(preview)
            """
        case .flowAborted(let reason):
            return "Anmeldung abgebrochen\(reason.map { " (\($0))" } ?? "")."
        case .noProviders:
            return "Der Server meldet keine Anmelde-Provider. Ist die Ersteinrichtung (Onboarding) abgeschlossen?"
        case .notAuthenticated:
            return "Nicht angemeldet."
        }
    }
}

/// Guards the two ways this app's credentials could leave the configured
/// server.
///
/// The certificate exception is scoped to a single host. Accepting any
/// certificate session-wide would turn the "trust my self-signed cert" switch
/// into a blanket man-in-the-middle hole: every host the session ever talks to
/// — including one it was redirected to — would be trusted unconditionally.
private final class HASessionDelegate: NSObject, URLSessionTaskDelegate {
    /// Host whose certificate the user explicitly chose to trust, if any.
    private let trustedHost: String?

    init(trustedHost: String?) {
        self.trustedHost = trustedHost
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let trustedHost,
              challenge.protectionSpace.host.caseInsensitiveCompare(trustedHost) == .orderedSame
        else {
            // Every other host keeps full TLS validation.
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let originalHost = task.originalRequest?.url?.host,
              let newHost = request.url?.host,
              originalHost.caseInsensitiveCompare(newHost) != .orderedSame
        else {
            completionHandler(request)
            return
        }

        // A redirect to a different host must not carry the bearer token with
        // it — otherwise a compromised server could harvest the access token by
        // pointing any endpoint at itself.
        var stripped = request
        stripped.setValue(nil, forHTTPHeaderField: "Authorization")
        completionHandler(stripped)
    }
}

enum HASessionFactory {
    /// One session for REST, images and the WebSocket, so the certificate
    /// decision and the redirect guard apply everywhere.
    static func makeSession(for server: HAServer?) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let trustedHost = (server?.allowsUntrustedCertificate ?? false) ? server?.baseURL.host : nil
        return URLSession(
            configuration: configuration,
            delegate: HASessionDelegate(trustedHost: trustedHost),
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
        self.session = session ?? HASessionFactory.makeSession(for: server)
    }

    // MARK: Login flow

    func providers() async throws -> [AuthProvider] {
        let request = URLRequest(url: server.url(path: "/auth/providers"))
        let data = try await perform(request)

        // Current releases wrap the list in an object alongside
        // `preselect_remember_me`; older ones answered with a bare array.
        let providers: [AuthProvider]
        if let wrapped = try? JSONDecoder().decode(ProvidersResponse.self, from: data) {
            providers = wrapped.providers
        } else {
            providers = try decode([AuthProvider].self, from: data, path: "/auth/providers")
        }

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

    /// - Returns: whether the server confirmed the revocation. A silent failure
    ///   would leave the token valid while the user believes they signed out.
    @discardableResult
    func revoke(refreshToken: String) async -> Bool {
        var request = URLRequest(url: server.url(path: "/auth/revoke"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(["token": refreshToken, "action": "revoke"])

        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse
        else { return false }
        return (200..<300).contains(http.statusCode)
    }

    // MARK: Plumbing

    private struct ProvidersResponse: Decodable {
        let providers: [AuthProvider]
    }

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
        return try decode(LoginFlowStep.self, from: data, path: url.path)
    }

    private func postForm(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: server.url(path: "/auth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(fields)
        let data = try await perform(request)
        return try decode(TokenResponse.self, from: data, path: "/auth/token")
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HAAuthError.invalidResponse
        }

        let path = request.url?.path ?? "Die Anfrage"

        guard (200..<300).contains(http.statusCode) else {
            let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw HAAuthError.http(status: http.statusCode, message: decoded?.text)
        }

        // A reverse proxy that does not forward the Home Assistant API happily
        // answers 200 with its own HTML. Catching that here turns Foundation's
        // useless "data isn't in the correct format" into something the user
        // can act on.
        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        guard contentType?.localizedCaseInsensitiveContains("json") == true else {
            throw HAAuthError.notHomeAssistant(
                path: path,
                status: http.statusCode,
                contentType: contentType,
                preview: Self.preview(of: data)
            )
        }

        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw HAAuthError.unexpectedPayload(path: path, preview: Self.preview(of: data))
        }
    }

    /// First readable characters of a response body, for error messages.
    private static func preview(of data: Data) -> String {
        let text = String(decoding: data.prefix(400), as: UTF8.self)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return "(leere Antwort)" }
        return text.count > 140 ? String(text.prefix(140)) + " …" : text
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
