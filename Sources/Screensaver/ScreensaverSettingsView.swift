import Foundation
import SwiftUI

/// Configures the ambient screen: whether it runs, after how long, and which
/// entities it shows.
struct ScreensaverSettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var screensaver: ScreensaverController
    @EnvironmentObject private var connection: HAWebSocketClient
    @Environment(\.dismiss) private var dismiss

    /// A room and what it holds. Only the identifiers are kept: entity states
    /// change constantly, and re-deriving this list on every one of those
    /// changes is what made the screen stutter.
    private struct AreaGroup: Identifiable {
        let id: String
        let name: String
        let symbol: String
        let entityIDs: [String]
    }

    @State private var groups: [AreaGroup] = []
    @State private var expandedGroupID: String?

    /// The media browser takes over the whole screen instead of opening a sheet
    /// on top of a sheet, which tvOS handles poorly.
    @State private var isBrowsing = false
    @State private var browsePath: [MediaEntry] = []
    @State private var browseEntries: [MediaEntry] = []
    @State private var browseError: String?

    var body: some View {
        Group {
            if isBrowsing {
                folderBrowser
            } else {
                settingsList
            }
        }
        .onAppear { groups = makeGroups() }
        .onChange(of: inventorySignature) { _, _ in groups = makeGroups() }
        // The ambient screen is a layer inside the dashboard, and a sheet is
        // presented above it — so a screen saver that starts while this is open
        // would be invisible behind it. Get out of its way.
        .onChange(of: screensaver.isActive) { _, isActive in
            if isActive { dismiss() }
        }
        // The Menu button unwinds whatever is deepest: the media browser one
        // folder at a time, then an expanded room, and only then the screen.
        .onExitCommand {
            if isBrowsing {
                if browsePath.isEmpty {
                    isBrowsing = false
                } else {
                    browsePath.removeLast()
                }
            } else if expandedGroupID != nil {
                withAnimation(.easeOut(duration: 0.2)) { expandedGroupID = nil }
            } else {
                dismiss()
            }
        }
    }

    private var settingsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                header
                enableSection
                previewSection

                if preferences.screensaverEnabled {
                    delaySection
                    appearanceSection
                    backgroundSection
                    entitySection
                }

                Button("Fertig") { dismiss() }
                    .padding(.top, 10)
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 50)
            .frame(maxWidth: 1400, alignment: .leading)
        }
    }

    /// Rebuild the rooms only when the inventory itself changes, not when a
    /// light turns on.
    private var inventorySignature: String {
        "\(store.areas.count)|\(store.entities.count)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bildschirmschoner")
                .font(.largeTitle.bold())
            Text("""
            Zeigt Uhrzeit und ausgewählte Entitäten, wenn die App eine Weile \
            unbenutzt bleibt. Solange er aktiv ist, unterdrückt die App den \
            Bildschirmschoner des Apple TV — der eigene erscheint stattdessen.
            """)
            .font(.title3)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var enableSection: some View {
        Toggle(
            "Bildschirmschoner aktivieren",
            isOn: Binding(
                get: { preferences.screensaverEnabled },
                set: { preferences.setScreensaverEnabled($0) }
            )
        )
    }

    /// Starting on demand, plus what the countdown is actually doing. Waiting
    /// out a five-minute delay to find out whether anything happens at all is
    /// no way to check a setting.
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Jetzt anzeigen") {
                screensaver.startNow()
                dismiss()
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(countdownDescription(at: context.date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func countdownDescription(at now: Date) -> String {
        if screensaver.isActive {
            return "Läuft gerade."
        }
        guard preferences.screensaverEnabled else {
            return "Startet nicht von selbst — der Bildschirmschoner ist ausgeschaltet."
        }
        guard let end = screensaver.countdownEndsAt else {
            return "Kein Countdown aktiv."
        }
        let remaining = max(0, Int(end.timeIntervalSince(now).rounded()))
        return String(format: "Startet von selbst in %d:%02d", remaining / 60, remaining % 60)
    }

    private var delaySection: some View {
        RemoteOptionPicker(
            title: "Startet nach",
            options: AppPreferences.ScreensaverDelay.allCases.map { String($0.rawValue) },
            selection: String(preferences.screensaverDelay.rawValue),
            label: { raw in
                AppPreferences.ScreensaverDelay(rawValue: Int(raw) ?? 300)?.title ?? raw
            }
        ) { raw in
            guard let value = Int(raw),
                  let delay = AppPreferences.ScreensaverDelay(rawValue: value)
            else { return }
            preferences.setScreensaverDelay(delay)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Darstellung")
                .font(.headline)

            Toggle(
                "Uhrzeit und Datum anzeigen",
                isOn: Binding(
                    get: { preferences.screensaverShowsClock },
                    set: { preferences.setScreensaverShowsClock($0) }
                )
            )

            RemoteOptionPicker(
                title: "Farbe",
                options: AppPreferences.ScreensaverPalette.allCases.map(\.rawValue),
                selection: preferences.screensaverPalette.rawValue,
                label: { AppPreferences.ScreensaverPalette(rawValue: $0)?.title ?? $0 }
            ) { raw in
                guard let palette = AppPreferences.ScreensaverPalette(rawValue: raw) else { return }
                preferences.setScreensaverPalette(palette)
            }

            RemoteOptionPicker(
                title: "Schrift",
                options: AppPreferences.ScreensaverTypeface.allCases.map(\.rawValue),
                selection: preferences.screensaverTypeface.rawValue,
                label: { AppPreferences.ScreensaverTypeface(rawValue: $0)?.title ?? $0 }
            ) { raw in
                guard let face = AppPreferences.ScreensaverTypeface(rawValue: raw) else { return }
                preferences.setScreensaverTypeface(face)
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hintergrundbilder")
                .font(.headline)
            Text(backgroundExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            RemoteOptionPicker(
                title: "Quelle",
                options: availableBackgroundSources.map(\.rawValue),
                selection: preferences.screensaverBackgroundSource.rawValue,
                label: { AppPreferences.ScreensaverBackgroundSource(rawValue: $0)?.title ?? $0 }
            ) { raw in
                guard let source = AppPreferences.ScreensaverBackgroundSource(rawValue: raw)
                else { return }
                // Switching sources throws away the old target: a media folder
                // identifier means nothing to the camera path and vice versa.
                preferences.setScreensaverBackground(source: source)
            }

            switch preferences.screensaverBackgroundSource {
            case .off:
                EmptyView()
            case .mediaFolder:
                mediaFolderChooser
            case .camera:
                cameraChooser
            }

            if preferences.screensaverBackgroundID != nil {
                RemoteOptionPicker(
                    title: "Bildwechsel",
                    options: AppPreferences.ScreensaverImageInterval.allCases
                        .map { String($0.rawValue) },
                    selection: String(preferences.screensaverImageInterval.rawValue),
                    label: { raw in
                        AppPreferences.ScreensaverImageInterval(rawValue: Int(raw) ?? 60)?
                            .title ?? raw
                    }
                ) { raw in
                    guard let value = Int(raw),
                          let interval = AppPreferences.ScreensaverImageInterval(rawValue: value)
                    else { return }
                    preferences.setScreensaverImageInterval(interval)
                }
            }
        }
    }

    /// The camera entry only appears once there is a camera to point it at —
    /// an empty option that leads nowhere is worse than no option.
    private var availableBackgroundSources: [AppPreferences.ScreensaverBackgroundSource] {
        var sources: [AppPreferences.ScreensaverBackgroundSource] = [.off, .mediaFolder]
        if !slideshowCameras.isEmpty {
            sources.append(.camera)
        }
        return sources
    }

    private var backgroundExplanation: String {
        switch preferences.screensaverBackgroundSource {
        case .off:
            return """
            Optional laufen Bilder abgedunkelt hinter Uhr und Werten — aus dem \
            Medien-Bereich deiner Instanz oder aus einer Diaschau-Integration.
            """
        case .mediaFolder:
            return """
            Bilder aus dem Medien-Bereich deiner Home-Assistant-Instanz, also \
            dem Ordner media und allem, was du über media_dirs eingebunden hast.
            """
        case .camera:
            return """
            Eine Diaschau-Kamera liefert die Bilder selbst — etwa Album \
            Slideshow mit PhotoPrism, Immich oder Google Fotos. Welche Bilder \
            an der Reihe sind, entscheidet die Integration; die App holt in \
            deinem Takt das jeweils aktuelle ab.
            """
        }
    }

    private var mediaFolderChooser: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(preferences.screensaverBackgroundID == nil
                   ? "Ordner wählen"
                   : "Anderen Ordner wählen") {
                browsePath = []
                browseError = nil
                isBrowsing = true
            }

            if let title = preferences.screensaverBackgroundTitle {
                Label(title, systemImage: "photo.on.rectangle.angled")
                    .font(.callout)
                    .foregroundStyle(Theme.accent)
                    .focusableCard()
            }
        }
    }

    private var cameraChooser: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(slideshowCameras) { camera in
                let isSelected = preferences.screensaverBackgroundID == camera.entityID
                Button {
                    preferences.setScreensaverBackground(
                        source: .camera,
                        id: camera.entityID,
                        title: store.displayName(for: camera.entityID)
                    )
                } label: {
                    HStack(spacing: 18) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Theme.accent : Theme.inactive)
                        Image(systemName: "photo.stack")
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                        Text(store.displayName(for: camera.entityID))
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 20)
                        if let subtitle = slideshowSubtitle(camera) {
                            Text(subtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.card)
            }
        }
    }

    /// Every camera qualifies as a background, but the ones that are actually
    /// slideshows announce an album, so they come first.
    private var slideshowCameras: [HAEntity] {
        store.entities.values
            .filter { $0.domain == "camera" }
            .sorted {
                let leftIsSlideshow = slideshowSubtitle($0) != nil
                let rightIsSlideshow = slideshowSubtitle($1) != nil
                if leftIsSlideshow != rightIsSlideshow { return leftIsSlideshow }
                return store.displayName(for: $0.entityID)
                    .localizedCaseInsensitiveCompare(store.displayName(for: $1.entityID))
                    == .orderedAscending
            }
    }

    /// The Album Slideshow integration publishes the album and how many
    /// pictures it holds; a doorbell camera publishes neither.
    private func slideshowSubtitle(_ entity: HAEntity) -> String? {
        let album = entity.attributes["album_title"]?.stringValue
        let count = entity.attributes["media_count"]?.intValue
        switch (album, count) {
        case let (album?, count?):
            return "\(album) · \(count) Bilder"
        case let (album?, nil):
            return album
        case let (nil, count?):
            return "\(count) Bilder"
        default:
            return nil
        }
    }

    // MARK: Media browser

    private var currentFolderID: String? { browsePath.last?.id }

    private var browseImageCount: Int {
        browseEntries.filter(\.isImage).count
    }

    private var folderBrowser: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ordner wählen")
                        .font(.largeTitle.bold())
                    Text(browsePath.isEmpty
                         ? "Medien deiner Home-Assistant-Instanz"
                         : browsePath.map(\.title).joined(separator: " › "))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let browseError {
                    Label(browseError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.unavailable)
                        .fixedSize(horizontal: false, vertical: true)
                        .focusableCard()
                }

                if let folder = browsePath.last, browseImageCount > 0 {
                    Button("Diesen Ordner verwenden — \(browseImageCount) Bilder") {
                        preferences.setScreensaverBackground(
                            source: .mediaFolder,
                            id: folder.id,
                            title: folder.title
                        )
                        isBrowsing = false
                    }
                } else if !browsePath.isEmpty, !browseEntries.isEmpty {
                    Text("Hier liegen keine Bilder, nur Unterordner.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .focusableCard()
                }

                ForEach(browseEntries.filter(\.isFolder)) { entry in
                    Button {
                        browsePath.append(entry)
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 40)
                            Text(entry.title)
                                .font(.headline)
                                .lineLimit(1)
                            Spacer(minLength: 20)
                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.card)
                }

                if browseEntries.isEmpty && browseError == nil {
                    ProgressView()
                        .padding(.top, 20)
                }

                Button(browsePath.isEmpty ? "Abbrechen" : "Eine Ebene zurück") {
                    if browsePath.isEmpty {
                        isBrowsing = false
                    } else {
                        browsePath.removeLast()
                    }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 50)
            .frame(maxWidth: 1400, alignment: .leading)
        }
        .task(id: browsePath.map(\.id).joined(separator: "|")) { await loadFolder() }
    }

    private func loadFolder() async {
        browseEntries = []
        browseError = nil
        do {
            browseEntries = try await MediaSource(client: connection).browse(currentFolderID)
            if browseEntries.isEmpty {
                browseError = "Dieser Ordner ist leer."
            }
        } catch {
            browseError = """
            Der Medien-Bereich konnte nicht gelesen werden: \
            \(error.localizedDescription)
            """
        }
    }

    private var entitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Angezeigte Entitäten")
                .font(.headline)
            Text("\(preferences.screensaverEntityIDs.count) ausgewählt · es werden bis zu 9 angezeigt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            if groups.isEmpty {
                Text("Es wurden keine passenden Entitäten gefunden.")
                    .foregroundStyle(.secondary)
                    .focusableCard()
            }

            ForEach(groups) { group in
                areaRow(group)

                if expandedGroupID == group.id {
                    ForEach(group.entityIDs, id: \.self) { entityID in
                        if let entity = store.entity(entityID) {
                            entityRow(entity)
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    /// The room itself: collapsed by default, because a house with a few
    /// hundred entities is not something anyone should scroll through with a
    /// remote to find the three they want on the screen.
    private func areaRow(_ group: AreaGroup) -> some View {
        let selected = group.entityIDs.filter { preferences.screensaverEntityIDs.contains($0) }.count
        let isExpanded = expandedGroupID == group.id

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                expandedGroupID = isExpanded ? nil : group.id
            }
        } label: {
            HStack(spacing: 18) {
                Image(systemName: group.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                Text(group.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 20)
                Text(selected == 0
                     ? "\(group.entityIDs.count) Entitäten"
                     : "\(selected) von \(group.entityIDs.count) ausgewählt")
                    .font(.callout)
                    .foregroundStyle(selected == 0 ? Color.secondary : Theme.accent)
                Image(systemName: "chevron.right")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.card)
    }

    private func entityRow(_ entity: HAEntity) -> some View {
        let isSelected = preferences.screensaverEntityIDs.contains(entity.entityID)
        return Button {
            preferences.toggleScreensaverEntity(entity.entityID)
        } label: {
            HStack(spacing: 18) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inactive)
                Image(systemName: entity.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                Text(store.displayName(for: entity.entityID))
                    .lineLimit(1)
                Spacer(minLength: 20)
                Text(entity.displayState)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.card)
    }

    /// Grouped by area, because a flat list of every entity is unusable with a
    /// remote. Entities without an area come last.
    private func makeGroups() -> [AreaGroup] {
        var result: [AreaGroup] = []

        for area in store.areas {
            let entities = store.primaryEntities(inArea: area.areaID).filter(Self.isWorthShowing)
            if !entities.isEmpty {
                result.append(
                    AreaGroup(
                        id: area.areaID,
                        name: area.name,
                        symbol: IconMapper.symbol(forMDI: area.icon, domain: nil),
                        entityIDs: entities.map(\.entityID)
                    )
                )
            }
        }

        let unassigned = store.primaryEntitiesWithoutArea.filter(Self.isWorthShowing)
        if !unassigned.isEmpty {
            result.append(
                AreaGroup(
                    id: "__no_area__",
                    name: "Ohne Bereich",
                    symbol: "tray",
                    entityIDs: unassigned.map(\.entityID)
                )
            )
        }

        return result
    }

    /// An ambient screen wants readings and states, not every button and scene.
    private static func isWorthShowing(_ entity: HAEntity) -> Bool {
        ["sensor", "binary_sensor", "weather", "climate", "light", "switch",
         "cover", "lock", "person", "device_tracker", "media_player", "sun"]
            .contains(entity.domain)
    }
}
