import SwiftUI

/// 笔记页：左侧笔记列表 + 右侧块编辑器
/// 块：正文 / 标题 / 列表 / 待办；行首输入「# 」「- 」「[] 」自动转换；待办可一键转成任务
struct NotesView: View {
    @EnvironmentObject private var store: DataStore
    @AppStorage("jinzhao.selectedNoteID") private var selectedRaw = ""
    @State private var search = ""
    @State private var pinnedOnly = false

    private var selectedID: UUID? { UUID(uuidString: selectedRaw) }

    private var filtered: [NoteItem] {
        let list = store.notes.sorted { a, b in
            if (a.isPinned ?? false) != (b.isPinned ?? false) { return a.isPinned ?? false }
            return a.updatedAt > b.updatedAt
        }
        let base = pinnedOnly ? list.filter { $0.isPinned ?? false } : list
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.plainText.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        SolidCard {
            HStack(spacing: 0) {
                listColumn
                    .frame(width: 270)
                Divider()
                if let id = selectedID, store.notes.contains(where: { $0.id == id }) {
                    NoteEditor(noteID: id)
                        .id(id)
                } else {
                    emptyEditor
                }
            }
        }
        .onAppear {
            if selectedID == nil || !store.notes.contains(where: { $0.id == selectedID }) {
                selectedRaw = filtered.first?.id.uuidString ?? ""
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoOpenNote)) { note in
            if let id = note.object as? UUID { selectedRaw = id.uuidString }
        }
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("笔记").font(.system(size: 22, weight: .bold))
                Spacer()
                Button { newNote() } label: { Image(systemName: "square.and.pencil") }
                    .glassButton().controlSize(.small)
                    .help("新建笔记")
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索笔记", text: $search).textFieldStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: JZ.radiusS))
            HStack(spacing: 6) {
                chip("全部", on: !pinnedOnly) { pinnedOnly = false }
                chip("已置顶", on: pinnedOnly) { pinnedOnly = true }
                Spacer()
            }
            ScrollView {
                VStack(spacing: 8) {
                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text").font(.title2).foregroundStyle(.secondary)
                            Text(store.notes.isEmpty ? "还没有笔记" : "没有匹配的笔记")
                                .font(.callout).foregroundStyle(.secondary)
                            if store.notes.isEmpty {
                                Button("写第一篇") { newNote() }.glassButton(prominent: true)
                            }
                        }
                        .padding(.top, 40)
                    }
                    ForEach(filtered) { note in
                        row(note)
                    }
                }
            }
        }
        .padding(16)
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Color.primary)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(on ? JZ.accent : JZ.controlFill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ note: NoteItem) -> some View {
        let selected = note.id == selectedID
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if note.isPinned ?? false {
                    Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(JZ.accent)
                        .rotationEffect(.degrees(30))
                }
                Text(note.title.isEmpty ? "无标题" : note.title)
                    .font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                if note.openTodoCount > 0 {
                    Text("\(note.openTodoCount) 个待办")
                        .font(.system(size: 10.5, weight: .medium)).foregroundStyle(JZ.accent)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(JZ.accent.opacity(0.12), in: Capsule())
                }
            }
            Text(note.preview.isEmpty ? "空白笔记" : note.preview)
                .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            Text(shortDate(note.updatedAt)).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? JZ.accent.opacity(0.12) : JZ.cardBg,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? JZ.accent.opacity(0.45) : JZ.separator.opacity(0.35), lineWidth: selected ? 1 : 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedRaw = note.id.uuidString }
        .contextMenu {
            Button((note.isPinned ?? false) ? "取消置顶" : "置顶") {
                store.updateNote(note.id) { $0.isPinned = !($0.isPinned ?? false) }
            }
            Divider()
            Button("删除笔记", role: .destructive) {
                store.deleteNote(note.id)
                if selected { selectedRaw = filtered.first?.id.uuidString ?? "" }
            }
        }
    }

    private var emptyEditor: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text").font(.system(size: 36)).foregroundStyle(.secondary)
            Text("选一篇笔记，或新建一篇").font(.jzSection)
            Text("行首输入「# 」变标题、「- 」变列表、「[] 」变待办；待办可以一键转成任务。")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
            Button("新建笔记") { newNote() }.glassButton(prominent: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func newNote() {
        let id = store.addNote()
        selectedRaw = id.uuidString
        search = ""
    }

    private func shortDate(_ d: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = cal.isDateInToday(d) ? "今天 HH:mm" : "M月d日 HH:mm"
        return f.string(from: d)
    }
}

// MARK: - 编辑器

