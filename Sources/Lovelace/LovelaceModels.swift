import Foundation

/// A dashboard entry from `lovelace/dashboards/list`, plus the built-in default
/// dashboard which that command does not report.
struct LovelaceDashboard: Identifiable, Hashable {
    let id: String
    /// `nil` addresses the default ("Overview") dashboard.
    let urlPath: String?
    let title: String
    let icon: String?
    let requiresAdmin: Bool

    static let overview = LovelaceDashboard(
        id: "__overview__",
        urlPath: nil,
        title: "Übersicht",
        icon: "mdi:view-dashboard",
        requiresAdmin: false
    )

    init(id: String, urlPath: String?, title: String, icon: String?, requiresAdmin: Bool) {
        self.id = id
        self.urlPath = urlPath
        self.title = title
        self.icon = icon
        self.requiresAdmin = requiresAdmin
    }

    init?(json: JSONValue) {
        guard let urlPath = json["url_path"]?.stringValue else { return nil }
        self.id = json["id"]?.stringValue ?? urlPath
        self.urlPath = urlPath
        self.title = json["title"]?.stringValue ?? urlPath
        self.icon = json["icon"]?.stringValue
        self.requiresAdmin = json["require_admin"]?.boolValue ?? false
    }
}

struct LovelaceConfig: Hashable {
    var title: String?
    var views: [LovelaceViewConfig]
    /// True when the server returned a strategy dashboard we could not run and
    /// the content below was generated locally instead.
    var isGenerated: Bool

    init(title: String? = nil, views: [LovelaceViewConfig], isGenerated: Bool = false) {
        self.title = title
        self.views = views
        self.isGenerated = isGenerated
    }

    init(json: JSONValue) {
        title = json["title"]?.stringValue
        views = (json["views"]?.arrayValue ?? [])
            .enumerated()
            .map { LovelaceViewConfig(json: $1, index: $0) }
        isGenerated = false
    }

    /// A dashboard defined only by a strategy has no views for us to render —
    /// strategies are JavaScript that runs in the frontend.
    var needsGeneratedFallback: Bool {
        views.isEmpty || views.allSatisfy { $0.isEmpty }
    }
}

struct LovelaceViewConfig: Identifiable, Hashable {
    let id: String
    var title: String?
    var path: String?
    var icon: String?
    /// `masonry` (default), `sidebar`, `panel` or `sections`.
    var type: String
    var badges: [LovelaceCardConfig]
    var cards: [LovelaceCardConfig]
    var sections: [LovelaceSectionConfig]
    var maxColumns: Int?
    var isSubview: Bool

    init(
        id: String,
        title: String?,
        path: String? = nil,
        icon: String? = nil,
        type: String = "masonry",
        badges: [LovelaceCardConfig] = [],
        cards: [LovelaceCardConfig] = [],
        sections: [LovelaceSectionConfig] = [],
        maxColumns: Int? = nil,
        isSubview: Bool = false
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.icon = icon
        self.type = type
        self.badges = badges
        self.cards = cards
        self.sections = sections
        self.maxColumns = maxColumns
        self.isSubview = isSubview
    }

    init(json: JSONValue, index: Int) {
        let identifier = json["path"]?.stringValue ?? "view-\(index)"
        id = identifier
        title = json["title"]?.stringValue
        path = json["path"]?.stringValue
        icon = json["icon"]?.stringValue
        type = json["type"]?.stringValue ?? (json["sections"] != nil ? "sections" : "masonry")
        maxColumns = json["max_columns"]?.intValue
        isSubview = json["subview"]?.boolValue ?? false

        badges = (json["badges"]?.arrayValue ?? [])
            .enumerated()
            .map { LovelaceCardConfig(badgeJSON: $1, id: "\(identifier).badge.\($0)") }

        cards = (json["cards"]?.arrayValue ?? [])
            .enumerated()
            .map { LovelaceCardConfig(json: $1, id: "\(identifier).card.\($0)") }

        sections = (json["sections"]?.arrayValue ?? [])
            .enumerated()
            .map { LovelaceSectionConfig(json: $1, id: "\(identifier).section.\($0)") }
    }

    var isEmpty: Bool {
        cards.isEmpty && sections.isEmpty && badges.isEmpty
    }

