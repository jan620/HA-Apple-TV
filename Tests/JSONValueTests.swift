import XCTest
@testable import Roomglance

/// `JSONValue` sits under every card and every service call, so a wrong
/// coercion breaks many places at once and quietly.
final class JSONValueTests: XCTestCase {
    private func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    // MARK: Decoding

    func testDecodesBoolWithoutCollapsingItIntoANumber() throws {
        XCTAssertEqual(try decode("true"), .bool(true))
        XCTAssertEqual(try decode("1"), .number(1))
    }

    func testDecodesNestedStructures() throws {
        let value = try decode(#"{"a": [1, "x", null], "b": {"c": false}}"#)
        XCTAssertEqual(value["a"]?[0], .number(1))
        XCTAssertEqual(value["a"]?[1], .string("x"))
        XCTAssertEqual(value["a"]?[2], .null)
        XCTAssertEqual(value["b"]?["c"], .bool(false))
    }

    func testSubscriptsReturnNilInsteadOfCrashingOnMismatch() throws {
        let value = try decode(#"{"a": 1}"#)
        XCTAssertNil(value[0])
        XCTAssertNil(value["missing"])
        XCTAssertNil(value["a"]?["deeper"])
    }

    // MARK: Coercions

    func testDoubleValueParsesNumericStrings() {
        // Home Assistant reports sensor states as strings.
        XCTAssertEqual(JSONValue.string("21.5").doubleValue, 21.5)
        XCTAssertEqual(JSONValue.number(3).doubleValue, 3)
        XCTAssertNil(JSONValue.string("unavailable").doubleValue)
    }

    func testBoolValueUnderstandsHomeAssistantSpellings() {
        XCTAssertEqual(JSONValue.string("on").boolValue, true)
        XCTAssertEqual(JSONValue.string("OFF").boolValue, false)
        XCTAssertEqual(JSONValue.number(0).boolValue, false)
        XCTAssertNil(JSONValue.string("maybe").boolValue)
    }

    func testIntValueRounds() {
        XCTAssertEqual(JSONValue.number(2.6).intValue, 3)
        XCTAssertEqual(JSONValue.number(-2.6).intValue, -3)
        XCTAssertNil(JSONValue.number(.infinity).intValue)
    }

    func testStringArrayNormalisesSingleValues() {
        // `entity_id` in a service target may be one string or a list.
        XCTAssertEqual(JSONValue.string("light.a").stringArrayValue, ["light.a"])
        XCTAssertEqual(
            JSONValue.array([.string("light.a"), .string("light.b")]).stringArrayValue,
            ["light.a", "light.b"]
        )
    }

    // MARK: Encoding

    func testIntegralNumbersEncodeAsIntegers() throws {
        // Some services reject 5.0 where they expect 5.
        let data = try JSONEncoder().encode(JSONValue.object(["brightness": .number(255)]))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"brightness":255}"#)
    }

    func testFractionalNumbersKeepTheirFraction() throws {
        let data = try JSONEncoder().encode(JSONValue.object(["volume_level": .number(0.55)]))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"volume_level":0.55}"#)
    }

    func testRoundTripPreservesValues() throws {
        let original = try decode(#"{"a":[1,2.5,"x",true,null],"b":{"c":"d"}}"#)
        let encoded = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: encoded), original)
    }
}
