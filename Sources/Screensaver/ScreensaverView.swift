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
            // Opaque, and dimmed on its own rather than through the whole
            // stack: a translucent screen saver shows the dashboard behind it.
            Color.black

            if let backgroundSource {
                ScreensaverBackground(
                    source: backgroundSource,
                    interval: preferences.screensaverImageInterval.seconds
                )
                // Photographs are far brighter than the plain background, and
                // white text on an arbitrary picture is unreadable. This is
                // also what keeps a static bright frame off the panel.
                .overlay(Color.black.opacity(0.45))
            } else {
                RadialGradient(
                    colors: [accent.opacity(0.10), .black],
                    center: .center,
                    startRadius: 40,
                    endRadius: 900
                )
            }

            VStack(spacing: 50) {
                if preferences.screensaverShowsClock {
                    clock(at: date)
                }
                if !entities.isEmpty {
                    entityRow
                }
            }
            .opacity(0.85)
            .offset(x: horizontal, y: vertical)
            .animation(.linear(duration: 1), value: horizontal)
            .animation(.linear(duration: 1), value: vertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundSource: ScreensaverBackground.Source? {
        guard let id = preferences.screensaverBackgroundID else { return nil }
        switch preferences.screensaverBackgroundSource {
        case .off: return nil
        case .mediaFolder: return .mediaFolder(id)
        case .camera: return .camera(id)
        }
    }

    private var accent: Color {
        preferences.screensaverPalette.accent
    }

    private var typeface: Font.Design {
        preferences.screensaverTypeface.design
    }

    private func clock(at date: Date) -> some View {
        VStack(spacing: 6) {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: 150, weight: .thin, design: typeface))
                .monospacedDigit()
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.system(.title2, design: typeface))
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
                        .foregroundStyle(entity.isActive ? accent : Theme.inactive)
                    Text(entity.displayState)
                        .font(.system(.title3, design: typeface).weight(.medium))
                        .lineLimit(1)
                    Text(store.displayName(for: entity.entityID))
                        .font(.system(.caption, design: typeface))
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
