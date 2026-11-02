import SwiftUI

/// 三栏外壳（照效果图）：左导航（渐变玻璃）｜ 中「今天」｜ 右常驻收件箱栏
struct ShellView: View {
    let today: Date
    @State private var selection: Section = .today
    @State private var searchText = ""

    enum Section: String, CaseIterable {
        case today = "今天"
        case upcoming = "即将到来"
        case calendar = "日历"
        case notes = "笔记"
        case tasks = "任务"
        case habits = "习惯"
        case inbox = "收件箱"

        var symbol: String {
            switch self {
            case .today: return "sun.max"
            case .upcoming: return "arrow.right"
            case .calendar: return "calendar"
            case .notes: return "doc.text"
            case .tasks: return "checklist"
            case .habits: return "repeat"
            case .inbox: return "tray"
            }
        }
    }

    var body: some View {
        HStack(spacing: JZ.spaceM) {
            SidebarView(selection: $selection)
                .frame(width: 208)
            center
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            InboxRailView(today: today)
                .frame(width: 272)
        }
        .padding(JZ.spaceM)
        .background(WindowBackdrop())
        .animation(.easeInOut(duration: 0.18), value: selection)
        .toolbar {
            // 搜索框挪到工具栏（原在侧边栏里）
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索或新建", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 170)
                        .onSubmit { selection = .tasks }
                    Text("⌘K").font(.jzCaption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(JZ.controlFill, in: Capsule())
            }
            // 新建按钮挪到工具栏：玻璃样式，不抢日期条「今天」的蓝色焦点
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("新建任务") { selection = .tasks }
                    Button("新建日程") { selection = .calendar }
                    Button("去收件箱随手记") { selection = .today }
                } label: {
                    Label("新建", systemImage: "plus")
                }
                .glassButton()
            }
        }
    }

    @ViewBuilder private var center: some View {
        switch selection {
        case .today:
            TodayView(date: today)
        case .upcoming:
            UpcomingView()
        case .calendar:
            CalendarView()
        case .tasks:
            TasksView()
        default:
            PlaceholderView(section: selection)
        }
    }
}

/// 窗口底色：深色为深蓝紫渐变，浅色为桃蓝黄柔和渐变（效果图同款氛围）
struct WindowBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.13, green: 0.10, blue: 0.30), Color(red: 0.05, green: 0.10, blue: 0.32), Color(red: 0.02, green: 0.05, blue: 0.16)]
                : [Color(red: 0.98, green: 0.80, blue: 0.70), Color(red: 0.85, green: 0.88, blue: 0.98), Color(red: 0.98, green: 0.93, blue: 0.72)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

/// 玻璃卡片容器：macOS 26 用原生液态玻璃（有折射和高光），旧系统回退毛玻璃材质
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = JZ.radiusL
    @ViewBuilder var content: Content

    @ViewBuilder var body: some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
        }
    }
}
