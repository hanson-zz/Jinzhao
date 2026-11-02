import SwiftUI

struct SidebarView: View {
    @Binding var selection: ShellView.Section
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService

    private func count(for section: ShellView.Section) -> Int? {
        switch section {
        case .today: return calendar.events(on: Date()).count + store.tasks.filter { !$0.isDone }.count
        case .tasks: return store.tasks.filter { !$0.isDone }.count
        case .inbox: return store.inbox.count
        default: return nil
        }
    }

    /// 文件夹按任务实际归属统计（没有文件夹的任务不显示）
    private var folderCounts: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: store.tasks.compactMap { $0.folderName }) { $0 }
        return grouped.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    private let folderColors: [Color] = [.green, .pink, .purple, .blue, .orange]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                // App 标识
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.orange, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 26, height: 26)
                        .overlay(Text("今").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
                    Text("今朝").font(.headline)
                    Spacer()
                    Text("Pro").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // 搜索/新建已挪到窗口工具栏（定版设计规范）
                ForEach(ShellView.Section.allCases, id: \.self) { section in
                    Button { selection = section } label: {
                        HStack {
                            Image(systemName: section.symbol).frame(width: 18)
                            Text(section.rawValue)
                            Spacer()
                            if let n = count(for: section) {
                                Text("\(n)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(selection == section ? Color.white.opacity(0.16) : .clear,
                                    in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if !folderCounts.isEmpty {
                    Text("文件夹").font(.caption).foregroundStyle(.secondary).padding(.top, 14)
                    ForEach(Array(folderCounts.enumerated()), id: \.offset) { i, folder in
                        folderRow(folder.name, folderColors[i % folderColors.count], folder.count)
                    }
                }

                Spacer()

                // 本地存储状态（卖点：数据在本地、断网可用）
                HStack(spacing: 8) {
                    Circle().fill(.orange).frame(width: 26, height: 26)
                        .overlay(Text("韩").font(.caption2).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("老板").font(.callout.weight(.medium))
                        Text("本地存储 · 已离线").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(14)
        }
    }

    private func folderRow(_ name: String, _ color: Color, _ count: Int) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.callout)
            Spacer()
            Text("\(count)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
