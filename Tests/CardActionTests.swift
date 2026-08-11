import XCTest
@testable import HomeAssistantTV

/// `CardAction.parse` decides what every button press does. Its silent
/// `default` paths make a wrong-but-plausible action easy to ship unnoticed.
final class CardActionTests: XCTestCase {
    private func action(_ json: String, default fallback: CardAction = .moreInfo) throws -> CardAction {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        return CardAction.parse(value, default: fallback)
    }

    func testMissingConfigurationUsesTheFallback() {
        XCTAssertEqual(CardAction.parse(nil, default: .toggle), .toggle)
        XCTAssertEqual(CardAction.parse(.object([:]), default: .moreInfo), .moreInfo)
    }

    func testSimpleActions() throws {
        XCTAssertEqual(try action(#"{"action":"toggle"}"#), .toggle)
        XCTAssertEqual(try action(#"{"action":"more-info"}"#), .moreInfo)
        XCTAssertEqual(try action(#"{"action":"none"}"#), .none)
    }

    func testNavigation() throws {
        XCTAssertEqual(
            try action(#"{"action":"navigate","navigation_path":"/lovelace/kitchen"}"#),
            .navigate("/lovelace/kitchen")
        )
    }

    func testNavigationWithoutAPathDoesNothing() throws {
        // Falling back to the default here would move the user somewhere
        // arbitrary instead of doing nothing.
        XCTAssertEqual(try action(#"{"action":"navigate"}"#, default: .toggle), .none)
    }

    func testModernPerformAction() throws {
        let parsed = try action("""
        {
          "action": "perform-action",
          "perform_action": "light.turn_on",
          "data": {"brightness_pct": 50},
          "target": {"entity_id": "light.kitchen"}
        }
        """)
        XCTAssertEqual(
            parsed,
            .performAction(
                domain: "light",
                service: "turn_on",
                data: ["brightness_pct": .number(50)],
                entityIDs: ["light.kitchen"]
            )
        )
    }

    /// `call-service` with `service` and `service_data` is the pre-2024.8
    /// spelling and still sits in plenty of dashboards.
    func testLegacyCallService() throws {
        let parsed = try action("""
        {
          "action": "call-service",
          "service": "script.turn_on",
          "service_data": {"entity_id": "script.good_night"}
        }
        """)
        XCTAssertEqual(
            parsed,
            .performAction(
                domain: "script",
                service: "turn_on",
                data: ["entity_id": .string("script.good_night")],
                entityIDs: []
            )
        )
    }

    func testServiceWithoutADomainSeparatorDoesNothing() throws {
        XCTAssertEqual(try action(#"{"action":"perform-action","perform_action":"broken"}"#), .none)
        XCTAssertEqual(try action(#"{"action":"perform-action"}"#), .none)
    }

    func testTargetAcceptsBothASingleEntityAndAList() throws {
        let many = try action("""
        {
          "action": "perform-action",
          "perform_action": "light.turn_off",
          "target": {"entity_id": ["light.a", "light.b"]}
        }
        """)
        guard case .performAction(_, _, _, let entityIDs) = many else {
            return XCTFail("Erwartet wurde eine performAction")
        }
        XCTAssertEqual(entityIDs, ["light.a", "light.b"])
    }

    func testUnknownActionKeepsTheFallback() throws {
        XCTAssertEqual(try action(#"{"action":"assist"}"#, default: .toggle), .toggle)
    }
}
