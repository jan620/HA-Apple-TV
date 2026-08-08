import AVKit
import SwiftUI

/// Resolves a camera's HLS stream through the `camera/stream` WebSocket command.
///
/// The returned URL carries its own signed token, so `AVPlayer` can play it
/// without the app's bearer token.
@MainActor
final class CameraStream: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isUnavailable = false

    func start(entityID: String, client: HAWebSocketClient, server: HAServer) async {
        stop()
        do {
            let response = try await client.send([
                "type": "camera/stream",
                "entity_id": .string(entityID),
                "format": .string("hls"),
            ])
            guard let path = response["url"]?.stringValue else {
                isUnavailable = true
                return
            }
            let url = path.hasPrefix("http") ? URL(string: path) : server.url(path: path)
            guard let url else {
                isUnavailable = true
                return
            }
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.play()
            self.player = player
            isUnavailable = false
        } catch {
            // Cameras without the `stream` integration have no HLS endpoint;
            // callers fall back to snapshot polling.
            isUnavailable = true
        }
    }

    func stop() {
        player?.pause()
        player = nil
    }
}

/// Live camera view: HLS when the camera supports it, still-image polling
/// otherwise.
struct CameraLiveView: View {
    let entityID: String
    var pollInterval: TimeInterval = 2

    @EnvironmentObject private var connection: HAWebSocketClient
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var stream = CameraStream()

    var body: some View {
        ZStack {
            if let player = stream.player {
                VideoPlayer(player: player)
            } else {
                HARemoteImage(
                    path: "/api/camera_proxy/\(entityID)",
                    refreshInterval: pollInterval
                )
            }
        }
        .task(id: entityID) {
            guard let server = auth.server else { return }
            await stream.start(entityID: entityID, client: connection, server: server)
        }
        .onDisappear { stream.stop() }
    }
}

/// A camera still that refreshes slowly — used inside dashboard cards, where a
/// live stream per camera would be wasteful.
struct CameraSnapshotView: View {
    let entityID: String
    var refreshInterval: TimeInterval = 10

    var body: some View {
        HARemoteImage(path: "/api/camera_proxy/\(entityID)", refreshInterval: refreshInterval)
    }
}

/// `type: picture-entity`
struct PictureEntityCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        let entity = card.entityID.flatMap { store.entity($0) }
        let cameraID = card["camera_image"]?.stringValue
            ?? (entity?.domain == "camera" ? entity?.entityID : nil)

        CardButton(card: card, entityID: card.entityID, defaultAction: .moreInfo) {
            VStack(spacing: 0) {
                imageContent(cameraID: cameraID, entity: entity)
                    .frame(height: 300)
                    .clipped()

                if card["show_name"]?.boolValue != false || card["show_state"]?.boolValue != false {
                    HStack {
                        if card["show_name"]?.boolValue != false {
                            Text(card["name"]?.stringValue ?? entity?.friendlyName ?? "—")
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 12)
                        if card["show_state"]?.boolValue != false, let entity {
                            Text(entity.displayState)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func imageContent(cameraID: String?, entity: HAEntity?) -> some View {
        if let cameraID {
            CameraSnapshotView(entityID: cameraID)
        } else if let picture = card["image"]?.stringValue ?? entity?.entityPicture {
            HARemoteImage(path: picture)
        } else {
            ZStack {
                Theme.cardBackgroundElevated
                EntityIcon(entity: entity, overrideIcon: card.icon, size: 64)
            }
        }
    }
}

/// `type: picture-glance`
struct PictureGlanceCardView: View {
    let card: LovelaceCardConfig

    @EnvironmentObject private var store: EntityStore

    var body: some View {
        CardSurface(padding: 0) {
            VStack(spacing: 0) {
                background
                    .frame(height: 300)
                    .clipped()

                HStack(spacing: 14) {
                    if let title = card["title"]?.stringValue {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 12)
                    ForEach(card.entityRows) { row in
                        if let entityID = row.entityID {
                            let entity = store.entity(entityID)
                            CardButton(card: card, entityID: entityID, appearance: .row) {
                                EntityIcon(entity: entity, overrideIcon: row.icon, size: 24)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if let cameraID = card["camera_image"]?.stringValue {
            CameraSnapshotView(entityID: cameraID)
        } else if let image = card["image"]?.stringValue {
            HARemoteImage(path: image)
        } else {
            Theme.cardBackgroundElevated
        }
    }
}

/// `type: picture`
struct PictureCardView: View {
    let card: LovelaceCardConfig

    var body: some View {
        // Spelled out because `.none` on an optional parameter would resolve to
        // `Optional.none` instead of the case we mean.
        CardButton(card: card, entityID: nil, defaultAction: CardAction.none) {
            Group {
                if let image = card["image"]?.stringValue {
                    HARemoteImage(path: image)
                } else {
                    Theme.cardBackgroundElevated
                }
            }
            .frame(height: 320)
            .clipped()
        }
    }
}
