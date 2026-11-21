import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    /// 最近一次获得焦点的块：点工具栏按钮时焦点可能已经离开输入框，以它为准
    @State private var current: UUID?

    private var note: NoteItem? { store.notes.first { $0.id == noteID } }

    var body: some View {
        if let note {
            VStack(spacing: 0) {
            NoteToolbar(noteID: noteID, current: $current, focused: $focused)
            Divider()
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
                    ForEach(Array(note.blocks.enumerated()), id: \.element.id) { i, block in
                        BlockRow(noteID: noteID, block: block, number: Self.number(at: i, in: note.blocks), focused: $focused)
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
            }
            .onAppear {
                if note.title.isEmpty && note.plainText.isEmpty { titleFocused = true }
            }
            .onChange(of: focused) { _, v in if let v { current = v } }
        }
    }

    /// 编号列表的序号：从连续一段编号块的第一块数起
    static func number(at i: Int, in blocks: [NoteBlock]) -> Int {
        guard blocks[i].kind == .numbered else { return 0 }
        var n = 1, j = i - 1
        while j >= 0 && blocks[j].kind == .numbered { n += 1; j -= 1 }
        return n
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
    var number: Int = 0
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
                if block.kind.isTextual {
                    ForEach(NoteBlock.Kind.textKinds, id: \.self) { k in
                        Button { setKind(k) } label: { Label(k.label, systemImage: k.symbol) }
                    }
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
            switch block.kind {
            case .image:
                NoteImageBlock(noteID: noteID, block: block)
            case .table:
                NoteTableBlock(noteID: noteID, block: block)
            case .divider:
                Rectangle().fill(JZ.separator).frame(height: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            default:
            TextField(placeholder, text: textBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .font(font)
                .italic(block.italic ?? false)
                .underline(block.underline ?? false)
                .strikethrough((block.kind == .todo && (block.isDone ?? false)) || (block.strike ?? false))
                .foregroundStyle(textColor)
                .focused(focused, equals: block.id)
                .onSubmit { insertBelow() }
                .onKeyPress(.delete) {
                    guard block.text.isEmpty else { return .ignored }
                    delete()
                    return .handled
                }
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
        .padding(.leading, block.kind == .quote ? 4 : 0)
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
        case .numbered:
            Text("\(number).").font(.system(size: 14.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(JZ.accent)
                .frame(minWidth: 18, alignment: .trailing)
        case .quote:
            RoundedRectangle(cornerRadius: 1.5).fill(Color.secondary.opacity(0.5)).frame(width: 3, height: 18)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 5 }
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
        if block.kind == .heading { return .system(size: 18, weight: .bold) }
        return .system(size: 14.5, weight: (block.bold ?? false) ? .bold : .regular)
    }

    private var textColor: Color {
        if block.kind == .todo && (block.isDone ?? false) { return .secondary }
        if block.kind == .quote && block.color == nil { return .secondary }
        return NoteToolbar.color(block.color) ?? .primary
    }

    private var placeholder: String {
        switch block.kind {
        case .heading: return "标题"
        case .todo: return "待办"
        case .bullet, .numbered: return "列表项"
        case .quote: return "引用"
        case .text: return "输入文字，「# 」标题 「- 」列表 「1. 」编号 「[] 」待办 「> 」引用"
        default: return ""
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
                else if v.hasPrefix("1. ") { kind = .numbered; v.removeFirst(3) }
                else if v.hasPrefix("> ") { kind = .quote; v.removeFirst(2) }
                else if v == "---" { kind = .divider; v = "" }
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
        let continuing: [NoteBlock.Kind] = [.bullet, .todo, .numbered]
        if continuing.contains(block.kind) && block.text.isEmpty {
            setKind(.text)
            return
        }
        k = continuing.contains(block.kind) ? block.kind : .text
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

// MARK: - 工具栏

private struct NoteToolbar: View {
    let noteID: UUID
    @Binding var current: UUID?
    var focused: FocusState<UUID?>.Binding
    @EnvironmentObject private var store: DataStore

    private var note: NoteItem? { store.notes.first { $0.id == noteID } }
    private var block: NoteBlock? {
        guard let id = current else { return nil }
        return note?.blocks.first { $0.id == id }
    }

    static func color(_ name: String?) -> Color? {
        switch name {
        case "red": return .red
        case "orange": return JZ.accent
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "gray": return .gray
        default: return nil
        }
    }
    static let colorLabels: [String: String] = ["red": "红色", "orange": "橙色", "green": "绿色", "blue": "蓝色", "purple": "紫色", "gray": "灰色"]

    var body: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(NoteBlock.Kind.textKinds, id: \.self) { k in
                    Button { setKind(k) } label: { Label(k.label, systemImage: k.symbol) }
                }
            } label: {
                Text(LocalizedStringKey(block?.kind.isTextual == true ? block!.kind.label : "正文"))
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: 6))
            .help("文字样式")

            sep
            toggle("bold", "加粗", \.bold)
            toggle("italic", "斜体", \.italic)
            toggle("underline", "下划线", \.underline)
            toggle("strikethrough", "删除线", \.strike)
            Menu {
                Button("默认颜色") { mutate { $0.color = nil } }
                Divider()
                ForEach(NoteBlock.colorNames, id: \.self) { c in
                    Button(Self.colorLabels[c] ?? c) { mutate { $0.color = c } }
                }
            } label: {
                Image(systemName: "character").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Self.color(block?.color) ?? .primary)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .frame(width: 28, height: 24)
            .help("文字颜色")

            sep
            icon("checkmark.square", "待办") { setKind(.todo) }
            icon("list.bullet", "列表") { setKind(.bullet) }
            icon("list.number", "编号列表") { setKind(.numbered) }
            icon("tablecells", "插入表格") { insert(NoteBlock(kind: .table, table: [["", "", ""], ["", "", ""], ["", "", ""]])) }
            icon("photo", "插入图片") { pickImage() }

            Menu {
                Button { setKind(.quote) } label: { Label("引用", systemImage: "text.quote") }
                Button { insert(NoteBlock(kind: .divider)) } label: { Label("分割线", systemImage: "minus") }
                Divider()
                Button("拷贝为 Markdown") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(markdown, forType: .string)
                }
                Button("导出 Markdown 文件…") { exportMarkdown() }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .frame(width: 28, height: 24)
            .help("更多")

            Spacer()
            ShareLink(item: markdown, subject: Text(note?.title ?? ""), preview: SharePreview(note?.title.isEmpty == false ? note!.title : "笔记")) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 24)
            .help("分享")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var sep: some View {
        Rectangle().fill(JZ.separator).frame(width: 0.5, height: 16).padding(.horizontal, 4)
    }

    private func icon(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .help(LocalizedStringKey(help))
    }

    private func toggle(_ symbol: String, _ help: String, _ key: WritableKeyPath<NoteBlock, Bool?>) -> some View {
        let on = block?[keyPath: key] ?? false
        return Button {
            mutate { $0[keyPath: key] = ($0[keyPath: key] ?? false) ? nil : true }
        } label: {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? JZ.accent : Color.primary)
                .frame(width: 28, height: 24)
                .background(on ? JZ.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(LocalizedStringKey(help + "（整行）"))
        .disabled(block?.kind.isTextual != true)
    }

    /// 改当前块；没有选中块时改最后一块
    private func mutate(_ change: (inout NoteBlock) -> Void) {
        store.updateNote(noteID) { n in
            let i = current.flatMap { id in n.blocks.firstIndex { $0.id == id } } ?? (n.blocks.isEmpty ? nil : n.blocks.count - 1)
            guard let i, n.blocks[i].kind.isTextual else { return }
            change(&n.blocks[i])
        }
        if let current { DispatchQueue.main.async { focused.wrappedValue = current } }
    }

    private func setKind(_ k: NoteBlock.Kind) {
        if block == nil || block?.kind.isTextual != true {
            insert(NoteBlock(kind: k, isDone: k == .todo ? false : nil))
            return
        }
        mutate { b in
            b.kind = (b.kind == k && k != .text) ? .text : k
            if b.kind == .todo && b.isDone == nil { b.isDone = false }
        }
    }

    /// 在当前块下面插入；新块是文字块就把光标放进去，其他块后面补一行空正文
    private func insert(_ nb: NoteBlock) {
        var follow: NoteBlock? = nil
        store.updateNote(noteID) { n in
            let i = current.flatMap { id in n.blocks.firstIndex { $0.id == id } } ?? (n.blocks.count - 1)
            var at = i + 1
            // 当前块是空正文就直接替换掉
            if i >= 0 && i < n.blocks.count && n.blocks[i].kind == .text && n.blocks[i].text.isEmpty && !nb.kind.isTextual {
                n.blocks[i] = nb; at = i + 1
            } else {
                n.blocks.insert(nb, at: max(0, min(at, n.blocks.count)))
                at += 1
            }
            if !nb.kind.isTextual {
                let t = NoteBlock()
                n.blocks.insert(t, at: min(at, n.blocks.count))
                follow = t
            }
        }
        let target = nb.kind.isTextual ? nb.id : follow?.id
        DispatchQueue.main.async {
            focused.wrappedValue = target
            current = target
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "插入"
        guard panel.runModal() == .OK, let url = panel.url,
              let name = NoteImageStore.importImage(from: url) else { return }
        insert(NoteBlock(kind: .image, imageFile: name))
    }

    var markdown: String { note.map(NoteMarkdown.render) ?? "" }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        let title = note?.title.isEmpty == false ? note!.title : "笔记"
        panel.nameFieldStringValue = title + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - 图片块

enum NoteImageStore {
    static var dir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jinzhao/NoteImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// 复制进 App 自己的目录，原图删了也不丢
    static func importImage(from url: URL) -> String? {
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
        let name = UUID().uuidString + "." + ext
        do {
            try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(name))
            return name
        } catch { return nil }
    }

    static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }
}

private struct NoteImageBlock: View {
    let noteID: UUID
    let block: NoteBlock
    @EnvironmentObject private var store: DataStore

    var body: some View {
        Group {
            if let name = block.imageFile, let img = NSImage(contentsOf: NoteImageStore.url(name)) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: min(img.size.width, 620), alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(JZ.separator.opacity(0.4), lineWidth: 0.5) }
            } else {
                Label("图片找不到了", systemImage: "photo.badge.exclamationmark")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(12)
                    .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contextMenu {
            if let name = block.imageFile {
                Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([NoteImageStore.url(name)]) }
            }
        }
    }
}

// MARK: - 表格块

private struct NoteTableBlock: View {
    let noteID: UUID
    let block: NoteBlock
    @EnvironmentObject private var store: DataStore

    private var rows: [[String]] { block.table ?? [[""]] }

    var body: some View {
        let cols = rows.map { $0.count }.max() ?? 1
        VStack(alignment: .leading, spacing: 6) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<rows.count, id: \.self) { r in
                    GridRow {
                        ForEach(0..<cols, id: \.self) { c in
                            TextField(r == 0 ? "表头" : "", text: cell(r, c), axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13.5, weight: r == 0 ? .semibold : .regular))
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                                .background(r == 0 ? JZ.accent.opacity(0.08) : Color.clear)
                                .overlay { Rectangle().strokeBorder(JZ.separator.opacity(0.6), lineWidth: 0.5) }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(JZ.separator.opacity(0.8), lineWidth: 0.5) }
            HStack(spacing: 12) {
                Button("+ 行") { edit { t in t.append(Array(repeating: "", count: cols)) } }
                Button("+ 列") { edit { t in for i in t.indices { t[i].append("") } } }
                Button("− 行") { edit { t in if t.count > 1 { t.removeLast() } } }
                Button("− 列") { edit { t in for i in t.indices where t[i].count > 1 { t[i].removeLast() } } }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func cell(_ r: Int, _ c: Int) -> Binding<String> {
        Binding(get: {
            let t = rows
            return r < t.count && c < t[r].count ? t[r][c] : ""
        }, set: { v in
            edit { t in
                while t.count <= r { t.append([]) }
                while t[r].count <= c { t[r].append("") }
                t[r][c] = v.replacingOccurrences(of: "\n", with: " ")
            }
        })
    }

    private func edit(_ change: (inout [[String]]) -> Void) {
        store.updateNote(noteID) { n in
            guard let i = n.blocks.firstIndex(where: { $0.id == block.id }) else { return }
            var t = n.blocks[i].table ?? [[""]]
            change(&t)
            n.blocks[i].table = t
        }
    }
}

// MARK: - Markdown 导出

enum NoteMarkdown {
    static func render(_ n: NoteItem) -> String {
        var out: [String] = []
        if !n.title.isEmpty { out.append("# " + n.title); out.append("") }
        var num = 0
        for b in n.blocks {
            num = b.kind == .numbered ? num + 1 : 0
            var t = b.text
            if b.kind.isTextual && !t.isEmpty {
                if b.bold ?? false { t = "**\(t)**" }
                if b.italic ?? false { t = "*\(t)*" }
                if b.strike ?? false { t = "~~\(t)~~" }
            }
            switch b.kind {
            case .text: out.append(t)
            case .heading: out.append("## " + t)
            case .bullet: out.append("- " + t)
            case .numbered: out.append("\(num). " + t)
            case .todo: out.append(((b.isDone ?? false) ? "- [x] " : "- [ ] ") + t)
            case .quote: out.append("> " + t)
            case .divider: out.append("---")
            case .image:
                if let f = b.imageFile { out.append("![](\(NoteImageStore.url(f).absoluteString))") }
            case .table:
                let rows = b.table ?? []
                guard let head = rows.first else { continue }
                let cols = rows.map { $0.count }.max() ?? head.count
                func line(_ r: [String]) -> String {
                    "| " + (0..<cols).map { $0 < r.count ? r[$0].replacingOccurrences(of: "|", with: "\\|") : "" }.joined(separator: " | ") + " |"
                }
                out.append(""); out.append(line(head))
                out.append("|" + Array(repeating: " --- |", count: cols).joined())
                for r in rows.dropFirst() { out.append(line(r)) }
                out.append("")
            }
        }
        return out.joined(separator: "\n")
    }
}
