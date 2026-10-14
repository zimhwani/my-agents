import SwiftUI
import PhotosUI

/// Her work: the photos that get her booked, laid out as clients see them (the cover big, the rest
/// in threes). Pushed from Profile. New photos really upload, with progress on each tile.
struct ProWorkView: View {
    @Environment(AppState.self) private var app
    @State private var filter: Category? = nil
    @State private var selected: WorkItem? = nil
    @State private var picks: [PhotosPickerItem] = []
    @State private var uploads: [PickedWorkPhoto] = []

    private var pro: Pro? { app.proSelf }
    private var all: [WorkItem] {
        let work = pro?.work ?? []
        return work.filter { $0.isPinned } + work.filter { !$0.isPinned }
    }
    private var shown: [WorkItem] { filter.map { c in all.filter { $0.category == c } } ?? all }
    private var pinnedCount: Int { all.filter(\.isPinned).count }
    private var categories: [Category] {
        var set = pro?.specialties ?? []
        for item in all where !set.contains(item.category) { set.append(item.category) }
        return set
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if app.isOffline { OfflineBar().padding(.horizontal, -Space.gutter) }
                header
                if !uploads.isEmpty { uploadRow }
                if all.isEmpty && uploads.isEmpty {
                    EmptyState(title: "No photos yet.", message: "Three good ones beat thirty average ones.")
                        .padding(.horizontal, -Space.gutter)
                } else if !all.isEmpty {
                    if categories.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            TextTabs(selection: $filter, options: [nil] + categories.map { Optional($0) }, style: .serif) { $0?.label ?? "All" }
                        }
                    }
                    WorkGrid(items: shown, coverID: filter == nil ? all.first?.id : nil) { item in
                        Haptics.light()
                        selected = item
                    }
                }
                PhotosPicker(selection: $picks, maxSelectionCount: 10, matching: .images) {
                    Text("Add photos")
                        .font(HDFont.bodyStrong)
                        .foregroundStyle(app.isOffline ? Palette.inkSoft : Palette.paper)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(app.isOffline ? Palette.line : Palette.ink, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
                .buttonStyle(PressLift())
                .disabled(app.isOffline)
                .accessibilityLabel("Add photos")
                Text("Your own work only. Anyone else's and your profile comes down.")
                    .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
            }
            .screenGutter()
            .padding(.bottom, Space.section)
        }
        .paperBackground()
        .hdNavHeader()
        .onChange(of: picks) { _, new in
            guard !new.isEmpty else { return }
            let items = new
            picks = []
            Task { await add(items) }
        }
        .sheet(item: $selected) { item in
            WorkDetailSheet(item: item, categories: categories.isEmpty ? Category.allCases : categories,
                            pinnedCount: pinnedCount, isCover: all.first?.id == item.id,
                            onSave: { updated in await save(updated) },
                            onMoveToFront: { await moveToFront(item) },
                            onDelete: { await delete(item) })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Work.").font(HDFont.display).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(countLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            Text("This is how clients see it. The big one's your cover. Close, in natural light, the work filling the frame.")
                .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private var countLine: String {
        let photos = ProFlow.count(all.count, "photo", "photos")
        let pinned = pinnedCount == 0 ? "none pinned" : "\(pinnedCount) pinned"
        return "\(photos) · \(pinned)"
    }

    private var uploadRow: some View {
        let done = uploads.filter { $0.state == .done }.count
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("Uploading \(min(done + 1, uploads.count)) of \(uploads.count)").labelStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(uploads) { u in
                        UploadTile(image: u.image, state: u.state, onRetry: { Task { await upload(u.id); tidy() } },
                                   onRemove: removeAction(for: u))
                    }
                }
            }
        }
    }

    // MARK: Uploads

    private func add(_ items: [PhotosPickerItem]) async {
        var fresh: [PickedWorkPhoto] = []
        for item in items {
            guard let image = await PhotoData.image(from: item), let jpeg = PhotoData.jpeg(from: image) else { continue }
            fresh.append(PickedWorkPhoto(image: image, jpeg: jpeg))
        }
        guard !fresh.isEmpty else {
            app.show("Those photos couldn't be read. Try others.")
            return
        }
        withAnimation(Motion.spring) { uploads.append(contentsOf: fresh) }
        for photo in fresh { await upload(photo.id) }
        tidy()
    }

    /// Once every tile is in, say so and clear the row. Failed ones stay until she retries or removes them.
    private func tidy() {
        guard !uploads.isEmpty, uploads.allSatisfy({ $0.state == .done }) else { return }
        let count = uploads.count
        Haptics.success()
        app.show(count == 1 ? "Added. Tap it to tag it." : "\(count) added. Tap one to tag it.")
        withAnimation(Motion.spring) { uploads = [] }
    }

    private func removeAction(for u: PickedWorkPhoto) -> (() -> Void)? {
        guard u.state == .failed else { return nil }
        let id = u.id
        return {
            withAnimation(Motion.spring) { uploads.removeAll { $0.id == id } }
            tidy()
        }
    }

    /// Uploads one, then adds it to her work. On any failure the tile says so and can try again.
    private func upload(_ id: String) async {
        guard let i = uploads.firstIndex(where: { $0.id == id }) else { return }
        uploads[i].state = .uploading(0.3)
        let jpeg = uploads[i].jpeg
        guard let url = await app.uploadWorkPhoto(jpeg) else {
            setState(id, .failed)
            return
        }
        setState(id, .uploading(0.9))
        let category = filter ?? pro?.primaryCategory ?? .hair
        let item = WorkItem(id: UUID().uuidString.lowercased(), category: category, caption: "", seed: Int.random(in: 1...9_999), imageURL: url)
        guard await mutate({ $0.work.append(item) }) else {
            setState(id, .failed)
            return
        }
        setState(id, .done)
    }

    private func setState(_ id: String, _ state: UploadState) {
        guard let i = uploads.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(Motion.gentle) { uploads[i].state = state }
    }

    // MARK: Mutations

    /// False if it didn't save; AppState's toast says why.
    private func mutate(_ change: (inout Pro) -> Void) async -> Bool {
        guard var p = app.proSelf else { return false }
        change(&p)
        return await app.saveProSelf(p)
    }

    private func save(_ updated: WorkItem) async -> Bool {
        let saved = await mutate { p in
            if let i = p.work.firstIndex(where: { $0.id == updated.id }) { p.work[i] = updated }
        }
        if saved { app.show("Saved.") }
        return saved
    }

    private func moveToFront(_ item: WorkItem) async -> Bool {
        let saved = await mutate { p in
            guard let i = p.work.firstIndex(where: { $0.id == item.id }) else { return }
            let moved = p.work.remove(at: i)
            p.work.insert(moved, at: 0)
        }
        if saved { app.show("Moved to the front.") }
        return saved
    }

    private func delete(_ item: WorkItem) async -> Bool {
        let saved = await mutate { $0.work.removeAll { $0.id == item.id } }
        if saved { app.show("Deleted.") }
        return saved
    }
}

