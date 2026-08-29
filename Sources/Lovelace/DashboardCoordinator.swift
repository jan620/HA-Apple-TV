import SwiftUI

/// Cross-cutting UI state for the dashboard: which entity's detail sheet is
/// open, and pending in-app navigation triggered by a card's `navigate` action.
///
/// Presenting a single sheet from the dashboard shell — instead of one per card
/// — keeps deeply nested stacks from each owning presentation state.
@MainActor
final class DashboardCoordinator: ObservableObject {
    @Published var moreInfoEntityID: String?
    @Published var requestedViewPath: String?
    @Published var requestedDashboardPath: String?

    func showMoreInfo(_ entityID: String) {
        moreInfoEntityID = entityID
    }

    /// Lovelace navigation paths look like `/lovelace/kitchen` or
    /// `/my-dashboard/overview`.
    func navigate(to path: String) {
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        switch components.count {
        case 0:
            return
        case 1:
            requestedViewPath = components[0]
        default:
            requestedDashboardPath = components[0]
            requestedViewPath = components[1]
        }
    }
}

/// What a card does when the user clicks it.
enum CardAction: Equatable {
    case toggle
    case moreInfo
    case navigate(String)
    case performAction(domain: String, service: String, data: [String: JSONValue], entityIDs: [String])
    case none

    /// Parses a `tap_action` / `hold_action` object, falling back to the card's
    /// natural default when the key is absent.
    static func parse(_ value: JSONValue?, default fallback: CardAction) -> CardAction {
        guard let value, let action = value["action"]?.stringValue else { return fallback }

        switch action {
        case "toggle":
            return .toggle
        case "more-info":
            return .moreInfo
        case "none":
            return .none
        case "navigate":
            guard let path = value["navigation_path"]?.stringValue else { return .none }
            return .navigate(path)
        case "call-service", "perform-action":
            // `call-service` is the pre-2024.8 spelling of the same thing.
            let identifier = value["perform_action"]?.stringValue ?? value["service"]?.stringValue
            guard let identifier, let separator = identifier.firstIndex(of: ".") else { return .none }
            let domain = String(identifier[identifier.startIndex..<separator])
            let service = String(identifier[identifier.index(after: separator)...])
            let data = value["data"]?.objectValue ?? value["service_data"]?.objectValue ?? [:]
            let target = value["target"]?["entity_id"]?.stringArrayValue ?? []
            return .performAction(domain: domain, service: service, data: data, entityIDs: target)
        default:
            return fallback
        }
    }
}

/// A focusable card surface that runs the configured tap action.
///
/// On tvOS the Siri Remote's select button is the only reliable primary input,
/// so it performs the card's action and the play/pause button opens the entity
/// detail sheet.
struct CardButton<Content: View>: View {
    enum Appearance {
        /// Standalone card with the system's focus lift and parallax.
        case card
        /// A row inside a larger card — highlights in place instead.
        case row
    }

    let card: LovelaceCardConfig
    let entityID: String?
    var defaultAction: CardAction?
    var appearance: Appearance = .card
    @ViewBuilder var content: () -> Content

    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var coordinator: DashboardCoordinator
    @FocusState private var isFocused: Bool

    var body: some View {
        switch appearance {
        case .card:
            button
                .buttonStyle(.card)
                .onPlayPauseCommand { showDetails() }
        case .row:
            button
                .buttonStyle(.plain)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    isFocused ? Theme.accent.opacity(0.28) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .scaleEffect(isFocused ? 1.015 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
                .onPlayPauseCommand { showDetails() }
        }
    }

    private var button: some View {
        Button {
            Task { await perform(resolvedAction) }
        } label: {
            content()
        }
    }

    private func showDetails() {
        if let entityID { coordinator.showMoreInfo(entityID) }
    }

    private var resolvedAction: CardAction {
        if let explicit = defaultAction {
            return CardAction.parse(card["tap_action"], default: explicit)
        }
        let entity = entityID.flatMap { store.entity($0) }
        let natural: CardAction = (entity?.isToggleable ?? false) || (entity?.isActivatable ?? false)
            ? .toggle
            : .moreInfo
        return CardAction.parse(card["tap_action"], default: natural)
    }

    private func perform(_ action: CardAction) async {
        switch action {
        case .none:
            break
        case .moreInfo:
            if let entityID { coordinator.showMoreInfo(entityID) }
        case .navigate(let path):
            coordinator.navigate(to: path)
        case .toggle:
            guard let entityID, let entity = store.entity(entityID) else { return }
            await store.performPrimaryAction(on: entity)
        case .performAction(let domain, let service, let data, let entityIDs):
            let targets = entityIDs.isEmpty ? [entityID].compactMap { $0 } : entityIDs
            await store.callService(domain: domain, service: service, entityIDs: targets, data: data)
        }
    }
}
