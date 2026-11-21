import SwiftUI

/// 收件箱整页：随手记的东西在这里分流——转任务（自动识别中文时间）、转笔记、删除
struct InboxPageView: View {
    @EnvironmentObject private var store: DataStore
    @State private var draft = ""
    @Binding var selection: ShellView.Section

    var body: some View {
        SolidCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("收件箱").font(.system(size: 24, weight: .bold))
                        Text("\(store.inbox.count) 条待分流").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "tray.and.arrow.down").foregroundStyle(.secondary)
                        TextField("想到什么先记下，回车保存（⌘N）", text: $draft)
                            .textFieldStyle(.plain)
                            .onSubmit { store.addInbox(text: draft); draft = "" }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: 11))

                    if store.inbox.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                            Text("收件箱清空了").font(.jzSection)
                            Text("随手记的东西会落在这里，之后再变成任务或笔记。")
                                .font(.jzBody).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 50)
                    }
                    ForEach(store.inbox) { item in
                        row(item)
                    }
                }
                .padding(20)
            }
        }
    }

    private func row(_ item: InboxItem) -> some View {
        let parsed = DatePhraseParser.parse(item.text)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle").font(.caption).foregroundStyle(.secondary).padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text).font(.body)
                HStack(spacing: 8) {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let due = parsed.due {
                        Label("识别到时间：\(due.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                            .foregroundStyle(JZ.accent)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("转任务") { withAnimation { store.inboxToTask(item) } }
                .glassButton().controlSize(.small)
            Button("转笔记") {
                let id = store.inboxToNote(item)
                selection = .notes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: .jinzhaoOpenNote, object: id)
                }
            }
            .glassButton().controlSize(.small)
            Button { withAnimation { store.deleteInbox(item) } } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("删除")
        }
        .padding(.vertical, 6).padding(.horizontal, 6)
        .hoverHighlight()
    }
}
