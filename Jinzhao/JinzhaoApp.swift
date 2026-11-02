import SwiftUI
import UserNotifications

@main
struct JinzhaoApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var calendarService = CalendarService()
    private let holidays = HolidayService()
    private let holidayUpdater: HolidayUpdater

    init() {
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
                .frame(minWidth: 1180, minHeight: 740)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("随手记") { NotificationCenter.default.post(name: .jinzhaoQuickCapture, object: nil) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("快速启动") { NotificationCenter.default.post(name: .jinzhaoQuickLaunch, object: nil) }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }
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
