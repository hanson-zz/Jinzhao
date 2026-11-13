import SwiftUI
import AppKit
import UserNotifications

@main
struct JinzhaoApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var calendarService = CalendarService()
    @AppStorage(AppearanceSetting.storageKey) private var appearanceRaw: String = AppearanceSetting.system.rawValue
    private let holidays = HolidayService()
    private let holidayUpdater: HolidayUpdater

    init() {
        // 关掉窗口标签页功能：「显示」菜单里的「显示标签页栏」等用不到的系统项随之消失
        NSWindow.allowsAutomaticWindowTabbing = false
        // 节假日更新接上：缓存目录合并优先于内置数据；启动时静默拉当年+次年，
        // 某年安排第一次公布时发本地通知（「调休安排公布后自动更新」从此是真的）
        let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jinzhao/Holidays", isDirectory: true)
        let updater = HolidayUpdater(service: holidays, storeDir: cacheDir)
        updater.onNewArrangement = { year in
            JinzhaoApp.notifyNewArrangement(year: year)
        }
        holidayUpdater = updater
        Task { await updater.refreshCurrentAndNext() }
    }

    var body: some Scene {
        WindowGroup {
            ShellView(today: Date())
                .environmentObject(store)
                .environmentObject(calendarService)
                .environment(\.holidayService, holidays)
                .frame(minWidth: 1060, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        Window("快速启动 · 今朝", id: "quick-launcher") {
            QuickLauncherView()
                .environmentObject(store)
                .environmentObject(calendarService)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        Window("今日浮窗 · 今朝", id: "today-floating") {
            TodayFloatingView()
                .environmentObject(store)
                .environmentObject(calendarService)
        }
        .defaultSize(width: 320, height: 440)
        .windowResizability(.contentSize)
        .commands {
            // 应用菜单：关于 / 设置（系统菜单标题由包内简体中文本地化决定）
            CommandGroup(replacing: .appInfo) {
                Button("关于今朝") { post(.jinzhaoShowAbout) }
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") { post(.jinzhaoShowSettings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
            // 文件菜单「新建」组
            CommandGroup(replacing: .newItem) {
                Button("随手记到收件箱") { post(.jinzhaoQuickCapture) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("新建任务") { post(.jinzhaoNewTask) }
                Button("新建日程") { post(.jinzhaoNewEvent) }
                Divider()
                Button("快速启动") { post(.jinzhaoQuickLaunch) }
                    .keyboardShortcut("k", modifiers: .command)
                Button("打开今日浮窗") { post(.jinzhaoShowFloatingToday) }
                    .keyboardShortcut("j", modifiers: [.command, .shift])
            }
            // 前往菜单：栏目切换（⌘1–⌘7）+ 外观（系统「显示」菜单保持原样，不重名）
            CommandMenu("前往") {
                ForEach(Array(ShellView.Section.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.rawValue) { post(.jinzhaoSwitchSection, object: section.rawValue) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
                ForEach(AppearanceSetting.allCases, id: \.self) { setting in
                    Button {
                        appearanceRaw = setting.rawValue
                    } label: {
                        if appearanceRaw == setting.rawValue {
                            Label(setting.rawValue, systemImage: "checkmark")
                        } else {
                            Text(setting.rawValue)
                        }
                    }
                }
            }
            // 帮助菜单
            CommandGroup(replacing: .help) {
                Button("今朝使用说明") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/hanson-zz/Jinzhao")!)
                }
                Button("反馈问题") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/hanson-zz/Jinzhao/issues")!)
                }
            }
        }
    }

    private func post(_ name: Notification.Name, object: Any? = nil) {
        NotificationCenter.default.post(name: name, object: object)
    }

    /// 新一年放假安排公布时的本地通知（先征得通知授权，未授权则静默跳过）
    private static func notifyNewArrangement(year: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "今朝"
            content.body = "\(year) 年放假安排已公布，日历上的休/班标记已自动更新。"
            let request = UNNotificationRequest(identifier: "holiday-\(year)",
                                                content: content, trigger: nil)
            center.add(request)
        }
    }
}

extension Notification.Name {
    static let jinzhaoQuickCapture = Notification.Name("jinzhao.quickCapture") // ⌘N 收件箱
    static let jinzhaoQuickLaunch = Notification.Name("jinzhao.quickLaunch")   // ⌘K 启动器
    static let jinzhaoNewTask = Notification.Name("jinzhao.newTask")           // 菜单：切到任务页再聚焦输入框
    static let jinzhaoFocusTaskField = Notification.Name("jinzhao.focusTaskField")
    static let jinzhaoNewEvent = Notification.Name("jinzhao.newEvent")         // 菜单：切到日历页再打开新建日程
    static let jinzhaoOpenNewEvent = Notification.Name("jinzhao.openNewEvent")
    static let jinzhaoSwitchSection = Notification.Name("jinzhao.switchSection") // object = 栏目中文名
    static let jinzhaoShowAbout = Notification.Name("jinzhao.showAbout")
    static let jinzhaoShowSettings = Notification.Name("jinzhao.showSettings")
    static let jinzhaoShowFloatingToday = Notification.Name("jinzhao.showFloatingToday")
}

// MARK: - HolidayService 注入

private struct HolidayServiceKey: EnvironmentKey {
    static let defaultValue = HolidayService()
}

extension EnvironmentValues {
    var holidayService: HolidayService {
        get { self[HolidayServiceKey.self] }
        set { self[HolidayServiceKey.self] = newValue }
    }
}
