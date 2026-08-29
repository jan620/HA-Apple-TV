import XCTest
@testable import HomeDash

/// `AVPlayer` fetches on its own and never passes through the session delegate
/// that pins the certificate to the configured host. An absolute stream URL
/// pointing anywhere else would therefore be contacted outside every trust
/// decision the rest of the app makes — so this is a security boundary, not a
/// convenience check.
final class CameraStreamTests: XCTestCase {
    private func server(_ address: String) -> HAServer {
        HAServer(baseURL: URL(string: address)!, name: "Test")
    }

    private func resolve(_ path: String, on address: String = "https://home.example.org") -> String? {
        CameraStream.streamURL(from: path, server: server(address))?.absoluteString
    }

    // MARK: The normal case

    func testRelativePathIsResolvedAgainstTheInstance() {
        XCTAssertEqual(
            resolve("/api/hls/abc123/master_playlist.m3u8"),
            "https://home.example.org/api/hls/abc123/master_playlist.m3u8"
        )
    }

    func testAbsoluteURLOnTheSameInstanceIsAccepted() {
        XCTAssertEqual(
            resolve("https://home.example.org/api/hls/abc/index.m3u8"),
            "https://home.example.org/api/hls/abc/index.m3u8"
        )
    }

    // MARK: What must be refused

    func testAbsoluteURLOnAnotherHostIsRefused() {
        XCTAssertNil(resolve("https://angreifer.example.net/stream.m3u8"))
    }

    /// A prefix match on the hostname would let `home.example.org.evil.net`
    /// through.
    func testLookalikeHostIsRefused() {
        XCTAssertNil(resolve("https://home.example.org.angreifer.net/stream.m3u8"))
    }

    func testDowngradeToPlainHTTPIsRefused() {
        XCTAssertNil(resolve("http://home.example.org/stream.m3u8"))
    }

    func testDifferentPortIsRefused() {
        XCTAssertNil(resolve("https://home.example.org:9999/stream.m3u8"))
    }

    /// Only that it is accepted — how Foundation spells the host back is its
    /// business, not this test's.
    func testHostIsComparedCaseInsensitively() {
        XCTAssertNotNil(resolve("https://HOME.example.ORG/api/hls/abc/index.m3u8"))
    }

    /// The scheme check has to survive a capitalised spelling rather than
    /// falling through to the relative-path branch.
    func testUppercaseSchemeIsStillTreatedAsAbsolute() {
        XCTAssertNil(resolve("HTTPS://angreifer.example.net/stream.m3u8"))
    }

    // MARK: Instances on a port

    func testMatchingPortIsAccepted() {
        XCTAssertEqual(
            resolve("http://192.168.1.10:8123/api/hls/a/i.m3u8", on: "http://192.168.1.10:8123"),
            "http://192.168.1.10:8123/api/hls/a/i.m3u8"
        )
    }

    func testRelativePathKeepsThePortOfTheInstance() {
        XCTAssertEqual(
            resolve("/api/hls/a/i.m3u8", on: "http://192.168.1.10:8123"),
            "http://192.168.1.10:8123/api/hls/a/i.m3u8"
        )
    }
}
