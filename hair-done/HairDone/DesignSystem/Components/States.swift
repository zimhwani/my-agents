import SwiftUI

// MARK: - EmptyState

/// Nothing here yet. Left-aligned at the gutter: a serif 28 line, an SF 15 inkSoft sentence, and an
/// optional `OutlineButton`. No SF Symbol (`symbol` is ignored, kept so old call sites compile).
/// It brings its own 20pt gutter, so don't add `screenGutter()` around it.
/// Where a rail of photos is relevant (Bookings empty, no search results), put it under this.
///
///     EmptyState(title: "Nothing on. Want to change that?", actionTitle: "See who's free") { tab = .home }
struct EmptyState: View {
    var symbol: String = ""
    var title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        StateBlock(title: title, message: message, actionTitle: actionTitle, action: action)
    }
}

// MARK: - ErrorState

/// Something didn't load. Same shape as `EmptyState`. Default copy: "Couldn't load." / "Check your
/// connection." / `Try again`. Say what happened first; if money is involved, say what happened to it.
///
///     ErrorState { Task { await app.loadBookings() } }
///     ErrorState(title: "Couldn't load her times.", message: "Check your connection.") { reload() }
struct ErrorState: View {
    var title: String = "Couldn't load."
    var message: String? = "Check your connection."
    var actionTitle: String = "Try again"
    var action: () -> Void

    var body: some View {
        StateBlock(title: title, message: message, actionTitle: actionTitle, action: action)
    }
}

private struct StateBlock: View {
    var title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(HDFont.titleSmall)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message)
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.s)
            }
            if let actionTitle, let action {
                OutlineButton(title: actionTitle, compact: true, action: action)
                    .fixedSize()
                    .padding(.top, Space.l)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.xxl)
    }
}

// MARK: - OfflineBar

/// A lacquerSoft bar under the header while there's no connection, 32pt at the default size:
/// "You're offline. Showing what we've got." Ink type (never inkSoft on lacquerSoft). At large
/// text sizes it wraps onto more lines rather than shrinking the words.
///
///     VStack(spacing: 0) { if !app.isOnline { OfflineBar() }; content }
struct OfflineBar: View {
    var text: String = "You're offline. Showing what we've got."

    var body: some View {
        Text(text)
            .font(HDFont.caption)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Space.xs)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .padding(.horizontal, Space.gutter)
            .background(Palette.lacquerSoft)
            .accessibilityAddTraits(.isStaticText)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Skeletons

/// A loading block in the real shape of what's coming: `line` at 2pt corners, breathing slowly.
/// Still under Reduce Motion.
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var radius: CGFloat = Radius.photo
    /// `line` on paper; `Palette.inkLine` on an ink ground.
    var color: Color = Palette.line

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(dim ? 0.55 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}

/// A list row loading: a 72x90 photo block and two text bars, hairline under. For Bookings,
/// Inbox, Today, Calendar and Earnings.
struct RowSkeleton: View {
    var photo: CGSize = CGSize(width: 72, height: 90)

    var body: some View {
        HStack(alignment: .top, spacing: Space.l) {
            SkeletonBlock(width: photo.width, height: photo.height)
            VStack(alignment: .leading, spacing: Space.s) {
                SkeletonBlock(width: 70, height: 10)
                SkeletonBlock(width: 160, height: 18)
                SkeletonBlock(width: 120, height: 12)
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.lineStrong).frame(height: 0.5) }
    }
}

/// A 4:5 portrait tile loading, with name and line bars under it (Who's free, favourites).
struct TileSkeleton: View {
    var width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SkeletonBlock(width: width, height: (width * 1.25).rounded())
            SkeletonBlock(width: width * 0.5, height: 14)
            SkeletonBlock(width: width * 0.75, height: 10)
        }
    }
}

/// A few `RowSkeleton`s at the gutter, announced once as "Loading".
struct ListSkeleton: View {
    var rows: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { _ in RowSkeleton() }
        }
        .padding(.horizontal, Space.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

#Preview("States") {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            OfflineBar()
            EmptyState(title: "Nothing on. Want to change that?", actionTitle: "See who's free") {}
            ErrorState {}
            ListSkeleton(rows: 2)
            HStack(spacing: 12) { TileSkeleton(); TileSkeleton() }.padding(20)
        }
    }
    .paperBackground()
}
