import SwiftUI
import UIKit

/// The nav header for pushed screens, in place of the stock nav bar: a 44pt row with a bare
/// `chevron.left` on the left, an optional serif 17 title in the middle, an optional bare trailing
/// glyph or text action, and a hairline under it only once the content has scrolled.
///
/// Easiest is the modifier, which also hides the system bar and keeps swipe-back working:
///
///     ScrollView { ... }
///         .hdNavHeader("Kiara M.")
///         .hdNavHeader(trailing: { IconButton(symbol: "square.and.arrow.up", label: "Share") { share() } })
///
/// On an ink ground (the booking flow, a full-screen viewer) pass `tone: .ink`.
struct HDNavHeader<Trailing: View>: View {
    typealias Tone = HDNavTone

    var title: String?
    var tone: Tone
    var showsHairline: Bool
    /// Nil uses the environment's `dismiss`.
    var onBack: (() -> Void)?
    /// False hides the back glyph (a root screen with a header).
    var showsBack: Bool
    private let trailing: Trailing

    @Environment(\.dismiss) private var dismiss

    init(
        _ title: String? = nil,
        tone: Tone = .paper,
        showsHairline: Bool = false,
        showsBack: Bool = true,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.tone = tone
        self.showsHairline = showsHairline
        self.showsBack = showsBack
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(HDFont.navTitle)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 56)
                    .accessibilityAddTraits(.isHeader)
            }
            HStack(spacing: 0) {
                if showsBack {
                    IconButton(symbol: "chevron.left", label: "Back", tint: ink) {
                        if let onBack { onBack() } else { dismiss() }
                    }
                }
                Spacer(minLength: 0)
                trailing.foregroundStyle(ink)
            }
            .padding(.horizontal, Space.gutter - 12)
        }
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .background(ground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(tone == .paper ? Palette.lineStrong : Palette.inkLine)
                .frame(height: 0.5)
                .opacity(showsHairline ? 1 : 0)
        }
    }

    private var ink: Color { tone == .paper ? Palette.ink : Palette.onInk }
    private var ground: Color { tone == .paper ? Palette.paper : Palette.inkGround }
}

/// `.paper` on paper screens, `.ink` on ink grounds.
enum HDNavTone { case paper, ink }

extension HDNavHeader where Trailing == EmptyView {
    /// No trailing action. For a custom back action, use the main init with `{ EmptyView() }`
    /// (kept off this one so a trailing closure can't be mistaken for `onBack`).
    init(_ title: String? = nil, tone: HDNavTone = .paper, showsHairline: Bool = false, showsBack: Bool = true) {
        self.init(title, tone: tone, showsHairline: showsHairline, showsBack: showsBack, onBack: nil) { EmptyView() }
    }
}

extension View {
    /// Hides the system nav bar, pins an `HDNavHeader` to the top, and keeps the edge swipe back.
    /// Put it on the pushed screen's outermost view.
    func hdNavHeader<Trailing: View>(
        _ title: String? = nil,
        tone: HDNavTone = .paper,
        showsHairline: Bool = false,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let header = HDNavHeader(title, tone: tone, showsHairline: showsHairline, onBack: onBack, trailing: trailing)
        return self
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .background(SwipeBackEnabler().frame(width: 0, height: 0).accessibilityHidden(true))
    }

    /// `hdNavHeader` with no trailing action and the standard back (dismiss). For a custom back,
    /// use the main form: `.hdNavHeader("Title", onBack: { ... }) { EmptyView() }`.
    func hdNavHeader(_ title: String? = nil, tone: HDNavTone = .paper, showsHairline: Bool = false) -> some View {
        hdNavHeader(title, tone: tone, showsHairline: showsHairline, onBack: nil) { EmptyView() }
    }
}

// MARK: - Swipe back with the bar hidden

/// Hiding the system bar also turns off the edge swipe back. This puts it back for the stack the
/// screen is in, allowing the swipe only when there's somewhere to go back to.
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.enable() }

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            enable()
        }
        func enable() {
            guard let nav = navigationController, let pop = nav.interactivePopGestureRecognizer else { return }
            if !(pop.delegate is SwipeBackDelegate) {
                let delegate = SwipeBackDelegate(nav: nav)
                objc_setAssociatedObject(nav, &SwipeBackDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                pop.delegate = delegate
            }
            pop.isEnabled = true
        }
    }
}

private final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static var key: UInt8 = 0
    weak var nav: UINavigationController?
    init(nav: UINavigationController) { self.nav = nav }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (nav?.viewControllers.count ?? 0) > 1
    }
}

#Preview("HDNavHeader") {
    NavigationStack {
        ScrollView {
            Text("Thursday 23 October, 6:15 pm").font(HDFont.quote).padding(20)
        }
        .paperBackground()
        .hdNavHeader("Kiara M.", showsHairline: true) {
            IconButton(symbol: "square.and.arrow.up", label: "Share") {}
        }
    }
}
