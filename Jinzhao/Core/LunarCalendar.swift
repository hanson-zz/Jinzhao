import Foundation

/// 农历信息。农历月/日与干支直接用系统中国历（Foundation .chinese），不引第三方库，国行设备离线可用。
struct LunarInfo: Equatable {
    let month: Int          // 1...12
    let day: Int            // 1...30
    let isLeapMonth: Bool
    let ganzhiYear: String  // 如「丙午」
    let zodiac: String      // 如「马」

    var monthText: String {
        let names = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        guard (1...12).contains(month) else { return "" }
        return (isLeapMonth ? "闰" : "") + names[month - 1] + "月"
    }

    var dayText: String { LunarCalendar.dayNames.indices.contains(day - 1) ? LunarCalendar.dayNames[day - 1] : "" }

    /// 「八月廿八」
    var shortText: String {
        let names = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        guard (1...12).contains(month) else { return dayText }
        return (isLeapMonth ? "闰" : "") + names[month - 1] + dayText
    }
}

enum LunarCalendar {
    static let chinese = Calendar(identifier: .chinese)

    static let dayNames = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                           "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                           "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]

    private static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let zodiacs = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

    static func info(for date: Date) -> LunarInfo {
        let c = chinese.dateComponents([.year, .month, .day, .isLeapMonth], from: date)
        // 系统中国历的 year 是六十甲子序数（1 = 甲子），据此推干支与生肖
        let cycle = c.year ?? 1
        let stem = stems[(cycle - 1) % 10]
        let branchIndex = (cycle - 1) % 12
        return LunarInfo(month: c.month ?? 1,
                         day: c.day ?? 1,
                         isLeapMonth: c.isLeapMonth ?? false,
                         ganzhiYear: stem + branches[branchIndex],
                         zodiac: zodiacs[branchIndex])
    }

    /// 在某个公历年里找农历某月某日（跳过闰月）。找不到返回 nil。
    /// 用逐日扫描实现，避免中国历 DateComponents 拼装的坑；一年最多 366 次，开销可忽略，结果按年缓存。
    private static var cache: [String: Date] = [:]

    static func gregorianDate(lunarMonth: Int, lunarDay: Int, inGregorianYear year: Int) -> Date? {
        let cacheKey = "\(year)-\(lunarMonth)-\(lunarDay)"
        if let hit = cache[cacheKey] { return hit }
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        guard var day = greg.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        let end = greg.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        while day < end {
            let c = chinese.dateComponents([.month, .day, .isLeapMonth], from: day)
            if c.month == lunarMonth, c.day == lunarDay, !(c.isLeapMonth ?? false) {
                cache[cacheKey] = day
                return day
            }
            day = greg.date(byAdding: .day, value: 1, to: day)!
        }
        return nil
    }
}
