import SwiftUI

/// Step one: pick which Home Assistant to talk to.
struct ServerSetupView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var discovery = ServiceDiscovery()

    @State private var urlText = ""
    @State private var allowsUntrustedCertificate = false
    @State private var isChecking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                header

                if !discovery.instances.isEmpty {
                    discoveredSection
                }

                manualSection

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.unavailable)
                        .font(.callout)
                        // Diagnostics can run several lines; without this they
                        // get truncated to exactly the part that does not help.
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 60)
        }
        .disabled(isChecking)
        .overlay {
            if isChecking {
                ProgressView("Verbinde …")
                    .padding(40)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home Assistant")
                .font(.largeTitle.bold())
            Text("Verbinde dieses Apple TV mit deiner Home Assistant Instanz.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var discoveredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Im Netzwerk gefunden", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)

            ForEach(discovery.instances) { instance in
                Button {
                    connect(to: instance.url, name: instance.name)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(instance.name)
                                .font(.headline)
                            Text(instance.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let version = instance.version {
                            Text(version)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.card)
            }
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Adresse eingeben", systemImage: "keyboard")
                .font(.headline)

            TextField("z. B. homeassistant.local:8123", text: $urlText)
                .textContentType(.URL)
                .autocorrectionDisabled()

            Toggle(isOn: $allowsUntrustedCertificate) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selbstsigniertem Zertifikat vertrauen")
                    Text("Nur aktivieren, wenn deine Instanz HTTPS mit eigenem Zertifikat nutzt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Verbinden") {
                guard let url = HAServer.normalizedURL(from: urlText) else {
                    errorMessage = "Die eingegebene Adresse ist keine gültige URL."
                    return
                }
                connect(to: url, name: url.host ?? "Home Assistant")
            }
            .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func connect(to url: URL, name: String) {
        errorMessage = nil
        isChecking = true

        let server = HAServer(
            baseURL: url,
            name: name,
            allowsUntrustedCertificate: allowsUntrustedCertificate
        )

        Task {
            defer { isChecking = false }
            do {
                // Listing providers both proves the instance is reachable and
                // primes the login screen with what it needs.
                _ = try await HAAuthClient(server: server).providers()
                auth.configure(server: server)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Step two: Home Assistant's login flow, rendered natively from the step
/// descriptions the server sends (tvOS has no web view to host the real page).
struct LoginFlowView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var providers: [AuthProvider] = []
    @State private var provider: AuthProvider?
    @State private var step: LoginFlowStep?
    @State private var textValues: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                if providers.count > 1, step == nil {
                    providerPicker
                } else if let step {
                    form(for: step)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.unavailable)
                        .font(.callout)
                        // Diagnostics can run several lines; without this they
                        // get truncated to exactly the part that does not help.
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Button("Anderen Server wählen", role: .destructive) {
                    Task { await auth.reset() }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 60)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .disabled(isBusy)
        .task { await loadProviders() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anmelden")
                .font(.largeTitle.bold())
            if let server = auth.server {
                Text(server.baseURL.absoluteString)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Anmeldeverfahren")
                .font(.headline)
            ForEach(providers) { entry in
                Button(entry.name) {
                    Task { await start(with: entry) }
                }
                .buttonStyle(.card)
            }
        }
    }

    @ViewBuilder
    private func form(for step: LoginFlowStep) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if step.stepID == "mfa" || step.dataSchema.contains(where: { $0.name == "code" }) {
                Label("Zwei-Faktor-Bestätigung", systemImage: "lock.shield.fill")
                    .font(.headline)
            }

            ForEach(step.dataSchema) { field in
                fieldView(field)
            }

            Button("Weiter") {
                Task { await submit(step) }
            }
            .disabled(step.dataSchema.isEmpty)
        }
    }

    @ViewBuilder
    private func fieldView(_ field: LoginFlowField) -> some View {
        if field.isBoolean {
            Toggle(field.localizedLabel, isOn: binding(bool: field.name))
        } else if field.isSelection {
            Picker(field.localizedLabel, selection: binding(text: field.name)) {
                ForEach(field.selectOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } else if field.isSecure {
            SecureField(field.localizedLabel, text: binding(text: field.name))
        } else {
            TextField(field.localizedLabel, text: binding(text: field.name))
                .autocorrectionDisabled()
        }
    }

    private func binding(text name: String) -> Binding<String> {
        Binding(
            get: { textValues[name] ?? "" },
            set: { textValues[name] = $0 }
        )
    }

    private func binding(bool name: String) -> Binding<Bool> {
        Binding(
            get: { boolValues[name] ?? false },
            set: { boolValues[name] = $0 }
        )
    }

    // MARK: Flow

    private func loadProviders() async {
        guard providers.isEmpty, let client = auth.authClient else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let list = try await client.providers()
            providers = list
            if list.count == 1, let only = list.first {
                await start(with: only)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func start(with provider: AuthProvider) async {
        guard let client = auth.authClient else { return }
        self.provider = provider
        isBusy = true
        defer { isBusy = false }
        do {
            let next = try await client.startLogin(with: provider)
            apply(next)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit(_ step: LoginFlowStep) async {
        guard let client = auth.authClient, let flowID = step.flowID else { return }

        var input: [String: JSONValue] = [:]
        for field in step.dataSchema {
            if field.isBoolean {
                input[field.name] = .bool(boolValues[field.name] ?? false)
            } else {
                input[field.name] = .string(textValues[field.name] ?? "")
            }
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let next = try await client.submit(flowID: flowID, input: input)
            if let code = next.authorizationCode {
                let tokens = try await client.exchange(authorizationCode: code)
                auth.completeLogin(with: tokens)
            } else {
                apply(next)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ next: LoginFlowStep) {
        switch next.type {
        case "abort":
            errorMessage = HAAuthError.flowAborted(next.reason).localizedDescription
            step = nil
        default:
            // A repeated form step means either bad credentials or an extra
            // challenge; either way the previous answers must not carry over.
            if next.stepID != step?.stepID {
                textValues.removeAll()
                boolValues.removeAll()
            } else {
                for field in next.dataSchema where field.isSecure {
                    textValues[field.name] = ""
                }
            }
            errorMessage = next.errorMessage.map(Self.localizedError)
            step = next
        }
    }

    private static func localizedError(_ code: String) -> String {
        switch code {
        case "invalid_auth": return "Benutzername oder Passwort ist falsch."
        case "invalid_code": return "Der Bestätigungscode ist falsch."
        case "too_many_retry": return "Zu viele Fehlversuche. Bitte später erneut probieren."
        default: return code
        }
    }
}
