import SwiftUI
import UIKit

/// Loads an image from a Home Assistant path (`/api/camera_proxy/...`,
/// `entity_picture`, …) with the session's bearer token attached, optionally
/// refreshing on an interval for camera snapshots.
struct HARemoteImage: View {
    let path: String
    var refreshInterval: TimeInterval?
    var contentMode: ContentMode = .fill

    @EnvironmentObject private var auth: AuthManager
    @State private var image: UIImage?
    @State private var isFailed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Theme.cardBackgroundElevated)
                    .overlay {
                        if isFailed {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: path) {
            await reloadLoop()
        }
    }

    private func reloadLoop() async {
        await reload()
        guard let refreshInterval, refreshInterval > 0 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(refreshInterval * Double(NSEC_PER_SEC)))
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    private func reload() async {
        guard let server = auth.server else { return }

        // Paths already carry a signed token for camera proxies, but sending the
        // bearer token as well keeps authenticated endpoints working.
        var request = URLRequest(url: server.url(path: path))
        if let token = try? await auth.validAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await auth.session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let decoded = UIImage(data: data)
            else {
                isFailed = image == nil
                return
            }
            image = decoded
            isFailed = false
        } catch {
            isFailed = image == nil
        }
    }
}
