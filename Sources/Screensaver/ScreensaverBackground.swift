import SwiftUI
import UIKit

/// The pictures behind the ambient screen, from either of two sources.
///
/// Both end up as a slow crossfade between full-bleed images; only where the
/// next picture comes from differs.
struct ScreensaverBackground: View {
    enum Source: Equatable {
        /// A folder from Home Assistant's media browser. The app picks the
        /// order and holds each picture for the configured interval.
        case mediaFolder(String)
        /// A camera entity that produces the pictures itself — what the
        /// Album Slideshow integration exposes for PhotoPrism, Immich and the
        /// like. The integration decides what to show; the app just looks.
        case camera(String)
    }

    let source: Source
    let interval: TimeInterval

    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var auth: AuthManager

    @State private var image: UIImage?
    /// Bumped with every picture so SwiftUI treats the next one as a new view
    /// and actually crossfades instead of swapping in place.
    @State private var revision = 0

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
                    .id(revision)
            }
        }
        .clipped()
        .ignoresSafeArea()
        .task(id: source) { await run() }
    }

    private func run() async {
        switch source {
        case .mediaFolder(let folderID):
            await runMediaFolder(folderID)
        case .camera(let entityID):
            await runCamera(entityID)
        }
    }

    // MARK: Media folder

    private func runMediaFolder(_ folderID: String) async {
        // Shuffled once per run, so the evening does not always start with the
        // same three pictures.
        let entries = (try? await MediaSource(client: connection).browse(folderID))?
            .filter(\.isImage)
            .shuffled() ?? []

        guard !entries.isEmpty else { return }

        var index = 0
        while !Task.isCancelled {
            await show(await loadMedia(entries[index % entries.count]))
            index += 1
            try? await Task.sleep(nanoseconds: UInt64(interval * Double(NSEC_PER_SEC)))
        }
    }

    /// Media URLs are signed with a short lifetime, so each one is resolved
    /// immediately before it is fetched rather than in a batch up front.
    private func loadMedia(_ entry: MediaEntry) async -> UIImage? {
        // `try?` on a method that already returns an optional nests two levels;
        // `?? nil` flattens them back to one.
        let resolved = (try? await MediaSource(client: connection).resolve(entry.id)) ?? nil
        guard let path = resolved else { return nil }
        return await fetch(path: path)
    }

    // MARK: Camera

    private func runCamera(_ entityID: String) async {
        while !Task.isCancelled {
            await show(await fetch(path: "/api/camera_proxy/\(entityID)"))
            try? await Task.sleep(nanoseconds: UInt64(interval * Double(NSEC_PER_SEC)))
        }
    }

    // MARK: Shared

    private func show(_ loaded: UIImage?) async {
        guard let loaded else { return }
        withAnimation(.easeInOut(duration: 1.5)) {
            image = loaded
            revision += 1
        }
    }

    private func fetch(path: String) async -> UIImage? {
        guard let server = auth.server else { return nil }

        var request = URLRequest(url: server.url(path: path))
        // A slideshow camera answers the same URL with a different picture
        // every time; a cached response would freeze the background.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let token = try? await auth.validAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await auth.session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return nil }

        return UIImage(data: data)
    }
}
