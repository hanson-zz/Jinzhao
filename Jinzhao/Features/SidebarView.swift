import SwiftUI
import AppKit

/// 侧边导航（参考 Loop / Ice 等开源 Mac 应用的分组导航）：
/// 品牌区（真实图标随浅/深外观切换 + 宣传语）→ 分组（日程 / 整理）→ 文件夹（可折叠）→ Pro 卡 → 本地状态
struct SidebarView: View {
    @Binding var selection: ShellView.Section
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.colorScheme) private var scheme // 外观切换时刷新品牌区图标
    @State private var foldersExpanded = true

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

    /// 栏目图标块配色（低饱和，选中时点亮；今天用暖橙，不抢日期条的蓝色焦点）
    private func tileColor(for section: ShellView.Section) -> Color {
        switch section {
        case .today: return JZ.warm
        case .upcoming: return .indigo
        case .calendar: return JZ.danger
        case .tasks: return JZ.success
        case .habits: return JZ.teal
        case .notes: return .yellow
        case .inbox: return .purple
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                brandHeader

                groupHeader("日程")
                navRow(.today)
                navRow(.upcoming)
                navRow(.calendar)

                groupHeader("整理")
                navRow(.tasks)
                navRow(.habits)
                navRow(.notes)
                navRow(.inbox)

                if !folderCounts.isEmpty {
                    folderHeader
                    if foldersExpanded {
                        ForEach(folderCounts, id: \.name) { folder in
                            folderRow(folder.name, folder.count)
                        }
                    }
                }

                Spacer()
                proCard
                localStatus
            }
            .padding(14)
        }
    }

    // MARK: 品牌区（图标 + 名称 + 宣传语）

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("今朝").font(.jzSection)
                Text("把今天，过得井井有条")
                    .font(.jzCaption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.bottom, 10)
        .id(scheme) // 外观切换后重新取对应外观的应用图标
    }

    // MARK: 分组与导航行

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.jzCaption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }

    private func navRow(_ section: ShellView.Section) -> some View {
        let selected = selection == section
        let tile = tileColor(for: section)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = section }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: section.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : tile)
                    .frame(width: 26, height: 26)
                    .background(selected ? tile : tile.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(section.rawValue)
                    .font(.jzBody.weight(selected ? .semibold : .regular))
                Spacer()
                if let n = count(for: section), n > 0 {
                    Text("\(n)")
                        .font(.jzCaption.weight(.medium))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(JZ.controlFill, in: Capsule())
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(selected ? JZ.hoverFill : Color.clear,
                        in: RoundedRectangle(cornerRadius: JZ.radiusS, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
    }

    // MARK: 文件夹（可折叠）

    private var folderHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { foldersExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text("文件夹")
                    .font(.jzCaption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(foldersExpanded ? 90 : 0))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func folderRow(_ name: String, _ count: Int) -> some View {
        HStack(spacing: 9) {
            Circle().fill(JZ.capsuleColor(for: name)).frame(width: 8, height: 8)
                .padding(.leading, 9)
            Text(name).font(.jzBody)
            Spacer()
            Text("\(count)")
                .font(.jzCaption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .contentShape(Rectangle())
        .hoverHighlight()
    }

    // MARK: 底部（Pro 卡 + 本地状态）

    private var proCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 13))
                .foregroundStyle(JZ.warm)
                .frame(width: 26, height: 26)
                .background(JZ.warm.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("今朝 Pro").font(.jzBody.weight(.semibold))
                Text("解锁全部功能").font(.jzCaption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous))
    }

    private var localStatus: some View {
        HStack(spacing: 7) {
            Circle().fill(JZ.success).frame(width: 8, height: 8)
            Text("本地存储 · 已离线可用").font(.jzCaption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }
}
