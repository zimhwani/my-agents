import SwiftUI
import PhotosUI
import UIKit

/// Photos she picks, made ready to upload: longest side 2000px at most, JPEG at 0.8.
enum PhotoData {
    static func jpeg(from image: UIImage, maxSide: CGFloat = 2000, quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let longest = max(size.width, size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        // Drawing also bakes in the orientation, so the upload is the right way up.
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// The picked photo as an image, or nil if it couldn't be read.
    static func image(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }
}

/// A photo she picked for her work, on its way up.
struct PickedWorkPhoto: Identifiable {
    let id: String
    var image: UIImage
    var jpeg: Data
    var state: UploadState
    var url: URL? = nil

    init(image: UIImage, jpeg: Data) {
        self.id = UUID().uuidString.lowercased()
        self.image = image
        self.jpeg = jpeg
        self.state = .uploading(0.15)
    }
}

/// The camera, for the ID photo and the selfie. Only use it when `isAvailable`; otherwise PhotosPicker.
struct CameraPicker: UIViewControllerRepresentable {
    var front = false
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if front, UIImagePickerController.isCameraDeviceAvailable(.front) { picker.cameraDevice = .front }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - ID check

/// Photo ID and a selfie, each uploaded to her private folder, then sent for a person to check.
/// Never says "ID checked" unless the server has said so (`isVerified`).
struct ProIDCheckView: View {
    @Environment(AppState.self) private var app
    /// Runs before the check is sent, e.g. to save her draft so there's a pro row to mark.
    var prepare: (() async -> Bool)? = nil
    var onSent: () -> Void = {}

    private enum Shot {
        case uploading(UIImage)
        case done(UIImage)
        case failed(UIImage, Data)

        var image: UIImage {
            switch self {
            case .uploading(let i), .done(let i), .failed(let i, _): return i
            }
        }
        var isDone: Bool { if case .done = self { return true } else { return false } }
        var state: UploadState {
            switch self {
            case .uploading: return .uploading(0.5)
            case .done: return .done
            case .failed: return .failed
            }
        }
    }

    @State private var shots: [IDDocumentKind: Shot] = [:]
    @State private var capturing: IDDocumentKind? = nil
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryPick: PhotosPickerItem? = nil
    @State private var sending = false
    @State private var problem: String? = nil

    private var pro: Pro? { app.proSelf }
    private var sent: Bool { pro?.idSubmitted == true || pro?.isVerified == true }
    private var bothIn: Bool { IDDocumentKind.allCases.allSatisfy { shots[$0]?.isDone == true } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if pro?.isVerified == true {
                VStack(alignment: .leading, spacing: Space.xs) {
                    VerifiedBadge()
                    Text("A person at Hair Done has checked it. The badge is on your profile.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                }
            } else if sent {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Sent.").font(HDFont.name).foregroundStyle(Palette.ink)
                    Text("Someone from Hair Done checks it by hand, usually within a day.")
                        .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .top, spacing: Space.m) {
                    slot(.photoID, title: "Add photo ID", line: "Licence or passport, flat and in focus.")
                    slot(.selfie, title: "Add a selfie", line: "Your face, in good light.")
                }
                if let problem { FieldMessage(text: problem) }
                InkButton(title: "Send for checking", isLoading: sending, isEnabled: bothIn && !app.isOffline) {
                    Task { await send() }
                }
                Text("A person at Hair Done looks at both, then deletes them. Only the tick stays.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(front: capturing == .selfie) { image in
                if let kind = capturing { take(image, for: kind) }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showLibrary, selection: $libraryPick, matching: .images)
        .onChange(of: libraryPick) { _, item in
            guard let item, let kind = capturing else { return }
            libraryPick = nil
            Task {
                if let image = await PhotoData.image(from: item) { take(image, for: kind) }
            }
        }
    }

    @ViewBuilder
    private func slot(_ kind: IDDocumentKind, title: String, line: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let shot = shots[kind] {
                UploadTile(image: shot.image, state: shot.state, size: CGSize(width: 104, height: 130), onRetry: { retry(kind) })
                TertiaryButton(title: "Take it again", tint: Palette.ink) { pick(kind) }
                    .padding(.leading, -8)
            } else {
                Button {
                    pick(kind)
                } label: {
                    VStack(spacing: Space.s) {
                        Image(systemName: kind == .selfie ? "person.crop.square" : "person.text.rectangle")
                            .font(.system(size: 21, weight: .light))
                        Text(title).font(HDFont.subMedium).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(Space.s)
                    .frame(width: 104, height: 130)
                    .overlay(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressLift())
                .disabled(app.isOffline)
                .accessibilityLabel(title)
                Text(line).font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                    .frame(width: 104, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pick(_ kind: IDDocumentKind) {
        Haptics.light()
        capturing = kind
        if CameraPicker.isAvailable { showCamera = true } else { showLibrary = true }
    }

    private func take(_ image: UIImage, for kind: IDDocumentKind) {
        guard let jpeg = PhotoData.jpeg(from: image) else {
            problem = "That photo didn't work. Try another."
            return
        }
        problem = nil
        upload(image, jpeg, kind)
    }

    private func retry(_ kind: IDDocumentKind) {
        guard case .failed(let image, let jpeg) = shots[kind] else { return }
        upload(image, jpeg, kind)
    }

    private func upload(_ image: UIImage, _ jpeg: Data, _ kind: IDDocumentKind) {
        withAnimation(Motion.gentle) { shots[kind] = .uploading(image) }
        Task {
            let ok = await app.uploadIDDocument(jpeg, kind: kind)
            withAnimation(Motion.gentle) { shots[kind] = ok ? .done(image) : .failed(image, jpeg) }
        }
    }

    private func send() async {
        sending = true
        defer { sending = false }
        problem = nil
        if let prepare, !(await prepare()) {
            problem = "Didn't send. Your photos are still here. Try again."
            return
        }
        if await app.submitIDCheck() {
            Haptics.success()
            onSent()
        } else {
            problem = app.lastError ?? "Didn't send. Your photos are still here. Try again."
        }
    }
}
