import SwiftUI

/// Procedural placeholder art: warm gradients with soft blurred shapes and a light grain.
/// Stands in for work photos until real ones are uploaded. Never a grey box.
enum Placeholder {
    static let swatches: [[Color]] = [
        [Color(hex: 0xF3D0CB), Color(hex: 0xE8A9A0), Color(hex: 0xC8323A)],
        [Color(hex: 0xEAD9CB), Color(hex: 0xC9A27E), Color(hex: 0x6B4A33)],
        [Color(hex: 0xE8D2DF), Color(hex: 0xC99DB7), Color(hex: 0x6E3E5C)],
        [Color(hex: 0xD8D4E5), Color(hex: 0xA79FC6), Color(hex: 0x46406B)],
        [Color(hex: 0xD9DED0), Color(hex: 0xA9B7A2), Color(hex: 0x48583A)],
        [Color(hex: 0xEFE3C8), Color(hex: 0xE9B96A), Color(hex: 0x7A5F1F)],
        [Color(hex: 0xF6DEDC), Color(hex: 0xD98E8A), Color(hex: 0x8C3A34)],
        [Color(hex: 0xF8F3EC), Color(hex: 0xE4CFC0), Color(hex: 0x9C7B66)]
    ]

    static func gradient(seed: Int) -> LinearGradient {
        let s = swatches[abs(seed) % swatches.count]
        let flip = seed % 2 == 0
        return LinearGradient(colors: [s[0], s[1]], startPoint: flip ? .topLeading : .bottomLeading, endPoint: flip ? .bottomTrailing : .topTrailing)
    }

    static func palette(seed: Int, category: Category? = nil) -> [Color] {
        if let category {
            switch category {
            case .nails: return swatches[(seed % 2 == 0) ? 0 : 6]
            case .hair: return swatches[(seed % 2 == 0) ? 1 : 7]
            case .makeup: return swatches[2]
            case .lashes: return swatches[3]
            case .brows: return swatches[4]
            case .theLot: return swatches[5]
            }
        }
        return swatches[abs(seed) % swatches.count]
    }
}

/// A work tile: gradient, two soft blobs positioned by seed, a grain overlay, optional caption.
struct WorkTile: View {
    var item: WorkItem
    var cornerRadius: CGFloat = Radius.tile
    var showCaption = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let colors = Placeholder.palette(seed: item.seed, category: item.category)
            let r = Rng(seed: item.seed)
            ZStack {
                if let url = item.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { art(colors: colors, r: r, w: w, h: h) }
                } else if let photo = BundledWork.image(for: item.category, seed: item.seed) {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    art(colors: colors, r: r, w: w, h: h)
                }
                if showCaption {
                    VStack {
                        Spacer()
                        HStack {
                            Text(item.caption)
                                .font(HDFont.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.black.opacity(0.28), in: Capsule())
                            Spacer()
                        }
                        .padding(10)
                    }
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .accessibilityLabel(item.caption)
    }

    private static func numbers(from r: Rng) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
        var rng = r
        return (rng.next(), rng.next(), rng.next(), rng.next(), rng.next())
    }

    private func art(colors: [Color], r: Rng, w: CGFloat, h: CGFloat) -> some View {
        let (a, b, c, d, e) = Self.numbers(from: r)
        return ZStack {
            LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(colors[2].opacity(0.55))
                .frame(width: w * (0.5 + a * 0.4))
                .blur(radius: w * 0.18)
                .offset(x: (b - 0.5) * w * 0.9, y: (c - 0.5) * h * 0.9)
            Circle()
                .fill(colors[0].opacity(0.9))
                .frame(width: w * (0.3 + d * 0.3))
                .blur(radius: w * 0.12)
                .offset(x: (e - 0.5) * w * 0.8, y: (a - 0.5) * h * 0.8)
            Ellipse()
                .fill(Color.white.opacity(0.35))
                .frame(width: w * 0.35, height: h * 0.18)
                .rotationEffect(.degrees(-30 + d * 40))
                .blur(radius: 6)
                .offset(x: -w * 0.2, y: -h * 0.25)
            Grain().opacity(0.06).blendMode(.multiply)
        }
    }
}

/// Tiny deterministic random source so tiles look the same every launch.
struct Rng {
    private var state: UInt64
    init(seed: Int) { state = UInt64(truncatingIfNeeded: seed) &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

/// A light grain overlay drawn once with Canvas.
struct Grain: View {
    var body: some View {
        Canvas { context, size in
            var r = Rng(seed: Int(size.width * 7 + size.height * 13))
            let count = Int(size.width * size.height / 60)
            for _ in 0..<min(count, 2500) {
                let x = r.next() * size.width, y = r.next() * size.height
                let dark = r.next() > 0.5
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(dark ? .black : .white))
            }
        }
        .allowsHitTesting(false)
    }
}


/// Photos dropped into `Resources/Work/` as `work-<category>-<n>.jpg` stand in for real work
/// until pros upload their own. Picked by seed so a pro's grid shows a stable mix.
/// Loaded by file URL: `UIImage(named:)` only finds loose JPGs if you spell the extension,
/// and the asset catalog isn't involved at all.
enum BundledWork {
    private static var urls: [Category: [URL]] = [:]
    private static var cache: [URL: UIImage] = [:]
    private static let lock = NSLock()

    static func image(for category: Category, seed: Int) -> UIImage? {
        let list = files(for: category)
        guard !list.isEmpty else { return nil }
        // Mix the seed so two pros in the same category don't land on the same photos in the same order.
        var x = UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 29
        let url = list[Int(x % UInt64(list.count))]
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[url] { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache[url] = image
        return image
    }

    private static func files(for category: Category) -> [URL] {
        lock.lock(); defer { lock.unlock() }
        if let known = urls[category] { return known }
        var found: [URL] = []
        var n = 1
        while true {
            let name = "work-\(category.rawValue.lowercased())-\(n)"
            guard let url = ["jpg", "jpeg", "png", "heic"].lazy
                .compactMap({ Bundle.main.url(forResource: name, withExtension: $0) }).first else { break }
            found.append(url); n += 1
        }
        urls[category] = found
        return found
    }
}
