import Combine
import Foundation
import SwiftUI

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

    /// How long the app waits before showing its ambient screen.
    enum ScreensaverDelay: Int, CaseIterable, Identifiable {
        case oneMinute = 60
        case twoMinutes = 120
        case fiveMinutes = 300
        case tenMinutes = 600

        var id: Int { rawValue }
        var seconds: TimeInterval { TimeInterval(rawValue) }
        var title: String { "\(rawValue / 60) Min" }
    }

    /// The accent the ambient screen draws its icons and glow in. Kept muted
    /// throughout: this screen runs for hours on a panel that can burn in.
    enum ScreensaverPalette: String, CaseIterable, Identifiable {
        case blue
        case amber
        case green
        case violet
        case monochrome

        var id: String { rawValue }

        var title: String {
            switch self {
            case .blue: return "Blau"
            case .amber: return "Bernstein"
            case .green: return "Grün"
            case .violet: return "Violett"
            case .monochrome: return "Neutral"
            }
        }

        var accent: Color {
            switch self {
            case .blue: return Color(red: 0.011, green: 0.662, blue: 0.956)
            case .amber: return Color(red: 1.0, green: 0.72, blue: 0.30)
            case .green: return Color(red: 0.30, green: 0.83, blue: 0.55)
            case .violet: return Color(red: 0.70, green: 0.52, blue: 0.98)
            case .monochrome: return Color(white: 0.80)
            }
        }
    }

    /// Typeface of the clock and the readings.
    enum ScreensaverTypeface: String, CaseIterable, Identifiable {
        case rounded
        case standard
        case serif
        case monospaced

        var id: String { rawValue }

        var title: String {
            switch self {
            case .rounded: return "Rund"
            case .standard: return "Standard"
            case .serif: return "Serif"
            case .monospaced: return "Technisch"
            }
        }

        var design: Font.Design {
            switch self {
            case .rounded: return .rounded
            case .standard: return .default
            case .serif: return .serif
            case .monospaced: return .monospaced
            }
        }
    }

    /// How long one background picture stays before the next one fades in.
    enum ScreensaverImageInterval: Int, CaseIterable, Identifiable {
        case fifteenSeconds = 15
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300

        var id: Int { rawValue }
        var seconds: TimeInterval { TimeInterval(rawValue) }

        var title: String {
            rawValue < 60 ? "\(rawValue) Sek" : "\(rawValue / 60) Min"
        }
    }

    @Published private(set) var screensaverEnabled: Bool
    @Published private(set) var screensaverDelay: ScreensaverDelay
    /// Ordered, because the ambient screen shows them in this sequence.
    @Published private(set) var screensaverEntityIDs: [String]
    @Published private(set) var screensaverShowsClock: Bool
    @Published private(set) var screensaverPalette: ScreensaverPalette
    @Published private(set) var screensaverTypeface: ScreensaverTypeface
    /// A `media-source://…` folder whose pictures play behind the ambient
    /// screen. `nil` keeps the plain dark background.
    @Published private(set) var screensaverImageFolderID: String?
    @Published private(set) var screensaverImageFolderTitle: String?
    @Published private(set) var screensaverImageInterval: ScreensaverImageInterval

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
        static let screensaverEnabled = "screensaver.enabled"
        static let screensaverDelay = "screensaver.delay"
        static let screensaverEntities = "screensaver.entities"
        static let screensaverClock = "screensaver.showsClock"
        static let screensaverPalette = "screensaver.palette"
        static let screensaverTypeface = "screensaver.typeface"
        static let screensaverImageFolder = "screensaver.imageFolder"
        static let screensaverImageFolderTitle = "screensaver.imageFolderTitle"
        static let screensaverImageInterval = "screensaver.imageInterval"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Key.completed)
        contentMode = defaults.string(forKey: Key.mode)
            .flatMap(ContentMode.init(rawValue:)) ?? .both
        selectedDashboardIDs = Set(defaults.stringArray(forKey: Key.dashboards) ?? [])
        selectedAreaIDs = Set(defaults.stringArray(forKey: Key.areas) ?? [])

        screensaverEnabled = defaults.bool(forKey: Key.screensaverEnabled)
        screensaverDelay = ScreensaverDelay(rawValue: defaults.integer(forKey: Key.screensaverDelay))
            ?? .fiveMinutes
        screensaverEntityIDs = defaults.stringArray(forKey: Key.screensaverEntities) ?? []
        // A clock is what makes an ambient screen useful at a glance, so it is
        // on unless the user says otherwise — which `bool(forKey:)` cannot
        // express on its own, hence the explicit "was it ever set" check.
        screensaverShowsClock = defaults.object(forKey: Key.screensaverClock) as? Bool ?? true
        screensaverPalette = defaults.string(forKey: Key.screensaverPalette)
            .flatMap(ScreensaverPalette.init(rawValue:)) ?? .blue
        screensaverTypeface = defaults.string(forKey: Key.screensaverTypeface)
            .flatMap(ScreensaverTypeface.init(rawValue:)) ?? .rounded
        screensaverImageFolderID = defaults.string(forKey: Key.screensaverImageFolder)
        screensaverImageFolderTitle = defaults.string(forKey: Key.screensaverImageFolderTitle)
        screensaverImageInterval = ScreensaverImageInterval(
            rawValue: defaults.integer(forKey: Key.screensaverImageInterval)
        ) ?? .oneMinute
    }

    // MARK: Screensaver

    func setScreensaverEnabled(_ enabled: Bool) {
        screensaverEnabled = enabled
        defaults.set(enabled, forKey: Key.screensaverEnabled)
    }

    func setScreensaverDelay(_ delay: ScreensaverDelay) {
        screensaverDelay = delay
        defaults.set(delay.rawValue, forKey: Key.screensaverDelay)
    }

    func toggleScreensaverEntity(_ entityID: String) {
        if let index = screensaverEntityIDs.firstIndex(of: entityID) {
            screensaverEntityIDs.remove(at: index)
        } else {
            screensaverEntityIDs.append(entityID)
        }
        defaults.set(screensaverEntityIDs, forKey: Key.screensaverEntities)
    }

    func setScreensaverShowsClock(_ shows: Bool) {
        screensaverShowsClock = shows
        defaults.set(shows, forKey: Key.screensaverClock)
    }

    func setScreensaverPalette(_ palette: ScreensaverPalette) {
        screensaverPalette = palette
        defaults.set(palette.rawValue, forKey: Key.screensaverPalette)
    }

    func setScreensaverTypeface(_ typeface: ScreensaverTypeface) {
        screensaverTypeface = typeface
        defaults.set(typeface.rawValue, forKey: Key.screensaverTypeface)
    }

    /// Passing `nil` returns the ambient screen to its plain dark background.
    func setScreensaverImageFolder(id: String?, title: String?) {
        screensaverImageFolderID = id
        screensaverImageFolderTitle = title
        defaults.set(id, forKey: Key.screensaverImageFolder)
        defaults.set(title, forKey: Key.screensaverImageFolderTitle)
    }

    func setScreensaverImageInterval(_ interval: ScreensaverImageInterval) {
        screensaverImageInterval = interval
        defaults.set(interval.rawValue, forKey: Key.screensaverImageInterval)
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
        screensaverEnabled = false
        screensaverDelay = .fiveMinutes
        screensaverEntityIDs = []
        screensaverShowsClock = true
        screensaverPalette = .blue
        screensaverTypeface = .rounded
        screensaverImageFolderID = nil
        screensaverImageFolderTitle = nil
        screensaverImageInterval = .oneMinute
        for key in [
            Key.completed, Key.mode, Key.dashboards, Key.areas,
            Key.screensaverEnabled, Key.screensaverDelay, Key.screensaverEntities,
            Key.screensaverClock, Key.screensaverPalette, Key.screensaverTypeface,
            Key.screensaverImageFolder, Key.screensaverImageFolderTitle,
            Key.screensaverImageInterval,
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
