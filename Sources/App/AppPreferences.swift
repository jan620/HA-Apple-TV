import Combine
import Foundation

/// What the user picked during onboarding: whether the app shows their own
/// Lovelace dashboards, one view per area, or both — and which of each.
///
/// A Home Assistant install with a dozen areas produces a dozen tabs. Choosing
/// up front is what keeps the app usable with a remote, so this is a
/// first-class setting rather than something buried in a menu.
@MainActor
final class AppPreferences: ObservableObject {
    enum ContentMode: String, Codable, CaseIterable {
        case areas
        case dashboards
        case both

        var title: String {
            switch self {
            case .areas: return "Räume"
            case .dashboards: return "Dashboards"
            case .both: return "Beides"
            }
        }

        var explanation: String {
            switch self {
            case .areas:
                return "Eine Ansicht pro Bereich, automatisch aus deinen Geräten aufgebaut."
            case .dashboards:
                return "Deine eigenen Lovelace-Dashboards, so wie du sie eingerichtet hast."
            case .both:
                return "Deine Dashboards und zusätzlich die Räume-Ansicht."
            }
        }

        var symbol: String {
            switch self {
            case .areas: return "sofa.fill"
            case .dashboards: return "square.grid.2x2.fill"
            case .both: return "rectangle.stack.fill"
            }
        }

        var includesAreas: Bool { self != .dashboards }
        var includesDashboards: Bool { self != .areas }
    }

    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var contentMode: ContentMode
    /// Empty means "everything the server offers".
    @Published private(set) var selectedDashboardIDs: Set<String>
    @Published private(set) var selectedAreaIDs: Set<String>

    private let defaults: UserDefaults

    private enum Key {
        static let completed = "onboarding.completed"
        static let mode = "onboarding.contentMode"
        static let dashboards = "onboarding.dashboards"
        static let areas = "onboarding.areas"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Key.completed)
        contentMode = defaults.string(forKey: Key.mode)
            .flatMap(ContentMode.init(rawValue:)) ?? .both
        selectedDashboardIDs = Set(defaults.stringArray(forKey: Key.dashboards) ?? [])
        selectedAreaIDs = Set(defaults.stringArray(forKey: Key.areas) ?? [])
    }

    func complete(mode: ContentMode, dashboardIDs: Set<String>, areaIDs: Set<String>) {
        contentMode = mode
        selectedDashboardIDs = dashboardIDs
        selectedAreaIDs = areaIDs

        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(Array(dashboardIDs), forKey: Key.dashboards)
        defaults.set(Array(areaIDs), forKey: Key.areas)

        hasCompletedOnboarding = true
        defaults.set(true, forKey: Key.completed)
    }

    /// Sends the user back through onboarding without touching the login.
    func restartOnboarding() {
        hasCompletedOnboarding = false
        defaults.set(false, forKey: Key.completed)
    }

    /// Called on sign-out — the next account gets its own choices.
    func reset() {
        hasCompletedOnboarding = false
        contentMode = .both
        selectedDashboardIDs = []
        selectedAreaIDs = []
        for key in [Key.completed, Key.mode, Key.dashboards, Key.areas] {
            defaults.removeObject(forKey: key)
        }
    }
}
