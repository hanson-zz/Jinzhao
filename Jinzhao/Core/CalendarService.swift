import Foundation
import EventKit
import AppKit

/// 苹果日历接入（EventKit）：读取全部日历的日程，识别会议链接；可在默认日历新建日程。
/// 数据不落盘，实时读系统日历，日历变化（EKEventStoreChanged）时自动刷新。
@MainActor
final class CalendarService: ObservableObject {
    enum AuthState: Equatable {
        case notDetermined, denied, authorized, unknown
    }

    @Published var events: [CalendarEventItem] = []
    @Published var authState: AuthState = .unknown

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private let cal = Calendar(identifier: .gregorian)

    init() {
        refreshAuthState()
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if authState == .authorized { refresh() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: 授权

    private func refreshAuthState() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: authState = .authorized
        case .denied, .restricted: authState = .denied
        case .notDetermined: authState = .notDetermined
        case .writeOnly: authState = .denied
        @unknown default: authState = .unknown
        }
    }

    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            // 用户拒绝或系统异常，状态刷新后界面会给出设置引导
        }
        refreshAuthState()
        if authState == .authorized { refresh() }
    }

    /// 打开系统设置的日历隐私页（被拒绝后引导用户手动开启）
    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: 读取

    /// 刷新窗口：今天往前 62 天、往后 93 天，覆盖今天页 / 14 天即将到来 / 前后月视图
    func refresh() {
        guard authState == .authorized else { return }
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -62, to: today),
              let end = cal.date(byAdding: .day, value: 94, to: today) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let fetched = store.events(matching: predicate)
        events = fetched.map(CalendarService.map).sorted { $0.start < $1.start }
    }

    func events(on day: Date) -> [CalendarEventItem] {
        events.filter { cal.isDate($0.start, inSameDayAs: day) }
    }

    // MARK: 写入

    /// 在默认日历新建日程，成功返回 true
    func createEvent(title: String, start: Date, end: Date, location: String?) -> Bool {
        guard authState == .authorized,
              let target = store.defaultCalendarForNewEvents else { return false }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        if let location, !location.isEmpty { event.location = location }
        event.calendar = target
        do {
            try store.save(event, span: .thisEvent)
            refresh()
            return true
        } catch {
            return false
        }
    }

    // MARK: 映射与会议识别

    private static func map(_ event: EKEvent) -> CalendarEventItem {
        let meeting = MeetingDetector.detect(in: event)
        return CalendarEventItem(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "（无标题）",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            location: cleanLocation(event.location),
            meetingProvider: meeting?.provider,
            meetingURL: meeting?.url,
            colorName: colorName(for: event.calendar)
        )
    }

    private static func cleanLocation(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.hasPrefix("http") { return nil }
        return t
    }

    /// 按日历颜色的色相映射到界面色板（近似即可）
    private static func colorName(for calendar: EKCalendar?) -> String {
        guard let cg = calendar?.cgColor,
              let ns = NSColor(cgColor: cg)?.usingColorSpace(.sRGB) else { return "blue" }
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0
        ns.getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)
        if sat < 0.25 { return "blue" }
        let deg = hue * 360
        switch deg {
        case ..<15, 345...: return "red"
        case 15..<45: return "orange"
        case 45..<70: return "yellow"
        case 70..<160: return "green"
        case 160..<255: return "blue"
        case 255..<290: return "purple"
        default: return "pink"
        }
    }
}

/// 会议链接识别：国行优先腾讯会议、飞书，其次 Zoom / Teams / Google Meet / Webex。
/// 链接可能在 event.url、地点、备注里；只有会议号没有链接时只报服务商、不给入会按钮。
enum MeetingDetector {
    static func detect(in event: EKEvent) -> (provider: String, url: URL?)? {
        var texts: [String] = []
        if let u = event.url { texts.append(u.absoluteString) }
        if let loc = event.location { texts.append(loc) }
        if let notes = event.notes { texts.append(notes) }
        texts.append(event.title ?? "")
        let joined = texts.joined(separator: "\n")

        let urls = extractURLs(from: joined)
        for url in urls {
            if let provider = provider(for: url) { return (provider, url) }
        }
        // 没有可入会链接时，识别服务商名称（如备注里只有腾讯会议号）
        if joined.contains("腾讯会议") { return ("腾讯会议", nil) }
        if joined.contains("飞书") || joined.contains("Feishu") { return ("飞书", nil) }
        if joined.contains("Zoom") { return ("Zoom", nil) }
        return nil
    }

    private static func provider(for url: URL) -> String? {
        let host = (url.host ?? "").lowercased()
        if host.contains("meeting.tencent.com") || host.contains("wemeet") { return "腾讯会议" }
        if host.contains("feishu") || host.contains("larksuite") || host.contains("lark") { return "飞书" }
        if host.contains("zoom.us") || host.contains("zoom.com") { return "Zoom" }
        if host.contains("teams.microsoft") || host.contains("teams.live") { return "Microsoft Teams" }
        if host.contains("meet.google") { return "Google Meet" }
        if host.contains("webex") { return "Webex" }
        return nil
    }

    private static func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { $0.url }
    }
}
