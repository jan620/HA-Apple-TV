import SwiftUI

/// Configures the ambient screen: whether it runs, after how long, and which
/// entities it shows.
struct ScreensaverSettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var store: EntityStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                enableSection

                if preferences.screensaverEnabled {
                    delaySection
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

    private var entitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Angezeigte Entitäten")
                .font(.headline)
            Text("\(preferences.screensaverEntityIDs.count) ausgewählt · es werden bis zu 9 angezeigt")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(groupedEntities, id: \.title) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)

                    ForEach(group.entities) { entity in
                        entityRow(entity)
                    }
                }
            }
        }
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
    private var groupedEntities: [(title: String, entities: [HAEntity])] {
        var groups: [(title: String, entities: [HAEntity])] = []

        for area in store.areas {
            let entities = store.primaryEntities(inArea: area.areaID).filter(Self.isWorthShowing)
            if !entities.isEmpty {
                groups.append((area.name, entities))
            }
        }

        let unassigned = store.primaryEntitiesWithoutArea.filter(Self.isWorthShowing)
        if !unassigned.isEmpty {
            groups.append(("Ohne Bereich", unassigned))
        }

        return groups
    }

    /// An ambient screen wants readings and states, not every button and scene.
    private static func isWorthShowing(_ entity: HAEntity) -> Bool {
        ["sensor", "binary_sensor", "weather", "climate", "light", "switch",
         "cover", "lock", "person", "device_tracker", "media_player", "sun"]
            .contains(entity.domain)
    }
}
