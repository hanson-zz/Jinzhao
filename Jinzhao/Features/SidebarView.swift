import SwiftUI

struct SidebarView: View {
    @Binding var selection: ShellView.Section
    @EnvironmentObject private var store: DemoStore

    private func count(for section: ShellView.Section) -> Int? {
        switch section {
        case .today: return store.events.count + store.tasks.filter { !$0.isDone }.count
        case .upcoming: return 14
        case .tasks: return store.tasks.count * 5 + 3 // 演示数，正式版由存储统计
        case .inbox: return store.inbox.count
        default: return nil
        }
    }

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

                // ⌘K 搜索/新建
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    Text("搜索或新建").foregroundStyle(.secondary)
                    Spacer()
                    Text("⌘K").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                .padding(.bottom, 10)

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

                Text("收藏").font(.caption).foregroundStyle(.secondary).padding(.top, 14)
                Label("Q4 客户拜访", systemImage: "circle.fill")
                    .labelStyle(.titleAndIcon).font(.callout)
                    .foregroundStyle(.primary, .yellow)
                Label("新品试吃会", systemImage: "circle.fill")
                    .font(.callout).foregroundStyle(.primary, .blue)

                Text("文件夹").font(.caption).foregroundStyle(.secondary).padding(.top, 12)
                folderRow("工作", .green, 12)
                folderRow("生活", .pink, 7)
                folderRow("读书笔记", .purple, 5)

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
