import XCTest
@testable import HomeDash

/// URL normalisation is the very first thing a user touches, typed with a
/// remote, and its scheme guess decides whether credentials travel in the clear.
final class HAServerTests: XCTestCase {
    private func normalized(_ input: String) -> String? {
        HAServer.normalizedURL(from: input)?.absoluteString
    }

    func testKeepsAnExplicitScheme() {
        XCTAssertEqual(normalized("http://example.com:8123"), "http://example.com:8123")
        XCTAssertEqual(normalized("https://abc.ui.nabu.casa"), "https://abc.ui.nabu.casa")
    }

    func testAssumesHTTPSForPublicHostnames() {
        XCTAssertEqual(normalized("abc.ui.nabu.casa"), "https://abc.ui.nabu.casa")
        XCTAssertEqual(normalized("home.example.org"), "https://home.example.org")
    }

    func testAssumesHTTPForPrivateAddresses() {
        XCTAssertEqual(normalized("192.168.1.10:8123"), "http://192.168.1.10:8123")
        XCTAssertEqual(normalized("10.0.0.5:8123"), "http://10.0.0.5:8123")
        XCTAssertEqual(normalized("homeassistant.local:8123"), "http://homeassistant.local:8123")
        XCTAssertEqual(normalized("localhost:8123"), "http://localhost:8123")
    }

    /// The 172 range is only private from 172.16 to 172.31 — treating all of
    /// `172.` as local would downgrade public addresses to cleartext.
    func testOnlyTheReservedPartOf172IsTreatedAsPrivate() {
        XCTAssertEqual(normalized("172.16.0.1:8123"), "http://172.16.0.1:8123")
        XCTAssertEqual(normalized("172.31.255.254:8123"), "http://172.31.255.254:8123")
        XCTAssertEqual(normalized("172.15.0.1:8123"), "https://172.15.0.1:8123")
        XCTAssertEqual(normalized("172.32.0.1:8123"), "https://172.32.0.1:8123")
    }

    func testStripsTrailingSlashesAndQueries() {
        XCTAssertEqual(normalized("https://example.com/"), "https://example.com")
        XCTAssertEqual(normalized("https://example.com/?a=b"), "https://example.com")
    }

    func testRejectsNonsense() {
        XCTAssertNil(normalized(""))
        XCTAssertNil(normalized("   "))
        XCTAssertNil(normalized("ftp://example.com"))
    }

    /// Home Assistant skips its IndieAuth network check when redirect URI and
    /// client ID share an origin, which is what makes login work for instances
    /// reachable only by IP.
    func testClientIDAndRedirectURIShareTheInstanceOrigin() throws {
        let url = try XCTUnwrap(HAServer.normalizedURL(from: "https://example.com/subpath"))
        let server = HAServer(baseURL: url, name: "Test")
        XCTAssertEqual(server.clientID, "https://example.com/")
        XCTAssertEqual(server.redirectURI, server.clientID)
    }

    func testWebSocketURLUpgradesTheScheme() throws {
        let secure = try XCTUnwrap(HAServer.normalizedURL(from: "https://example.com"))
        XCTAssertEqual(
            HAServer(baseURL: secure, name: "T").webSocketURL.absoluteString,
            "wss://example.com/api/websocket"
        )

        let plain = try XCTUnwrap(HAServer.normalizedURL(from: "http://192.168.1.10:8123"))
        XCTAssertEqual(
            HAServer(baseURL: plain, name: "T").webSocketURL.absoluteString,
            "ws://192.168.1.10:8123/api/websocket"
        )
    }
}
