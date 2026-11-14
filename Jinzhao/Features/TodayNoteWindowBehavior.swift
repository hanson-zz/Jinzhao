import SwiftUI
import AppKit

/// 桌面今日便签专用窗口配置。将状态持久化交给 AppStorage，
/// 位置持久化交给 AppKit 的 frame autosave；不修改任务 JSON 数据。
struct TodayNoteWindowBehavior: NSViewRepresentable {
    let alwaysOnTop: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.level = alwaysOnTop ? .floating : .normal
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("JinzhaoTodayStickyNoteWindow")
    }
}
