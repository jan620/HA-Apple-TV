import SwiftUI

enum Theme {
    /// Home Assistant's brand blue, used for focus accents and active states.
    static let accent = Color(red: 0.011, green: 0.662, blue: 0.956)
    /// The warm tint Home Assistant uses for "this thing is currently on".
    static let active = Color(red: 1.0, green: 0.79, blue: 0.30)
    static let inactive = Color(white: 0.55)
    static let unavailable = Color(red: 0.85, green: 0.34, blue: 0.34)

    static let cardBackground = Color(white: 0.14)
    static let cardBackgroundElevated = Color(white: 0.19)

    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 22
    static let gridSpacing: CGFloat = 32
    static let columnSpacing: CGFloat = 40

    /// Overscan-safe horizontal inset for full-screen content.
    static let screenInset: CGFloat = 60

    static func stateColor(for entity: HAEntity) -> Color {
        if entity.isUnavailable { return unavailable }
        return entity.isActive ? active : inactive
    }
}

/// A plain (non-interactive) card surface. Interactive cards use `Button` with
/// `.buttonStyle(.card)` so they get tvOS's native focus lift and parallax.
struct CardSurface<Content: View>: View {
    var padding: CGFloat = Theme.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}

/// Makes a purely informational card reachable with the remote.
///
/// tvOS scroll views only move when focus moves — there is no scrolling
/// gesture. A card containing nothing focusable is therefore not just
/// unselectable but unreachable, and so is everything below it. Marking such
/// cards focusable is what lets the user travel down the page at all.
struct FocusableCardModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: isFocused ? 4 : 0)
            }
            .scaleEffect(isFocused ? 1.01 : 1)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    func focusableCard() -> some View {
        modifier(FocusableCardModifier())
    }
}

/// Title row shared by most cards.
struct CardHeader: View {
    let title: String
    var subtitle: String?
    var icon: String?

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Placeholder for Lovelace card types this app cannot render natively.
struct UnsupportedCardView: View {
    let type: String
    var reason: String?

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 8) {
                Label("Karte nicht unterstützt", systemImage: "questionmark.square.dashed")
                    .font(.headline)
                Text(type)
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.accent)
                if let reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Otherwise the placeholder becomes a dead end that blocks scrolling
        // past it.
        .focusableCard()
    }
}
