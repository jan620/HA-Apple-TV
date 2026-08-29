import Foundation

/// One entry in Home Assistant's media browser — a folder to descend into or a
/// single file.
struct MediaEntry: Identifiable, Hashable {
    /// Home Assistant's `media-source://…` identifier. Doubles as the id.
    let id: String
    let title: String
    let isFolder: Bool
    let mediaClass: String
    let contentType: String

    /// Whether this entry is something the screen saver can show.
    ///
    /// `media_class` is the reliable signal — Home Assistant reports plain
    /// `image` there — while `media_content_type` carries the MIME type for
    /// files but a bare `app` or `directory` for folders.
    var isImage: Bool {
        !isFolder && (mediaClass == "image" || contentType.hasPrefix("image/"))
    }

    init?(json: JSONValue) {
        guard let id = json["media_content_id"]?.stringValue else { return nil }
        self.id = id
        title = json["title"]?.stringValue ?? id
        isFolder = json["can_expand"]?.boolValue ?? false
        mediaClass = json["media_class"]?.stringValue ?? ""
        contentType = json["media_content_type"]?.stringValue ?? ""
    }
}

/// Reads Home Assistant's media sources over the WebSocket API.
///
/// This is the same tree the "Medien" panel shows: the server's `media/`
/// folder, plus whatever integrations contribute. Pictures served this way need
/// no extra configuration and reuse the session the app already holds.
struct MediaSource {
    let client: HAWebSocketClient

    /// The root of the tree. Passing `nil` as the identifier asks Home
    /// Assistant for the top level.
    func browse(_ contentID: String?) async throws -> [MediaEntry] {
        var payload: [String: JSONValue] = ["type": "media_source/browse_media"]
        if let contentID {
            payload["media_content_id"] = .string(contentID)
        }

        let response = try await client.send(payload)
        let children = response["children"]?.arrayValue ?? []
        return children.compactMap(MediaEntry.init(json:))
    }

    /// Turns a media identifier into a path the app can fetch. The result is
    /// signed and short-lived, so it is resolved right before use rather than
    /// stored.
    func resolve(_ contentID: String) async throws -> String? {
        let response = try await client.send([
            "type": "media_source/resolve_media",
            "media_content_id": .string(contentID),
        ])
        return response["url"]?.stringValue
    }
}
