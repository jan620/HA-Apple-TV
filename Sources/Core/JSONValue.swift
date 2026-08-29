import Foundation

/// A dynamically typed JSON value.
///
/// Home Assistant is schemaless in the places that matter most to this app:
/// entity attributes differ per integration and Lovelace card configuration is
/// free-form (including custom cards). Decoding those payloads into concrete
/// Swift types would mean losing everything we did not anticipate, so they are
/// kept as `JSONValue` and read through the typed accessors below.
enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Codable

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Value is not representable as JSON"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            // Home Assistant treats `5` and `5.0` differently in a few services
            // (notably `media_player.volume_set` vs. `light.turn_on`'s
            // `brightness`), so integral values go back out as integers.
            if let integer = Int(exactly: value.rounded()), value == value.rounded() {
                try container.encode(integer)
            } else {
                try container.encode(value)
            }
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Accessors

extension JSONValue {
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            return Double(value)
        case .bool(let value):
            return value ? 1 : 0
        default:
            return nil
        }
    }

    var intValue: Int? {
        guard let double = doubleValue, double.isFinite else { return nil }
        return Int(double.rounded())
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .number(let value):
            return value != 0
        case .string(let value):
            switch value.lowercased() {
            case "true", "on", "yes", "1": return true
            case "false", "off", "no", "0": return false
            default: return nil
            }
        default:
            return nil
        }
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    /// Strings that Home Assistant sometimes stores as a single value and
    /// sometimes as a list — `entity_id` in a service target being the classic
    /// example. Both shapes are normalised into an array.
    var stringArrayValue: [String]? {
        switch self {
        case .string(let value):
            return [value]
        case .array(let values):
            return values.compactMap(\.stringValue)
        default:
            return nil
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }

    subscript(index: Int) -> JSONValue? {
        guard case .array(let array) = self, array.indices.contains(index) else { return nil }
        return array[index]
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByNilLiteral {
    init(nilLiteral: ()) { self = .null }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

// MARK: - Convenience

extension JSONValue {
    static func strings(_ values: [String]) -> JSONValue {
        .array(values.map { .string($0) })
    }

    /// Human readable rendering used for attribute inspectors and fallback card
    /// content.
    var displayString: String {
        switch self {
        case .null:
            return "—"
        case .bool(let value):
            return value ? "an" : "aus"
        case .number(let value):
            if let integer = Int(exactly: value.rounded()), value == value.rounded() {
                return String(integer)
            }
            return String(format: "%.2f", value)
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.displayString).joined(separator: ", ")
        case .object(let object):
            return object.keys.sorted().joined(separator: ", ")
        }
    }
}
