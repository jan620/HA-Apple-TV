import XCTest
@testable import Roomglance

/// Home Assistant describes folders and files with the same shape, and the
/// screen saver has to tell them apart from `media_class` alone — a picture
/// folder and a picture look nearly identical otherwise.
final class MediaSourceTests: XCTestCase {
    private func entry(
        id: String = "media-source://media_source/local/x.jpg",
        title: String = "x.jpg",
        canExpand: Bool = false,
        mediaClass: String = "image",
        contentType: String = "image/jpeg"
    ) -> MediaEntry? {
        MediaEntry(json: .object([
            "media_content_id": .string(id),
            "title": .string(title),
            "can_expand": .bool(canExpand),
            "media_class": .string(mediaClass),
            "media_content_type": .string(contentType),
        ]))
    }

    func testEntryWithoutAnIdentifierIsRejected() {
        XCTAssertNil(MediaEntry(json: .object(["title": .string("Ohne ID")])))
    }

    func testPictureIsRecognisedByMediaClass() {
        let picture = entry(mediaClass: "image", contentType: "image/jpeg")
        XCTAssertEqual(picture?.isImage, true)
        XCTAssertEqual(picture?.isFolder, false)
    }

    /// Older cores leave `media_class` empty on files and only fill the MIME
    /// type, so the fallback has to hold.
    func testPictureIsRecognisedByMimeTypeAlone() {
        XCTAssertEqual(entry(mediaClass: "", contentType: "image/png")?.isImage, true)
    }

    func testFolderIsNeverTreatedAsAPicture() {
        let folder = entry(
            id: "media-source://media_source/local/urlaub",
            title: "Urlaub",
            canExpand: true,
            mediaClass: "directory",
            contentType: "app"
        )
        XCTAssertEqual(folder?.isFolder, true)
        XCTAssertEqual(folder?.isImage, false)
    }

    /// A folder whose class is `image` — Home Assistant labels picture albums
    /// this way — must still not be fetched as a picture.
    func testPictureFolderIsNotAPicture() {
        let album = entry(title: "Album", canExpand: true, mediaClass: "image", contentType: "app")
        XCTAssertEqual(album?.isFolder, true)
        XCTAssertEqual(album?.isImage, false)
    }

    func testVideoIsNotAPicture() {
        XCTAssertEqual(entry(mediaClass: "video", contentType: "video/mp4")?.isImage, false)
    }

    func testTitleFallsBackToTheIdentifier() {
        let json = JSONValue.object(["media_content_id": .string("media-source://x")])
        XCTAssertEqual(MediaEntry(json: json)?.title, "media-source://x")
    }
}
