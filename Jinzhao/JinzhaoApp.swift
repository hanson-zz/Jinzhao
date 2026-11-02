import SwiftUI

@main
struct JinzhaoApp: App {
    @StateObject private var store = DemoStore()
    private let holidays = HolidayService()

    var body: some Scene {
        WindowGroup {
            ShellView(today: DemoStore.referenceDate) // 正式版改为 Date()
                .environmentObject(store)
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