    var displayTitle: String {
        title ?? path?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Ansicht"
    }
}

struct LovelaceSectionConfig: Identifiable, Hashable {
    let id: String
    var title: String?
    var cards: [LovelaceCardConfig]
    var columnSpan: Int?

    init(id: String, title: String?, cards: [LovelaceCardConfig], columnSpan: Int? = nil) {
        self.id = id
        self.title = title
        self.cards = cards
        self.columnSpan = columnSpan
    }

    init(json: JSONValue, id: String) {
        self.id = id
        // Newer configs put the section title in a `heading` card; older ones
        // used a plain `title` key.
        self.title = json["title"]?.stringValue
        self.columnSpan = json["column_span"]?.intValue
        self.cards = (json["cards"]?.arrayValue ?? [])
            .enumerated()
            .map { LovelaceCardConfig(json: $1, id: "\(id).card.\($0)") }
    }
}

/// One Lovelace card. The full configuration is kept as raw JSON so card views
/// can read whatever keys they support without the model having to know every
/// option of every card type.
struct LovelaceCardConfig: Identifiable, Hashable {
    let id: String
    let type: String
    let raw: [String: JSONValue]

    init(id: String, type: String, raw: [String: JSONValue]) {
        self.id = id
        self.type = type
        self.raw = raw
    }

    init(json: JSONValue, id: String) {
        self.id = id
        self.raw = json.objectValue ?? [:]
        self.type = json["type"]?.stringValue ?? "entities"
    }

    /// Badges accept a bare entity ID string in addition to a card-like object.
    init(badgeJSON json: JSONValue, id: String) {
        if let entityID = json.stringValue {
            self.init(id: id, type: "entity", raw: ["entity": .string(entityID)])
            return
        }
        var raw = json.objectValue ?? [:]
        if raw["type"] == nil {
            raw["type"] = .string("entity")
        }
        self.init(id: id, type: raw["type"]?.stringValue ?? "entity", raw: raw)
    }

    subscript(key: String) -> JSONValue? { raw[key] }

    var title: String? { raw["title"]?.stringValue ?? raw["name"]?.stringValue }
    var entityID: String? { raw["entity"]?.stringValue }
    var icon: String? { raw["icon"]?.stringValue }

    /// `tap_action.action` — `toggle`, `more-info`, `navigate`, `perform-action`,
    /// `call-service` (legacy) or `none`.
    var tapAction: String? {
        raw["tap_action"]?["action"]?.stringValue
    }

    /// Nested cards of `vertical-stack`, `horizontal-stack` and `grid`.
    var childCards: [LovelaceCardConfig] {
        (raw["cards"]?.arrayValue ?? [])
            .enumerated()
            .map { LovelaceCardConfig(json: $1, id: "\(id).child.\($0)") }
    }

    /// Rows of an `entities` / `glance` card.
    var entityRows: [LovelaceEntityRow] {
        (raw["entities"]?.arrayValue ?? [])
            .enumerated()
            .map { LovelaceEntityRow(json: $1, id: "\(id).row.\($0)") }
    }

    /// Entity IDs referenced anywhere obvious in this card, used to decide
    /// whether a generated card is worth showing.
    var referencedEntityIDs: [String] {
        var result: [String] = []
        if let entityID { result.append(entityID) }
        if let camera = raw["camera_image"]?.stringValue { result.append(camera) }
        result.append(contentsOf: entityRows.compactMap(\.entityID))
        return result
    }
}

/// A row inside an `entities`-style card.
struct LovelaceEntityRow: Identifiable, Hashable {
    let id: String
    let raw: [String: JSONValue]

    init(json: JSONValue, id: String) {
        self.id = id
        if let entityID = json.stringValue {
            self.raw = ["entity": .string(entityID)]
        } else {
            self.raw = json.objectValue ?? [:]
        }
    }

    var entityID: String? { raw["entity"]?.stringValue }
    var name: String? { raw["name"]?.stringValue }
    var icon: String? { raw["icon"]?.stringValue }
    /// Special rows such as `divider`, `section`, `attribute`, `weblink`.
    var rowType: String? { raw["type"]?.stringValue }
    var secondaryInfo: String? { raw["secondary_info"]?.stringValue }
    var attribute: String? { raw["attribute"]?.stringValue }
}
