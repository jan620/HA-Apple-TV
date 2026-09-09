import XCTest
@testable import Roomglance

/// Ein Thermostat im Modus „Heizen/Kühlen" hat kein `temperature`, sondern ein
/// Paar aus `target_temp_low` und `target_temp_high`. Wer nur das erste liest,
/// zeigt bei genau diesen Geräten einen Strich statt der Solltemperatur — auf
/// dem Apple TV war das an der Ecobee-Demo zu sehen, während die
/// Weboberfläche daneben 21,0 und 24,0 anzeigte.
final class ClimateTargetTests: XCTestCase {
    private func text(target: Double? = nil, low: Double? = nil, high: Double? = nil) -> String {
        ThermostatCardView.targetText(target: target, low: low, high: high, unit: "°C")
    }

    /// Bewusst ganze Zahlen: `HANumber.format` benutzt die Locale der Umgebung,
    /// und ein Test auf „21,5" wäre auf einem Runner mit Punkt als
    /// Dezimaltrennzeichen rot, ohne dass am Verhalten etwas falsch wäre.
    func testSingleSetpointIsShownAsOneValue() {
        XCTAssertEqual(text(target: 21), "21°C")
    }

    func testRangeIsShownAsBothBounds() {
        XCTAssertEqual(text(low: 21, high: 24), "21 – 24°C")
    }

    /// `temperature` hat Vorrang: liefert eine Instanz beides, ist der einzelne
    /// Sollwert der maßgebliche.
    func testSingleSetpointWinsOverRange() {
        XCTAssertEqual(text(target: 22, low: 21, high: 24), "22°C")
    }

    /// Eine halbe Angabe ist keine — ein Bereich braucht beide Grenzen.
    func testHalfARangeFallsBackToTheDash() {
        XCTAssertEqual(text(low: 21), "—")
        XCTAssertEqual(text(high: 24), "—")
    }

    func testNothingConfiguredShowsTheDash() {
        XCTAssertEqual(text(), "—")
    }
}
