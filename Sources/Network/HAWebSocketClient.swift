import Combine
import Foundation
import OSLog

enum HAConnectionError: LocalizedError {
    case notConnected
    case authenticationFailed(String?)
    case authenticationTimedOut
    case command(code: String, message: String?)
    case encoding

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Keine Verbindung zu Home Assistant."
        case .authenticationFailed(let message):
            return message ?? "Anmeldung am WebSocket abgelehnt."
        case .authenticationTimedOut:
            return "Zeitüberschreitung bei der WebSocket-Anmeldung."
        case .command(let code, let message):
            return message ?? "Befehl fehlgeschlagen (\(code))."
        case .encoding:
            return "Nachricht konnte nicht kodiert werden."
        }
    }

    var isConfigNotFound: Bool {
        if case .command(let code, _) = self { return code == "config_not_found" }
        return false
    }
}

/// Event callback for a WebSocket subscription. Isolated to the main actor so
/// subscribers can touch their published state directly.
typealias HAEventHandler = @MainActor (JSONValue) -> Void

/// Long-lived connection to `/api/websocket`.
///
/// Everything runs on the main actor: message volume is modest for a single
/// household, and it removes an entire class of races between the receive loop,
/// the pending-request table and SwiftUI state.
@MainActor
final class HAWebSocketClient: ObservableObject {
    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case disconnected(String?)