// MARK: - The grid

/// The profile's grid: 2pt gaps and corners, the cover across two columns and two rows, then threes.
/// Pinned photos get a small paper square with an outline pin. Nothing else on a photo.
struct WorkGrid: View {
    var items: [WorkItem]
    var coverID: String?
    var onTap: (WorkItem) -> Void

    var body: some View {
        CoverGridLayout(hasCover: coverID != nil && items.first?.id == coverID) {
            ForEach(items) { item in
                Button { onTap(item) } label: {
                    WorkTile(item: item, cornerRadius: Radius.photo)
                        .overlay(alignment: .topTrailing) {
                            if item.isPinned {
                                Image(systemName: "pin")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(Color(hex: 0x241A16))
                                    .frame(width: 16, height: 16)
                                    .background(Palette.onPhoto, in: RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
                                    .padding(4)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressLift(scale: 0.97))
                .accessibilityLabel("\(item.caption.isEmpty ? "Untitled photo" : item.caption), \(item.category.label)\(item.isPinned ? ", pinned" : "")\(item.id == coverID ? ", your cover" : "")")
                .accessibilityHint("Opens the photo")
            }
        }
        .animation(Motion.spring, value: items.map(\.id))
    }
}

/// Three square columns with 2pt gaps. With a cover, the first item spans two by two and the next
/// two stack beside it.
struct CoverGridLayout: Layout {
    var hasCover: Bool
    var gap: CGFloat = 2

    private func frames(width: CGFloat, count: Int) -> [CGRect] {
        let cell = max((width - gap * 2) / 3, 0)
        var frames: [CGRect] = []
        var index = 0
        var y: CGFloat = 0
        if hasCover && count > 0 {
            frames.append(CGRect(x: 0, y: 0, width: cell * 2 + gap, height: cell * 2 + gap))
            index = 1
            for row in 0..<2 where index < count {
                frames.append(CGRect(x: (cell + gap) * 2, y: CGFloat(row) * (cell + gap), width: cell, height: cell))
                index += 1
            }
            y = (cell + gap) * 2
        }
        var column = 0
        while index < count {
            frames.append(CGRect(x: CGFloat(column) * (cell + gap), y: y, width: cell, height: cell))
            index += 1
            column += 1
            if column == 3 { column = 0; y += cell + gap }
        }
        return frames
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let height = frames(width: width, count: subviews.count).map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let all = frames(width: bounds.width, count: subviews.count)
        for (view, frame) in zip(subviews, all) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       proposal: ProposedViewSize(frame.size))
        }
    }
}

// MARK: - One photo

/// One photo, big on ink, with its caption, tag, pin, move to front and delete.
struct WorkDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var item: WorkItem
    var categories: [Category]
    var pinnedCount: Int
    var isCover: Bool
    var onSave: (WorkItem) async -> Bool
    var onMoveToFront: () async -> Bool
    var onDelete: () async -> Bool

