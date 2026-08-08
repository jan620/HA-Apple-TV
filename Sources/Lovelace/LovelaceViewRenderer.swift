import SwiftUI

/// Renders one Lovelace view. Masonry is approximated with fixed columns —
/// there is no measured reflow — which reads well at TV distances where every
/// card is large anyway.
struct LovelaceViewRenderer: View {
    let view: LovelaceViewConfig

    private var columnCount: Int {
        switch view.type {
        case "panel":
            return 1
        case "sidebar":
            return 2
        default:
            return min(max(view.maxColumns ?? 3, 1), 4)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gridSpacing) {
                if !view.badges.isEmpty {
                    badgeRow
                }
                content
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.top, 30)
            .padding(.bottom, 80)
        }
    }

    private var badgeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(view.badges) { badge in
                    LovelaceBadgeView(badge: badge)
                }
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !view.sections.isEmpty {
            sectionsLayout
        } else if view.type == "panel" {
            VStack(spacing: Theme.gridSpacing) {
                ForEach(view.cards) { card in
                    LovelaceCardView(card: card)
                }
            }
        } else if view.cards.isEmpty {
            emptyState
        } else {
            masonryLayout
        }
    }

    private var masonryLayout: some View {
        HStack(alignment: .top, spacing: Theme.columnSpacing) {
            ForEach(Array(distributedColumns.enumerated()), id: \.offset) { _, column in
                VStack(spacing: Theme.gridSpacing) {
                    ForEach(column) { card in
                        LovelaceCardView(card: card)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// Cards are dealt round-robin into the columns, the same ordering Home
    /// Assistant's masonry view uses before it measures heights.
    private var distributedColumns: [[LovelaceCardConfig]] {
        var columns = Array(repeating: [LovelaceCardConfig](), count: columnCount)
        for (index, card) in view.cards.enumerated() {
            columns[index % columnCount].append(card)
        }
        return columns.filter { !$0.isEmpty }
    }

    private var sectionsLayout: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Theme.columnSpacing, alignment: .top),
                count: columnCount
            ),
            alignment: .leading,
            spacing: Theme.gridSpacing
        ) {
            ForEach(view.sections) { section in
                VStack(alignment: .leading, spacing: 16) {
                    if let title = section.title {
                        Text(title)
                            .font(.title3.bold())
                    }
                    ForEach(section.cards) { card in
                        LovelaceCardView(card: card)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Diese Ansicht enthält keine Karten.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}