private struct NoteEditor: View {
    let noteID: UUID
    @EnvironmentObject private var store: DataStore
    @FocusState private var focused: UUID?
    @FocusState private var titleFocused: Bool

    private var note: NoteItem? { store.notes.first { $0.id == noteID } }

    var body: some View {
        if let note {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("标题", text: titleBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 28, weight: .bold))
                        .focused($titleFocused)
                        .onSubmit { focusFirstBlock() }
                    Text(metaLine(note)).font(.system(size: 12)).foregroundStyle(.secondary)
                        .padding(.top, 2)
                    Divider().padding(.vertical, 10)
                    ForEach(note.blocks) { block in
                        BlockRow(noteID: noteID, block: block, focused: $focused)
                    }
                    Button {
                        appendBlock()
                    } label: {
                        Label("添加一行", systemImage: "plus").font(.callout)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    linkedTasks(note)
                }
                .padding(.horizontal, 28).padding(.vertical, 22)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                if note.title.isEmpty && note.plainText.isEmpty { titleFocused = true }
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(get: { note?.title ?? "" },
                set: { v in store.updateNote(noteID) { $0.title = v.replacingOccurrences(of: "\n", with: "") } })
    }

    private func metaLine(_ n: NoteItem) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy年M月d日 HH:mm"
        let lunar = LunarCalendar.info(for: n.createdAt).shortText
        let term = SolarTermTable.currentTerm(on: n.createdAt).map { " · \($0)" } ?? ""
        return "创建于 \(f.string(from: n.createdAt))   |   农历\(lunar)\(term)"
    }

    private func focusFirstBlock() {
        if let first = note?.blocks.first { focused = first.id } else { appendBlock() }
    }

    private func appendBlock() {
        let b = NoteBlock()
        store.updateNote(noteID) { $0.blocks.append(b) }
        DispatchQueue.main.async { focused = b.id }
    }

    @ViewBuilder private func linkedTasks(_ n: NoteItem) -> some View {
        let tasks = store.tasks.filter { $0.sourceNoteID == n.id }
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Divider().padding(.vertical, 10)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.square").foregroundStyle(JZ.accent).font(.system(size: 16))
                    Text("从这篇笔记建的任务").font(.system(size: 16, weight: .bold))
                    Text("\(tasks.count)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(JZ.controlFill, in: Capsule())
                }
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { i, t in
                        HStack(spacing: 10) {
                            Button { store.toggleTask(t) } label: {
                                Image(systemName: t.isDone ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 15))
                                    .foregroundStyle(JZ.accent)
                            }
                            .buttonStyle(.plain)
                            Text(t.title).font(.system(size: 13.5)).strikethrough(t.isDone)
                                .foregroundStyle(t.isDone ? .secondary : .primary)
                            Spacer()
                            if let d = t.dueDate {
                                Text(Self.pill(d))
                                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(JZ.controlFill, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        if i < tasks.count - 1 { Divider().padding(.leading, 40) }
                    }
                }
                .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(JZ.separator.opacity(0.5), lineWidth: 0.5)
                }
            }
        }
    }

    static func pill(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }
}

private struct BlockRow: View {
    let noteID: UUID
    let block: NoteBlock
    var focused: FocusState<UUID?>.Binding
    @EnvironmentObject private var store: DataStore
    @State private var hovering = false

