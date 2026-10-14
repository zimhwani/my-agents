import SwiftUI
import PhotosUI
import UIKit

/// Turns a photo she picked into what we upload: at most 2000px on the long side, JPEG at 0.8.
/// Used by the inspo step. (Other screens keep their own copy; this one is the booking flow's.)
enum InspoPhoto {
    static let maxSide: CGFloat = 2000
    static let quality: CGFloat = 0.8

    /// Loads a picked item and returns the upload-ready JPEG, or nil if it couldn't be read.
    static func jpeg(from item: PhotosPickerItem) async -> Data? {
        guard let raw = try? await item.loadTransferable(type: Data.self) else { return nil }
        return jpeg(from: raw)
    }

    /// Any image data (HEIC, PNG, JPEG) to a downscaled JPEG.
    static func jpeg(from raw: Data) -> Data? {
        guard let image = UIImage(data: raw) else { return nil }
        return downscaled(image).jpegData(compressionQuality: quality)
    }

    /// A small copy for a tile, so the step doesn't decode full-size photos on every redraw.
    static func thumbnail(from jpeg: Data, side: CGFloat = 320) -> UIImage? {
        guard let image = UIImage(data: jpeg) else { return nil }
        return downscaled(image, maxSide: side)
    }

    private static func downscaled(_ image: UIImage, maxSide: CGFloat = InspoPhoto.maxSide) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
