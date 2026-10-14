import SwiftUI

/// A short paper sheet that asks before something she can't take back: log out, delete, cancel a
/// booking, block, decline, leave a flow. Replaces `confirmationDialog` and `.alert` (both system
/// red). Serif 28 question, one inkSoft sentence, an `InkButton` for the action and a quiet
/// text button to back out. No red anywhere: a destructive action is still ink.
///
///     .confirmSheet(isPresented: $confirmLogout,
///                   title: "Log out?",
///                   message: "You'll need your email or phone to get back in.",
///                   confirmTitle: "Log out",
///                   cancelTitle: "Stay") { app.signOut() }
///
/// For extra content (the cancellation amount), use `ConfirmSheet` directly inside `.sheet` with a
/// `detail` view, and `.confirmSheetPresentation()`.
struct ConfirmSheet<Detail: View>: View {
    var title: String
    var message: String?
    var confirmTitle: String
    var cancelTitle: String
    var isWorking: Bool
    var onConfirm: () -> Void
    var onCancel: (() -> Void)?
    private let detail: Detail

    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        message: String? = nil,
        confirmTitle: String,
        cancelTitle: String = "Keep it",
        isWorking: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder detail: () -> Detail
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isWorking = isWorking
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(HDFont.titleSmall)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .font(HDFont.sub)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.s)
            }
            detail
                .padding(.top, Space.l)
            VStack(spacing: Space.xs) {
                InkButton(title: confirmTitle, isLoading: isWorking) { onConfirm() }
                TertiaryButton(title: cancelTitle) {
                    if let onCancel { onCancel() } else { dismiss() }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, Space.xl)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.xl + Space.s)
        .padding(.bottom, Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ConfirmSheet where Detail == EmptyView {
    init(
        title: String,
        message: String? = nil,
        confirmTitle: String,
        cancelTitle: String = "Keep it",
        isWorking: Bool = false,
        onConfirm: @escaping () -> Void
    ) {
        self.init(title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle,
                  isWorking: isWorking, onConfirm: onConfirm, onCancel: nil) { EmptyView() }
    }
}

extension View {
    /// Asks before an action, on a content-sized paper sheet. `onConfirm` runs after the sheet
    /// closes, so it can present something else or dismiss the screen under it.
    func confirmSheet(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String,
        cancelTitle: String = "Keep it",
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmSheetModifier(isPresented: isPresented, title: title, message: message,
                                      confirmTitle: confirmTitle, cancelTitle: cancelTitle, onConfirm: onConfirm))
    }

    /// The presentation every ConfirmSheet uses: paper ground, height fitted to the content,
    /// grabber showing. Put it on the sheet's content when building one by hand.
    func confirmSheetPresentation() -> some View {
        modifier(FittedSheet())
    }
}

private struct ConfirmSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String?
    var confirmTitle: String
    var cancelTitle: String
    var onConfirm: () -> Void

    @State private var confirmed = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: {
                if confirmed { confirmed = false; onConfirm() }
            }) {
                ConfirmSheet(title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle,
                             onConfirm: { confirmed = true; isPresented = false },
                             onCancel: { isPresented = false }) { EmptyView() }
                    .confirmSheetPresentation()
            }
    }
}

/// Sizes a sheet to its content (iOS 17 has no fitted detent), on paper.
private struct FittedSheet: ViewModifier {
    @State private var height: CGFloat = 280

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(SheetHeightKey.self) { h in
                if h > 0 { height = h }
            }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.paper)
    }
}

private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ConfirmSheetPreview: View {
    @State private var asking = true
    var body: some View {
        VStack {
            TertiaryButton(title: "Log out", tint: Palette.ink) { asking = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .confirmSheet(isPresented: $asking,
                      title: "Log out?",
                      message: "You'll need your email or phone to get back in.",
                      confirmTitle: "Log out",
                      cancelTitle: "Stay") {}
    }
}

#Preview("ConfirmSheet") { ConfirmSheetPreview() }