    private var taskExists: Bool {
        guard let id = block.linkedTaskID else { return false }
        return store.tasks.contains { $0.id == id }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Menu {
                ForEach(NoteBlock.Kind.allCases, id: \.self) { k in
                    Button { setKind(k) } label: { Label(k.label, systemImage: k.symbol) }
                }
                Divider()
                Button("删除这一行", role: .destructive) { delete() }
            } label: {
                Image(systemName: "line.3.horizontal").font(.system(size: 10))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 16)
            .opacity(hovering ? 0.7 : 0)

            leading
            TextField(placeholder, text: textBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .font(font)
                .strikethrough(block.kind == .todo && (block.isDone ?? false))
                .foregroundStyle(block.kind == .todo && (block.isDone ?? false) ? .secondary : .primary)
                .focused(focused, equals: block.id)
                .onSubmit { insertBelow() }
                .onKeyPress(.delete) {
                    guard block.text.isEmpty else { return .ignored }
                    delete()
                    return .handled
                }
            if block.kind == .todo {
                if taskExists {
                    Label("已转任务", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(JZ.success)
                        .labelStyle(.titleAndIcon)
                } else if !(block.isDone ?? false) && !block.text.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        store.convertBlockToTask(noteID: noteID, blockID: block.id)
                    } label: {
                        Text("转为任务").font(.system(size: 11))
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(JZ.controlFill, in: Capsule())
                            .overlay { Capsule().strokeBorder(JZ.separator.opacity(0.5), lineWidth: 0.5) }
                    }
                    .buttonStyle(.plain)
                    .opacity(hovering ? 1 : 0.7)
                    .help("建一条任务；文字里的「明天下午三点」会自动设成截止时间")
                }
            }
        }
        .padding(.vertical, block.kind == .heading ? 8 : (block.kind == .todo ? 5 : 2))
        .padding(.horizontal, block.kind == .todo ? 6 : 0)
        .background(block.kind == .todo && hovering ? JZ.accent.opacity(0.07) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var leading: some View {
        switch block.kind {
        case .heading:
            RoundedRectangle(cornerRadius: 1.5).fill(JZ.accent).frame(width: 3.5, height: 18)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 5 }
        case .bullet:
            Circle().fill(JZ.accent).frame(width: 5, height: 5)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
        case .todo:
            Button {
                store.updateNote(noteID) { n in
                    if let i = n.blocks.firstIndex(where: { $0.id == block.id }) {
                        n.blocks[i].isDone = !(n.blocks[i].isDone ?? false)
                    }
                }
            } label: {
                Image(systemName: (block.isDone ?? false) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle((block.isDone ?? false) ? JZ.accent : Color.secondary)
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }

    private var font: Font {
        block.kind == .heading ? .system(size: 18, weight: .bold) : .system(size: 14.5)
    }

    private var placeholder: String {
        switch block.kind {
        case .heading: return "标题"
        case .todo: return "待办"
        case .bullet: return "列表项"
        case .text: return "输入文字，「# 」标题 「- 」列表 「[] 」待办"
        }
    }

    private var textBinding: Binding<String> {
        Binding(get: { block.text }, set: { newValue in
            var v = newValue
            var kind: NoteBlock.Kind? = nil
            // Markdown 快捷：只在行首触发
            if block.kind == .text {
                if v.hasPrefix("# ") { kind = .heading; v.removeFirst(2) }
                else if v.hasPrefix("- ") || v.hasPrefix("* ") { kind = .bullet; v.removeFirst(2) }
                else if v.hasPrefix("[] ") { kind = .todo; v.removeFirst(3) }
                else if v.hasPrefix("[ ] ") { kind = .todo; v.removeFirst(4) }
            }
            // 多行粘贴/换行：拆成多块
            let lines = v.components(separatedBy: "\n")
            store.updateNote(noteID) { n in
                guard let i = n.blocks.firstIndex(where: { $0.id == block.id }) else { return }
                if let kind { n.blocks[i].kind = kind; if kind == .todo { n.blocks[i].isDone = false } }
                n.blocks[i].text = lines[0]
                if lines.count > 1 {
                    let k = n.blocks[i].kind == .heading ? NoteBlock.Kind.text : n.blocks[i].kind
                    let extra = lines.dropFirst().map { NoteBlock(kind: k, text: $0, isDone: k == .todo ? false : nil) }
                    n.blocks.insert(contentsOf: extra, at: i + 1)
                }
            }
        })
    }

    private func setKind(_ k: NoteBlock.Kind) {
        store.updateNote(noteID) { n in
            if let i = n.blocks.firstIndex(where: { $0.id == block.id }) {
                n.blocks[i].kind = k
                if k == .todo && n.blocks[i].isDone == nil { n.blocks[i].isDone = false }
            }
        }
    }

    private func insertBelow() {
        // 列表/待办回车延续同类；空的列表/待办回车变回正文
        let k: NoteBlock.Kind
        if (block.kind == .bullet || block.kind == .todo) && block.text.isEmpty {
            setKind(.text)
            return
        }
        k = (block.kind == .bullet || block.kind == .todo) ? block.kind : .text
        let nb = NoteBlock(kind: k, text: "", isDone: k == .todo ? false : nil)
        store.updateNote(noteID) { n in
            let i = n.blocks.firstIndex(where: { $0.id == block.id }) ?? (n.blocks.count - 1)
            n.blocks.insert(nb, at: i + 1)
        }
        DispatchQueue.main.async { focused.wrappedValue = nb.id }
    }

    private func delete() {
        var prev: UUID? = nil
        store.updateNote(noteID) { n in
            guard let i = n.blocks.firstIndex(where: { $0.id == block.id }) else { return }
            if n.blocks.count == 1 { n.blocks[0] = NoteBlock(); prev = n.blocks[0].id; return }
            prev = i > 0 ? n.blocks[i - 1].id : n.blocks[min(i + 1, n.blocks.count - 1)].id
            n.blocks.remove(at: i)
        }
        DispatchQueue.main.async { focused.wrappedValue = prev }
    }
}
