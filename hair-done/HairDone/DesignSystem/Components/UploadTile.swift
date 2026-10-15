import SwiftUI
import UIKit

/// Where a photo she picked has got to.
enum UploadState: Equatable {
    /// 0...1. Shows as a 2pt ink line growing along the bottom edge.
    case uploading(Double)
    case done
    /// The photo at 45% with a retry glyph, and "Didn't upload. Tap to try again." under the tile
    /// (it wraps at large text sizes, so the view grows taller); tapping either calls `onRetry`.
    case failed
}

/// A photo she picked (work, inspo, a cover), 104x130 by default at 2pt corners, with its upload
/// state. A failed one is taller: its words sit under the tile. Always shows *her* picked image, never a stand-in photo (audit M21).
///
///     UploadTile(image: picked.image, state: picked.state) { retry(picked) }
///     UploadTile(state: .failed, onRetry: retry) { WorkTile(item: item, cornerRadius: 0) }
struct UploadTile<Photo: View>: View {
    var state: UploadState
    var size: CGSize
    var onRetry: (() -> Void)?
    var onRemove: (() -> Void)?
    private let photo: Photo

    init(state: UploadState, size: CGSize = CGSize(width: 104, height: 130),
         onRetry: (() -> Void)? = nil, onRemove: (() -> Void)? = nil,
         @ViewBuilder photo: () -> Photo) {
        self.state = state
        self.size = size
        self.onRetry = onRetry
        self.onRemove = onRemove
        self.photo = photo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            tile
            if state == .failed {
                // Under the tile, not on it, so the words can wrap at any text size.
                Button {
                    Haptics.light()
                    onRetry?()
                } label: {
                    Text("Didn't upload. Tap to try again.")
                        .font(HDFont.caption)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: size.width, alignment: .leading)
                        .frame(minHeight: 44, alignment: .topLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Didn't upload. Try again")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
    }

    private var tile: some View {
        ZStack(alignment: .bottomLeading) {
            Palette.photoGround
            photo
                .frame(width: size.width, height: size.height)
                .clipped()
                .opacity(state == .failed ? 0.45 : 1)
            switch state {
            case .uploading(let progress):
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Palette.onPhoto.opacity(0.6))
                        Rectangle().fill(Palette.ink)
                            .frame(width: proxy.size.width * CGFloat(min(max(progress, 0), 1)))
                    }
                }
                .frame(height: 2)
                .animation(Motion.gentle, value: progress)
            case .failed:
                // The faded photo is a retry target too, with a small outline glyph to say so.
                Button {
                    Haptics.light()
                    onRetry?()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            case .done:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height)
        .photoShape()
        .overlay(alignment: .topTrailing) {
            if let onRemove {
                Button {
                    Haptics.light()
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 20, height: 20)
                        .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove photo")
            }
        }
    }

    private var accessibilityText: String {
        switch state {
        case .uploading(let p): return "Photo, uploading, \(Int((p * 100).rounded())) percent"
        case .done: return "Photo"
        case .failed: return "Photo didn't upload. Double-tap to try again."
        }
    }
}

extension UploadTile where Photo == AnyView {
    /// A picked `UIImage`, filled and cropped. Nil shows the warm photo ground.
    /// A trailing closure is `onRetry`.
    init(image: UIImage?, state: UploadState, size: CGSize = CGSize(width: 104, height: 130),
         onRetry: (() -> Void)? = nil, onRemove: (() -> Void)? = nil) {
        self.init(state: state, size: size, onRetry: onRetry, onRemove: onRemove) {
            image.map { AnyView(Image(uiImage: $0).resizable().scaledToFill()) } ?? AnyView(Palette.photoGround)
        }
    }
}

#Preview("UploadTile") {
    HStack(spacing: 8) {
        UploadTile(state: .uploading(0.4)) { Placeholder.gradient(seed: 3) }
        UploadTile(state: .done, onRemove: {}) { Placeholder.gradient(seed: 5) }
        UploadTile(state: .failed, onRetry: {}) { Placeholder.gradient(seed: 7) }
    }
    .padding(20)
    .paperBackground()
}
