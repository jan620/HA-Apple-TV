import Combine
import Foundation
import OSLog

/// Owns the configured server, the token pair, and the single place that hands
/// out a currently-valid access token.
@MainActor
final class AuthManager: ObservableObject {
    enum State: Equatable {
        case unconfigured
        case needsLogin
        case authenticated
    }

    @Published private(set) var state: State = .unconfigured
    @Published private(set) var server: HAServer?
    /// Set when signing out could not revoke the token server-side.
    @Published private(set) var signOutWarning: String?

    private var tokens: HATokens?
    private var refreshTask: Task<HATokens, Error>?
    private var cachedSession: URLSession?

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "io.roomglance.tvos", category: "auth")

    private static let serverDefaultsKey = "ha.server"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    // MARK: Session

    /// Shared session for REST calls, camera images and the WebSocket, so the
    /// "allow untrusted certificate" decision applies everywhere.
    var session: URLSession {
        if let cachedSession { return cachedSession }
        let session = HASessionFactory.makeSession(for: server)
        cachedSession = session
        return session
    }

    var authClient: HAAuthClient? {
        guard let server else { return nil }
        return HAAuthClient(server: server, session: session)
    }

    // MARK: Lifecycle

    private func restore() {
        guard let data = defaults.data(forKey: Self.serverDefaultsKey),
              let server = try? JSONDecoder().decode(HAServer.self, from: data)
        else {
            state = .unconfigured
            return
        }

        self.server = server
        tokens = KeychainStore.loadJSON(HATokens.self, account: server.origin.absoluteString)
        // An expired access token is fine at this point — the refresh token is
        // what decides whether the session survives, and it is exercised lazily.
        state = tokens == nil ? .needsLogin : .authenticated
    }

    /// Selects the server to log into. Does not authenticate.
    func configure(server: HAServer) {
        self.server = server
        cachedSession = nil
        tokens = nil
        refreshTask?.cancel()
        refreshTask = nil
        persistServer()
        state = .needsLogin
    }

    func completeLogin(with tokens: HATokens) {
        guard let server else { return }
        signOutWarning = nil
        self.tokens = tokens
        persistTokens(tokens, for: server)
        state = .authenticated
    }

    /// Revokes the refresh token and returns to the login screen, keeping the
    /// server configured so the user does not retype the URL.
    func signOut() async {
        signOutWarning = nil

        if let server, let tokens {
            let revoked = await HAAuthClient(server: server, session: session)
                .revoke(refreshToken: tokens.refreshToken)
            if !revoked {
                // The local token is gone either way, but the server still
                // accepts it — the user should know their "sign out" was only
                // half of one.
                logger.error("Token-Widerruf am Server fehlgeschlagen")
                signOutWarning = """
                Abgemeldet, aber der Zugang konnte am Server nicht widerrufen werden. \
                Falls dieses Gerät nicht mehr vertrauenswürdig ist, entziehe den Zugang \
                in Home Assistant unter Profil → Sicherheit.
                """
            }
            KeychainStore.delete(account: server.origin.absoluteString)
        }
        tokens = nil
        refreshTask?.cancel()
        refreshTask = nil
        state = server == nil ? .unconfigured : .needsLogin
    }

    /// Forgets the server entirely.
    func reset() async {
        await signOut()
        server = nil
        cachedSession = nil
        defaults.removeObject(forKey: Self.serverDefaultsKey)
        state = .unconfigured
    }

    /// Swallowing a keychain failure would leave the app "logged in" until the
    /// next launch, with nothing in the log explaining where the session went.
    private func persistTokens(_ tokens: HATokens, for server: HAServer) {
        do {
            try KeychainStore.saveJSON(tokens, account: server.origin.absoluteString)
        } catch {
            logger.error("Token nicht im Keychain gespeichert: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistServer() {
        guard let server, let data = try? JSONEncoder().encode(server) else { return }
        defaults.set(data, forKey: Self.serverDefaultsKey)
    }

    // MARK: Tokens

    /// Returns a token that is valid right now, refreshing it if needed.
    /// Concurrent callers share a single refresh.
    func validAccessToken() async throws -> String {
        guard let server, let current = tokens else {
            throw HAAuthError.notAuthenticated
        }

        if current.isValid() {
            return current.accessToken
        }

        if let refreshTask {
            return try await refreshTask.value.accessToken
        }

        let client = HAAuthClient(server: server, session: session)
        let task = Task { try await client.refresh(using: current.refreshToken) }
        refreshTask = task

        do {
            let refreshed = try await task.value
            refreshTask = nil
            tokens = refreshed
            persistTokens(refreshed, for: server)
            return refreshed.accessToken
        } catch {
            refreshTask = nil
            logger.error("Token-Refresh fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            // A rejected refresh token is terminal: the user revoked it, or the
            // instance was reset. Anything else (network blips) keeps the
            // session so a reconnect can retry later.
            if case HAAuthError.http(let status, _) = error, status == 400 || status == 401 || status == 403 {
                KeychainStore.delete(account: server.origin.absoluteString)
                tokens = nil
                state = .needsLogin
            }
            throw error
        }
    }
}
