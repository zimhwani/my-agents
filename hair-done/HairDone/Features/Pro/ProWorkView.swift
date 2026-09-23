import SwiftUI
import PhotosUI

/// Her work: the photos that get her booked. Pinned ones first, tag by category, add from the camera roll.
struct ProWorkView: View {
    @Environment(AppState.self) private var app
    @State private var filter: Category? = nil
    @State private var selected: WorkItem? = nil
    @State private var picks: [PhotosPickerItem] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    if all.isEmpty {
                        EmptyState(symbol: "photo.on.rectangle.angled", title: "No photos yet.", message: "Three good ones beat thirty average ones.")
                    } else {
                        if categories.count > 1 { filterChips }
                        grid
                    }
                    AddPhotosButton(selection: $picks)
                    Text("Your own work only. Anyone else's and your profile comes down.")
                        .font(HDFont.caption).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .screenGutter()
                .padding(.top, Space.s)
                .padding(.bottom, Space.section)
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
            .hdDestinations()
            .onChange(of: picks) { _, new in
                guard !new.isEmpty else { return }
                Task { await add(count: new.count); picks = [] }
            }
            .sheet(item: $selected) { item in
                WorkDetailSheet(item: item, categories: categories.isEmpty ? Category.allCases : categories,
                                pinnedCount: pinnedCount, isCover: all.first?.id == item.id,
                                onSave: { updated in Task { await save(updated) } },
                                onMoveToFront: { Task { await moveToFront(item) } },
                                onDelete: { Task { await delete(item) } })
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Work").font(HDFont.hero).foregroundStyle(Palette.ink)
            Text(countLine).font(HDFont.sub).foregroundStyle(Palette.inkSoft)
            Text("Close, in natural light, your hands and her hair. Crop in till the work fills the frame, not the room.")
                .font(HDFont.sub).foregroundStyle(Palette.inkSoft)
                .padding(.top, 2)
        }
    }

    private var countLine: String {
        let photos = all.count == 1 ? "1 photo" : "\(all.count) photos"
        let pinned = pinnedCount == 0 ? "none pinned" : "\(pinnedCount) pinned"
        return "\(photos) · \(pinned)"
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                Chip(title: "All", isSelected: filter == nil) { withAnimation(Motion.spring) { filter = nil } }
                ForEach(categories) { c in
                    Chip(title: c.label, isSelected: filter == c, tint: c.tint) { withAnimation(Motion.spring) { filter = c } }
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(shown) { item in
                Button {
                    Haptics.light()
                    selected = item
                } label: {
                    WorkTile(item: item)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(alignment: .topLeading) {
                            // The cover is always a pinned photo, so one tag is enough on a tile this size.
                            Group {
                                if all.first?.id == item.id { Tag(text: "Cover", color: Palette.ink, background: Palette.paper.opacity(0.92)) }
                                else if item.isPinned { Tag(text: "Pinned", color: Palette.lacquer, background: Palette.paper.opacity(0.92)) }
                            }
                            .padding(6)
                        }
                }
                .buttonStyle(PressLift(scale: 0.96))
                .accessibilityLabel("\(item.caption.isEmpty ? "Untitled photo" : item.caption), \(item.category.label)\(item.isPinned ? ", pinned" : "")")
                .accessibilityHint("Opens the photo")
            }
        }
        .animation(Motion.spring, value: shown.map(\.id))
    }

    // MARK: Mutations

    private func mutate(_ change: (inout Pro) -> Void) async {
        guard var p = app.proSelf else { return }
        change(&p)
        await app.saveProSelf(p)
    }

    private func add(count: Int) async {
        let category = filter ?? pro?.primaryCategory ?? .hair
        let fresh = (0..<count).map { _ in WorkItem.placeholder(category: category) }
        await mutate { $0.work.append(contentsOf: fresh) }
        Haptics.success()
        app.show(count == 1 ? "Added. Tap it to tag it." : "\(count) added. Tap one to tag it.")
    }

    private func save(_ updated: WorkItem) async {
        await mutate { p in
            if let i = p.work.firstIndex(where: { $0.id == updated.id }) { p.work[i] = updated }
        }
        app.show("Saved.")
    }

    private func moveToFront(_ item: WorkItem) async {
        await mutate { p in
            guard let i = p.work.firstIndex(where: { $0.id == item.id }) else { return }
            let moved = p.work.remove(at: i)
            p.work.insert(moved, at: 0)
        }
        app.show("Moved to the front.")
    }

    private func delete(_ item: WorkItem) async {
        await mutate { $0.work.removeAll { $0.id == item.id } }
        app.show("Deleted.")
    }
}

/// One photo, big, with its caption, tag, pin and delete.
struct WorkDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var item: WorkItem
    var categories: [Category]
    var pinnedCount: Int
    var isCover: Bool
    var onSave: (WorkItem) -> Void
    var onMoveToFront: () -> Void
    var onDelete: () -> Void

    @State private var caption: String
    @State private var category: Category
    @State private var isPinned: Bool
    @State private var confirmDelete = false
    @State private var pinNote: String? = nil

    init(item: WorkItem, categories: [Category], pinnedCount: Int, isCover: Bool,
         onSave: @escaping (WorkItem) -> Void, onMoveToFront: @escaping () -> Void, onDelete: @escaping () -> Void) {
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
            SheetHeader(title: "This photo", subtitle: isCover ? "Your cover. It's the first thing a client sees." : nil, onClose: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    WorkTile(item: WorkItem(id: item.id, category: category, caption: caption, seed: item.seed, imageURL: item.imageURL), cornerRadius: Radius.card)
                        .aspectRatio(1, contentMode: .fit)
                    HDTextField(label: "Caption", placeholder: "Chrome on a short almond", text: $caption)
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("Tag it").font(HDFont.subStrong).foregroundStyle(Palette.ink)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                ForEach(categories) { c in
                                    Chip(title: c.label, isSelected: category == c, tint: c.tint) { category = c }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        SecondaryButton(title: isPinned ? "Unpin" : "Pin", symbol: isPinned ? "pin.slash" : "pin") { togglePin() }
                        Text(pinNote ?? "Pinned photos stay at the top. Up to four.")
                            .font(HDFont.caption).foregroundStyle(pinNote == nil ? Palette.inkSoft : Palette.warn)
                    }
                    HStack {
                        if !isCover { TertiaryButton(title: "Move to front", tint: Palette.ink) { onMoveToFront(); dismiss() } }
                        Spacer()
                        TertiaryButton(title: "Delete", tint: Palette.lacquer) { confirmDelete = true }
                    }
                }
                .screenGutter()
                .padding(.vertical, Space.l)
            }
            PrimaryButton(title: "Save", isEnabled: isDirty) {
                var updated = item
                updated.caption = caption.trimmingCharacters(in: .whitespaces)
                updated.category = category
                updated.isPinned = isPinned
                onSave(updated)
                dismiss()
            }
            .screenGutter()
            .padding(.vertical, Space.l)
        }
        .paperBackground()
        .presentationDragIndicator(.visible)
        .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete(); dismiss() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Gone from your profile, not from your camera roll.")
        }
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
    ProWorkView().environment(previewApp(mode: .pro))
}