        var isConnected: Bool { self == .connected }
    }

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var haVersion: String?

    /// Invoked after every successful (re)authentication, so callers can
    /// re-prime caches and re-establish subscriptions.
    var onConnected: (@MainActor () async -> Void)?

    private let auth: AuthManager
    private let logger = Logger(subsystem: "io.homeassistant.tvos", category: "websocket")

    private var task: URLSessionWebSocketTask?
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var handlers: [Int: HAEventHandler] = [:]

    private var authContinuation: CheckedContinuation<Void, Error>?
    private var authTimeoutTask: Task<Void, Never>?
    private var pendingToken: String?

    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var pingTask: Task<Void, Never>?
    private var isStopped = true

    init(auth: AuthManager) {
        self.auth = auth
    }

    // MARK: Lifecycle

    func connect() {
        isStopped = false
        Task { await establish() }
    }

    func disconnect() {
        isStopped = true
        reconnectTask?.cancel()
        reconnectTask = nil
        teardown(error: nil, reconnect: false)
        connectionState = .idle
    }

    private func establish() async {
        guard !isStopped, task == nil, let server = auth.server else { return }

        connectionState = .connecting

        let token: String
        do {
            token = try await auth.validAccessToken()
        } catch {
            logger.error("Kein gültiges Token: \(error.localizedDescription, privacy: .public)")
            connectionState = .disconnected(error.localizedDescription)
            scheduleReconnect()
            return
        }

        guard !isStopped, task == nil else { return }

        let socket = auth.session.webSocketTask(with: server.webSocketURL)
        // `get_states` on a large instance comfortably exceeds the 1 MiB
        // default and would otherwise kill the connection on first use.
        socket.maximumMessageSize = 32 * 1024 * 1024
        pendingToken = token
        task = socket
        socket.resume()
        receiveNext(on: socket)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                authContinuation = continuation
                startAuthTimeout()
            }
        } catch {
            logger.error("WebSocket-Anmeldung fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            teardown(error: error, reconnect: true)
            return
        }

        reconnectAttempt = 0
        connectionState = .connected
        startPing()
        await onConnected?()
    }

    private func startAuthTimeout() {
        authTimeoutTask?.cancel()
        authTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15 * NSEC_PER_SEC)
            guard !Task.isCancelled else { return }
            self?.finishAuth(with: HAConnectionError.authenticationTimedOut)
        }
    }

    private func finishAuth(with error: Error?) {
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        guard let continuation = authContinuation else { return }
        authContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    private func teardown(error: Error?, reconnect: Bool) {
        guard task != nil || authContinuation != nil else {
            if reconnect { scheduleReconnect() }
            return
        }

        pingTask?.cancel()
        pingTask = nil

        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        pendingToken = nil

        let failure = error ?? HAConnectionError.notConnected
        finishAuth(with: failure)

        let outstanding = pending
        pending.removeAll()
        handlers.removeAll()
        for continuation in outstanding.values {
            continuation.resume(throwing: failure)
        }

        connectionState = .disconnected(error?.localizedDescription)
        if reconnect { scheduleReconnect() }
    }

    private func scheduleReconnect() {
        guard !isStopped, reconnectTask == nil else { return }
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(min(reconnectAttempt, 5))), 30)
        logger.debug("Reconnect in \(delay, privacy: .public)s")

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * Double(NSEC_PER_SEC)))
            guard let self, !Task.isCancelled else { return }
            self.reconnectTask = nil
            await self.establish()
        }
    }

    private func startPing() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * NSEC_PER_SEC)
                guard let self, !Task.isCancelled else { return }
                do {
                    _ = try await self.send(["type": "ping"])
                } catch {
                    guard !Task.isCancelled else { return }
                    self.teardown(error: error, reconnect: true)
                    return
                }
            }
        }
    }

    // MARK: Sending

    @discardableResult
    func send(_ payload: [String: JSONValue]) async throws -> JSONValue {
        guard connectionState.isConnected else { throw HAConnectionError.notConnected }
        return try await send(payload, id: allocateID())
    }

    /// Registers the event handler *before* the subscribe command is sent, so an
    /// event that lands immediately after the acknowledgement is never dropped.
    @discardableResult
    func subscribe(
        _ payload: [String: JSONValue],
        handler: @escaping HAEventHandler
    ) async throws -> Int {
        guard connectionState.isConnected else { throw HAConnectionError.notConnected }
        let id = allocateID()
        handlers[id] = handler
        do {
            _ = try await send(payload, id: id)
            return id
        } catch {
            handlers.removeValue(forKey: id)
            throw error
        }
    }

    func unsubscribe(_ subscriptionID: Int) async {
        handlers.removeValue(forKey: subscriptionID)
        guard connectionState.isConnected else { return }
        _ = try? await send([
            "type": "unsubscribe_events",
            "subscription": .number(Double(subscriptionID)),
        ])
    }

    private func allocateID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func send(_ payload: [String: JSONValue], id: Int) async throws -> JSONValue {
        guard let socket = task else { throw HAConnectionError.notConnected }

        var message = payload
        message["id"] = .number(Double(id))
        let text = try encode(.object(message))

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            socket.send(.string(text)) { [weak self] error in
                guard let error else { return }
                Task { @MainActor in
                    guard let self, let waiting = self.pending.removeValue(forKey: id) else { return }
                    waiting.resume(throwing: error)
                }
            }
        }
    }

    private func sendUnchecked(_ payload: JSONValue) {
        guard let socket = task, let text = try? encode(payload) else { return }
        socket.send(.string(text)) { _ in }
    }

    private func encode(_ value: JSONValue) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HAConnectionError.encoding
        }
        return text
    }

    // MARK: Receiving

    private func receiveNext(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.task === socket else { return }
                switch result {
                case .failure(let error):
                    self.teardown(error: error, reconnect: true)
                case .success(let message):
                    self.handle(message)
                    guard self.task === socket else { return }
                    self.receiveNext(on: socket)
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let payload):
            data = payload
        @unknown default:
            return
        }

        guard let value = try? JSONDecoder().decode(JSONValue.self, from: data),
              let type = value["type"]?.stringValue
        else { return }

        switch type {
        case "auth_required":
            haVersion = value["ha_version"]?.stringValue
            if let token = pendingToken {
                sendUnchecked(.object(["type": "auth", "access_token": .string(token)]))
            }

        case "auth_ok":
            haVersion = value["ha_version"]?.stringValue ?? haVersion
            pendingToken = nil
            finishAuth(with: nil)

        case "auth_invalid":
            pendingToken = nil
            finishAuth(with: HAConnectionError.authenticationFailed(value["message"]?.stringValue))

        case "result":
            guard let id = value["id"]?.intValue,
                  let continuation = pending.removeValue(forKey: id)
            else { return }
            if value["success"]?.boolValue == true {
                continuation.resume(returning: value["result"] ?? .null)
            } else {
                let error = value["error"]
                continuation.resume(throwing: HAConnectionError.command(
                    code: error?["code"]?.stringValue ?? "unknown",
                    message: error?["message"]?.stringValue
                ))
            }

        case "event":
            guard let id = value["id"]?.intValue else { return }
            handlers[id]?(value["event"] ?? .null)

        case "pong":
            guard let id = value["id"]?.intValue,
                  let continuation = pending.removeValue(forKey: id)
            else { return }
            continuation.resume(returning: .null)

        default:
            break
        }
    }
}
