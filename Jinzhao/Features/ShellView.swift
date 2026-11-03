import SwiftUI
import AppKit

/// 三栏外壳（照效果图）：左导航（渐变玻璃）｜ 中「今天」｜ 右常驻收件箱栏
struct ShellView: View {
    let today: Date
    @State private var selection: Section = .today
    @State private var searchText = ""
    @AppStorage(AppearanceSetting.storageKey) private var appearanceRaw: String = AppearanceSetting.system.rawValue
    @State private var showAbout = false
    @State private var showSettings = false
    @FocusState private var searchFocused: Bool

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
                .layoutPriority(2) // 两侧栏定宽优先保住
            center
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0) // 窗口拉窄时只有中间栏变窄，右栏不溢出
                .transition(.opacity)
            InboxRailView(today: today)
                .frame(width: 272)
                .layoutPriority(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(JZ.spaceM) // 左右留白一致
        .background(WindowBackdrop())
        .animation(.easeInOut(duration: 0.18), value: selection)
        .toolbar {
            // 搜索框挪到工具栏（原在侧边栏里）
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索或新建", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
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
        .preferredColorScheme((AppearanceSetting(rawValue: appearanceRaw) ?? .system).colorScheme)
        // 菜单栏命令接线（命令在 JinzhaoApp 的 .commands 里定义）
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoSwitchSection)) { note in
            if let name = note.object as? String, let s = Section(rawValue: name) { selection = s }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoNewTask)) { _ in
            selection = .tasks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .jinzhaoFocusTaskField, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoNewEvent)) { _ in
            selection = .calendar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .jinzhaoOpenNewEvent, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoQuickLaunch)) { _ in
            searchFocused = true // ⌘K 先聚焦工具栏搜索，启动器实体在后续切片
        }
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoShowAbout)) { _ in showAbout = true }
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoShowSettings)) { _ in showSettings = true }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
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
                : [Color(red: 1.00, green: 0.94, blue: 0.86), Color(red: 1.00, green: 0.88, blue: 0.73), Color(red: 0.99, green: 0.91, blue: 0.78)],
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

/// 关于今朝（菜单栏「今朝 → 关于今朝」）：图标 / 版本 / 宣传语 / holiday-cn MIT 致谢
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: JZ.spaceS) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("今朝").font(.jzTitle)
            Text("版本 0.1.0（开发版）").font(.jzCaption).foregroundStyle(.secondary)
            Text("把今天，过得井井有条。").font(.jzBody).padding(.top, 4)
            Divider().padding(.vertical, 6)
            Text("节假日数据来自开源项目 holiday-cn（作者 NateScarlet，MIT License），随应用内置并可自动更新。你的数据只保存在本机，不上传。")
                .font(.jzCaption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("好") { dismiss() }
                .glassButton(prominent: true)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 6)
        }
        .padding(JZ.spaceL)
        .frame(width: 340)
    }
}

/// 设置（菜单栏「今朝 → 设置…」⌘,）：先落外观一项，与「前往」菜单共用同一设置
struct SettingsView: View {
    @AppStorage(AppearanceSetting.storageKey) private var appearanceRaw: String = AppearanceSetting.system.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: JZ.spaceM) {
            Text("设置").font(.jzTitle)
            HStack {
                Text("外观").font(.jzBody)
                Spacer()
                Picker("", selection: $appearanceRaw) {
                    ForEach(AppearanceSetting.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)
            }
            Text("数据保存在本机（~/Library/Application Support/Jinzhao），不联网上传，断网可用。")
                .font(.jzCaption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .glassButton(prominent: true)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(JZ.spaceL)
        .frame(width: 400)
    }
}
