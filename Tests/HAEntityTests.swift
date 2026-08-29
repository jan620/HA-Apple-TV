import XCTest
@testable import HomeDash

/// These branches decide whether a tile looks on, whether clicking it toggles
/// or opens details, and what the state line reads — all instantly visible and
/// easy to break while refactoring.
final class HAEntityTests: XCTestCase {
    private func entity(
        _ entityID: String,
        _ state: String,
        _ attributes: [String: JSONValue] = [:]
    ) -> HAEntity {
        HAEntity(entityID: entityID, state: state, attributes: attributes)
    }

    // MARK: Identity

    func testDomainAndObjectIDSplitOnTheFirstDot() {
        let light = entity("light.living_room", "on")
        XCTAssertEqual(light.domain, "light")
        XCTAssertEqual(light.objectID, "living_room")
    }

    func testFriendlyNameFallsBackToAReadableObjectID() {
        XCTAssertEqual(entity("light.living_room", "on").friendlyName, "Living Room")
        XCTAssertEqual(
            entity("light.x", "on", ["friendly_name": .string("Stehlampe")]).friendlyName,
            "Stehlampe"
        )
    }

    // MARK: isActive

    func testActiveStatesAreDomainSpecific() {
        XCTAssertTrue(entity("light.a", "on").isActive)
        XCTAssertFalse(entity("light.a", "off").isActive)

        // A closed cover is inactive; anything else counts as active.
        XCTAssertTrue(entity("cover.a", "open").isActive)
        XCTAssertFalse(entity("cover.a", "closed").isActive)

        // A lock is "active" when unlocked, which is the inverse of its state.
        XCTAssertTrue(entity("lock.a", "unlocked").isActive)
        XCTAssertFalse(entity("lock.a", "locked").isActive)

        XCTAssertFalse(entity("media_player.a", "idle").isActive)
        XCTAssertTrue(entity("media_player.a", "playing").isActive)

        XCTAssertTrue(entity("climate.a", "heat").isActive)
        XCTAssertFalse(entity("climate.a", "off").isActive)

        XCTAssertTrue(entity("person.a", "home").isActive)
        XCTAssertFalse(entity("person.a", "not_home").isActive)
    }

    func testUnavailableEntitiesAreNeverActive() {
        XCTAssertFalse(entity("light.a", "unavailable").isActive)
        XCTAssertFalse(entity("light.a", "unknown").isActive)
        XCTAssertTrue(entity("light.a", "unavailable").isUnavailable)
    }

    func testReadOnlyDomainsAreNeverActive() {
        // A sensor reading of "on" must not light up as if it were switchable.
        XCTAssertFalse(entity("sensor.a", "on").isActive)
        XCTAssertFalse(entity("weather.a", "sunny").isActive)
        XCTAssertFalse(entity("update.a", "on").isActive)
    }

    // MARK: Interaction

    func testToggleableDomains() {
        XCTAssertTrue(entity("light.a", "on").isToggleable)
        XCTAssertTrue(entity("switch.a", "off").isToggleable)
        XCTAssertFalse(entity("sensor.a", "5").isToggleable)
        XCTAssertFalse(entity("light.a", "unavailable").isToggleable)
    }

    func testMediaPlayerIsOnlyToggleableWhenItSupportsPower() {
        let dumb = entity("media_player.a", "playing")
        XCTAssertFalse(dumb.isToggleable)

        let smart = entity(
            "media_player.a",
            "playing",
            ["supported_features": .number(Double(MediaPlayerFeature.turnOff))]
        )
        XCTAssertTrue(smart.isToggleable)
    }

    func testActivatableDomains() {
        XCTAssertTrue(entity("scene.a", "unknown").isActivatable)
        XCTAssertTrue(entity("script.a", "off").isActivatable)
        XCTAssertFalse(entity("light.a", "on").isActivatable)
    }

    func testSupportedFeaturesIsABitmask() {
        let cover = entity(
            "cover.a",
            "open",
            ["supported_features": .number(Double(CoverFeature.open | CoverFeature.setPosition))]
        )
        XCTAssertTrue(cover.supports(CoverFeature.open))
        XCTAssertTrue(cover.supports(CoverFeature.setPosition))
        XCTAssertFalse(cover.supports(CoverFeature.setTiltPosition))
    }

    // MARK: Display

    func testNumericStatesAreShownWithTheirUnit() {
        let sensor = entity(
            "sensor.temp",
            "21.5",
            ["unit_of_measurement": .string("°C")]
        )
        XCTAssertTrue(sensor.displayState.contains("°C"))
        XCTAssertTrue(sensor.displayState.contains("21"))
    }

    func testKnownStatesAreTranslated() {
        XCTAssertEqual(entity("light.a", "on").displayState, "An")
        XCTAssertEqual(entity("cover.a", "closed").displayState, "Geschlossen")
        XCTAssertEqual(entity("person.a", "not_home").displayState, "Abwesend")
    }

    func testUnknownStatesStayReadable() {
        XCTAssertEqual(entity("sensor.a", "some_custom_state").displayState, "Some Custom State")
    }

    // MARK: Parsing

    func testInitFromStateJSON() throws {
        let json = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {
          "entity_id": "light.kitchen",
          "state": "on",
          "attributes": {"friendly_name": "Küche", "brightness": 128},
          "last_changed": "2026-08-09T10:11:12.123456+00:00"
        }
        """.utf8))

        let parsed = try XCTUnwrap(HAEntity(json: json))
        XCTAssertEqual(parsed.entityID, "light.kitchen")
        XCTAssertEqual(parsed.friendlyName, "Küche")
        XCTAssertEqual(parsed.attributes["brightness"]?.intValue, 128)
        // Six fractional digits are what Home Assistant actually sends.
        XCTAssertNotNil(parsed.lastChanged)
    }

    func testInitRejectsIncompleteJSON() throws {
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"state":"on"}"#.utf8))
        XCTAssertNil(HAEntity(json: json))
    }
}