    @State private var caption: String
    @State private var category: Category
    @State private var isPinned: Bool
    @State private var confirmDelete = false
    @State private var pinNote: String? = nil
    @State private var saving = false
    @State private var failed = false

    init(item: WorkItem, categories: [Category], pinnedCount: Int, isCover: Bool,
         onSave: @escaping (WorkItem) async -> Bool, onMoveToFront: @escaping () async -> Bool, onDelete: @escaping () async -> Bool) {
        self.item = item
        self.categories = categories
        self.pinnedCount = pinnedCount
        self.isCover = isCover
        self.onSave = onSave
        self.onMoveToFront = onMoveToFront
        self.onDelete = onDelete
        _caption = State(initialValue: item.caption)
        _category = State(initialValue: item.category)
        _isPinned = State(initialValue: item.isPinned)
    }

    private var isDirty: Bool { caption != item.caption || category != item.category || isPinned != item.isPinned }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        Palette.inkGround
                        WorkTile(item: WorkItem(id: item.id, category: category, caption: caption, seed: item.seed, imageURL: item.imageURL), cornerRadius: Radius.photo)
                            .aspectRatio(4 / 5, contentMode: .fit)
                            .padding(.horizontal, Space.xxl)
                            .padding(.top, 52)
                            .padding(.bottom, Space.xl)
                        IconButton(symbol: "xmark", label: "Close", tint: Palette.onInk) { dismiss() }
                            .padding(.top, Space.xs)
                            .padding(.trailing, Space.s)
                    }
                    if isCover {
                        Text("Your cover. It's the first thing a client sees.")
                            .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                            .screenGutter()
                            .padding(.top, Space.m)
                    }
                    VStack(alignment: .leading, spacing: Space.xl) {
                        HDTextField(label: "Caption", placeholder: "Chrome on a short almond", text: $caption)
                        if categories.count > 1 {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Tag it").font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    TextTabs(selection: $category, options: categories) { $0.label }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            HairlineRow(title: isPinned ? "Unpin" : "Pin",
                                        subtitle: pinNote ?? "Pinned photos stay at the top. Up to four.", chevron: false) { togglePin() }
                            if !isCover {
                                HairlineRow(title: "Move to front", subtitle: "Makes it your cover.", chevron: false) {
                                    Task { if await onMoveToFront() { dismiss() } }
                                }
                            }
                            HairlineRow(title: "Delete", chevron: false) { confirmDelete = true }
                        }
                        if failed { FieldMessage(text: "Didn't save. Your changes are still here. Try again.") }
                    }
                    .screenGutter()
                    .padding(.top, Space.l)
                    .padding(.bottom, Space.l)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            InkButton(title: "Save", isLoading: saving, isEnabled: isDirty) { Task { await save() } }
                .screenGutter()
                .padding(.vertical, Space.l)
        }
        .paperBackground()
        .holdsPushRoutes()
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .confirmSheet(isPresented: $confirmDelete, title: "Delete this photo?",
                      message: "Gone from your profile, not from your camera roll.",
                      confirmTitle: "Delete", cancelTitle: "Keep it") {
            Task { if await onDelete() { dismiss() } }
        }
    }

    private func save() async {
        var updated = item
        updated.caption = caption.trimmingCharacters(in: .whitespaces)
        updated.category = category
        updated.isPinned = isPinned
        saving = true
        failed = false
        let ok = await onSave(updated)
        saving = false
        if ok { dismiss() } else { failed = true }
    }

    private func togglePin() {
        if !isPinned {
            let others = pinnedCount - (item.isPinned ? 1 : 0)
            if others >= 4 {
                Haptics.warning()
                withAnimation(Motion.spring) { pinNote = "Four's the limit. Unpin one first." }
                return
            }
        }
        withAnimation(Motion.spring) { isPinned.toggle(); pinNote = nil }
    }
}

#Preview("Work") {
    NavigationStack { ProWorkView().hdDestinations() }
        .environment(previewApp(mode: .pro))
}
