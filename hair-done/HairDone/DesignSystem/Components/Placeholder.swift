import SwiftUI

/// Procedural placeholder art: warm gradients with soft blurred shapes and a light grain.
/// Stands in for work photos on the sample data, and for marketing art. Never a grey box.
/// Each swatch has a dark twin (the same hues, deep and muted) so the art doesn't glow on dark paper.
enum Placeholder {
    static let swatches: [[Color]] = [
        [Palette.dyn(light: 0xF3D0CB, dark: 0x38221E), Palette.dyn(light: 0xE8A9A0, dark: 0x58322D), Palette.dyn(light: 0xC8323A, dark: 0x81373B)],
        [Palette.dyn(light: 0xEAD9CB, dark: 0x382A1E), Palette.dyn(light: 0xC9A27E, dark: 0x58412D), Palette.dyn(light: 0x6B4A33, dark: 0x7C563B)],
        [Palette.dyn(light: 0xE8D2DF, dark: 0x381E2E), Palette.dyn(light: 0xC99DB7, dark: 0x552F46), Palette.dyn(light: 0x6E3E5C, dark: 0x754262)],
        [Palette.dyn(light: 0xD8D4E5, dark: 0x262136), Palette.dyn(light: 0xA79FC6, dark: 0x383153), Palette.dyn(light: 0x46406B, dark: 0x4B4573)],
        [Palette.dyn(light: 0xD9DED0, dark: 0x2E3324), Palette.dyn(light: 0xA9B7A2, dark: 0x3F4B3A), Palette.dyn(light: 0x48583A, dark: 0x5B6F49)],
        [Palette.dyn(light: 0xEFE3C8, dark: 0x38301E), Palette.dyn(light: 0xE9B96A, dark: 0x58472D), Palette.dyn(light: 0x7A5F1F, dark: 0x816B37)],
        [Palette.dyn(light: 0xF6DEDC, dark: 0x38201E), Palette.dyn(light: 0xD98E8A, dark: 0x582F2D), Palette.dyn(light: 0x8C3A34, dark: 0x813C37)],
        [Palette.dyn(light: 0xF8F3EC, dark: 0x382E1E), Palette.dyn(light: 0xE4CFC0, dark: 0x583F2D), Palette.dyn(light: 0x9C7B66, dark: 0x6F5748)]
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

/// A work tile: her photo when it has one. Otherwise, on the sample data, a bundled stock photo or
/// procedural art (gradient, two soft blobs positioned by seed, grain). On the live backend a real
/// pro's work or a real client's inspo never borrows a stock photo: it's the neutral photo ground
/// with a small outline glyph. `isIllustration: true` is for art that isn't anyone's work (a
/// category picture in onboarding), which keeps the stock photos on both backends.
struct WorkTile: View {
    var item: WorkItem
    var cornerRadius: CGFloat = Radius.tile
    var showCaption = false
    /// Marketing or onboarding art, not presented as a pro's work or a client's photo.
    var isIllustration = false

    @Environment(\.colorScheme) private var scheme

    private var usesStandIns: Bool { isIllustration || BundledWork.standsInForWork }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let colors = Placeholder.palette(seed: item.seed, category: item.category)
            let r = Rng(seed: item.seed)
            ZStack {
                if let url = item.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        if usesStandIns { art(colors: colors, r: r, w: w, h: h) } else { Palette.photoGround }
                    }
                } else if !usesStandIns {
                    noPhoto(w: w, h: h)
                } else if let photo = BundledWork.image(for: item.category, seed: item.seed) {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    art(colors: colors, r: r, w: w, h: h)
                }
                if showCaption {
                    // No capsule on the photo: a soft bottom scrim and paper type, as on the work viewer.
                    VStack {
                        Spacer()
                        Text(item.caption)
                            .font(HDFont.caption)
                            .foregroundStyle(Palette.onPhoto)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                    }
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .accessibilityLabel(item.caption)
    }

    /// No photo on the live backend: the warm ground and a small outline glyph, nothing borrowed.
    private func noPhoto(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Palette.photoGround
            Image(systemName: "photo")
                .font(.system(size: min(max(min(w, h) * 0.16, 13), 22), weight: .light))
                .foregroundStyle(Palette.inkSoft.opacity(0.7))
                .accessibilityHidden(true)
        }
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
                .fill(Color.white.opacity(scheme == .dark ? 0.08 : 0.35))
                .frame(width: w * 0.35, height: h * 0.18)
                .rotationEffect(.degrees(Double(-30 + d * 40)))
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


/// Photos dropped into `Resources/Work/` as `work-<category>-<n>.jpg` stand in for work on the
/// sample data, and serve as marketing art (Home's categories, onboarding). Picked by seed so a
/// pro's grid shows a stable mix. `WorkTile` only uses them for a pro's work or inspo while
/// `standsInForWork` is true (the sample data); `image(for:seed:)` itself is always available.
/// Loaded by file URL: `UIImage(named:)` only finds loose JPGs if you spell the extension,
/// and the asset catalog isn't involved at all.
enum BundledWork {
    /// True on the sample data, false on the live backend. Set once at launch by `AppState`.
    static var standsInForWork = true

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
