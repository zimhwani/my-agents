import SwiftUI
import AVFoundation
import UIKit

/// The three clips behind the welcome screen: hair, makeup, nails, in that order.
/// Each slot resolves to a bundled file first (`Resources/Intro/<name>.mp4`), then a
/// remote URL, then nothing. With nothing, the welcome screen shows placeholder art.
enum IntroClips {
    struct Clip { let name: String; let remote: URL? }

    static let all: [Clip] = [
        Clip(name: "intro-hair",   remote: nil),
        Clip(name: "intro-makeup", remote: nil),
        Clip(name: "intro-nails",  remote: nil)
    ]

    static func urls() -> [URL] {
        all.compactMap { clip in
            if let bundled = Bundle.main.url(forResource: clip.name, withExtension: "mp4")
                ?? Bundle.main.url(forResource: clip.name, withExtension: "mov") { return bundled }
            return clip.remote
        }
    }

    /// True when there's something to play and the phone isn't asking us not to.
    static func shouldPlay(reduceMotion: Bool) -> Bool {
        !urls().isEmpty && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

/// Full-bleed, muted, aspect-fill playlist that loops. Hard cuts between clips.
struct IntroVideoView: UIViewRepresentable {
    var urls: [URL]

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        context.coordinator.attach(to: view, urls: urls)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    final class Coordinator: NSObject {
        private var player: AVQueuePlayer?
        private var urls: [URL] = []
        private var endObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?

        func attach(to view: PlayerView, urls: [URL]) {
            self.urls = urls
            let player = AVQueuePlayer(items: urls.map { AVPlayerItem(url: $0) })
            player.isMuted = true
            player.actionAtItemEnd = .advance
            player.preventsDisplaySleepDuringVideoPlayback = false
            view.playerLayer.player = player
            view.playerLayer.videoGravity = .resizeAspectFill
            self.player = player

            // When the last clip ends the queue is empty; refill and go again.
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self, let player = self.player else { return }
                // The finished item is still in the queue at this point; once it's the only one left, top up.
                if player.items().count <= 1 {
                    for url in self.urls { player.insert(AVPlayerItem(url: url), after: nil) }
                    player.play()
                }
            }
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.player?.play() }

            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            player.play()
        }

        func detach() {
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
            player?.pause()
            player = nil
        }
    }
}

/// What the welcome screen shows when there's no video: three tiles that slowly crossfade.
struct IntroPlaceholderView: View {
    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let items: [WorkItem] = Array(MockData.pros.prefix(6).compactMap { $0.work.first })

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                WorkTile(item: item, cornerRadius: 0)
                    .opacity(i == index ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .task {
            guard !reduceMotion, items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.easeInOut(duration: 1.2)) { index = (index + 1) % items.count }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Video or placeholder, plus the ink gradient that makes paper-coloured type readable on top.
struct IntroBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if IntroClips.shouldPlay(reduceMotion: reduceMotion) {
                IntroVideoView(urls: IntroClips.urls()).ignoresSafeArea()
            } else {
                IntroPlaceholderView()
            }
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x171210).opacity(0.25), location: 0),
                    .init(color: Color(hex: 0x171210).opacity(0.55), location: 0.55),
                    .init(color: Color(hex: 0x171210).opacity(0.92), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}
