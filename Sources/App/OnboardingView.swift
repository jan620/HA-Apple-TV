import SwiftUI

/// First-run setup: the user decides what the app should show before ever
/// seeing a tab bar.
///
/// Without this the app opens onto whatever Home Assistant happens to expose —
/// which on a typical install is a dozen area tabs plus dashboards the user may
/// not care about on a TV.
struct OnboardingView: View {
    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var lovelace: LovelaceService
    @EnvironmentObject private var preferences: AppPreferences

    private enum Step {
        case welcome
        case mode
        case dashboards
        case areas
        case summary
    }

    @State private var step: Step = .welcome
    @State private var mode: AppPreferences.ContentMode = .both
    @State private var selectedDashboardIDs: Set<String> = []
    @State private var selectedAreaIDs: Set<String> = []

    /// Dashboards the user can pick from — the built-in overview plus whatever
    /// the server reports.
    private var offeredDashboards: [LovelaceDashboard] {
        lovelace.dashboards
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                content
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 60)
            .frame(maxWidth: 1400, alignment: .leading)
        }
        .onAppear(perform: preselectEverything)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcomeStep
        case .mode: modeStep
        case .dashboards: dashboardStep
        case .areas: areaStep
        case .summary: summaryStep
        }
    }

    // MARK: Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            header(
                title: store.config?.locationName ?? "Home Assistant",
                subtitle: "Verbunden. Lass uns kurz einrichten, was auf dem Fernseher erscheinen soll."
            )

            VStack(alignment: .leading, spacing: 10) {
                foundRow(count: store.entities.count, label: "Entitäten")
                foundRow(count: store.areas.count, label: "Bereiche")
                foundRow(count: offeredDashboards.count, label: "Dashboards")
            }

            Button("Einrichten") { step = .mode }
                .buttonStyle(.card)
        }
    }

    private var modeStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            header(
                title: "Was möchtest du sehen?",
                subtitle: "Das lässt sich später jederzeit ändern."
            )

            ForEach(AppPreferences.ContentMode.allCases, id: \.self) { option in
                Button {
                    mode = option
                    advanceFromMode()
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: option.symbol)
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .font(.title3.bold())
                            Text(option.explanation)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.card)
            }
        }
    }

    private var dashboardStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            header(
                title: "Welche Dashboards?",
                subtitle: "Wähle aus, was in der Tab-Leiste erscheinen soll."
            )

            if offeredDashboards.isEmpty {
                Text("Es wurden keine Dashboards gefunden.")
                    .foregroundStyle(.secondary)
            }

            ForEach(offeredDashboards) { dashboard in
                selectionRow(
                    title: dashboard.title,
                    subtitle: dashboard.urlPath.map { "/\($0)" } ?? "Standard-Übersicht",
                    symbol: IconMapper.symbol(forMDI: dashboard.icon, domain: nil),
                    isSelected: selectedDashboardIDs.contains(dashboard.id)
                ) {
                    toggle(dashboard.id, in: &selectedDashboardIDs)
                }
            }

            navigation(
                canContinue: !selectedDashboardIDs.isEmpty,
                back: { step = .mode },
                next: { step = mode.includesAreas ? .areas : .summary }
            )
        }
    }

    private var areaStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            header(
                title: "Welche Räume?",
                subtitle: "Für jeden ausgewählten Bereich entsteht eine eigene Ansicht."
            )

            if store.areas.isEmpty {
                Text("""
                Es wurden keine Bereiche gefunden. Das passiert, wenn dein Konto \
                kein Administrator ist — Home Assistant gibt die Bereichsliste \
                dann nicht heraus.
                """)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(store.areas) { area in
                selectionRow(
                    title: area.name,
                    subtitle: "\(store.primaryEntities(inArea: area.areaID).count) Geräte",
                    symbol: IconMapper.symbol(forMDI: area.icon, domain: nil),
                    isSelected: selectedAreaIDs.contains(area.areaID)
                ) {
                    toggle(area.areaID, in: &selectedAreaIDs)
                }
            }

            navigation(
                canContinue: !selectedAreaIDs.isEmpty || store.areas.isEmpty,
                back: { step = mode.includesDashboards ? .dashboards : .mode },
                next: { step = .summary }
            )
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            header(title: "Fertig", subtitle: "Das erscheint auf deinem Apple TV:")

            VStack(alignment: .leading, spacing: 12) {
                if mode.includesDashboards {
                    summaryRow(
                        symbol: "square.grid.2x2.fill",
                        text: selectedDashboardTitles
                    )
                }
                if mode.includesAreas {
                    summaryRow(
                        symbol: "sofa.fill",
                        text: selectedAreaIDs.isEmpty
                            ? "Alle Räume"
                            : "\(selectedAreaIDs.count) Räume"
                    )
                }
            }

            HStack(spacing: 20) {
                Button("Zurück") {
                    step = mode.includesAreas ? .areas : (mode.includesDashboards ? .dashboards : .mode)
                }
                Button("Loslegen", action: finish)
            }
        }
    }

    // MARK: Building blocks

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func foundRow(count: Int, label: String) -> some View {
        HStack(spacing: 12) {
            Text("\(count)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 80, alignment: .trailing)
            Text(label)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func selectionRow(
        title: String,
        subtitle: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inactive)
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.card)
    }

    private func summaryRow(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.title3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func navigation(
        canContinue: Bool,
        back: @escaping () -> Void,
        next: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 20) {
            Button("Zurück", action: back)
            Button("Weiter", action: next)
                .disabled(!canContinue)
        }
        .padding(.top, 10)
    }

    // MARK: Logic

    private var selectedDashboardTitles: String {
        let titles = offeredDashboards
            .filter { selectedDashboardIDs.contains($0.id) }
            .map(\.title)
        return titles.isEmpty ? "Keine Dashboards" : titles.joined(separator: ", ")
    }

    /// Everything is on by default, so "Weiter" durchklicken gives the full
    /// picture rather than an empty app.
    private func preselectEverything() {
        if selectedDashboardIDs.isEmpty {
            selectedDashboardIDs = Set(offeredDashboards.map(\.id))
        }
        if selectedAreaIDs.isEmpty {
            selectedAreaIDs = Set(store.areas.map(\.areaID))
        }
    }

    private func advanceFromMode() {
        switch mode {
        case .dashboards:
            step = .dashboards
        case .areas:
            step = .areas
        case .both:
            step = .dashboards
        }
    }

    private func toggle(_ id: String, in set: inout Set<String>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }

    private func finish() {
        preferences.complete(
            mode: mode,
            dashboardIDs: mode.includesDashboards ? selectedDashboardIDs : [],
            areaIDs: mode.includesAreas ? selectedAreaIDs : []
        )
        // The rooms config depends on the area selection, so cached configs
        // must not survive the choice.
        lovelace.reset()
    }
}
