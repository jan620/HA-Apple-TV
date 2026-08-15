import SwiftUI
import UIKit

/// Cycles through the pictures of a Home Assistant media folder behind the
/// ambient screen.
///
/// Images are resolved one at a time rather than up front: Home Assistant signs
/// media URLs with a short lifetime, so a list resolved an hour ago would be
/// worthless by the time the screen saver reaches it.
struct ScreensaverBackground: View {
    let folderID: String
    let interval: TimeInterval

    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var auth: AuthManager

    @State private var entries: [MediaEntry] = []
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
        .task(id: folderID) { await run() }
    }

    private func run() async {
        entries = (try? await MediaSource(client: connection).browse(folderID))?
            .filter(\.isImage)
            .shuffled() ?? []

        guard !entries.isEmpty else { return }

        var index = 0
        while !Task.isCancelled {
            if let loaded = await load(entries[index % entries.count]) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    image = loaded
                    revision += 1
                }
            }
            index += 1

            try? await Task.sleep(nanoseconds: UInt64(interval * Double(NSEC_PER_SEC)))
        }
    }

    private func load(_ entry: MediaEntry) async -> UIImage? {
        // `try?` on a method that already returns an optional nests two levels;
        // `?? nil` flattens them back to one.
        let resolved = (try? await MediaSource(client: connection).resolve(entry.id)) ?? nil

        guard let server = auth.server, let path = resolved else { return nil }

        var request = URLRequest(url: server.url(path: path))
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
