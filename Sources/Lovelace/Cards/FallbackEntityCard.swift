import SwiftUI

/// What the app shows in place of a card type it cannot render, when the card
/// at least names an entity.
///
/// Many custom cards — flight trackers, departure boards, waste calendars — are
/// a table over one attribute that holds a list of records. Rendering that list
/// generically recovers most of the card's value without knowing anything about
/// the card itself.
struct FallbackEntityCardView: View {
    let card: LovelaceCardConfig
    let entity: HAEntity

    var body: some View {
        CardButton(card: card, entityID: entity.entityID, defaultAction: .moreInfo) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    EntityIcon(entity: entity, overrideIcon: card.icon, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card["title"]?.stringValue ?? entity.friendlyName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(entity.displayState)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if let records = recordList {
                    RecordTableView(records: records)
                }

                Text("Originalkarte \(card.type) wird auf tvOS nicht unterstützt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The first attribute holding a list of objects — that is where this kind
    /// of card keeps its rows.
    private var recordList: [JSONValue]? {
        for key in entity.attributes.keys.sorted() {
            guard let array = entity.attributes[key]?.arrayValue,
                  !array.isEmpty,
                  array.allSatisfy({ $0.objectValue != nil })
            else { continue }
            return array
        }
        return nil
    }
}

/// Renders an array of like-shaped JSON objects as a compact table.
struct RecordTableView: View {
    let records: [JSONValue]
    var maximumRows = 6
    var maximumColumns = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                ForEach(columns, id: \.self) { column in
                    Text(column.replacingOccurrences(of: "_", with: " "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                }
            }

            ForEach(Array(records.prefix(maximumRows).enumerated()), id: \.offset) { _, record in
                HStack(spacing: 16) {
                    ForEach(columns, id: \.self) { column in
                        Text(record[column]?.displayString ?? "—")
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                    }
                }
                Divider()
            }

            if records.count > maximumRows {
                Text("… und \(records.count - maximumRows) weitere")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Keys that appear in most records and carry a single readable value.
    /// Nested objects and arrays are skipped — they do not fit a table cell.
    private var columns: [String] {
        var counts: [String: Int] = [:]
        for record in records.prefix(20) {
            for (key, value) in record.objectValue ?? [:] {
                switch value {
                case .array, .object, .null:
                    continue
                default:
                    counts[key, default: 0] += 1
                }
            }
        }

        let threshold = max(1, min(records.count, 20) / 2)
        return counts
            .filter { $0.value >= threshold }
            .keys
            .sorted()
            .prefix(maximumColumns)
            .map { $0 }
    }
}
