import SwiftUI
import PhotosUI
import UIKit

/// Turns a picked photo into what we upload: at most 2000px on the long side, JPEG at 0.8.
enum AccountPhotoData {
    static let maxSide: CGFloat = 2000

    /// The picked item's image, scaled down, and its JPEG. Nil if it couldn't be read.
    static func load(_ item: PhotosPickerItem) async -> (image: UIImage, jpeg: Data)? {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return nil }
        let scaled = downscale(original)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.8) else { return nil }
        return (scaled, jpeg)
    }

    static func downscale(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let factor = maxSide / longest
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
