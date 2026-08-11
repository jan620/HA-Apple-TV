import SwiftUI

/// The ambient screen: a clock plus the entities the user picked.
///
/// Everything drifts slowly and stays dim. A TV panel showing a static bright
/// layout for hours is exactly how burn-in happens, and this screen is designed
/// to run unattended.
struct ScreensaverView: View {
    let onWake: () -> Void

    @EnvironmentObject private var store: EntityStore
    @EnvironmentObject private var preferences: AppPreferences

    private var entities: [HAEntity] {
        preferences.screensaverEntityIDs.compactMap { store.entity($0) }
    }

    var body: some View {
        // A button rather than a plain view: it guarantees a way out even if
        // the window-level activity detector ever misses an event.
        Button(action: onWake) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(at: context.date)
            }
        }
        .buttonStyle(.plain)
        .onMoveCommand { _ in onWake() }
        .onExitCommand(perform: onWake)
        .onPlayPauseCommand(perform: onWake)
        .ignoresSafeArea()
    }

    private func content(at date: Date) -> some View {
        // Two incommensurable periods, so the path never repeats exactly and no
        // pixel keeps the same content for long.
        let seconds = date.timeIntervalSinceReferenceDate
        let horizontal = sin(seconds / 47) * 70
        let vertical = cos(seconds / 61) * 45

        return ZStack {
            Color.black
            RadialGradient(
                colors: [Theme.accent.opacity(0.10), .black],
                center: .center,
                startRadius: 40,
                endRadius: 900
            )

            VStack(spacing: 50) {
                clock(at: date)
                if !entities.isEmpty {
                    entityRow
                }
            }
            .offset(x: horizontal, y: vertical)
            .animation(.linear(duration: 1), value: horizontal)
            .animation(.linear(duration: 1), value: vertical)
        }
        .opacity(0.85)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clock(at date: Date) -> some View {
        VStack(spacing: 6) {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: 150, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var entityRow: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: columnCount),
            spacing: 30
        ) {
            ForEach(entities.prefix(9)) { entity in
                VStack(spacing: 10) {
                    Image(systemName: entity.symbolName)
                        .font(.system(size: 40))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.stateColor(for: entity))
                    Text(entity.displayState)
                        .font(.title3.weight(.medium))
                        .lineLimit(1)
                    Text(store.displayName(for: entity.entityID))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 1500)
    }

    private var columnCount: Int {
        min(max(entities.count, 1), 3)
    }
}
