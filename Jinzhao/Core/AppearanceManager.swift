import AppKit

/// 外观与 Dock 图标：设置里的「跟随系统 / 浅色 / 深色」同时作用于全部窗口和 Dock 图标
/// 浅色 = 睁眼的朝朝（dock-light.png），深色 = 闭眼的朝朝（dock-dark.png）
@MainActor
final class AppearanceManager {
    static let shared = AppearanceManager()
    private var appearanceObservation: NSKeyValueObservation?
    private var defaultsObserver: NSObjectProtocol?
    private var lastApplied: String?

    func start() {
        guard appearanceObservation == nil else { apply(); return }
        apply()
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            Task { @MainActor in AppearanceManager.shared.apply() }
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppearanceManager.shared.apply() }
        }
    }

    private var setting: AppearanceSetting {
        AppearanceSetting(rawValue: UserDefaults.standard.string(forKey: AppearanceSetting.storageKey) ?? "") ?? .system
    }

    func apply() {
        let app = NSApplication.shared
        let s = setting
        switch s {
        case .system: if app.appearance != nil { app.appearance = nil }
        case .light: if app.appearance?.name != .aqua { app.appearance = NSAppearance(named: .aqua) }
        case .dark: if app.appearance?.name != .darkAqua { app.appearance = NSAppearance(named: .darkAqua) }
        }
        let isDark: Bool
        switch s {
        case .light: isDark = false
        case .dark: isDark = true
        case .system: isDark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        let name = isDark ? "dock-dark" : "dock-light"
        guard name != lastApplied else { return }
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "DockIcons"),
           let image = NSImage(contentsOf: url) {
            app.applicationIconImage = image
            lastApplied = name
        }
    }
}

/// 界面语言：跟随系统 / 简体中文 / English。写入本应用的 AppleLanguages，重启后生效。
enum LanguageSetting: String, CaseIterable {
    case system = "跟随系统"
    case chinese = "简体中文"
    case english = "English"

    static let storageKey = "jinzhao.language"

    static var current: LanguageSetting {
        LanguageSetting(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    func applyForNextLaunch() {
        let d = UserDefaults.standard
        d.set(rawValue, forKey: LanguageSetting.storageKey)
        switch self {
        case .system: d.removeObject(forKey: "AppleLanguages")
        case .chinese: d.set(["zh-Hans"], forKey: "AppleLanguages")
        case .english: d.set(["en"], forKey: "AppleLanguages")
        }
    }

    @MainActor static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
        }
    }
}
