import Foundation

// MARK: - holiday-cn 数据模型
// 数据来源：NateScarlet/holiday-cn（MIT）。JSON 按年份分文件：
// { "year": 2026, "papers": [...], "days": [ { "name": "国庆节", "date": "2026-10-10", "isOffDay": false } ] }
// isOffDay = true 是放假（休），false 是调休上班（班）。

struct HolidayDay: Codable, Equatable {
    let name: String
    let date: String      // "yyyy-MM-dd"
    let isOffDay: Bool
}

struct HolidayYearFile: Codable {
    let year: Int
    let days: [HolidayDay]
}

/// 某一天的角标
enum DayBadge: Equatable {
    case off(festival: String)   // 休
    case work(festival: String)  // 班
    case none                    // 普通工作日/周末，不加角标

    var text: String? {
        switch self {
        case .off: return "休"
        case .work: return "班"
        case .none: return nil
        }
    }
}

struct NextHoliday: Equatable {
    let name: String
    let date: Date
    let daysAway: Int
    /// true = 当年安排还没公布，日期是法定节日锚点，需标注「调休安排待公布」
    let arrangementPending: Bool
}

// MARK: - 节假日服务

/// 判断规则（定版，见 DECISIONS-v1.md）：
/// - 只查日期所在年份的文件；12 月显示次年 1 月时连带查次年文件（datesInSameStrip 一并加载）
/// - 数据里有这一天 → 休/班；没有 → 普通日，无角标（跟假期连着的周末也一样）
/// - 某年数据为空（如 2027）→ 不显示调休、不报错；「下一个假期」回退到法定节日锚点
final class HolidayService {
    /// [年份: [日期字符串: HolidayDay]]
    private var byYear: [Int: [String: HolidayDay]] = [:]
    private let calendar = Calendar(identifier: .gregorian)

    /// 从 App 包内 Resources/Holidays/*.json 加载（本地缓存的更新由 HolidayUpdater 写入后调用 reload 合并，缓存优先）
    init(bundle: Bundle = .main) {
        loadBundled(from: bundle)
    }

    init(directories: [URL]) {
        for dir in directories { loadDirectory(dir) }
    }

    // MARK: 加载

    func loadBundled(from bundle: Bundle) {
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Holidays") else { return }
        for url in urls { merge(fileURL: url) }
    }

    func loadDirectory(_ dir: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "json" { merge(fileURL: url) }
    }

    /// 合并一个年份文件。校验不过（解析失败、年份对不上、日期格式错）直接忽略，绝不让坏数据进库。
    /// 空数据不覆盖已有数据（拉到空数组时保留本地旧数据）。
    func merge(fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        merge(data: data)
    }

    func merge(data: Data) {
        guard let file = try? JSONDecoder().decode(HolidayYearFile.self, from: data),
              HolidayService.isValid(file) else { return }
        if file.days.isEmpty, byYear[file.year] != nil { return } // 空不覆盖
        var dict: [String: HolidayDay] = [:]
        for day in file.days { dict[day.date] = day }
        byYear[file.year] = dict
    }

    static func isValid(_ file: HolidayYearFile) -> Bool {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar(identifier: .gregorian)
        return file.days.allSatisfy { day in
            guard let d = fmt.date(from: day.date) else { return false }
            return cal.component(.year, from: d) == file.year
        }
    }

    // MARK: 查询

    func dayEntry(on date: Date) -> HolidayDay? {
        let year = calendar.component(.year, from: date)
        return byYear[year]?[HolidayService.key(for: date)]
    }

    func badge(on date: Date) -> DayBadge {
        guard let entry = dayEntry(on: date) else { return .none }
        return entry.isOffDay ? .off(festival: entry.name) : .work(festival: entry.name)
    }

    func isOffDay(on date: Date) -> Bool { dayEntry(on: date)?.isOffDay ?? false }

    /// 下一个假期：先在已有数据里找 date 之后第一段连休的第一天；
    /// 数据里找不到（比如次年安排未公布）→ 用法定节日锚点回退，并标 arrangementPending。
    func nextHoliday(after date: Date) -> NextHoliday? {
        let start = calendar.startOfDay(for: date)
        // 1) 数据路径
        var candidates: [Date] = []
        for (year, dict) in byYear where year >= calendar.component(.year, from: start) {
            for (key, day) in dict where day.isOffDay {
                if let d = HolidayService.date(fromKey: key), d > start { candidates.append(d) }
            }
        }
        if let first = candidates.sorted().first {
            // 回到这段连休的第一天
            var d = first
            while let prev = calendar.date(byAdding: .day, value: -1, to: d),
                  let e = dayEntry(on: prev), e.isOffDay {
                d = prev
            }
            let name = dayEntry(on: d)?.name ?? "假期"
            return NextHoliday(name: name, date: d,
                               daysAway: calendar.dateComponents([.day], from: start, to: d).day ?? 0,
                               arrangementPending: false)
        }
        // 2) 法定锚点回退
        let thisYear = calendar.component(.year, from: start)
        let anchors = (thisYear...(thisYear + 1)).flatMap { StatutoryAnchors.of(year: $0) }
            .sorted { $0.date < $1.date }
        guard let next = anchors.first(where: { $0.date > start }) else { return nil }
        return NextHoliday(name: next.name, date: next.date,
                           daysAway: calendar.dateComponents([.day], from: start, to: next.date).day ?? 0,
                           arrangementPending: true)
    }

    // MARK: 工具

    static func key(for date: Date) -> String {
        let c = Calendar(identifier: .gregorian)
        return String(format: "%04d-%02d-%02d",
                      c.component(.year, from: date),
                      c.component(.month, from: date),
                      c.component(.day, from: date))
    }

    static func date(fromKey key: String) -> Date? {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: key)
    }
}

// MARK: - 法定节日锚点（安排未公布时用）

/// 只给「下一个假期」做日期回退，不代表实际放假天数。
/// 公历锚点：元旦 1/1、劳动节 5/1、国庆 10/1；农历锚点：春节 正月初一、端午 五月初五、中秋 八月十五；清明为节气日，查节气表。
enum StatutoryAnchors {
    static func of(year: Int) -> [(name: String, date: Date)] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        func solar(_ m: Int, _ d: Int) -> Date? {
            cal.date(from: DateComponents(year: year, month: m, day: d))
        }
        var out: [(String, Date)] = []
        if let d = solar(1, 1) { out.append(("元旦", d)) }
        if let d = LunarCalendar.gregorianDate(lunarMonth: 1, lunarDay: 1, inGregorianYear: year) { out.append(("春节", d)) }
        if let d = SolarTermTable.date(of: "清明", year: year) { out.append(("清明节", d)) }
        if let d = solar(5, 1) { out.append(("劳动节", d)) }
        if let d = LunarCalendar.gregorianDate(lunarMonth: 5, lunarDay: 5, inGregorianYear: year) { out.append(("端午节", d)) }
        if let d = LunarCalendar.gregorianDate(lunarMonth: 8, lunarDay: 15, inGregorianYear: year) { out.append(("中秋节", d)) }
        if let d = solar(10, 1) { out.append(("国庆节", d)) }
        return out
    }
}
